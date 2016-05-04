use "net"
use "collections"
use "buffy/messages"
use "buffy/metrics"
use "sendence/bytes"
use "sendence/tcp"
use "time"

class SourceNotifier is TCPListenNotify
  let _env: Env
  let _auth: AmbientAuth
  let _host: String
  let _service: String
  let _source_id: I32
  let _step_manager: StepManager
  let _metrics_collector: MetricsCollector

  new iso create(env: Env, auth: AmbientAuth, source_host: String,
    source_service: String, source_id: I32, step_manager: StepManager,
    metrics_collector: MetricsCollector) =>
    _env = env
    _auth = auth
    _host = source_host
    _service = source_service
    _source_id = source_id
    _step_manager = step_manager
    _metrics_collector = metrics_collector

  fun ref listening(listen: TCPListener ref) =>
    _env.out.print("Source " + _source_id.string() + ": listening on " + _host + ":" + _service)

  fun ref not_listening(listen: TCPListener ref) =>
    _env.out.print("Source " + _source_id.string() + ": couldn't listen")
    listen.close()

  fun ref connected(listen: TCPListener ref) : TCPConnectionNotify iso^ =>
    SourceConnectNotify(_env, _auth, _source_id, _step_manager, _metrics_collector)

class SourceConnectNotify is TCPConnectionNotify
  var _msg_id: I32 = 0
  let _env: Env
  let _auth: AmbientAuth
  let _source_id: I32
  let _step_manager: StepManager
  let _metrics_collector: MetricsCollector
  let _framer: Framer = Framer

  new iso create(env: Env, auth: AmbientAuth, source_id: I32,
    step_manager: StepManager, metrics_collector: MetricsCollector) =>
    _env = env
    _auth = auth
    _source_id = source_id
    _step_manager = step_manager
    _metrics_collector = metrics_collector

  fun ref accepted(conn: TCPConnection ref) =>
    _env.out.print("Source " + _source_id.string() + ": connection accepted")

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso) =>
    for chunked in _framer.chunk(consume data).values() do
      try
        let msg = WireMsgDecoder(consume chunked)
        match msg
        | let m: ExternalMsg val =>
          let new_msg: Message[I32] val = Message[I32](_msg_id = _msg_id + 1, m.data.i32())
          _metrics_collector.report_boundary_metrics(BoundaryTypes.source().i32(),
            new_msg.id, Time.millis())
          _step_manager(_source_id, new_msg)
        | let m: UnknownMsg val =>
          _env.err.print("Unknown message type.")
        else
          _env.err.print("Source " + _source_id.string()
            + ": decoded message wasn't external.")
        end
      else
        _env.err.print("Error decoding incoming message.")
      end
    end

  fun ref connected(conn: TCPConnection ref) =>
    _env.out.print("Source " + _source_id.string() + ": connected.")

  fun ref connect_failed(conn: TCPConnection ref) =>
    _env.out.print("Source " + _source_id.string() + ": connection failed.")

  fun ref closed(conn: TCPConnection ref) =>
    _env.out.print("Source " + _source_id.string() + ": server closed")
