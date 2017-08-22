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
use "wallaroo/ent/data_receiver"
use "wallaroo/ent/cluster_manager"
use "wallaroo/fail"
use "wallaroo/initialization"
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/ent/network"
use "wallaroo/recovery"
use "wallaroo/spike"
use "wallaroo/topology"

actor Startup
  let _env: Env
  var _startup_options: StartupOptions = StartupOptions

  let _application: Application val
  let _app_name: (String | None)

  var _ph_host: String = ""
  var _ph_service: String = ""
  var _external_host: String = ""
  var _external_service: String = ""
  var _is_multi_worker: Bool = true
  var _cluster_initializer: (ClusterInitializer | None) = None
  var _application_distributor: (ApplicationDistributor | None) = None
  var _swarm_manager_addr: String = ""
  var _event_log_dir_filepath: (FilePath | None) = None
  var _event_log_file_basename: String = ""
  var _event_log_file_suffix: String = ""
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
    ifdef "spike" then
      @printf[I32]("****SPIKE is active****\n".cstring())
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

      (_external_host, _external_service) =
        match _startup_options.x_arg
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

      _event_log_dir_filepath = FilePath(auth, _startup_options.resilience_dir)
      _event_log_file_basename = name + "-" + _startup_options.worker_name
      _event_log_file_suffix = ".evlog"
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

      @printf[I32](("||| Resilience directory: " +
        _startup_options.resilience_dir + "|||\n").cstring())

      if not FilePath(auth, _startup_options.resilience_dir).exists() then
        @printf[I32](("Resilience directory: " +
          _startup_options.resilience_dir + " doesn't exist\n").cstring())
        error
      end

      ifdef "resilience" then
        @printf[I32](("||| Log-rotation: " +
          _startup_options.log_rotation.string() + "|||\n").cstring())
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
          JoiningControlSenderConnectNotifier(auth,
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
      let m_addr = _startup_options.m_arg as Array[String]

      if _startup_options.worker_name == "" then
        @printf[I32](("You must specify a worker name via " +
          "--name/-n.\n").cstring())
        error
      end

      // TODO::joining
      let connect_auth = TCPConnectAuth(auth)
      let metrics_conn = ReconnectingMetricsSink(m_addr(0),
          m_addr(1), _application.name(), _startup_options.worker_name)

      var is_recovering: Bool = false
      let event_log_dir_filepath = _event_log_dir_filepath as FilePath

      // check to see if we can recover
      // Use Set to make the logic explicit and clear
      let existing_files: Set[String] = Set[String]

      let event_log_filepath = try
        let elf: FilePath = LastLogFilePath(_event_log_file_basename,
          _event_log_file_suffix, event_log_dir_filepath)
        existing_files.set(elf.path)
        elf
      else
        FilePath(event_log_dir_filepath,
          _event_log_file_basename + _event_log_file_suffix)
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
      ifdef "resilience" then
        required_files.set(event_log_filepath.path)
      end
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
          @printf[I32](("Some resilience/recovery files are missing! "
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

      _event_log = ifdef "resilience" then
        if _startup_options.log_rotation then
          EventLog(EventLogConfig(event_log_dir_filepath,
            _event_log_file_basename
            where backend_file_length' = _startup_options.event_log_file_length,
            suffix' = _event_log_file_suffix, log_rotation' = true))
        else
          EventLog(EventLogConfig(event_log_dir_filepath,
            _event_log_file_basename + _event_log_file_suffix
            where backend_file_length' =
              _startup_options.event_log_file_length))
        end
      else
        EventLog()
      end
      let event_log = _event_log as EventLog

      let connections = Connections(_application.name(),
        _startup_options.worker_name, auth,
        _startup_options.c_host, _startup_options.c_service,
        _startup_options.d_host, _startup_options.d_service,
        _ph_host, _ph_service, _external_host, _external_service,
        metrics_conn, m_addr(0), m_addr(1), _startup_options.is_initializer,
        _connection_addresses_file, _startup_options.is_joining,
        _startup_options.spike_config, event_log, _startup_options.log_rotation)

      let data_receivers = DataReceivers(auth,
        _startup_options.worker_name, is_recovering)

      let router_registry = RouterRegistry(auth,
        _startup_options.worker_name, data_receivers,
        connections, _startup_options.stop_the_world_pause)
      router_registry.set_event_log(event_log)
      event_log.set_router_registry(router_registry)

      let recovery_replayer = RecoveryReplayer(auth,
        _startup_options.worker_name, data_receivers, router_registry,
        connections, is_recovering)

      let recovery = Recovery(auth, _startup_options.worker_name,
        event_log, recovery_replayer, connections)

      let local_topology_initializer =
        if _startup_options.is_swarm_managed then
          let cluster_manager: DockerSwarmClusterManager =
            DockerSwarmClusterManager(auth, _swarm_manager_addr,
              _startup_options.c_service)
          LocalTopologyInitializer(
            _application, _startup_options.worker_name,
            _startup_options.worker_count, _env, auth, connections,
            router_registry, metrics_conn, _startup_options.is_initializer,
            data_receivers, event_log, recovery, recovery_replayer,
            _local_topology_file, _data_channel_file, _worker_names_file,
            cluster_manager)
        else
          LocalTopologyInitializer(
            _application, _startup_options.worker_name,
            _startup_options.worker_count, _env, auth, connections,
            router_registry, metrics_conn, _startup_options.is_initializer,
            data_receivers, event_log, recovery, recovery_replayer,
            _local_topology_file, _data_channel_file, _worker_names_file)
        end

      if _startup_options.is_initializer then
        @printf[I32]("Running as Initializer...\n".cstring())
        _application_distributor = ApplicationDistributor(auth, _application,
          local_topology_initializer)
        match _application_distributor
        | let ad: ApplicationDistributor =>
          _cluster_initializer = ClusterInitializer(auth,
            _startup_options.worker_name,
            _startup_options.worker_count, connections,
            ad, local_topology_initializer, _startup_options.d_addr,
            metrics_conn, is_recovering)
        end
      end

      let control_notifier: TCPListenNotify iso =
        ControlChannelListenNotifier(_startup_options.worker_name,
          auth, connections,
          _startup_options.is_initializer, _cluster_initializer,
          local_topology_initializer, recovery,
          recovery_replayer, router_registry,
          control_channel_filepath, _startup_options.my_d_host,
          _startup_options.my_d_service
          where event_log = event_log)

      if _startup_options.is_initializer then
        connections.make_and_register_recoverable_listener(
          auth, consume control_notifier, control_channel_filepath,
          _startup_options.c_host, _startup_options.c_service)
      else
        connections.make_and_register_recoverable_listener(
          auth, consume control_notifier, control_channel_filepath,
          _startup_options.my_c_host, _startup_options.my_c_service)
      end

      if is_recovering then
        // need to do this before recreating the data connection as at
        // that point replay starts
        let recovered_workers = _recover_worker_names(
          worker_names_filepath)
        if _is_multi_worker then
          local_topology_initializer.recover_and_initialize(
            recovered_workers, _cluster_initializer)
        else
          local_topology_initializer.initialize(where recovering = true)
        end
      end

      if not is_recovering then
        match _cluster_initializer
        | let ci: ClusterInitializer =>
          // TODO: Pass in initializer name once we've refactored
          // to expect it at .start() for pipeline apps.
          ci.start()
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

  be complete_join(info_sending_host: String, m: InformJoiningWorkerMsg) =>
    try
      let auth = _env.root as AmbientAuth

      let metrics_conn = ReconnectingMetricsSink(m.metrics_host,
        m.metrics_service, _application.name(), _startup_options.worker_name)

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

      let data_receivers = DataReceivers(auth, _startup_options.worker_name)

      let event_log_dir_filepath = _event_log_dir_filepath as FilePath
      _event_log = ifdef "resilience" then
        if _startup_options.log_rotation then
          EventLog(EventLogConfig(event_log_dir_filepath,
            _event_log_file_basename
            where backend_file_length' = _startup_options.event_log_file_length,
            suffix' = _event_log_file_suffix, log_rotation' = true))
        else
          EventLog(EventLogConfig(event_log_dir_filepath,
            _event_log_file_basename + _event_log_file_suffix
            where backend_file_length' =
              _startup_options.event_log_file_length))
        end
      else
        EventLog()
      end
      let event_log = _event_log as EventLog

      let connections = Connections(_application.name(),
        _startup_options.worker_name,
        auth, c_host, c_service, d_host, d_service, _ph_host, _ph_service,
        _external_host, _external_service,
        metrics_conn, m.metrics_host, m.metrics_service,
        _startup_options.is_initializer,
        _connection_addresses_file, _startup_options.is_joining,
        _startup_options.spike_config, event_log, _startup_options.log_rotation)

      let router_registry = RouterRegistry(auth,
        _startup_options.worker_name, data_receivers,
        connections, _startup_options.stop_the_world_pause)
      router_registry.set_event_log(event_log)
      event_log.set_router_registry(router_registry)

      let recovery_replayer = RecoveryReplayer(auth,
        _startup_options.worker_name,
        data_receivers, router_registry, connections)

      let recovery = Recovery(auth, _startup_options.worker_name,
        event_log, recovery_replayer, connections)

      let local_topology_initializer =
        if _startup_options.is_swarm_managed then
          let cluster_manager: DockerSwarmClusterManager =
            DockerSwarmClusterManager(auth, _swarm_manager_addr, c_service)
          LocalTopologyInitializer(
            _application, _startup_options.worker_name,
            _startup_options.worker_count, _env, auth, connections,
            router_registry, metrics_conn,
            _startup_options.is_initializer, data_receivers,
            event_log, recovery, recovery_replayer,
            _local_topology_file, _data_channel_file, _worker_names_file,
            cluster_manager where is_joining = _startup_options.is_joining)
        else
          LocalTopologyInitializer(
            _application, _startup_options.worker_name,
            _startup_options.worker_count, _env, auth, connections,
            router_registry, metrics_conn,
            _startup_options.is_initializer, data_receivers,
            event_log, recovery, recovery_replayer,
            _local_topology_file, _data_channel_file, _worker_names_file
            where is_joining = _startup_options.is_joining)
        end

      router_registry.set_data_router(DataRouter)
      local_topology_initializer.update_topology(m.local_topology)
      local_topology_initializer.create_data_channel_listener(m.worker_names,
        _startup_options.my_d_host, _startup_options.my_d_service)

      // Prepare control and data addresses, but sub in correct host for
      // the worker that sent inform message (since it didn't know its
      // host string as seen externally)
      let control_addrs = recover trn Map[String, (String, String)] end
      let data_addrs = recover trn Map[String, (String, String)] end
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
          auth, connections,
          _startup_options.is_initializer, _cluster_initializer,
          local_topology_initializer, recovery,
          recovery_replayer, router_registry, control_channel_filepath,
          _startup_options.my_d_host, _startup_options.my_d_service
          where event_log = event_log)

      connections.make_and_register_recoverable_listener(
        auth, consume control_notifier, control_channel_filepath,
        _startup_options.my_c_host, _startup_options.my_c_service)

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
    let ws = recover trn Array[String] end

    let file = File(worker_names_filepath)
    for worker_name in file.lines() do
      ws.push(worker_name)
      @printf[I32]("recover_worker_names: %s\n".cstring(),
        worker_name.cstring())
    end

    ws
