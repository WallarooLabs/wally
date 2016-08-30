use "net"
use "options"
use "collections"
use "buffy/metrics"
use "buffy/flusher"
use "spike"
use "./network"
use "./topology"
use "time"
use "logger"

class StartupBuffyNode
  new create(env: Env, topology: Topology val, source_count: USize) =>
    var is_worker = true
    var worker_count: USize = 0
    var node_name: String = "0"
    var phone_home_addr = Array[String]
    var metrics_addr = Array[String]
    var metrics_period: U64 = 1_000_000_000
    var metrics_file: (String | None) = None
    var metrics_file_period: U64 = 300_000_000_000
    var options = Options(env, false)
    var leader_control_addr = Array[String]
    var leader_data_addr = Array[String]
    var source_addrs: Array[String] iso = recover Array[String] end
    var sink_addrs = Array[String]
    var app_name: String = ""
    var spike_delay = false
    var spike_drop = false
    var spike_seed: U64 = Time.millis()
    var log_level: LogLevel = Info

    options
      .add("leader", "l", None)
      .add("worker-count", "w", I64Argument)
      .add("phone-home", "p", StringArgument)
      .add("name", "n", StringArgument)
      .add("leader-control-address", "c", StringArgument)
      .add("leader-data-address", "d", StringArgument)
      // Comma-delimited source and sink addresses.
      // e.g. --source 127.0.0.1:6000,127.0.0.1:7000
      .add("source", "r", StringArgument)
      .add("sink", "k", StringArgument)
      .add("metrics", "m", StringArgument)
      .add("metrics-period", "", F64Argument)
      .add("metrics-file", "", StringArgument)
      .add("spike-delay", "", None)
      .add("spike-drop", "", None)
      .add("spike-seed", "", I64Argument)
      .add("app-name", "", StringArgument)
      .add("log-level", "", StringArgument)
      .add("help", "h", None)

    for option in options do
      match option
      | ("leader", None) => is_worker = false
      | ("leader-control-address", let arg: String) => leader_control_addr = arg.split(":")
      | ("leader-data-address", let arg: String) => leader_data_addr = arg.split(":")
      | ("worker-count", let arg: I64) => worker_count = arg.usize()
      | ("phone-home", let arg: String) => phone_home_addr = arg.split(":")
      | ("name", let arg: String) => node_name = arg
      | ("source", let arg: String) => source_addrs.append(arg.split(","))
      | ("sink", let arg: String) => sink_addrs.append(arg.split(","))
      | ("metrics", let arg: String) => metrics_addr = arg.split(":")
      | ("metrics-period", let arg: F64) =>
        metrics_period = (arg*1_000_000_000).u64()
      | ("metrics-file", let arg: String) => metrics_file = arg
      | ("spike-delay", None) =>
        spike_delay = true
      | ("spike-drop", None) =>
        spike_drop = true
      | ("spike-seed", let arg: I64) => spike_seed = arg.u64()
      | ("app-name", let arg: String) => app_name = arg
      | ("log-level", let arg: String) =>
        log_level = match arg
          | "fine" => Fine
          | "info" => Info
          | "warn" => Warn
          | "error" => Error
          else
            Info
          end
      | ("help", None) =>
        StartupHelp(env)
        return
      end
    end

    try
      let logger: Logger[String] = StringLogger(log_level, env.out, lambda(msg: String, loc: SourceLoc): String => "buffy: " + msg end)
      if not is_worker then node_name = "leader" end
      let leader_control_host = leader_control_addr(0)
      let leader_control_service = leader_control_addr(1)
      let leader_data_host = leader_data_addr(0)
      let leader_data_service = leader_data_addr(1)
      logger(Info) and logger.log("Using Spike seed " + spike_seed.string())
      let spike_config = SpikeConfig(spike_delay, spike_drop, spike_seed)
      let auth = env.root as AmbientAuth

      let sinks: Map[U64, (String, String)] iso =
        recover Map[U64, (String, String)] end

      for i in Range(0, sink_addrs.size()) do
        let sink_addr: Array[String] = sink_addrs(i).split(":")
        let sink_host = sink_addr(0)
        let sink_service = sink_addr(1)
        sinks(i.u64()) = (sink_host, sink_service)
      end

      var metrics_host: (String | None) = None
      var metrics_service: (String | None) = None
      if metrics_addr.size() > 0 then
        metrics_host = metrics_addr(0)
        metrics_service = metrics_addr(1)
      end
      let metrics_collector =
        if (((metrics_host isnt None) and (metrics_service isnt None)) or
          (metrics_file isnt None)) then
          MetricsCollector(auth
            where node_name=node_name, app_name=app_name,
            logger = logger,
            metrics_host=metrics_host, metrics_service=metrics_service,
            report_file=metrics_file, period=metrics_period)
        else
          None
        end

      let step_manager = StepManager(env, node_name, consume sinks,
        metrics_collector, logger)

      let timers = Timers
      match metrics_collector
      | let m: MetricsCollector tag =>
        Flusher(timers, m, metrics_period)
        Flusher(timers, step_manager, 1_000_000_000)
      end

      let coordinator: Coordinator = Coordinator(node_name, env, auth,
        leader_control_host, leader_control_service, leader_data_host,
        leader_data_service, step_manager, spike_config, metrics_collector,
        is_worker, logger)
      coordinator.add_timers(timers)

      let phone_home_host = phone_home_addr(0)
      let phone_home_service = phone_home_addr(1)

      let phone_home_conn: TCPConnection = TCPConnection(auth,
        HomeConnectNotify(env, node_name, coordinator, logger), phone_home_host,
          phone_home_service)

      coordinator.add_phone_home_connection(phone_home_conn)

      if is_worker then
        coordinator.add_listener(TCPListener(auth,
          ControlNotifier(env, auth, node_name, coordinator,
            metrics_collector, true, logger)))
        coordinator.add_listener(TCPListener(auth,
          WorkerIntraclusterDataNotifier(env, auth, node_name, leader_control_host,
            leader_control_service, coordinator, spike_config, logger)))
      else
        if source_addrs.size() != source_count then
          logger(Info) and logger.log("There are " + source_count.string() + " sources but "
            + source_addrs.size().string() + " source addresses specified.")
          return
        end
        // Set up source listeners
        // for i in Range(0, source_count) do
        //   let source_addr: Array[String] = source_addrs(i).split(":")
        //   let source_host = source_addr(0)
        //   let source_service = source_addr(1)
        //   let source_notifier: TCPListenNotify iso = SourceNotifier[String](
        //     env, source_host, source_service, i.u64(), 
        //     coordinator, IdentityParser, EmptyStep)
        //   coordinator.add_listener(TCPListener(auth, consume source_notifier,
        //     source_host, source_service))
        // end
        let topology_manager: TopologyManager = TopologyManager(env, auth,
          node_name, worker_count, leader_control_host, leader_control_service,
          leader_data_host, leader_data_service, coordinator, topology,
          consume source_addrs, logger)

        coordinator.add_topology_manager(topology_manager)

        // Set up leader listeners
        let control_notifier: TCPListenNotify iso =
          ControlNotifier(env, auth, node_name, coordinator,
          metrics_collector, false, logger)
        coordinator.add_listener(TCPListener(auth, consume control_notifier,
          leader_control_host, leader_control_service))
        let data_notifier: TCPListenNotify iso =
          LeaderIntraclusterDataNotifier(env, auth, node_name, coordinator,
          spike_config, logger)
        coordinator.add_listener(TCPListener(auth, consume data_notifier,
          leader_data_host, leader_data_service))
      end

      if is_worker then
        logger(Info) and logger.log("**Buffy Worker " + node_name + "**")
      else
        logger(Info) and logger.log("**Buffy Leader " + node_name + " control: "
          + leader_control_host + ":" + leader_control_service + "**")
        logger(Info) and logger.log("**Buffy Leader " + node_name + " data: "
          + leader_data_host + ":" + leader_data_service + "**")
        logger(Info) and logger.log("** -- Looking for " + worker_count.string()
          + " workers --**")
      end
    else
      StartupHelp(env)
    end
