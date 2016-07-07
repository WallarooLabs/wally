use "net"
use "collections"
use "buffy"
use "buffy/metrics"
use "buffy/flusher"
use "buffy/sink-node"
use "sendence/tcp"
use "sendence/bytes"
use "options"
use "time"

actor Receiver
  new create(env: Env) =>
    var required_args_are_present = true

    var listen_addr_arg: (Array[String] | None) = None
    var monhub_addr_arg: (Array[String] | None) = None
    var app_name_arg: (String | None) = None
    var period_arg: U64 = 1_000_000_000
    var delay_arg: (U64 | None) = None
    var report_file: (String | None) = None
    var report_period: U64 = 300_000_000_000
    var phone_home_addr: (Array[String] | None) = None
    var name: String = "metrics-receiver"

    try
      var options = Options(env, false)
      options
        .add("run-sink", "", None)
        .add("metrics-receiver", "r", None)
        .add("listen", "l", StringArgument)
        .add("monitor", "m", StringArgument)
        .add("app-name", "a", StringArgument)
        .add("period", "e", I64Argument)
        .add("delay", "d", F64Argument)
        .add("report-file", "f", StringArgument)
        .add("report-period", "", I64Argument)
        .add("phone-home", "p", StringArgument)
        .add("name", "n", StringArgument)

      for option in options do
        match option
        | ("run-sink", None) => None
        | ("listen", let arg: String) => listen_addr_arg = arg.split(":")
        | ("monitor", let arg: String) => monhub_addr_arg = arg.split(":")
        | ("app-name", let arg: String) => app_name_arg = arg
        | ("period", let arg: I64) => period_arg = arg.u64()
        | ("delay", let arg: F64) => delay_arg = (arg*1_000_000_000).u64()
        | ("report-file", let arg: String) => report_file = arg
        | ("report-period", let arg: I64) =>
          report_period = (arg*1_000_000_000).u64()
        | ("phone-home", let arg: String) => phone_home_addr = arg.split(":")
        | ("name", let arg: String) => name = arg
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

      if phone_home_addr isnt None then
        if (phone_home_addr as Array[String]).size() != 2 then
          env.err.print(
            "'--phone-home' argument should be in format: '127.0.0.1:8080")
          required_args_are_present = false
        end
      end

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
        let app_name' = recover val (app_name_arg as String).clone() end
        let delay' = recover val (delay_arg as U64) end

        let coordinator = SinkNodeCoordinatorFactory(env, name, 
          phone_home_addr)

        // Create connections and actors here
        let collections: Array[MetricsCollection tag] trn =
          recover trn Array[MetricsCollection tag] end

        // MonitoringHub Output:
        let notifier: TCPConnectionNotify iso =
          recover MonitoringHubConnectNotify(env.out, env.err) end
        let conn = TCPConnection(auth, consume notifier, host', service')
        let output = MonitoringHubOutput(env.out, env.err, conn, app_name')
        let handler: MetricsOutputHandler val =
          MetricsOutputHandler(MonitoringHubEncoder, consume output, app_name')

        // Metrics Collection actor
        let bin_selector: F64Selector val = Log10Selector //FixedBinSelector
        let mc = MetricsCollection(bin_selector, period_arg, handler)

        // start a timer to flush the metrics-collection
        Flusher(mc, delay')

        collections.push(consume mc)

        // File Output
        match report_file
        | let arg: String =>
          let output' = MetricsFileOutput(env.out, env.err, auth, app_name',
            arg)
          let handler': MetricsOutputHandler val =
            MetricsOutputHandler(MonitoringHubEncoder(false), consume output',
              app_name')
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
                                        service, collections', coordinator)
        let listener = TCPListener(auth, consume notifier', host, service)

        let receiver = MetricsReceiver(env.out, env.err, listener, collections')


        // SignalHandler(TermHandler(coordinator), Sig.term())


      else
        env.out.print(
          """
          PARAMETERS:
          -----------------------------------------------------------------------------------
          --run-sink [Runs as sink node]
          --metrics-receiver/-r [Runs as metrics-receiver node]
          --listen [Listen address in xxx.xxx.xxx.xxx:pppp format]
          --monitor [Monitoring Hub address in xxx.xxx.xxx.xxx:pppp format]
          --app-name [Application name to report to Monitoring Hub]
          --period [Aggregation periods for reports to Monitoring Hub]
          --delay [Maximum period of time before sending data]
          --report-file/rf [File path to write reports to]
          --report-period/rp [Aggregation period for reports in report-file]
          --phone-home [Address on which Dagon is listening]
          --name [Name to use with Dagon receiver]
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
