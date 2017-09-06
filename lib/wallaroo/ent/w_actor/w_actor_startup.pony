/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "buffered"
use "collections"
use "files"
use "itertools"
use "net"
use "net/http"
use "time"
use "sendence/hub"
use "sendence/mort"
use "sendence/options"
use "sendence/rand"
use "wallaroo"
use "wallaroo/core/boundary"
use "wallaroo/ent/data_receiver"
use "wallaroo/ent/cluster_manager"
use "wallaroo/ent/network"
use "wallaroo/ent/recovery"
use "wallaroo/ent/router_registry"
use "wallaroo/ent/w_actor/broadcast"
use "wallaroo/core/initialization"
use "wallaroo/core/messages"
use "wallaroo/core/metrics"
use "wallaroo/core/topology"

actor ActorSystemStartup
  var _startup_options: StartupOptions = StartupOptions

  let _env: Env
  let _system: ActorSystem val
  let _app_name: String
  var _is_multi_worker: Bool = true
  var _is_joining: Bool = false
  var _cluster_initializer: (ClusterInitializer | None) = None
  var _event_log_dir_filepath: (FilePath | None) = None
  var _event_log_file_basename: String = ""
  var _event_log_file_suffix: String = ""
  var _local_actor_system_file: String = ""
  var _data_channel_file: String = ""
  var _control_channel_file: String = ""
  var _worker_names_file: String = ""
  var _connection_addresses_file: String = ""
  var _connections: (Connections | None) = None
  // DEMO fields
  var _iterations: USize = 100

  var _ph_host: String = ""
  var _ph_service: String = ""
  var _external_host: String = ""
  var _external_service: String = ""

  new create(env: Env, system: ActorSystem val, app_name: String) =>
    _env = env
    _system = system
    _app_name = app_name

    try
      let auth = _env.root as AmbientAuth
      _startup_options = WallarooConfig.wactor_args(_env.args)

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

      //////////////////
      // RESILIENCE
      //////////////////
      _event_log_dir_filepath = FilePath(auth, _startup_options.resilience_dir)
      _event_log_file_basename = name + "-" + _startup_options.worker_name
      _event_log_file_suffix = ".evlog"
      _local_actor_system_file = _startup_options.resilience_dir + "/" + name +
        "-" + _startup_options.worker_name + ".local-actor-system"
      _data_channel_file = _startup_options.resilience_dir + "/" + name + "-" +
        _startup_options.worker_name + ".tcp-data"
      _control_channel_file = _startup_options.resilience_dir + "/" + name +
        "-" + _startup_options.worker_name + ".tcp-control"
      _worker_names_file = _startup_options.resilience_dir + "/" + name + "-" +
        _startup_options.worker_name + ".workers"
      _connection_addresses_file = _startup_options.resilience_dir + "/" +
        name + "-" + _startup_options.worker_name + ".connection-addresses"


      @printf[I32](("||| Resilience directory: " +
        _startup_options.resilience_dir + " |||\n").cstring())
      ifdef "resilience" then
        @printf[I32](("||| Log-rotation: " +
          _startup_options.log_rotation.string() + "|||\n").cstring())
      end

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
      ifdef "resilience" then
        required_files.set(event_log_filepath.path)
      end
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

      //////////////////////////
      // Actor System Startup
      //////////////////////////
      let event_log = ifdef "resilience" then
        if _startup_options.log_rotation then
          EventLog(EventLogConfig(event_log_dir_filepath,
            _event_log_file_basename
            where backend_file_length' = _startup_options.event_log_file_length,
            logging_batch_size' = 1,
            suffix' = _event_log_file_suffix, log_rotation' = true))
        else
          EventLog(EventLogConfig(event_log_dir_filepath,
            _event_log_file_basename + _event_log_file_suffix
            where backend_file_length' =
              _startup_options.event_log_file_length,
              logging_batch_size' = 1))
        end
      else
        EventLog()
      end

      let seed: U64 = 123456

      let empty_metrics_conn = ReconnectingMetricsSink("", "", "", "")
      let connections = Connections(_app_name, _startup_options.worker_name,
        auth, _startup_options.c_host, _startup_options.c_service,
        _startup_options.d_host, _startup_options.d_service, _ph_host,
        _ph_service, _external_host, _external_service, empty_metrics_conn,
        "", "", _startup_options.is_initializer, _connection_addresses_file,
        _is_joining, _startup_options.spike_config, event_log,
        _startup_options.log_rotation where recovery_file_cleaner = this)
      _connections = connections

      let w_name = _startup_options.worker_name

      let data_receivers = DataReceivers(auth, connections,
        _startup_options.worker_name, is_recovering)

      let router_registry = RouterRegistry(auth, _startup_options.worker_name,
        data_receivers, connections, _startup_options.stop_the_world_pause)
      router_registry.set_event_log(event_log)
      event_log.set_router_registry(router_registry)

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
            is_recovering)
        match _startup_options.worker_count
        | let wc: USize =>
          _cluster_initializer = ClusterInitializer(auth,
            _startup_options.worker_name, wc, connections, distributor,
            initializer, _startup_options.d_addr, empty_metrics_conn,
            is_recovering)
        else
          Unreachable()
        end
      end

      let control_notifier: TCPListenNotify iso =
        ControlChannelListenNotifier(_startup_options.worker_name,
          auth, connections, _startup_options.is_initializer,
          _cluster_initializer, initializer, recovery, recovery_replayer,
          router_registry, control_channel_filepath,
          _startup_options.my_d_host, _startup_options.my_d_service,
          event_log, this where broadcast_variables = broadcast_variables)

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
        let recovered_workers = _recover_worker_names(worker_names_filepath)
        if _is_multi_worker then
          initializer.recover_and_initialize(recovered_workers,
            _cluster_initializer)
        else
          initializer.initialize(where recovering = true)
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

  be clean_recovery_files() =>
    @printf[I32]("Removing recovery files\n".cstring())
    _remove_file(_local_actor_system_file)
    _remove_file(_data_channel_file)
    _remove_file(_control_channel_file)
    _remove_file(_worker_names_file)
    _remove_file(_connection_addresses_file)

    try
      let event_log_dir_filepath = _event_log_dir_filepath as FilePath
      let base_dir = Directory(event_log_dir_filepath)

      let event_log_filenames = FilterLogFiles(_event_log_file_basename,
        _event_log_file_suffix, base_dir.entries())
      for fn in event_log_filenames.values() do
        _remove_file(event_log_dir_filepath.path + "/" + fn)
      end
    else
      Fail()
    end

    @printf[I32]("Recovery files removed.\n".cstring())

    match _connections
    | let c: Connections =>
      c.shutdown()
    else
      Fail()
    end

  fun ref _remove_file(filename: String) =>
    @printf[I32]("...Removing %s...\n".cstring(), filename.cstring())
    @remove[I32](filename.cstring())

primitive EmptyConnections
  fun apply(env: Env, auth: AmbientAuth): Connections =>
    Connections("", "", auth, "", "", "", "", "", "", "", "",
      ReconnectingMetricsSink("", "", "", ""), "", "", false, "", false
      where event_log = EventLog())

primitive EmptyRouterRegistry
  fun apply(auth: AmbientAuth, c: Connections): RouterRegistry =>
    RouterRegistry(auth, "", DataReceivers(auth, c, ""), c, 0)
