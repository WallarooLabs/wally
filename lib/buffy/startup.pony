use "net"
use "options"
use "collections"

actor Startup
  new create(env: Env, topology: Topology val, step_lookup: StepLookup val,
    source_count: USize) =>
    var is_worker = true
    var worker_count: USize = 0
    var node_name: String = "0"
    var phone_home_addr = Array[String]
    var options = Options(env)
    var leader_addr = Array[String]
    var source_addrs = Array[String]
    var sink_addrs = Array[String]

    options
      .add("leader", "l", None)
      .add("worker_count", "w", I64Argument)
      .add("phone_home", "p", StringArgument)
      .add("name", "n", StringArgument)
      // Comma-delimited source and sink addresses.
      // e.g. --source 127.0.0.1:6000,127.0.0.1:7000
      .add("leader-address", "", StringArgument)
      .add("source", "", StringArgument)
      .add("sink", "", StringArgument)

    for option in options do
      match option
      | ("leader", None) => is_worker = false
      | ("leader-address", let arg: String) => leader_addr = arg.split(":")
      | ("worker_count", let arg: I64) => worker_count = arg.usize()
      | ("phone_home", let arg: String) => phone_home_addr = arg.split(":")
      | ("name", let arg: String) => node_name = arg
      | ("source", let arg: String) => source_addrs.append(arg.split(","))
      | ("sink", let arg: String) => sink_addrs.append(arg.split(","))
      end
    end

    var args = options.remaining()

    try
      let auth = env.root as AmbientAuth
      let coordinator: Coordinator = Coordinator(node_name)
      let phone_home_host = phone_home_addr(0)
      let phone_home_service = phone_home_addr(1)

      let phone_home_conn: TCPConnection = TCPConnection(auth,
        HomeConnectNotify(env, node_name, coordinator), phone_home_host,
          phone_home_service)

      coordinator.add_phone_home_connection(phone_home_conn)

      let leader_host = leader_addr(0)
      let leader_service = leader_addr(1)

      let sinks: Map[I32, (String, String)] iso =
        recover Map[I32, (String, String)] end

      for i in Range(0, sink_addrs.size()) do
        let sink_addr: Array[String] = sink_addrs(i).split(":")
        let sink_host = sink_addr(0)
        let sink_service = sink_addr(1)
        env.out.print("Sink " + i.string())
        env.out.print(sink_host + ":" + sink_service)
        sinks(i.i32()) = (sink_host, sink_service)
      end

      let step_manager = StepManager(env, step_lookup, consume sinks)
      if is_worker then
        coordinator.add_listener(TCPListener(auth,
          WorkerNotifier(env, auth, node_name, leader_host, leader_service,
            phone_home_conn, step_manager, coordinator)))
      else
        if source_addrs.size() != source_count then
          env.out.print("There are " + source_count.string() + " sources but "
            + source_addrs.size().string() + " source addresses specified.")
          return
        end
        // Set up source listeners
        for i in Range(0, source_count) do
          let source_addr: Array[String] = source_addrs(i).split(":")
          let source_host = source_addr(0)
          let source_service = source_addr(1)
          let source_notifier: TCPListenNotify iso = SourceNotifier(env, auth,
            source_host, source_service, i.i32(), step_manager, coordinator)
          coordinator.add_listener(TCPListener(auth, consume source_notifier,
            source_host, source_service))
        end
        // Set up leader listener
        let topology_manager: TopologyManager = TopologyManager(env, auth,
          node_name, worker_count, leader_host, leader_service, phone_home_conn,
          step_manager, coordinator, topology)

        coordinator.add_topology_manager(topology_manager)

        let notifier: TCPListenNotify iso = LeaderNotifier(env, auth, node_name,
          leader_host, leader_service, step_manager, coordinator,
          topology_manager)
        coordinator.add_listener(TCPListener(auth, consume notifier, leader_host,
          leader_service))
      end

      if is_worker then
        env.out.print("**Buffy Worker " + node_name + "**")
      else
        env.out.print("**Buffy Leader " + node_name + " at " + leader_host + ":"
          + leader_service + "**")
        env.out.print("** -- Looking for " + worker_count.string()
          + " workers --**")
      end
    else
      TestMain(env)
      env.out.print("Parameters: leader_address [-l -w <worker_count>"
        + "-p <phone_home_address> --id <node_name>]")
    end

