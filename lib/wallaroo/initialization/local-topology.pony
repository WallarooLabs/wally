use "net"
use "collections"
use "sendence/guid"
use "sendence/messages"
use "wallaroo/backpressure"
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/network"
use "wallaroo/topology"
use "wallaroo/tcp-sink"
use "wallaroo/tcp-source"

class ProxyAddress
  let worker: String
  let step_id: U128

  new val create(w: String, s_id: U128) =>
    worker = w
    step_id = s_id

class EgressBuilder
  let _addr: (Array[String] val | ProxyAddress val)
  let _sink_builder: (TCPSinkBuilder val | None)

  new val create(addr: (Array[String] val | ProxyAddress val), 
    sink_builder: (TCPSinkBuilder val | None) = None)
  =>
    _addr = addr
    _sink_builder = sink_builder

  fun apply(worker_name: String, reporter: MetricsReporter iso, 
    auth: AmbientAuth,
    proxies: Map[String, Array[Step tag]] = Map[String, Array[Step tag]]): 
    RunnableStep tag ?
  =>    
    match _addr
    | let a: Array[String] val =>
      try
        match _sink_builder
        | let tsb: TCPSinkBuilder val =>
          @printf[I32](("Connecting to sink at " + a(0) + ":" + a(1) + "\n").cstring())

          tsb(reporter.clone(), a(0), a(1))
        else
          EmptySink
        end
      else
        @printf[I32]("Error connecting to sink.\n".cstring())
        error
      end
    | let p: ProxyAddress val =>
      @printf[I32](("Creating Proxy to " + p.worker + "\n").cstring())
      let proxy = Proxy(worker_name, p.step_id, reporter.clone(), auth)
      let proxy_step = Step(consume proxy, consume reporter)
      if proxies.contains(worker_name) then
        proxies(p.worker).push(proxy_step)
      else
        proxies(p.worker) = Array[Step tag]
        proxies(p.worker).push(proxy_step)
      end
      proxy_step
    else
      // The match is exhaustive, so this can't happen
      @printf[I32]("Exhaustive match failed somehow\n".cstring())
      error
    end 

