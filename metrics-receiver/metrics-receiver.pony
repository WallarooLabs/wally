use "net"
use "collections"
use "buffy"
use "buffy/metrics"
use "sendence/tcp"
use "options"
use "time"


actor Main
  new create(env: Env) =>
    var options = Options(env)
    var args = options.remaining()
    try
      let auth = env.root as AmbientAuth
      // Listening address
      let addr: Array[String] = args(1).split(":")
      let host = addr(0)
      let service = addr(1)

      // Monitoring Hub Address
      let addr': Array[String] = args(2).split(":")
      let host' = addr'(0)
      let service' = addr'(1)

      // Application name to report to Monitoring Hub
      let name': String = args(3).clone()

      let receiver = MetricsReceiver(env, auth, host, service, host',
                                     service', name')
      // start a timer to flush the receiver
      let timers = Timers
      let timer = Timer(FlushTimer(env, receiver), 0, 1_000_000_000)
      timers(consume timer)   
    end


actor MetricsReceiver
  let _env: Env
  let _handlers: Array[MetricsCollectionOutputHandler] ref =
    Array[MetricsCollectionOutputHandler]

  let _period: U64 = 1
  let _bin_selector: F64Selector val = Log10Selector
  let _mc: MetricsCollection tag
  let _listener: TCPListener

  new create(env: Env, auth: AmbientAuth, host: String, service: String,
             host': String, service': String, name': String) =>
    _env = env

    let output = MonitoringHubOutput(env, name', host', service')
    let handler: MetricsMonitoringHubHandler val = 
      MetricsMonitoringHubHandler(MonitoringHubEncoder, output)
    _mc = MetricsCollection(_bin_selector, _period, handler)
    _listener = TCPListener(auth, MetricsNotifier(env, host, service, _mc),
                            host, service)

  be finished() =>
    _listener.dispose()

  be flush() =>
    _mc.send_output()
    _env.out.print("flushed")

class MetricsNotifier is TCPListenNotify
  let _env: Env
  let _host: String
  let _service: String
  let _mc: MetricsCollection tag

  new iso create(env: Env, host: String, service: String,
                 mc: MetricsCollection tag) =>
    _env = env
    _host = host
    _service = service
    _mc = mc 

  fun ref listening(listen: TCPListener ref) =>
    _env.out.print("listening on " + _host + ":" + _service)

  fun ref not_listening(listen: TCPListener ref) =>
    _env.out.print("couldn't listen")
    listen.close()

  fun ref connected(listen: TCPListener ref) : TCPConnectionNotify iso^ =>
    MetricsReceiverNotify(_env, _mc)

class MetricsReceiverNotify is TCPConnectionNotify
  let _env: Env
  // TODO: Don't use Framer. Use "expect" from
  //       https://github.com/Sendence/buffy/blob/master/giles/receiver/giles-receiver.pony#L126
  let _framer: Framer = Framer
  let _mc: MetricsCollection tag

  new iso create(env: Env, mc: MetricsCollection tag) =>
    _env = env
    _mc = mc

  fun ref accepted(conn: TCPConnection ref) =>
    _env.out.print("connection accepted")

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso) =>
    for chunked in _framer.chunk(consume data).values() do
      try
        let msg = ReportMsgDecoder(consume chunked)
        match msg
        | let m: NodeMetricsSummary val =>
          _mc.process_summary(m)
        | let m: BoundaryMetricsSummary val =>
          _mc.process_summary(m)
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


class FlushTimer is TimerNotify  
  let _env: Env
  let _receiver: MetricsReceiver

  new iso create(env: Env, receiver: MetricsReceiver) =>
    _env = env
    _receiver = receiver

  fun ref apply(timer: Timer, count: U64): Bool =>
    _receiver.flush()
    true
