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

class LocalTopology
  let _pipeline_name: String
  let _builders: Array[StepBuilder val] val
  let _local_sink: (ProxyAddress val | None)
  let _global_sink: Array[String] val

  new val create(p_name: String, bs: Array[StepBuilder val] val,
    local_sink: (ProxyAddress val | None) = None,
    global_sink: Array[String] val = recover Array[String] end) 
  =>
    _pipeline_name = p_name
    _builders = bs
    _local_sink = local_sink
    _global_sink = global_sink

  fun pipeline_name(): String =>
    _pipeline_name

  fun builders(): Array[StepBuilder val] val =>
    _builders

  fun sink(): (Array[String] val | ProxyAddress val) =>
    match _local_sink
    | let p: ProxyAddress val => 
      p
    else
      _global_sink
    end

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
        let proxies: Map[String, Array[Step tag]] = proxies.create()

        let sink = _create_sink(t, proxies)  

        let builders = t.builders()
        var builder_idx: I64 = (builders.size() - 1).i64()
        var latest_step = sink
        while builder_idx >= 0 do 
          let builder = builders(builder_idx.usize())
          latest_step = builder(latest_step, _metrics_conn)
          routes(builder.id()) = latest_step
          builder_idx = builder_idx - 1
        end  

        _register_proxies(proxies)

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

  fun _create_sink(t: LocalTopology val, 
    proxies: Map[String, Array[Step tag]]): Step tag ? 
  =>
    let sink_reporter = MetricsReporter(t.pipeline_name(), _metrics_conn)
    
    match t.sink()
    | let addr: Array[String] val =>
      try
        let connect_auth = TCPConnectAuth(_auth)

        let out_conn = TCPConnection(connect_auth,
          OutNotify("results"), addr(0), addr(1))

        Step(EncoderSink(consume sink_reporter, out_conn))
      else
        _env.out.print("Error connecting to sink.")
        error
      end
    | let p: ProxyAddress val =>
      let proxy = Proxy(_worker_name, p.step_id, consume sink_reporter, _auth)
      let proxy_step = Step(consume proxy)
      if proxies.contains(_worker_name) then
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

  fun _register_proxies(proxies: Map[String, Array[Step tag]]) =>
    for (worker, ps) in proxies.pairs() do
      for proxy in ps.values() do
        _connections.register_proxy(worker, proxy)
      end
    end
