use "net"
use "collections"
use "sendence/dag"
use "sendence/guid"
use "sendence/queue"
use "sendence/messages"
use "wallaroo/backpressure"
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/network"
use "wallaroo/resilience"
use "wallaroo/topology"
use "wallaroo/tcp-sink"
use "wallaroo/tcp-source"

class LocalTopology
  let _app_name: String
  let _graph: Dag[StepInitializer val] val
  // _state_builders maps from state_name to StateSubpartition
  let _state_builders: Map[String, StateSubpartition val] val

  new val create(name': String, graph': Dag[StepInitializer val] val,
    state_builders': Map[String, StateSubpartition val] val)
  =>
    _app_name = name'
    _graph = graph'
    _state_builders = state_builders'

  fun update_state_map(state_map: Map[String, StateAddresses val],
    metrics_conn: TCPConnection, alfred: Alfred)
  =>
    for (state_name, subpartition) in _state_builders.pairs() do
      if not state_map.contains(state_name) then
        @printf[I32](("----Creating state steps for " + state_name + "----\n").cstring())
        state_map(state_name) = subpartition.build(metrics_conn, alfred)
      end
    end

  fun graph(): Dag[StepInitializer val] val => _graph

  fun name(): String => _app_name

  fun is_empty(): Bool =>
    _graph.is_empty()

actor LocalTopologyInitializer
  let _worker_name: String
  let _env: Env
  let _auth: AmbientAuth
  let _connections: Connections
  let _metrics_conn: TCPConnection
  let _alfred : Alfred tag
  let _is_initializer: Bool
  var _topology: (LocalTopology val | None) = None

  new create(worker_name: String, env: Env, auth: AmbientAuth,
    connections: Connections, metrics_conn: TCPConnection,
    is_initializer: Bool, alfred: Alfred tag)
  =>
    _worker_name = worker_name
    _env = env
    _auth = auth
    _connections = connections
    _metrics_conn = metrics_conn
    _is_initializer = is_initializer
    _alfred = alfred

  be update_topology(t: LocalTopology val) =>
    _topology = t

  be initialize(worker_initializer: (WorkerInitializer | None) = None) =>
    @printf[I32]("---------------------------------------------------------\n".cstring())
    @printf[I32]("|^|^|^Initializing Local Topology^|^|^|\n\n".cstring())
    try
      match _topology
      | let t: LocalTopology val =>
        if t.is_empty() then
          @printf[I32]("----This worker has no steps----\n".cstring())
        end

        // Make sure we only create shared state once and reuse it
        let state_map: Map[String, StateAddresses val] = state_map.create()

        // Keep track of all Steps by id so we can create a DataRouter
        // for the data channel boundary
        let routes: Map[U128, Step tag] trn =
          recover Map[U128, Step tag] end

        @printf[I32](("\nInitializing " + t.name() + " application locally:\n\n").cstring())

        // Create shared state for this topology
        t.update_state_map(state_map, _metrics_conn, _alfred)

        // We'll need to register our proxies later over Connections
        let proxies: Map[String, Array[Step tag]] = proxies.create()


        /////////
        // Initialize based on DAG
        //
        // Assumptions:
        //   I. Acylic graph
        //   II. No splits (only joins), ignoring partitions
        //   III. No direct chains of different partitions
        /////////

        let frontier = Queue[DagNode[StepInitializer val] val]

        let built = Map[U128, ...StepLike...]

        /////////
        // 1. Find graph sinks and add to frontier queue. 
        //    We'll work our way backwards.
        for node in t.graph().nodes() do
          if node.is_sink() then frontier.enqueue(node) end
        end

        /////////
        // 2. Loop: Check next frontier item for if all outgoing steps have 
        //          been created
        //       if no, send to back of frontier queue.
        //       if yes, add ins to frontier queue, then build the step 
        //       (connecting it to its out step, which has already been built)

        // If there are no cycles, this will terminate
        while frontier.size() > 0 do
          let next = frontier.dequeue()
          var ready = true
          for out in next.outs() do
            if not built.contains(out.id) then ready = false end
          end
          if ready then
            // ins can't be repeats here because there are no splits
            for in_node in next.ins() do
              frontier.enqueue(in_node)
            end
            let builder = next.value

            // ...match kind of initializer and go from there...

            built(builder.id()) = ...steplike...
          else
            frontier.enqueue(next)
          end
        end





        // // Create our sink or Proxy using this pipeline's egress builder
        // let sink_reporter = MetricsReporter(pipeline.name(), _metrics_conn)

        // // let sink = pipeline.egress_builder()(_worker_name,
        // //   consume sink_reporter, _auth, proxies)

        // // For each step initializer in this pipeline, build the step
        // // working backwards so we can plug later steps into earlier ones
        // let initializers = pipeline.initializers()
        // var initializer_idx = initializers.size()
        // var latest_router: Router val = DirectRouter(sink)
        // while initializer_idx > 0 do
        //   var initializer =
        //     try
        //       initializers((initializer_idx - 1).usize())
        //     else
        //       @printf[I32]("Initializers is empty when we expected one\n".cstring())
        //       error
        //     end

        //   match initializer
        //   | let p_builder: PartitionedPreStateStepBuilder val =>
        //     try
        //       let state_addresses = state_map(p_builder.state_name())

        //       @printf[I32](("----Spinning up partition for " + p_builder.name() + "----\n").cstring())
        //       let partition_router: PartitionRouter val =
        //         p_builder.build_partition(_worker_name, state_addresses,
        //           _metrics_conn, _auth, _connections, _alfred, latest_router)
        //       for (id, s) in partition_router.local_map().pairs() do
        //         routes(id) = s
        //       end
        //       latest_router = partition_router

        //       initializer_idx = initializer_idx - 1
        //     else
        //       _env.err.print("Missing state step for " + p_builder.state_name() + "!")
        //       error
        //     end
        //   | let builder: StepBuilder val =>
        //     if builder.is_stateful() then
        //       @printf[I32](("----Spinning up state for " + builder.name() + "----\n").cstring())
        //       let state_step = builder(EmptyRouter, _metrics_conn,
        //         pipeline.name(), _alfred)
        //       let state_step_router = DirectRouter(state_step)
        //       routes(builder.id()) = state_step

        //       initializer_idx = initializer_idx - 1

        //       // Before a non-partitioned state builder, we should
        //       // always have a non-partition pre-state builder
        //       try
        //         match initializers((initializer_idx - 1).usize())
        //         | let b: StepBuilder val =>
        //           @printf[I32](("----Spinning up " + b.name() + "----\n").cstring())
        //           let next_step = b(state_step_router, _metrics_conn,
        //             pipeline.name(), _alfred, latest_router)
        //           latest_router = DirectRouter(next_step)
        //           routes(b.id()) = next_step
        //         else
        //           @printf[I32]("Expected a StepBuilder\n".cstring())
        //           error
        //         end
        //       else
        //         @printf[I32]("Expected a pre state StepBuilder\n".cstring())
        //         error
        //       end
        //       initializer_idx = initializer_idx - 1
        //     else
        //       @printf[I32](("----Spinning up " + builder.name() + "----\n").cstring())
        //       let next_step = builder(latest_router, _metrics_conn,
        //         pipeline.name(), _alfred)
        //       latest_router = DirectRouter(next_step)
        //       routes(builder.id()) = next_step
        //       initializer_idx = initializer_idx - 1
        //     end
        //   end

        // end

        // // Create source if there is source data specified for this worker's
        // // portion of the pipeline
        // match pipeline.source_data()
        // | let sd: SourceData val =>
        //   let source_reporter = MetricsReporter(pipeline.name(),
        //     _metrics_conn)

        //   let listen_auth = TCPListenAuth(_auth)
        //   try
        //     @printf[I32](("----Creating source for " + pipeline.name() + " pipeline with " + sd.runner_builder().name() + "----\n").cstring())
        //     TCPSourceListener(sd.builder()(sd.runner_builder(),
        //       latest_router, _metrics_conn), _alfred,
        //       sd.address()(0), sd.address()(1))
        //   else
        //     @printf[I32]("Ill-formed source address\n".cstring())
        //   end
        // else
        //   @printf[I32]("No source data\n".cstring())
        // end

        _register_proxies(proxies)




        // If this is not the initializer worker, then create the data channel
        // incoming boundary
        if not _is_initializer then
          let data_notifier: TCPListenNotify iso =
            DataChannelListenNotifier(_worker_name, _env, _auth, _connections,
              _is_initializer, DataRouter(consume routes))
          _connections.register_listener(
            TCPListener(_auth, consume data_notifier)
          )
        end

        if _is_initializer then
          match worker_initializer
          | let wi: WorkerInitializer =>
            wi.topology_ready("initializer")
          else
            @printf[I32]("Need WorkerInitializer to inform that topology is ready\n".cstring())
          end
        else
          // Inform the initializer that we're done initializing our local
          // topology
          let topology_ready_msg = 
            try
              ChannelMsgEncoder.topology_ready(_worker_name, _auth)
            else
              @printf[I32]("ChannelMsgEncoder failed\n".cstring())
              error
            end
          _connections.send_control("initializer", topology_ready_msg)

          let ready_msg = ExternalMsgEncoder.ready(_worker_name)
          _connections.send_phone_home(ready_msg)
        end

        @printf[I32]("Local topology initialized\n".cstring())
      else
        @printf[I32]("Local Topology Initializer: No local topology to initialize\n".cstring())
      end

      @printf[I32]("\n|^|^|^Finished Initializing Local Topology^|^|^|\n".cstring())
      @printf[I32]("---------------------------------------------------------\n".cstring())
    else
      _env.err.print("Error initializing local topology")
    end

  // Connections knows how to plug proxies into other workers via TCP
  fun _register_proxies(proxies: Map[String, Array[Step tag]]) =>
    for (worker, ps) in proxies.pairs() do
      for proxy in ps.values() do
        _connections.register_proxy(worker, proxy)
      end
    end
