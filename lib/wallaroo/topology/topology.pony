use "net"
use "collections"
use "sendence/guid"
use "wallaroo/metrics"
use "wallaroo/network"

class LocalTopology
  let _pipeline_name: String
  let _builders: Array[StepBuilder val] val
  let _local_sink: U64
  let _global_sink: Array[String] val

  new val create(p_name: String, bs: Array[StepBuilder val] val,
    local_sink: U64 = 0,
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

  fun sink(): (Array[String] val | U64) =>
    if _local_sink == 0 then
      _global_sink
    else
      _local_sink
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
        @printf[I32]("Local Topology Initializer: Initializing local topology\n".cstring())
        let routes: Map[U128, Step tag] trn = 
          recover Map[U128, Step tag] end

        let sink = _create_sink(t)  

        let builders = t.builders()
        var builder_idx: I64 = (builders.size() - 1).i64()
        var latest_step = sink
        while builder_idx >= 0 do 
          let builder = builders(builder_idx.usize())
          latest_step = builder(latest_step, _metrics_conn)
          routes(builder.id()) = latest_step
          builder_idx = builder_idx - 1
        end  

        if not _is_initializer then
          let data_notifier: TCPListenNotify iso =
            DataChannelListenNotifier(_worker_name, _env, _auth, _connections, 
              _is_initializer, DataRouter(consume routes))
          TCPListener(_auth, consume data_notifier)
        end
      else
        @printf[I32]("Local Topology Initializer: No local topology to initialize\n".cstring())
      end
    else
      _env.err.print("Error initializing local topology")
    end

  fun _create_sink(t: LocalTopology val): Step tag ? =>
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
    | let proxy_id: U64 =>
      @printf[I32]("Sink is a proxy id.\n".cstring())
      Step(SimpleSink(consume sink_reporter))
    else
      // The match is exhaustive, so this can't happen
      error
    end 