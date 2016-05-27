use "net"
use "collections"
use "buffy"
use "buffy/metrics"
use "sendence/tcp"
use "options"
use "time"


actor Main
  new create(env: Env) =>
    var required_args_are_present = true
    var run_tests = env.args.size() == 1

    if run_tests then
      TestMain(env)
    else
      var listen_addr_arg: (Array[String] | None) = None
      var monhub_addr_arg: (Array[String] | None) = None
      var name_arg: (String | None) = None
      var delay_arg: (U64 | None) = None

      try
        var options = Options(env)
        options
          .add("listen", "l", StringArgument)
          .add("monitor", "m", StringArgument)
          .add("name", "n", StringArgument)
          .add("delay", "d", F64Argument)

        for option in options do
          match option
          | ("listen", let arg: String) => listen_addr_arg = arg.split(":")
          | ("monitor", let arg: String) => monhub_addr_arg = arg.split(":")
          | ("name", let arg: String) => name_arg = arg
          | ("delay", let arg: F64) => delay_arg = (arg*1_000_000_000).u64()
          end
        end

        if listen_addr_arg is None then
          env.err.print("Must supply required '--listen' argument")
          required_args_are_present = false
        else
          if (listen_addr_arg as Array[String]).size() != 2 then
            env.err.print(
              "'--listen' argument should be in format '127.0.0.1:9999'")
            required_args_are_present = false
          end
        end

        if monhub_addr_arg is None then
          env.err.print("Must supply required --monitor' argument")
        else
          if (monhub_addr_arg as Array[String]).size() != 2 then
            env.err.print(
              "'--monitor' argument should be in format '127.0.0.1:9999'")
            required_args_are_present = false
          end
        end

        if name_arg is None then name_arg = "" end
        if delay_arg is None then delay_arg = 1_000_000_000 end

        if required_args_are_present then
          let auth = env.root as AmbientAuth
          let host = (listen_addr_arg as Array[String])(0)
          let service = (listen_addr_arg as Array[String])(1)
          let host' = (monhub_addr_arg as Array[String])(0)
          let service' = (monhub_addr_arg as Array[String])(1)
          let name' = recover val (name_arg as String).clone() end
          let delay' = recover val (delay_arg as U64) end

          let receiver = MetricsReceiver(env, auth, host, service, host',
                                         service', name')
          // start a timer to flush the receiver
          let timers = Timers
          let timer = Timer(FlushTimer(env, receiver), 0, delay')
          timers(consume timer)
        else
          env.err.print("FUBAR! FUBAR!")
        end
      end
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
