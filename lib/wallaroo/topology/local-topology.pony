use "net"
use "collections"
use "sendence/guid"
use "sendence/messages"
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/network"

class ProxyAddress
  let worker: String
  let step_id: U128

  new val create(w: String, s_id: U128) =>
    worker = w
    step_id = s_id

class EgressBuilder
  let _addr: (Array[String] val | ProxyAddress val)
  let _sink_runner_builder: (SinkRunnerBuilder val | None)

  new val create(addr: (Array[String] val | ProxyAddress val), 
    sink_runner_builder: (SinkRunnerBuilder val | None) = None)
  =>
    _addr = addr
    _sink_runner_builder = sink_runner_builder

  fun apply(worker_name: String, reporter: MetricsReporter iso, 
    auth: AmbientAuth,
    proxies: Map[String, Array[Step tag]] = Map[String, Array[Step tag]]): 
    Step tag ?
  =>    
    match _addr
    | let a: Array[String] val =>
      try
        match _sink_runner_builder
        | let srb: SinkRunnerBuilder val =>
          let connect_auth = TCPConnectAuth(auth)
          let sink_name = "sink at " + a(0) + ":" + a(1)

          let out_conn = TCPConnection(connect_auth,
            OutNotify(sink_name), a(0), a(1))

          Step(srb(reporter.clone(), TCPRouter(out_conn,0)), consume reporter)
        else
          @printf[I32]("No sink runner builder!\n".cstring())
          error
        end
      else
        @printf[I32]("Error connecting to sink.\n".cstring())
        error
      end
    | let p: ProxyAddress val =>
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
      error
    end 

class LocalPipeline
  let _name: String
  let _builders: Array[StepBuilder val] val
  // var _sink_target_ids: Array[U64] val = recover Array[U64] end
  var _egress_builder: EgressBuilder val

  new val create(name': String, builders': Array[StepBuilder val] val, 
    egress_builder': EgressBuilder val) =>
    _name = name'
    _builders = builders'
    _egress_builder = egress_builder'

  fun name(): String => _name
  fun builders(): Array[StepBuilder val] val => _builders
  fun egress_builder(): EgressBuilder val => _egress_builder

class LocalTopology
  let _app_name: String
  let _pipelines: Array[LocalPipeline val] val

  new val create(app_name': String, pipelines': Array[LocalPipeline val] val)
  =>
    _app_name = app_name'
    _pipelines = pipelines'

  fun app_name(): String => _app_name

  fun pipelines(): Array[LocalPipeline val] val => _pipelines

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
    try
      match _topology
      | let t: LocalTopology val =>
        let routes: Map[U128, Step tag] trn = 
          recover Map[U128, Step tag] end
        for pipeline in t.pipelines().values() do
          let proxies: Map[String, Array[Step tag]] = proxies.create()

          let sink_reporter = MetricsReporter(pipeline.name(), _metrics_conn)

          let sink = pipeline.egress_builder()(_worker_name, 
            consume sink_reporter, _auth, proxies)

          let builders = pipeline.builders()
          var builder_idx = builders.size()
          var latest_step = sink
          while builder_idx > 0 do 
            let builder = builders((builder_idx - 1).usize())
            let next = DirectRouter(latest_step, builder_idx.u64())
            latest_step = builder(next, _metrics_conn, pipeline.name())
            routes(builder.id()) = latest_step
            builder_idx = builder_idx - 1
          end  

          _register_proxies(proxies)
        end

        if not _is_initializer then
          let data_notifier: TCPListenNotify iso =
            DataChannelListenNotifier(_worker_name, _env, _auth, _connections, 
              _is_initializer, DataRouter(consume routes))
          _connections.register_listener(
            TCPListener(_auth, consume data_notifier)
          )
        end

        let topology_ready_msg = 
          ChannelMsgEncoder.topology_ready(_worker_name, _auth)
        _connections.send_control("initializer", topology_ready_msg)

        let ready_msg = ExternalMsgEncoder.ready(_worker_name)
        _connections.send_phone_home(ready_msg)

        @printf[I32]("Local topology initialized\n".cstring())
      else
        @printf[I32]("Local Topology Initializer: No local topology to initialize\n".cstring())
      end
    else
      _env.err.print("Error initializing local topology")
    end

  fun _register_proxies(proxies: Map[String, Array[Step tag]]) =>
    for (worker, ps) in proxies.pairs() do
      for proxy in ps.values() do
        _connections.register_proxy(worker, proxy)
      end
    end
