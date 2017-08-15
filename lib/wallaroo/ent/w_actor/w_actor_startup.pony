use "buffered"
use "collections"
use "files"
use "itertools"
use "net"
use "net/http"
use "time"
use "sendence/hub"
use "sendence/options"
use "sendence/rand"
use "wallaroo"
use "wallaroo/ent/w_actor/broadcast"
use "wallaroo/boundary"
use "wallaroo/cluster_manager"
use "wallaroo/fail"
use "wallaroo/initialization"
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/ent/network"
use "wallaroo/recovery"
use "wallaroo/topology"

actor ActorSystemStartup
  var _startup_options: StartupOptions = StartupOptions

  let _env: Env
  let _system: ActorSystem val
  let _app_name: String
  var _is_multi_worker: Bool = true
  var _is_joining: Bool = false
  var _cluster_initializer: (ClusterInitializer | None) = None
  var _is_swarm_managed: Bool = false
  var _swarm_manager_addr: String = ""
  var _event_log_file: String = ""
  var _local_actor_system_file: String = ""
  var _data_channel_file: String = ""
  var _control_channel_file: String = ""
  var _worker_names_file: String = ""
  var _connection_addresses_file: String = ""
  // DEMO fields
  var _iterations: USize = 100

  var _ph_host: String = ""
  var _ph_service: String = ""

  new create(env: Env, system: ActorSystem val, app_name: String) =>
    _env = env
    _system = system
    _app_name = app_name

    try
      let auth = _env.root as AmbientAuth
      _startup_options = WallarooConfig.wallaroo_args(_env.args)

      @printf[I32]("#########################################\n".cstring())
      @printf[I32]("#*# Wallaroo Actor System Application #*#\n".cstring())
      @printf[I32]("#########################################\n\n".cstring())
      @printf[I32]("#*# %s starting up! #*#\n\n".cstring(),
        _startup_options.worker_name.cstring())

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
        let host = _startup_options.input_addrs(0)(0)
        let service = _startup_options.input_addrs(0)(1)
      else
        @printf[I32]("You must provide a source address! (-in/-i)\n".cstring())
        Fail()
      end

      let name = match _app_name
        | let n: String => n
        else
          ""
        end

      //////////////////
      // RESILIENCE
      //////////////////
      _event_log_file = _startup_options.resilience_dir + "/" + name + "-" +
        _startup_options.worker_name + ".evlog"
      _local_actor_system_file = _startup_options.resilience_dir + "/" + name + "-" +
        _startup_options.worker_name + ".local-actor-system"
      _data_channel_file = _startup_options.resilience_dir + "/" + name + "-" +
        _startup_options.worker_name + ".tcp-data"
      _control_channel_file = _startup_options.resilience_dir + "/" + name +
        "-" + _startup_options.worker_name + ".tcp-control"
      _worker_names_file = _startup_options.resilience_dir + "/" + name + "-" +
        _startup_options.worker_name + ".workers"
      _connection_addresses_file = _startup_options.resilience_dir + "/" +
        name + "-" + _startup_options.worker_name + ".connection-addresses"


      ifdef "resilience" then
        @printf[I32](("||| Resilience directory: " +
          _startup_options.resilience_dir + " |||\n").cstring())
      end

      var is_recovering: Bool = false

      // check to see if we can recover
      ifdef "resilience" then
        // Use Set to make the logic explicit and clear
        let existing_files: Set[String] = Set[String]

        let event_log_filepath: FilePath = FilePath(auth, _event_log_file)
        if event_log_filepath.exists() then
          existing_files.set(event_log_filepath.path)
        end

        let local_actor_system_filepath: FilePath = FilePath(auth,
          _local_actor_system_file)
        if local_actor_system_filepath.exists() then
          existing_files.set(local_actor_system_filepath.path)
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
        required_files.set(local_actor_system_filepath.path)
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
            @printf[I32]("||| Recovering from recovery files! |||\n".cstring())
            // we are recovering because all files exist
            is_recovering = true
          end
        end
      end

      //////////////////////////
      // Actor System Startup
      //////////////////////////
      let event_log = ifdef "resilience" then
          EventLog(_env, _event_log_file
            where backend_file_length = _startup_options.event_log_file_length,
              logging_batch_size = 1)
        else
          EventLog(_env, None)
        end

      let seed: U64 = 123456

      let empty_metrics_conn = ReconnectingMetricsSink("", "", "", "")
      let connections = Connections(_app_name, _startup_options.worker_name,
        auth, _startup_options.c_host, _startup_options.c_service,
        _startup_options.d_host, _startup_options.d_service, _ph_host,
        _ph_service, empty_metrics_conn, "", "",
        _startup_options.is_initializer, _connection_addresses_file,
        _is_joining, _startup_options.spike_config)

      let w_name = _startup_options.worker_name

      let data_receivers = DataReceivers(auth, _startup_options.worker_name,
        is_recovering)

      let router_registry = RouterRegistry(auth, _startup_options.worker_name,
        data_receivers, connections, _startup_options.stop_the_world_pause)

      //TODO: Remove this once we have application lifecycle implemented
      //for ActorSystem
      router_registry.application_ready_to_work()

      let recovery_replayer = RecoveryReplayer(auth,
        _startup_options.worker_name, data_receivers, router_registry,
        connections, is_recovering)

      let recovery = Recovery(auth, _startup_options.worker_name, event_log,
        recovery_replayer, connections)

      let broadcast_variables = BroadcastVariables(
        _startup_options.worker_name, auth, connections,
        system.broadcast_variables())

      let initializer = WActorInitializer(_startup_options.worker_name,
        _app_name, auth, event_log, _startup_options.input_addrs,
        _local_actor_system_file,
        _iterations, recovery, recovery_replayer, _data_channel_file,
        _worker_names_file, data_receivers, empty_metrics_conn, seed,
        connections, router_registry, broadcast_variables,
        _startup_options.is_initializer)

      if _startup_options.is_initializer then
        @printf[I32]("Running as Initializer...\n".cstring())
        let distributor =
          ActorSystemDistributor(auth, _system, initializer, connections,
            _startup_options.input_addrs, is_recovering)
        _cluster_initializer = ClusterInitializer(auth,
          _startup_options.worker_name, _startup_options.worker_count,
          connections, distributor, initializer, _startup_options.d_addr,
          empty_metrics_conn, is_recovering)
      end

      let control_channel_filepath: FilePath = FilePath(auth,
        _control_channel_file)
      let control_notifier: TCPListenNotify iso =
        ControlChannelListenNotifier(_startup_options.worker_name,
          auth, connections, _startup_options.is_initializer,
          _cluster_initializer, initializer, recovery, recovery_replayer,
          router_registry, control_channel_filepath,
          _startup_options.my_d_host, _startup_options.my_d_service
          where broadcast_variables = broadcast_variables)

      ifdef "resilience" then
        if _startup_options.is_initializer then
          connections.make_and_register_recoverable_listener(
            auth, consume control_notifier, control_channel_filepath,
            _startup_options.c_host, _startup_options.c_service)
        else
          connections.make_and_register_recoverable_listener(
            auth, consume control_notifier, control_channel_filepath,
            _startup_options.my_c_host, _startup_options.my_c_service)
        end
      else
        if _startup_options.is_initializer then
          connections.register_listener(
            TCPListener(auth, consume control_notifier,
              _startup_options.c_host, _startup_options.c_service))
        else
          connections.register_listener(
            TCPListener(auth, consume control_notifier,
              _startup_options.my_c_host, _startup_options.my_c_service))
        end
      end

      ifdef "resilience" then
        if is_recovering then
          // need to do this before recreating the data connection as at
          // that point replay starts
          let worker_names_filepath: FilePath = FilePath(auth,
            _worker_names_file)
          let recovered_workers = _recover_worker_names(worker_names_filepath)
          if _is_multi_worker then
            initializer.recover_and_initialize(recovered_workers,
              _cluster_initializer)
          else
            initializer.initialize(where recovering = true)
          end
        end
      end

      if not is_recovering then
        match _cluster_initializer
        | let ci: ClusterInitializer =>
          ci.start(_startup_options.worker_name)
        end
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

primitive EmptyConnections
  fun apply(env: Env, auth: AmbientAuth): Connections =>
    Connections("", "", auth, "", "", "", "", "", "",
      ReconnectingMetricsSink("", "", "", ""), "", "", false, "", false)

primitive EmptyRouterRegistry
  fun apply(auth: AmbientAuth, c: Connections): RouterRegistry =>
    RouterRegistry(auth, "", DataReceivers(auth, ""), c, 0)
