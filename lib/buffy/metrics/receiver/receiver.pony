use "net"
use "collections"
use "buffy"
use "buffy/metrics"
use "buffy/flusher"
use "sendence/tcp"
use "sendence/bytes"
use "options"
use "time"

actor Receiver
  new create(env: Env) =>
    var required_args_are_present = true

    var listen_addr_arg: (Array[String] | None) = None
    var monhub_addr_arg: (Array[String] | None) = None
    var name_arg: (String | None) = None
    var period_arg: U64 = 1
    var delay_arg: (U64 | None) = None
    var report_file: (String | None) = None
    var report_period: U64 = 300

    try
      var options = Options(env)
      options
        .add("run-sink", "", None)
        .add("metrics-receiver", "r", None)
        .add("listen", "l", StringArgument)
        .add("monitor", "m", StringArgument)
        .add("name", "n", StringArgument)
        .add("period", "", I64Argument)
        .add("delay", "d", F64Argument)
        .add("report-file", "", StringArgument)
        .add("report-period", "", I64Argument)

      for option in options do
        match option
        | ("run-sink", None) => None
        | ("listen", let arg: String) => listen_addr_arg = arg.split(":")
        | ("monitor", let arg: String) => monhub_addr_arg = arg.split(":")
        | ("name", let arg: String) => name_arg = arg
        | ("period", let arg: I64) => period_arg = arg.u64()
        | ("delay", let arg: F64) => delay_arg = (arg*1_000_000_000).u64()
        | ("report-file", let arg: String) => report_file = arg
        | ("report-period", let arg: I64) => report_period = arg.u64()
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
        env.err.print("Must supply required '--monitor' argument")
      else
        if (monhub_addr_arg as Array[String]).size() != 2 then
          env.err.print(
            "'--monitor' argument should be in format '127.0.0.1:9999'")
          required_args_are_present = false
        end
      end

      if name_arg is None then name_arg = "" end
      if delay_arg is None then delay_arg = 1_000_000_000 end

      if ((delay_arg as U64)/1_000_000_000) < period_arg then
        env.err.print("'--delay' must be at least as large as '--period'.")
        required_args_are_present = false
      end

      if required_args_are_present then
        let auth = env.root as AmbientAuth
        let host = (listen_addr_arg as Array[String])(0)
        let service = (listen_addr_arg as Array[String])(1)
        let host' = (monhub_addr_arg as Array[String])(0)
        let service' = (monhub_addr_arg as Array[String])(1)
        let name' = recover val (name_arg as String).clone() end
        let delay' = recover val (delay_arg as U64) end

        // Create connections and actors here
        let collections: Array[MetricsCollection tag] trn =
          recover trn Array[MetricsCollection tag] end

        // MonitoringHub Output:
        let notifier: TCPConnectionNotify iso =
          recover MonitoringHubConnectNotify(env.out, env.err) end
        let conn = TCPConnection(auth, consume notifier, host', service')
        let output = MonitoringHubOutput(env.out, env.err, conn, name')
        let handler: MetricsOutputHandler val =
          MetricsOutputHandler(MonitoringHubEncoder, consume output, name')

        // Metrics Collection actor
        let bin_selector: F64Selector val = FixedBinSelector
        let mc = MetricsCollection(bin_selector, period_arg, handler)

        // start a timer to flush the metrics-collection
        Flusher(mc, delay')

        collections.push(consume mc)

        // File Output
        match report_file
        | let arg: String =>
          let output' = MetricsFileOutput(env.out, env.err, auth, name',
            arg)
          let handler': MetricsOutputHandler val =
            MetricsOutputHandler(MonitoringHubEncoder(false), consume output',
              name')
          let bin_selector': F64Selector val = FixedBinSelector
          let mc' = MetricsCollection(bin_selector', report_period, handler')

          // start a timer to flush the metrics-collection
          Flusher(mc', report_period)

          collections.push(consume mc')
          env.out.print("Reporting to file " + arg + " every " +
            report_period.string() + " seconds.")
        end

        // Metrics Receiver Listener
        let collections': Array[MetricsCollection tag] val =
          consume collections
        let notifier' = MetricsNotifier(env.out, env.err, auth, host,
                                        service, collections')
        let listener = TCPListener(auth, consume notifier', host, service)

        let receiver = MetricsReceiver(env.out, env.err, listener, collections')

      else
        env.out.print(
          """
          PARAMETERS:
          -----------------------------------------------------------------------------------
          --run-sink [Runs as sink node]
          --metrics-receiver/-r [Runs as metrics-receiver node]
          --listen [Listen address in xxx.xxx.xxx.xxx:pppp format]
          --monitor [Monitoring Hub address in xxx.xxx.xxx.xxx:pppp format]
          --name [Application name to report to Monitoring Hub]
          --period [Aggregation periods for reports to Monitoring Hub]
          --delay [Maximum period of time before sending data]
          --report-file/rf [File path to write reports to]
          --report-period/rp [Aggregation period for reports in report-file]
          """
        )
      end
    end

actor MetricsReceiver is FlushingActor
  let _stderr: StdStream
  let _stdout: StdStream
  let _handlers: Array[MetricsCollectionOutputHandler] ref =
    Array[MetricsCollectionOutputHandler]
  let _collections: Array[MetricsCollection tag] val
  let _listener: TCPListener

  new create(stdout: StdStream, stderr: StdStream, listener: TCPListener,
             collections: Array[MetricsCollection tag] val) =>
    _stdout = stdout
    _stderr = stderr
    _collections = collections
    _listener = listener

  be finished() =>
    _flush()
    _listener.dispose()
    for mc in _collections.values() do
      mc.dispose()
    end

  be flush() =>
    _flush()

  fun _flush() =>
    for mc in _collections.values() do
      mc.send_output()
    end


class MetricsNotifier is TCPListenNotify
  let _auth: AmbientAuth
  let _stdout: StdStream
  let _stderr: StdStream
  let _host: String
  let _service: String
  let _collections: Array[MetricsCollection tag] val

  new iso create(stdout: StdStream, stderr: StdStream, auth: AmbientAuth,
                 host: String, service: String,
                 collections: Array[MetricsCollection tag] val) =>
    _auth = auth
    _stdout = stdout
    _stderr = stderr
    _host = host
    _service = service
    _collections = collections

  fun ref listening(listen: TCPListener ref) =>
    _stdout.print("listening on " + _host + ":" + _service)

  fun ref not_listening(listen: TCPListener ref) =>
    _stderr.print("couldn't listen")
    listen.close()

  fun ref connected(listen: TCPListener ref) : TCPConnectionNotify iso^ =>
    MetricsReceiverNotify(_stdout, _stderr, _auth, _collections)

class MetricsReceiverNotify is TCPConnectionNotify
  let _auth: AmbientAuth
  let _stdout: StdStream
  let _stderr: StdStream
  let _decoder: MetricsMsgDecoder = MetricsMsgDecoder
  var _header: Bool = true
  let _collections: Array[MetricsCollection tag] val

  new iso create(stdout: StdStream, stderr: StdStream, auth: AmbientAuth,
                 collections: Array[MetricsCollection tag] val) =>
    _auth = auth
    _stdout = stdout
    _stderr = stderr
    _collections = collections


  fun ref accepted(conn: TCPConnection ref) =>
    conn.expect(4)
    _stdout.print("connection accepted")

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso) =>
    let d: Array[U8] val = consume data
    if _header then
      try
        let expect = Bytes.to_u32(d(0), d(1), d(2), d(3)).usize()
        conn.expect(expect)
        _header = false
      else
        _stderr.print("Blew up reading header from Buffy")
      end
    else
      handle_data(consume d)
      conn.expect(4)
      _header = true
    end

  fun ref handle_data(data: (Array[U8] val | Array[U8] iso)) =>
      let msg = _decoder(consume data, _auth)
      match msg
      | let m: NodeMetricsSummary val =>
        process_data(m)
      | let m: BoundaryMetricsSummary val =>
        process_data(m)
      else
        _stderr.print("Message couldn't be decoded!")
      end

  fun ref process_data(m: (NodeMetricsSummary val | BoundaryMetricsSummary val))
  =>
    for mc in _collections.values() do
      mc.process_summary(m)
    end

  fun ref connected(conn: TCPConnection ref) =>
    _stdout.print("connected.")

  fun ref connect_failed(conn: TCPConnection ref) =>
    _stdout.print("connection failed.")

  fun ref closed(conn: TCPConnection ref) =>
    _stdout.print("server closed")
