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
use "wallaroo/boundary"
use "wallaroo/cluster_manager"
use "wallaroo/fail"
use "wallaroo/initialization"
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/network"
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
  var _o_addrs_write: Array[Array[String]] trn =
    recover Array[Array[String]] end
  // DEMO fields
  var _iterations: USize = 100

  // TODO: remove DEMO param actor_count
  new create(env: Env, system: ActorSystem val, app_name: String,
    actor_count: USize)
  =>
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
        let source_addr = _startup_options.i_addrs_write(0)
        let host = source_addr(0)
        let service = source_addr(1)
      else
        @printf[I32]("You must provide a source address! (-in/-i)\n".cstring())
        Fail()
      end

      let d_addr_ref = _startup_options.d_arg as Array[String]
      let d_addr_trn: Array[String] trn = recover Array[String] end
      d_addr_trn.push(d_addr_ref(0))
      d_addr_trn.push(d_addr_ref(1))
      let d_addr: Array[String] val = consume d_addr_trn
      let d_host = d_addr(0)
      let d_service = d_addr(1)

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

      let recovery = Recovery(_startup_options.worker_name, event_log)

      let seed: U64 = 123456

      // TODO: Determine how these are going to be shared across
      // Pipeline and RouterRegistry and stop using these empty versions.
      let empty_connections = EmptyConnections(_env, auth)
      let empty_metrics_conn = MetricsSink("", "", "", "")

      let input_addrs: Array[Array[String]] val =
        _startup_options.i_addrs_write = recover Array[Array[String]] end

      let output_addrs: Array[Array[String]] val =
        _o_addrs_write = recover Array[Array[String]] end

      let w_name = _startup_options.worker_name
      let workers: Array[String] val =
        recover [w_name] end

      let data_receivers = DataReceivers(auth, _startup_options.worker_name,
        empty_connections, is_recovering)

      let router_registry = RouterRegistry(auth, _startup_options.worker_name,
        data_receivers, empty_connections,
        _startup_options.stop_the_world_pause)

      let recovery_replayer = RecoveryReplayer(auth,
        _startup_options.worker_name, data_receivers, router_registry,
        empty_connections, is_recovering)

      let initializer = WActorInitializer(_startup_options.worker_name,
        _app_name, auth, event_log, input_addrs, output_addrs,
        _local_actor_system_file, actor_count, _iterations,
        recovery, recovery_replayer, _data_channel_file, data_receivers,
        empty_metrics_conn, workers, seed, empty_connections, router_registry,
        _startup_options.is_initializer)


      if _startup_options.is_initializer then
        @printf[I32]("Running as Initializer...\n".cstring())
        let distributor =
          ActorSystemDistributor(auth, _system, initializer, input_addrs,
            output_addrs, is_recovering)
        _cluster_initializer = ClusterInitializer(auth,
          _startup_options.worker_name, _startup_options.worker_count,
          empty_connections, distributor, initializer, d_addr,
          empty_metrics_conn)
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

primitive EmptyConnections
  fun apply(env: Env, auth: AmbientAuth): Connections =>
    Connections("", "", auth, "", "", "", "", "", "",
      ReconnectingMetricsSink("", "", "", ""), "", "", false, "", false)

primitive EmptyRouterRegistry
  fun apply(auth: AmbientAuth, c: Connections): RouterRegistry =>
    RouterRegistry(auth, "", DataReceivers(auth, ""), c, 0)
