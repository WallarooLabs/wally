use "debug"
use "net"
use "collections"
use "buffy"
use "buffy/metrics"
use "buffy/flusher"
use "sendence/tcp"
use "sendence/bytes"
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

          // Create connections and actors here
          // MonitoringHub Output:
          let notifier: TCPConnectionNotify iso =
            recover MonitoringHubConnectNotify(env.out, env.err) end
          let conn = TCPConnection(auth, consume notifier, host', service')
          let output = MonitoringHubOutput(env.out, env.err, conn, name')
          let handler: MetricsMonitoringHubHandler val =
            MetricsMonitoringHubHandler(MonitoringHubEncoder, output)

          // Metrics Collection actor
          let period: U64 = 1
          let bin_selector: F64Selector val = Log10Selector
          let mc = MetricsCollection(bin_selector, period, handler)

          // Metrics Receiver Listener
          let notifier' = MetricsNotifier(env.out, env.err, auth, host,
                                          service, mc)
          let listener = TCPListener(auth, consume notifier', host, service)

          let receiver = MetricsReceiver(env.out, env.err, listener, mc)

          // start a timer to flush the receiver
          Flusher(receiver, delay')
        else
          env.err.print("FUBAR! FUBAR!")
        end
      end
    end

actor MetricsReceiver is FlushingActor
  let _stderr: StdStream
  let _stdout: StdStream
  let _handlers: Array[MetricsCollectionOutputHandler] ref =
    Array[MetricsCollectionOutputHandler]
  let _mc: MetricsCollection tag
  let _listener: TCPListener

  new create(stdout: StdStream, stderr: StdStream, listener: TCPListener,
             mc: MetricsCollection) =>
    _stdout = stdout
    _stderr = stderr
    _mc = mc
    _listener = listener


  be finished() =>
    _listener.dispose()

  be flush() =>
    _mc.send_output()


class MetricsNotifier is TCPListenNotify
  let _auth: AmbientAuth
  let _stdout: StdStream
  let _stderr: StdStream
  let _host: String
  let _service: String
  let _mc: MetricsCollection tag

  new iso create(stdout: StdStream, stderr: StdStream, auth: AmbientAuth,
                 host: String, service: String, mc: MetricsCollection tag) =>
    _auth = auth
    _stdout = stdout
    _stderr = stderr
    _host = host
    _service = service
    _mc = mc

  fun ref listening(listen: TCPListener ref) =>
    _stdout.print("listening on " + _host + ":" + _service)

  fun ref not_listening(listen: TCPListener ref) =>
    _stderr.print("couldn't listen")
    listen.close()

  fun ref connected(listen: TCPListener ref) : TCPConnectionNotify iso^ =>
    MetricsReceiverNotify(_stdout, _stderr, _auth, _mc)

class MetricsReceiverNotify is TCPConnectionNotify
  let _auth: AmbientAuth
  let _stdout: StdStream
  let _stderr: StdStream
  let _mc: MetricsCollection tag
  let _decoder: MetricsMsgDecoder = MetricsMsgDecoder
  var _header: Bool = true

  new iso create(stdout: StdStream, stderr: StdStream, auth: AmbientAuth,
                 mc: MetricsCollection tag) =>
    _auth = auth
    _stdout = stdout
    _stderr = stderr
    _mc = mc


  fun ref accepted(conn: TCPConnection ref) =>
    conn.expect(4)
    _stdout.print("connection accepted")

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso) =>
    let d: Array[U8] val = consume data
    Debug(d)
    if _header then
      try
        let expect = Bytes.to_u32(d(0), d(1), d(2), d(3)).usize()
        Debug("Expect: " + expect.string())
        conn.expect(expect)
        _header = false
      else
        _stderr.print("Blew up reading header from Buffy")
      end
    else
      Debug("length: " + d.size().string())
      process_data(consume d)
      conn.expect(4)
      _header = true
    end

  fun ref process_data(data: (Array[U8] val | Array[U8] iso)) =>
      let msg = _decoder(consume data, _auth)
      match msg
      | let m: NodeMetricsSummary val =>
        _mc.process_summary(m)
      | let m: BoundaryMetricsSummary val =>
        _mc.process_summary(m)
      else
        _stderr.print("Message couldn't be decoded!")
      end

  fun ref connected(conn: TCPConnection ref) =>
    _stdout.print("connected.")

  fun ref connect_failed(conn: TCPConnection ref) =>
    _stdout.print("connection failed.")

  fun ref closed(conn: TCPConnection ref) =>
    _stdout.print("server closed")
