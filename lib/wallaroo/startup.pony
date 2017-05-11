use "buffered"
use "collections"
use "files"
use "itertools"
use "net"
use "net/http"
use "time"
use "sendence/hub"
use "sendence/options"
use "wallaroo/boundary"
use "wallaroo/cluster_manager"
use "wallaroo/fail"
use "wallaroo/initialization"
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/network"
use "wallaroo/recovery"
use "wallaroo/topology"

actor Startup
  let _env: Env
  var _startup_options: StartupOptions = StartupOptions

  let _application: Application val
  let _app_name: (String | None)

  var _ph_host: String = ""
  var _ph_service: String = ""
  var _is_multi_worker: Bool = true
  var _worker_initializer: (WorkerInitializer | None) = None
  var _application_initializer: (ApplicationInitializer | None) = None
  var _swarm_manager_addr: String = ""
  var _event_log_file: String = ""
  var _local_topology_file: String = ""
  var _data_channel_file: String = ""
  var _control_channel_file: String = ""
  var _worker_names_file: String = ""
  var _connection_addresses_file: String = ""
  var _event_log: (EventLog | None) = None
  var _joining_listener: (TCPListener | None) = None

  new create(env: Env, application: Application val,
    app_name: (String | None))
  =>
    _env = env
    _application = application
    _app_name = app_name
    ifdef "resilience" then
      @printf[I32]("****RESILIENCE is active****\n".cstring())
    end
    ifdef "trace" then
      @printf[I32]("****TRACE is active****\n".cstring())
    end

    try
      let auth = _env.root as AmbientAuth
      _startup_options = WallarooConfig.wallaroo_args(_env.args)

      if _startup_options.is_swarm_managed then
        if _startup_options.a_arg is None then
          @printf[I32](("You must supply '--swarm-manager-address' if " +
            "passing '--swarm-managed'\n").cstring())
          error
        else
          let swarm_manager_url =
            URL.build(_startup_options.a_arg as String, false)
          if swarm_manager_url.is_valid() then
            _swarm_manager_addr = _startup_options.a_arg as String
          else
            @printf[I32](("You must provide a valid URL to " +
              "'--swarm-manager-address'\n").cstring())
            error
          end
        end
      end

      (_ph_host, _ph_service) =
        match _startup_options.p_arg
        | let addr: Array[String] =>
          try
            (addr(0), addr(1))
          else
            Fail()
            ("", "")
          end
        else
          ("", "")
        end

      let name = match _app_name
        | let n: String => n
        else
          ""
        end

      _event_log_file = _startup_options.resilience_dir + "/" + name + "-" +
        _startup_options.worker_name + ".evlog"
      _local_topology_file = _startup_options.resilience_dir
        + "/" + name + "-" + _startup_options.worker_name + ".local-topology"
      _data_channel_file = _startup_options.resilience_dir + "/" + name + "-" +
        _startup_options.worker_name + ".tcp-data"
      _control_channel_file = _startup_options.resilience_dir + "/" + name +
        "-" + _startup_options.worker_name + ".tcp-control"
      _worker_names_file = _startup_options.resilience_dir + "/" + name + "-" +
        _startup_options.worker_name + ".workers"
      _connection_addresses_file = _startup_options.resilience_dir + "/" +
        name + "-" + _startup_options.worker_name + ".connection-addresses"

      ifdef "resilience" then
        @printf[I32](("|||Resilience directory: " +
          _startup_options.resilience_dir + "|||\n").cstring())
      end

      if _startup_options.is_joining then
        @printf[I32]("New worker preparing to join cluster\n".cstring())
      else
        if _startup_options.worker_count == 1 then
          @printf[I32]("Single worker topology\n".cstring())
          _startup_options.is_initializer = true
          _is_multi_worker = false
        else
          @printf[I32]((_startup_options.worker_count.string() +
            " worker topology\n").cstring())
        end
      end

      if _startup_options.is_initializer then
        _startup_options.worker_name = "initializer"
      end

      // TODO: When we add full cluster join functionality, we will probably
      // need to break out initialization branches into primitives.
      // Currently a joining worker only nominally becomes part of the cluster.
      if _startup_options.is_joining then
        if _startup_options.worker_name == "" then
          @printf[I32](("You must specify a name for the worker " +
            "via the -n parameter.\n").cstring())
          error
        end
        let j_addr = _startup_options.j_arg as Array[String]
        let control_notifier: TCPConnectionNotify iso =
          JoiningControlSenderConnectNotifier(_env, auth,
            _startup_options.worker_name, this)
        let control_conn: TCPConnection =
          TCPConnection(auth, consume control_notifier, j_addr(0), j_addr(1))
        let cluster_join_msg =
          ChannelMsgEncoder.join_cluster(_startup_options.worker_name, auth)
        control_conn.writev(cluster_join_msg)
        @printf[I32]("Attempting to join cluster...\n".cstring())
        // This only exists to keep joining worker alive while it waits for
        // cluster information.
        // TODO: Eliminate the need for this.
        _joining_listener =
          TCPListener(auth, JoiningListenNotifier)
      else
        initialize()
      end
    else
      StartupHelp(_env)
    end

  be initialize() =>
    try
      let auth = _env.root as AmbientAuth

      let input_addrs: Array[Array[String]] val =
        (_startup_options.i_addrs_write = recover Array[Array[String]] end)
      let m_addr = _startup_options.m_arg as Array[String]
      let c_addr = _startup_options.c_arg as Array[String]
      let c_host = c_addr(0)
      let c_service = c_addr(1)
      let d_addr_ref = _startup_options.d_arg as Array[String]
      let d_addr_trn: Array[String] trn = recover Array[String] end
      d_addr_trn.push(d_addr_ref(0))
      d_addr_trn.push(d_addr_ref(1))
      let d_addr: Array[String] val = consume d_addr_trn
      let d_host = d_addr(0)
      let d_service = d_addr(1)

      let my_c_host = _startup_options.my_c_addr(0)
      let my_c_service = _startup_options.my_c_addr(1)
      let my_d_host = _startup_options.my_d_addr(0)
      let my_d_service = _startup_options.my_d_addr(1)

      let o_addr_ref = _startup_options.o_arg as Array[String]
      let o_addr_trn: Array[String] trn = recover Array[String] end
      o_addr_trn.push(o_addr_ref(0))
      o_addr_trn.push(o_addr_ref(1))
      let o_addr: Array[String] val = consume o_addr_trn

      if _startup_options.worker_name == "" then
        _env.out.print("You must specify a worker name via --worker-name/-n.")
        error
      end

      // TODO::joining
      let connect_auth = TCPConnectAuth(auth)
      let metrics_conn = MetricsSink(m_addr(0),
          m_addr(1), _application.name(), _startup_options.worker_name)

      var is_recovering: Bool = false

      // check to see if we can recover
      ifdef "resilience" then
        // Use Set to make the logic explicit and clear
        let existing_files: Set[String] = Set[String]

        let event_log_filepath: FilePath = FilePath(auth, _event_log_file)
        if event_log_filepath.exists() then
          existing_files.set(event_log_filepath.path)
        end

        let local_topology_filepath: FilePath = FilePath(auth,
          _local_topology_file)
        if local_topology_filepath.exists() then
          existing_files.set(local_topology_filepath.path)
        end

        let data_channel_filepath: FilePath = FilePath(auth,
          _data_channel_file)
        if data_channel_filepath.exists() then
          existing_files.set(data_channel_filepath.path)
        end

        let control_channel_filepath: FilePath = FilePath(auth,
          _control_channel_file)
        if control_channel_filepath.exists() then
          existing_files.set(control_channel_filepath.path)
        end

        let worker_names_filepath: FilePath = FilePath(auth,
          _worker_names_file)
        if worker_names_filepath.exists() then
          existing_files.set(worker_names_filepath.path)
        end

        let connection_addresses_filepath: FilePath = FilePath(auth,
          _connection_addresses_file)
        if connection_addresses_filepath.exists() then
          existing_files.set(connection_addresses_filepath.path)
        end

        let required_files: Set[String] = Set[String]
        required_files.set(event_log_filepath.path)
        required_files.set(local_topology_filepath.path)
        required_files.set(control_channel_filepath.path)
        required_files.set(worker_names_filepath.path)
        if not _startup_options.is_initializer then
          required_files.set(data_channel_filepath.path)
          required_files.set(connection_addresses_filepath.path)
        end

        // Only validate _all_ files exist if _any_ files exist.
        if existing_files.size() > 0 then
          // If any recovery file exists, but not all, then fail
          if (required_files.op_and(existing_files)) != required_files then
            @printf[I32](("Some resilience recovery files are missing! "
              + "Cannot continue!\n").cstring())
              let files_missing = required_files.without(existing_files)
              let files_missing_str: String val = "\n    ".join(
                Iter[String](files_missing.values()).collect(Array[String]))
              @printf[I32]("The missing files are:\n    %s\n".cstring(),
                files_missing_str.cstring())
            Fail()
          else
            @printf[I32]("Recovering from recovery files!\n".cstring())
            // we are recovering because all files exist
            is_recovering = true
          end
        end
      end

      _event_log = ifdef "resilience" then
          EventLog(_env, _event_log_file
            where backend_file_length = _startup_options.event_log_file_length)
        else
          EventLog(_env, None)
        end

      let connections = Connections(_application.name(),
        _startup_options.worker_name, _env,
        auth, c_host, c_service, d_host, d_service, _ph_host, _ph_service,
        metrics_conn, m_addr(0), m_addr(1), _startup_options.is_initializer,
        _connection_addresses_file, _startup_options.is_joining)

      let data_receivers = DataReceivers(auth,
        _startup_options.worker_name, connections, is_recovering)

      let router_registry = RouterRegistry(auth,
        _startup_options.worker_name, data_receivers,
        connections, _startup_options.stop_the_world_pause)

      let recovery_replayer = RecoveryReplayer(auth,
        _startup_options.worker_name, data_receivers, router_registry,
        connections, is_recovering)

      let recovery = Recovery(_startup_options.worker_name,
        _event_log as EventLog, recovery_replayer)

      let local_topology_initializer =
        if _startup_options.is_swarm_managed then
          let cluster_manager: DockerSwarmClusterManager =
            DockerSwarmClusterManager(auth, _swarm_manager_addr, c_service)
          LocalTopologyInitializer(
            _application, _startup_options.worker_name,
            _startup_options.worker_count, _env, auth, connections,
            router_registry, metrics_conn, _startup_options.is_initializer,
            data_receivers, _event_log as EventLog, recovery,
            recovery_replayer, input_addrs, _local_topology_file,
            _data_channel_file, _worker_names_file, cluster_manager)
        else
          LocalTopologyInitializer(
            _application, _startup_options.worker_name,
            _startup_options.worker_count, _env, auth, connections,
            router_registry, metrics_conn, _startup_options.is_initializer,
            data_receivers, _event_log as EventLog, recovery,
            recovery_replayer, input_addrs, _local_topology_file,
            _data_channel_file, _worker_names_file)
        end

      if _startup_options.is_initializer then
        _env.out.print("Running as Initializer...")
        _application_initializer = ApplicationInitializer(auth,
          local_topology_initializer, input_addrs, o_addr)
        match _application_initializer
        | let ai: ApplicationInitializer =>
          _worker_initializer = WorkerInitializer(auth,
            _startup_options.worker_name,
            _startup_options.worker_count, connections,
            ai, local_topology_initializer, d_addr,
            metrics_conn)
        end
        _startup_options.worker_name = "initializer"
      end

      let control_channel_filepath: FilePath = FilePath(auth,
        _control_channel_file)
      let control_notifier: TCPListenNotify iso =
        ControlChannelListenNotifier(_startup_options.worker_name,
          _env, auth, connections,
          _startup_options.is_initializer, _worker_initializer,
          local_topology_initializer,
          recovery_replayer, router_registry,
          control_channel_filepath, my_d_host, my_d_service)

      ifdef "resilience" then
        if _startup_options.is_initializer then
          connections.make_and_register_recoverable_listener(
            auth, consume control_notifier, control_channel_filepath,
            c_host, c_service)
        else
          connections.make_and_register_recoverable_listener(
            auth, consume control_notifier, control_channel_filepath,
            my_c_host, my_c_service)
        end
      else
        if _startup_options.is_initializer then
          connections.register_listener(
            TCPListener(auth, consume control_notifier, c_host, c_service))
        else
          connections.register_listener(
            TCPListener(auth, consume control_notifier, my_c_host,
              my_c_service))
        end
      end

      ifdef "resilience" then
        if is_recovering then
          // need to do this before recreating the data connection as at
          // that point replay starts
          let worker_names_filepath: FilePath = FilePath(auth,
            _worker_names_file)
          let recovered_workers = _recover_worker_names(
            worker_names_filepath)
          if _is_multi_worker then
            local_topology_initializer.recover_and_initialize(
              recovered_workers, _worker_initializer)
          else
            local_topology_initializer.initialize(where recovering = true)
          end
        end
      end

      if not is_recovering then
        match _worker_initializer
        | let w: WorkerInitializer =>
          w.start(_application)
        end
      end

      if _startup_options.is_joining then
        // Dispose of temporary listener
        match _joining_listener
        | let tcp_l: TCPListener =>
          tcp_l.dispose()
        else
          Fail()
        end
      end
    else
      StartupHelp(_env)
    end

  be complete_join(info_sending_host: String, m: InformJoiningWorkerMsg val) =>
    try
      let auth = _env.root as AmbientAuth

      let input_addrs: Array[Array[String]] val =
        (_startup_options.i_addrs_write = recover Array[Array[String]] end)

      let metrics_conn = MetricsSink(m.metrics_host, m.metrics_service,
        _application.name(), _startup_options.worker_name)

      // TODO: Are we creating connections to all addresses or just
      // initializer?
      (let c_host, let c_service) =
        if m.sender_name == "initializer" then
          (info_sending_host, m.control_addrs("initializer")._2)
        else
          m.control_addrs("initializer")
        end
      (let d_host, let d_service) =
        if m.sender_name == "initializer" then
          (info_sending_host, m.data_addrs("initializer")._2)
        else
          m.data_addrs("initializer")
        end

      let my_c_host = _startup_options.my_c_addr(0)
      let my_c_service = _startup_options.my_c_addr(1)
      let my_d_host = _startup_options.my_d_addr(0)
      let my_d_service = _startup_options.my_d_addr(1)

      let connections = Connections(_application.name(),
        _startup_options.worker_name, _env,
        auth, c_host, c_service, d_host, d_service, _ph_host, _ph_service,
        metrics_conn, m.metrics_host, m.metrics_service,
        _startup_options.is_initializer,
        _connection_addresses_file, _startup_options.is_joining)

      let data_receivers = DataReceivers(auth, _startup_options.worker_name, connections)

      let router_registry = RouterRegistry(auth,
        _startup_options.worker_name, data_receivers,
        connections, _startup_options.stop_the_world_pause)

      let recovery_replayer = RecoveryReplayer(auth,
        _startup_options.worker_name,
        data_receivers, router_registry, connections)

      let recovery = Recovery(_startup_options.worker_name,
        _event_log as EventLog, recovery_replayer)

      let local_topology_initializer = if _startup_options.is_swarm_managed then
        let cluster_manager: DockerSwarmClusterManager =
          DockerSwarmClusterManager(auth, _swarm_manager_addr, c_service)
        LocalTopologyInitializer(
          _application, _startup_options.worker_name,
          _startup_options.worker_count, _env, auth, connections,
          router_registry, metrics_conn,
          _startup_options.is_initializer, data_receivers,
          _event_log as EventLog, recovery, recovery_replayer, input_addrs,
          _local_topology_file, _data_channel_file, _worker_names_file,
          cluster_manager where is_joining = _startup_options.is_joining)
      else
        LocalTopologyInitializer(
          _application, _startup_options.worker_name,
          _startup_options.worker_count, _env, auth, connections,
          router_registry, metrics_conn,
          _startup_options.is_initializer, data_receivers,
          _event_log as EventLog, recovery, recovery_replayer, input_addrs,
          _local_topology_file, _data_channel_file, _worker_names_file
          where is_joining = _startup_options.is_joining)
      end

      router_registry.set_data_router(DataRouter)
      local_topology_initializer.update_topology(m.local_topology)
      local_topology_initializer.create_data_channel_listener(m.worker_names,
        my_d_host, my_d_service)

      // Prepare control and data addresses, but sub in correct host for
      // the worker that sent inform message (since it didn't know its
      // host string as seen externally)
      let control_addrs: Map[String, (String, String)] trn =
        recover Map[String, (String, String)] end
      let data_addrs: Map[String, (String, String)] trn =
        recover Map[String, (String, String)] end
      for (worker, addr) in m.control_addrs.pairs() do
        if m.sender_name == worker then
          control_addrs(worker) = (info_sending_host, addr._2)
        else
          control_addrs(worker) = addr
        end
      end
      for (worker, addr) in m.data_addrs.pairs() do
        if m.sender_name == worker then
          data_addrs(worker) = (info_sending_host, addr._2)
        else
          data_addrs(worker) = addr
        end
      end

      let control_channel_filepath: FilePath = FilePath(auth,
        _control_channel_file)
      let control_notifier: TCPListenNotify iso =
        ControlChannelListenNotifier(_startup_options.worker_name,
          _env, auth, connections,
          _startup_options.is_initializer, _worker_initializer,
          local_topology_initializer,
          recovery_replayer, router_registry, control_channel_filepath,
          my_d_host, my_d_service)

      ifdef "resilience" then
        connections.make_and_register_recoverable_listener(
          auth, consume control_notifier, control_channel_filepath,
          my_c_host, my_c_service)
      else
        connections.register_listener(
          TCPListener(auth, consume control_notifier, my_c_host,
            my_c_service))
      end

      // Call this on local topology initializer instead of Connections
      // directly to make sure messages are processed in the create
      // initialization order
      local_topology_initializer.create_connections(consume control_addrs,
        consume data_addrs)
      local_topology_initializer.quick_initialize_data_connections()

      // Dispose of temporary listener
      match _joining_listener
      | let tcp_l: TCPListener =>
        tcp_l.dispose()
      else
        Fail()
      end
    else
      Fail()
    end

  fun ref _recover_worker_names(worker_names_filepath: FilePath):
    Array[String] val
  =>
    """
    Read in a list of the names of all workers after recovery.
    """
    let ws: Array[String] trn = recover Array[String] end

    let file = File(worker_names_filepath)
    for worker_name in file.lines() do
      ws.push(worker_name)
      @printf[I32]("recover_worker_names: %s\n".cstring(),
        worker_name.cstring())
    end

    ws