class LocalPipeline
  let _name: String
  let _initializers: Array[StepInitializer val] val
  let _source_data: (SourceData val | None)
  // _state_builders maps from state_name to StateSubpartition
  let _state_builders: Map[String, StateSubpartition val] val
  var _egress_builder: EgressBuilder val

  new val create(name': String, initializers': Array[StepInitializer val] val, 
    egress_builder': EgressBuilder val,
    source_data': (SourceData val | None) = None,
    state_builders': Map[String, StateSubpartition val] val) 
  =>
    _name = name'
    _initializers = initializers'
    _egress_builder = egress_builder'
    _source_data = source_data'
    _state_builders = state_builders'

  fun update_state_map(state_map: Map[String, StateAddresses val], 
    metrics_conn: TCPConnection) 
  =>
    for (state_name, subpartition) in _state_builders.pairs() do
      if not state_map.contains(state_name) then
        @printf[I32](("----Creating state steps for " + state_name + "----\n").cstring())
        state_map(state_name) = subpartition.build(metrics_conn)
      end
    end

  fun name(): String => _name
  fun initializers(): Array[StepInitializer val] val => _initializers
  fun egress_builder(): EgressBuilder val => _egress_builder
  fun source_data(): (SourceData val | None) => _source_data

class LocalTopology
  let _app_name: String
  let _pipelines: Array[LocalPipeline val] val

  new val create(app_name': String, pipelines': Array[LocalPipeline val] val)
  =>
    _app_name = app_name'
    _pipelines = pipelines'

  fun app_name(): String => _app_name

  fun pipelines(): Array[LocalPipeline val] val => _pipelines

  fun is_empty(): Bool =>
    var r = true
    for p in _pipelines.values() do
      if p.initializers().size() > 0 then r = false end
    end
    r

actor LocalTopologyInitializer
  let _worker_name: String
  let _env: Env
  let _auth: AmbientAuth
  let _connections: Connections
  let _metrics_conn: TCPConnection
  let _is_initializer: Bool
  var _topology: (LocalTopology val | None) = None

  new create(worker_name: String, env: Env, auth: AmbientAuth, 
    connections: Connections, metrics_conn: TCPConnection,
    is_initializer: Bool) 
  =>
    _worker_name = worker_name
    _env = env
    _auth = auth
    _connections = connections
    _metrics_conn = metrics_conn
    _is_initializer = is_initializer

  be update_topology(t: LocalTopology val) =>
    _topology = t

  be initialize() =>
    @printf[I32]("---------------------------------------------------------\n".cstring())
    @printf[I32]("|^|^|^Initializing Local Topology^|^|^|\n\n".cstring())
    try
      match _topology
      | let t: LocalTopology val =>
        @printf[I32](("Found " + t.pipelines().size().string() + " pipelines\n").cstring())

        if t.is_empty() then 
          @printf[I32]("----This worker has no steps----\n".cstring())
        end

        // Make sure we only create shared state once and reuse it
        let state_map: Map[String, StateAddresses val] = state_map.create()

        // Keep track of all Steps by id so we can create a DataRouter
        // for the data channel boundary
        let routes: Map[U128, Step tag] trn = 
          recover Map[U128, Step tag] end

        // Keep track of which source address we're using
        var source_addr_idx: USize = 0

        for pipeline in t.pipelines().values() do
          @printf[I32](("\nInitializing " + pipeline.name() + " pipeline:\n\n").cstring())

          // If need be, create shared state for this pipeline and add to our 
          // map
          pipeline.update_state_map(state_map, _metrics_conn)

          // We'll need to register our proxies later over Connections
          let proxies: Map[String, Array[Step tag]] = proxies.create()

          // Create our sink or Proxy using this pipeline's egress builder
          let sink_reporter = MetricsReporter(pipeline.name(), _metrics_conn)

          let sink = pipeline.egress_builder()(_worker_name, 
            consume sink_reporter, _auth, proxies)

          // For each step initializer in this pipeline, build the step
          // working backwards so we can plug later steps into earlier ones
          let initializers = pipeline.initializers()
          var initializer_idx = initializers.size()
          var latest_router: Router val = DirectRouter(sink)
          while initializer_idx > 0 do 
            var initializer = 
              try
                initializers((initializer_idx - 1).usize())
              else
                @printf[I32]("Initializers is empty when we expected one\n".cstring())
                error
              end

            match initializer
            | let p_builder: PartitionedPreStateStepBuilder val =>
              try
                let state_addresses = state_map(p_builder.state_name())

                @printf[I32](("----Spinning up partition for " + p_builder.name() + "----\n").cstring())
                let partition_router: PartitionRouter val =
                  p_builder.build_partition(_worker_name, state_addresses, 
                    _metrics_conn, _auth, _connections, latest_router)
                for (id, s) in partition_router.local_map().pairs() do 
                  routes(id) = s
                end
                latest_router = partition_router

                initializer_idx = initializer_idx - 1                
              else
                _env.err.print("Missing state step for " + p_builder.state_name() + "!")
                error
              end
            | let builder: StepBuilder val =>
              if builder.is_stateful() then
                @printf[I32](("----Spinning up state for " + builder.name() + "----\n").cstring())
                let state_step = builder(EmptyRouter, _metrics_conn, 
                  pipeline.name())
                let state_step_router = DirectRouter(state_step)
                routes(builder.id()) = state_step

                initializer_idx = initializer_idx - 1
                
                // Before a non-partitioned state builder, we should
                // always have a non-partition pre-state builder
                try
                  match initializers((initializer_idx - 1).usize())
                  | let b: StepBuilder val =>
                    @printf[I32](("----Spinning up " + b.name() + "----\n").cstring())
                    let next_step = b(state_step_router, _metrics_conn, 
                      pipeline.name(), latest_router)
                    latest_router = DirectRouter(next_step)
                    routes(b.id()) = next_step 
                  else
                    @printf[I32]("Expected a StepBuilder\n".cstring())
                    error
                  end
                else
                  @printf[I32]("Expected a pre state StepBuilder\n".cstring())
                  error
                end
                initializer_idx = initializer_idx - 1              
              else
                @printf[I32](("----Spinning up " + builder.name() + "----\n").cstring())
                let next_step = builder(latest_router, _metrics_conn, 
                  pipeline.name())
                latest_router = DirectRouter(next_step)
                routes(builder.id()) = next_step
                initializer_idx = initializer_idx - 1
              end
            end

          end  


                // SourceListenerNotify(sd.builder(), latest_router, 
                //   consume source_reporter),

          // Create source if there is source data specified for this worker's
          // portion of the pipeline
          match pipeline.source_data()
          | let sd: SourceData val =>
            let source_reporter = MetricsReporter(pipeline.name(), 
              _metrics_conn)

            let listen_auth = TCPListenAuth(_auth)
            try
              @printf[I32](("----Creating source for " + pipeline.name() + " pipeline with " + sd.runner_builder().name() + "----\n").cstring())
              TCPSourceListener(sd.builder()(sd.runner_builder(), 
                latest_router, _metrics_conn), 
                recover Array[CreditFlowConsumer] end, 
                sd.address()(0), sd.address()(1)) 
            else
              @printf[I32]("Ill-formed source address\n".cstring())
            end
          else
            @printf[I32]("No source data\n".cstring())
          end

          _register_proxies(proxies)
        end
        // We're done with all LocalPipelines

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
