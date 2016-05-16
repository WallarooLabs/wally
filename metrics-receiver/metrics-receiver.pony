use "net"
use "collections"
use "buffy"
use "buffy/metrics"
use "sendence/tcp"
use "options"

actor Main
  new create(env: Env) =>
    var options = Options(env)
    var args = options.remaining()
    try
      let auth = env.root as AmbientAuth
      let addr: Array[String] = args(1).split(":")
      let host = addr(0)
      let service = addr(1)
      let name: String = args(2).clone()
      TCPListener(auth, Notifier(env, host, service, name), host, service)
    end

class Notifier is TCPListenNotify
  let _env: Env
  let _host: String
  let _service: String
  let _name: String

  new iso create(env: Env, host: String, service: String, name: String) =>
    _env = env
    _host = host
    _service = service
    _name = name

  fun ref listening(listen: TCPListener ref) =>
    _env.out.print("listening on " + _host + ":" + _service)

  fun ref not_listening(listen: TCPListener ref) =>
    _env.out.print("couldn't listen")
    listen.close()

  fun ref connected(listen: TCPListener ref) : TCPConnectionNotify iso^ =>
    MetricsReceiver(_env, _name)

class MetricsReceiver is TCPConnectionNotify
  let _env: Env
  let _framer: Framer = Framer
  let _period: U64 = 1
  let _bin_selector: F64Selector = Log10Selector
  let _mc: MetricsCollection
  let _handlers: Array[MetricsCollectionOutputHandler] = Array[MetricsCollectionOutputHandler]


  new iso create(env: Env, name: String) =>
    _env = env
    _mc = MetricsCollection(_bin_selector, _period)
    let output = MonitoringHubOutput(env, name)
    let encoder = MonitoringHubEncoder
    let handler = MetricsMonitoringHubHandler(encoder, output)
    _handlers.push(handler)

  fun ref accepted(conn: TCPConnection ref) =>
    _env.out.print("connection accepted")

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso) =>
    for chunked in _framer.chunk(consume data).values() do
      try
        let msg = ReportMsgDecoder(consume chunked)
        match msg
        | let m: NodeMetricsSummary val =>
          _mc(m)
        | let m: BoundaryMetricsSummary val =>
          _mc(m)
        else
          _env.err.print("Message couldn't be decoded!")
        end
      else
        _env.err.print("Error decoding incoming message.")
      end
    end
  fun ref connected(conn: TCPConnection ref) =>
    _env.out.print("connected.")

  fun ref connect_failed(conn: TCPConnection ref) =>
    _env.out.print("connection failed.")

  fun ref closed(conn: TCPConnection ref) =>
    _env.out.print("server closed")
