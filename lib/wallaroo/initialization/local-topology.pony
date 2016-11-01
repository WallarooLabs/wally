use "net"
use "collections"
use "promises"
use "sendence/dag"
use "sendence/guid"
use "sendence/queue"
use "sendence/messages"
use "wallaroo/backpressure"
use "wallaroo/boundary"
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
  let _worker_count: USize
  let _env: Env
  let _auth: AmbientAuth
  let _connections: Connections
  let _metrics_conn: TCPConnection
  let _alfred : Alfred tag
  let _is_initializer: Bool
  var _outgoing_boundaries: Map[String, OutgoingBoundary] val = 
    recover Map[String, OutgoingBoundary] end
  var _topology: (LocalTopology val | None) = None
  let _data_receivers: Map[String, DataReceiver] = _data_receivers.create()

  new create(worker_name: String, worker_count: USize, env: Env, 
    auth: AmbientAuth, connections: Connections, metrics_conn: TCPConnection,
    is_initializer: Bool, alfred: Alfred tag)
  =>
    _worker_name = worker_name
    _worker_count = worker_count
    _env = env
    _auth = auth
    _connections = connections
    _metrics_conn = metrics_conn
    _is_initializer = is_initializer
    _alfred = alfred

  be update_topology(t: LocalTopology val) =>
    _topology = t

  be update_boundaries(bs: Map[String, OutgoingBoundary] val) =>
    _outgoing_boundaries = bs

  be create_data_receivers(ws: Array[String] val) =>
    let drs: Map[String, DataReceiver] trn = 
      recover Map[String, DataReceiver] end

    for w in ws.values() do
      if w != _worker_name then
        let data_receiver = DataReceiver(_connections, _alfred)
        drs(w) = data_receiver
        _data_receivers(w) = data_receiver
      end
    end

    let data_receivers: Map[String, DataReceiver] val = consume drs 

    if not _is_initializer then
      let data_notifier: TCPListenNotify iso =
        DataChannelListenNotifier(_worker_name, _env, _auth, _connections,
          _is_initializer, data_receivers)
      _connections.register_listener(
        TCPListener(_auth, consume data_notifier))
    else
      _connections.create_initializer_data_channel(data_receivers)
    end

  be initialize(worker_initializer: (WorkerInitializer | None) = None) =>
    @printf[I32]("---------------------------------------------------------\n".cstring())
    @printf[I32]("|^|^|^Initializing Local Topology^|^|^|\n\n".cstring())
    try
      if (_worker_count > 1) and (_outgoing_boundaries.size() == 0) then
        @printf[I32]("Outgoing boundaries not set up!\n".cstring())
        error
      end

      // TODO: Check if we are recovering (have a saved LocalTopology)
      // and if so read and load it

      match _topology
      | let t: LocalTopology val =>
        // TODO: Write LocalTopology (t) to disk

        if t.is_empty() then
          @printf[I32]("----This worker has no steps----\n".cstring())
        end

        let graph = t.graph()

        @printf[I32]("Creating graph:\n".cstring())
        @printf[I32]((graph.string() + "\n").cstring())

        // Make sure we only create shared state once and reuse it
        let state_map: Map[String, StateAddresses val] = state_map.create()

        // Keep track of all Steps by id so we can create a DataRouter
        // for the data channel boundary
        let data_routes: Map[U128, Step tag] trn =
          recover Map[U128, Step tag] end

        @printf[I32](("\nInitializing " + t.name() + " application locally:\n\n").cstring())

        // Create shared state for this topology
        t.update_state_map(state_map, _metrics_conn, _alfred)

        // // We'll need to register our proxies later over Connections
        // let proxies: Map[String, Array[Step tag]] = proxies.create()

        // Keep track of everything we need to call initialize() on when
        // we're done
        let initializables: Array[Initializable tag] = initializables.create()


        /////////
        // Initialize based on DAG
        //
        // Assumptions:
        //   I. Acylic graph
        //   II. No splits (only joins), ignoring partitions
        //   III. No direct chains of different partitions
        /////////

        let frontier = Queue[DagNode[StepInitializer val] val]

        let built = Map[U128, Router val]

        /////////
        // 1. Find graph sinks and add to frontier queue. 
        //    We'll work our way backwards. 
        @printf[I32]("Adding sink nodes to frontier\n".cstring())
        for node in graph.nodes() do
          if node.is_sink() then 
            @printf[I32](("Adding " + node.value.name() + " node to frontier\n").cstring())
            frontier.enqueue(node) 
          end
        end

        /////////
        // 2. Loop: Check next frontier item for if all outgoing steps have 
        //          been created
        //       if no, send to back of frontier queue.
        //       if yes, add ins to frontier queue, then build the step 
        //       (connecting it to its out step, which has already been built)

        // If there are no cycles (I), this will terminate
        while frontier.size() > 0 do
          let next_node = frontier.dequeue()

          if built.contains(next_node.id) then
            // We've already handled this node (probably because it's 
            // pre-state)
            continue
          end

          // We are only ready to build a node if all of its outputs
          // have been built (though currently, because there are no
          // splits (II), there will only be at most one output per node)
          var ready = true
          for out in next_node.outs() do
            if not built.contains(out.id) then ready = false end
          end
          if ready then
            let next_initializer: StepInitializer val = next_node.value

            // ...match kind of initializer and go from there...
            match next_initializer
            | let builder: StepBuilder val =>              
              let next_id = builder.id()

              if not builder.is_stateful() then
                @printf[I32](("----Spinning up " + builder.name() + "----\n").cstring())
                // Currently there are no splits (II), so we know that a node // has only one output in the graph. We also know this is not
                // a sink or proxy, so there is exactly one output.
                let out_id: U128 = _get_output_node_id(next_node)

                let out_router = 
                  try
                    built(out_id)
                  else
                    @printf[I32]("Invariant was violated: node was not built before one of its inputs.\n".cstring())
                    error 
                  end

                let next_step = builder(out_router, _metrics_conn, _alfred)
                data_routes(next_id) = next_step
                initializables.push(next_step)

                let next_router = DirectRouter(next_step)
                built(next_id) = next_router
              else
                // Our step is stateful and non-partitioned, so we need to 
                // build both a state step and a prestate step
           
                // First, we must check that all state computation targets
                // have been built.  If they haven't, then we send this node
                // to the back of the frontier queue (it will eventually
                // be processed because of no splits (II))
                var targets_ready = true
                for in_node in next_node.ins() do
                  match in_node.value.pre_state_target_id()
                  | let id: U128 =>
                    try
                      built(id)
                    else
                      targets_ready = false
                    end
                  end
                end

                if not targets_ready then
                  frontier.enqueue(next_node)
                  continue
                end
                

                @printf[I32](("----Spinning up state for " + builder.name() + "----\n").cstring())
                let state_step = builder(EmptyRouter, _metrics_conn, _alfred)
                data_routes(next_id) = state_step
                initializables.push(state_step)

                let state_step_router = DirectRouter(state_step)
                built(next_id) = state_step_router

                // Before a non-partitioned state builder, we should
                // always have one or more non-partitioned pre-state builders.
                // The only inputs coming into a state builder should be
                // prestate builder, so we're going to build them all
                for in_node in next_node.ins() do
                  match in_node.value
                  | let b: StepBuilder val =>
                    @printf[I32](("----Spinning up " + b.name() + "----\n").cstring())

                    let state_comp_target = 
                      match b.pre_state_target_id()
                      | let id: U128 =>
                        try
                          built(id)
                        else
                          @printf[I32]("Prestate comp target not built! We should have already caught this\n".cstring())
                          error
                        end
                      else
                        EmptyRouter
                      end

                    let pre_state_step = b(state_step_router, _metrics_conn,
                      _alfred, state_comp_target)
                    data_routes(b.id()) = pre_state_step                    
                    initializables.push(pre_state_step)

                    let pre_state_router = DirectRouter(pre_state_step)
                    built(b.id()) = pre_state_router

                    state_step.register_routes(state_comp_target, 
                      b.forward_route_builder())

                    // Add ins to this prestate node to the frontier
                    for in_in_node in in_node.ins() do
                      if not built.contains(in_in_node.id) then
                        frontier.enqueue(in_in_node)
                      end
                    end

                    @printf[I32](("Finished handling " + in_node.value.name() + " node\n").cstring())
                  else
                    @printf[I32]("State steps should only have prestate predecessors!\n".cstring())
                    error
                  end
                end
              end
            | let p_builder: PartitionedPreStateStepBuilder val =>
              let next_id = p_builder.id()

              try
                let state_addresses = state_map(p_builder.state_name())

                @printf[I32](("----Spinning up partition for " + p_builder.name() + "----\n").cstring())

                let state_comp_target = 
                  match p_builder.pre_state_target_id()
                  | let id: U128 =>
                    try
                      built(id)
                    else
                      @printf[I32]("Prestate comp target not built!\n".cstring())
                      error
                    end
                  else
                    EmptyRouter
                  end

                state_addresses.register_routes(state_comp_target,
                   p_builder.forward_route_builder())

                let partition_router: PartitionRouter val =
                  p_builder.build_partition(_worker_name, state_addresses,
                    _metrics_conn, _auth, _connections, _alfred, 
                    state_comp_target)
                
                // Create a data route to each pre-state step in the 
                // partition located on this worker
                for (id, s) in partition_router.local_map().pairs() do
                  data_routes(id) = s
                  initializables.push(s)
                end
                // Add the partition router to our built list for nodes
                // that connect to this node via an in edge and to prove
                // we've handled it
                built(next_id) = partition_router
              else
                _env.err.print("Missing state step for " + p_builder.state_name() + "!")
                error
              end
            | let egress_builder: EgressBuilder val =>
              let next_id = egress_builder.id()

              let sink_reporter = MetricsReporter(
                egress_builder.pipeline_name(), _metrics_conn)

              // Create a sink or OutgoingBoundary proxy. 
              let sink = egress_builder(_worker_name,
                consume sink_reporter, _auth, _outgoing_boundaries)

              initializables.push(sink)

              let sink_router = 
                match sink
                | let ob: OutgoingBoundary =>
                  match egress_builder.target_address()
                  | let pa: ProxyAddress val =>
                    ProxyRouter(_worker_name, ob, pa, _auth)
                  else
                    @printf[I32]("No ProxyAddress for proxy!\n".cstring())
                    error
                  end
                else
                  DirectRouter(sink)
                end

              built(next_id) = sink_router
            | let source_data: SourceData val =>
              let next_id = source_data.id()
              let pipeline_name = source_data.pipeline_name()

              // Currently there are no splits (II), so we know that a node has
              // only one output in the graph. We also know this is not
              // a sink or proxy, so there is exactly one output.
              let out_id: U128 = _get_output_node_id(next_node)
              let out_router = 
                try
                  built(out_id)
                else
                  @printf[I32]("Invariant was violated: node was not built before one of its inputs.\n".cstring())
                  error 
                end

              let source_reporter = MetricsReporter(pipeline_name, 
                _metrics_conn)

              // TODO: How do we add an Initializable to our list for 
              // the Source?

              let listen_auth = TCPListenAuth(_auth)
              try
                @printf[I32](("----Creating source for " + pipeline_name + " pipeline with " + source_data.name() + "----\n").cstring())
                TCPSourceListener(
                  source_data.builder()(source_data.runner_builder(), 
                    out_router, _metrics_conn),
                  out_router,
                  source_data.route_builder(),
                  _alfred, 
                  source_data.address()(0), 
                  source_data.address()(1))
              else
                @printf[I32]("Ill-formed source address\n".cstring())
              end

              // Nothing connects to a source via an in edge locally,
              // so this just marks that we've built this one
              built(next_id) = EmptyRouter
            end

            // Add all the nodes with incoming edges to next_node to the
            // frontier
            for in_node in next_node.ins() do
              if not built.contains(in_node.id) then
                frontier.enqueue(in_node)
              end
            end

            @printf[I32](("Finished handling " + next_node.value.name() + " node\n").cstring())
          else
            frontier.enqueue(next_node)
          end
        end

        let data_router = DataRouter(consume data_routes)
        for receiver in _data_receivers.values() do
          receiver.update_router(data_router)
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

        // Initialize all our initializables to get backpressure started
        for i in initializables.values() do
          i.initialize()
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

  fun _get_output_node_id(node: DagNode[StepInitializer val] val): U128 ? =>
    // Currently there are no splits (II), so we know that a node has
    // only one output in the graph. 

    // Make sure this is not a sink or proxy node. 
    match node.value
    | let eb: EgressBuilder val =>
      @printf[I32]("Sinks and Proxies have no output nodes in the local graph!\n".cstring())
      error 
    end

    // Since this is not a sink or proxy, there should be exactly one 
    // output.
    var out_id: U128 = 0
    for out in node.outs() do
      out_id = out.id
    end
    if out_id == 0 then
      @printf[I32]("Invariant was violated: non-sink node had no output node.\n".cstring())
      error
    end
    out_id

  // Connections knows how to plug proxies into other workers via TCP
  // fun _register_proxies(proxies: Map[String, Array[Step tag]]) =>
  //   for (worker, ps) in proxies.pairs() do
  //     for proxy in ps.values() do
  //       _connections.register_proxy(worker, proxy)
  //     end
  //   end
