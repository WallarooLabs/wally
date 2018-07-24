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
use "net"
use "serialise"
use "time"
use "wallaroo_labs/messages"
use "wallaroo"
use "wallaroo/core/boundary"
use "wallaroo/core/common"
use "wallaroo/core/data_channel"
use "wallaroo/core/initialization"
use "wallaroo/core/messages"
use "wallaroo/core/metrics"
use "wallaroo/core/source/tcp_source"
use "wallaroo/core/topology"
use "wallaroo/ent/data_receiver"
use "wallaroo/ent/recovery"
use "wallaroo/ent/router_registry"
use "wallaroo/ent/spike"
use "wallaroo_labs/collection_helpers"
use "wallaroo_labs/mort"


actor Connections is Cluster
  let _app_name: String
  let _worker_name: String
  let _auth: AmbientAuth
  let _is_initializer: Bool
  var _my_control_addr: (String, String) = ("", "")
  var _my_data_addr: (String, String) = ("", "")
  let _control_addrs: Map[String, (String, String)] = _control_addrs.create()
  let _data_addrs: Map[String, (String, String)] = _data_addrs.create()
  let _control_conns: Map[String, ControlConnection] =
    _control_conns.create()
  let _data_conn_builders: Map[String, OutgoingBoundaryBuilder] =
    _data_conn_builders.create()
  let _data_conns: Map[String, OutgoingBoundary] = _data_conns.create()
  let _metrics_conn: MetricsSink
  let _metrics_host: String
  let _metrics_service: String
  let _init_d_host: String
  let _init_d_service: String
  let _disposables: SetIs[DisposableActor] = _disposables.create()
  let _step_id_gen: RoutingIdGenerator = RoutingIdGenerator
  let _connection_addresses_file: String
  let _is_joining: Bool
  let _spike_config: (SpikeConfig | None)
  let _event_log: EventLog
  let _log_rotation: Bool

  new create(app_name: String, worker_name: String,
    auth: AmbientAuth, c_host: String, c_service: String,
    d_host: String, d_service: String,
    metrics_conn: MetricsSink, metrics_host: String, metrics_service: String,
    is_initializer: Bool, connection_addresses_file: String,
    is_joining: Bool, spike_config: (SpikeConfig | None) = None,
    event_log: EventLog, log_rotation: Bool = false,
    recovery_file_cleaner: (RecoveryFileCleaner | None) = None)
  =>
    _app_name = app_name
    _worker_name = worker_name
    _auth = auth
    _is_initializer = is_initializer
    _metrics_conn = metrics_conn
    _metrics_host = metrics_host
    _metrics_service = metrics_service
    _init_d_host = d_host
    _init_d_service = d_service
    _connection_addresses_file = connection_addresses_file
    _is_joining = is_joining
    _spike_config = spike_config
    _event_log = event_log
    _log_rotation = log_rotation

    if _is_initializer then
      _my_control_addr = (c_host, c_service)
      _my_data_addr = (d_host, d_service)
    else
      create_control_connection("initializer", c_host, c_service)
    end

    _register_disposable(_metrics_conn)

  be register_my_control_addr(host: String, service: String) =>
    _my_control_addr = (host, service)

  be register_my_data_addr(host: String, service: String) =>
    _my_data_addr = (host, service)

  be register_disposable(d: DisposableActor) =>
    _register_disposable(d)

  fun ref _register_disposable(d: DisposableActor) =>
    _disposables.set(d)

  be make_and_register_recoverable_listener(auth: TCPListenerAuth,
    notifier: TCPListenNotify iso,
    recovery_addr_file: FilePath val,
    host: String val = "", port: String val = "0")
  =>
    if recovery_addr_file.exists() then
      try
        let file = File(recovery_addr_file)
        let host' = file.line()?
        let port' = file.line()?

        @printf[I32]("Restarting a listener ...\n\n".cstring())

        let listener = TCPListener(auth, consume notifier, consume host',
            consume port')
         _register_disposable(listener)
      else
        @printf[I32](("could not recover host and port from file (replace " +
          " with Fail())\n").cstring())
      end
    else
      let listener = TCPListener(auth, consume notifier, host, port)
      _register_disposable(listener)
    end

  be make_and_register_recoverable_data_channel_listener(auth: TCPListenerAuth,
    notifier: DataChannelListenNotify iso,
    router_registry: RouterRegistry,
    recovery_addr_file: FilePath val,
    host: String val = "", port: String val = "0")
  =>
    if recovery_addr_file.exists() then
      try
        let file = File(recovery_addr_file)
        var host': String = file.line()?
        let port': String = file.line()?

        @printf[I32]("Restarting a data channel listener on %s:%s...\n\n"
          .cstring(), host'.cstring(), port'.cstring())
        let dch_listener = DataChannelListener(auth, consume notifier,
          router_registry, consume host', consume port')
        _register_disposable(dch_listener)
      else
        @printf[I32](("could not recover host and port from file (replace " +
          "with Fail())\n").cstring())
      end
    else
      let dch_listener = DataChannelListener(auth, consume notifier,
        router_registry, host, port)
      _register_disposable(dch_listener)
    end

  be create_initializer_data_channel_listener(
    data_receivers: DataReceivers,
    recovery_replayer: RecoveryReconnecter,
    router_registry: RouterRegistry,
    cluster_initializer: ClusterInitializer, data_channel_file: FilePath,
    layout_initializer: LayoutInitializer tag)
  =>
    let data_notifier: DataChannelListenNotifier iso =
      DataChannelListenNotifier(_worker_name, _auth, this,
        _is_initializer,
        MetricsReporter(_app_name, _worker_name, _metrics_conn),
        data_channel_file, layout_initializer, data_receivers,
        recovery_replayer, router_registry)
    // TODO: we need to get the init and max sizes from OS max
    // buffer size
    let dch_listener = DataChannelListener(_auth, consume data_notifier,
      router_registry, _init_d_host, _init_d_service, 0, 1_048_576, 1_048_576)
    _register_disposable(dch_listener)

    cluster_initializer.identify_data_address("initializer", _init_d_host,
      _init_d_service)

  be send_control(worker: String, data: Array[ByteSeq] val) =>
    _send_control(worker, data)

  fun _send_control(worker: String, data: Array[ByteSeq] val) =>
    try
      _control_conns(worker)?.writev(data)
      @printf[I32](("Sent control message to " + worker + "\n").cstring())
    else
      @printf[I32](("No control connection for worker " + worker + "\n")
        .cstring())
    end

  be send_control_to_cluster(data: Array[ByteSeq] val) =>
    _send_control_to_cluster(data)

  be send_control_to_cluster_with_exclusions(data: Array[ByteSeq] val,
    exclusions: Array[String] val)
  =>
    _send_control_to_cluster(data, exclusions)

  fun _send_control_to_cluster(data: Array[ByteSeq] val,
    exclusions: Array[String] val = recover Array[String] end)
  =>
    for worker in _control_conns.keys() do
      if not ArrayHelpers[String].contains[String](exclusions, worker) then
        _send_control(worker, data)
      end
    end

  be send_control_to_random(data: Array[ByteSeq] val) =>
    _send_control_to_random(data)

  fun _send_control_to_random(data: Array[ByteSeq] val) =>
    let target_idx: USize = Time.nanos().usize() % _control_conns.size()
    var count: USize = 0
    for worker in _control_conns.keys() do
      if target_idx == count then
        _send_control(worker, data)
        break
      end
      count = count + 1
    end

  be send_data(worker: String, data: Array[ByteSeq] val) =>
    _send_data(worker, data)

  fun _send_data(worker: String, data: Array[ByteSeq] val) =>
    try
      _data_conns(worker)?.writev(data)
    else
      @printf[I32](("No outgoing boundary to worker " + worker + "\n")
        .cstring())
    end

  be send_data_to_cluster(data: Array[ByteSeq] val) =>
    for worker in _data_conns.keys() do
      _send_data(worker, data)
    end

  be disconnect_from(worker: String) =>
    try
      (_, let d) = _data_conns.remove(worker)?
      d.dispose()
      (_, let c) = _control_conns.remove(worker)?
      c.dispose()
      _control_addrs.remove(worker)?
      _data_addrs.remove(worker)?
      _data_conn_builders.remove(worker)?
    else
      @printf[I32]("Couldn't find worker %s for disconnection\n".cstring(),
        worker.cstring())
    end

  be notify_joining_workers_of_joining_addresses(joining_workers:
    Array[String] val)
  =>
    for w1 in joining_workers.values() do
      let others_control = recover iso Map[String, (String, String)] end
      let others_data = recover iso Map[String, (String, String)] end
      for w2 in joining_workers.values() do
        try
          if w1 != w2 then others_control(w2) = _control_addrs(w2)? end
          if w1 != w2 then others_data(w2) = _data_addrs(w2)? end
        else
          Fail()
        end
      end
      try
        let msg = ChannelMsgEncoder.announce_connections(
          consume others_control, consume others_data, _auth)?
        _send_control(w1, msg)
      else
        Fail()
      end
    end

  be notify_current_workers_of_joining_addresses(joining_workers:
    Array[String] val)
  =>
    let joining_control = recover iso Map[String, (String, String)] end
    let joining_data = recover iso Map[String, (String, String)] end
    for jw in joining_workers.values() do
      try
        joining_control(jw) = _control_addrs(jw)?
        joining_data(jw) = _data_addrs(jw)?
      else
        Fail()
      end
    end
    try
      let msg = ChannelMsgEncoder.announce_joining_workers(_worker_name,
        consume joining_control, consume joining_data, _auth)?
      _send_control_to_cluster(msg where exclusions = joining_workers)
    else
      Fail()
    end

  be notify_cluster_of_new_stateful_step(id: RoutingId, key: Key,
    state_name: String, exclusions: Array[String] val =
    recover Array[String] end)
  =>
    try
      let new_step_msg = ChannelMsgEncoder.announce_new_stateful_step(id,
        _worker_name, key, state_name, _auth)?
      for (target, ch) in _control_conns.pairs() do
        // Only send to workers that don't already know about this step
        if not exclusions.contains(target) then
          ch.writev(new_step_msg)
        end
      end
      let migration_complete_msg =
        ChannelMsgEncoder.step_migration_complete(id, _auth)?
      for producer in exclusions.values() do
        _control_conns(producer)?.writev(migration_complete_msg)
      end
    else
      Fail()
    end

  be notify_cluster_of_new_source(id: RoutingId) =>
    try
      let msg = ChannelMsgEncoder.announce_new_source(_worker_name, id,
        _auth)?
      _send_control_to_cluster(msg)
    else
      Fail()
    end

  be stop_the_world(exclusions: Array[String] val = recover Array[String] end)
  =>
    try
      let mute_request_msg =
        ChannelMsgEncoder.mute_request(_worker_name, _auth)?
      for (target, ch) in _control_conns.pairs() do
        if
          (target != _worker_name) and
          (not exclusions.contains(target,
            {(a: String, b: String): Bool => a == b}))
        then
          ch.writev(mute_request_msg)
        end
      end
    else
      Fail()
    end

  be request_cluster_unmute() =>
    try
      let unmute_request_msg = ChannelMsgEncoder.unmute_request(_worker_name,
        _auth)?
      for (target, ch) in _control_conns.pairs() do
        if target != _worker_name then
          ch.writev(unmute_request_msg)
        end
      end
    else
      Fail()
    end

  be create_boundary_to_joining_worker(target: String, boundary_id: U128,
    local_topology_initializer: LocalTopologyInitializer)
  =>
    try
      (let host, let service) = _data_addrs(target)?
      let reporter = MetricsReporter(_app_name,
        _worker_name, _metrics_conn)
      let builder = OutgoingBoundaryBuilder(_auth, _worker_name,
        consume reporter, host, service, _spike_config)
      let boundary = builder.build_and_initialize(boundary_id, target,
        local_topology_initializer)
      _register_disposable(boundary)
      local_topology_initializer.add_boundary_to_joining_worker(target,
        boundary, builder)
    else
      @printf[I32]("Can't find data address for worker\n".cstring())
      Fail()
    end

  be update_boundaries(layout_initializer: LayoutInitializer,
    recovering: Bool = false)
  =>
    _update_boundaries(layout_initializer, recovering)

  fun _update_boundaries(layout_initializer: LayoutInitializer,
    recovering: Bool = false, router_registry: (RouterRegistry | None) = None)
  =>
    let out_bs_trn = recover trn Map[String, OutgoingBoundary] end

    for (target, boundary) in _data_conns.pairs() do
      out_bs_trn(target) = boundary
    end

    let out_bbs_trn = recover trn Map[String, OutgoingBoundaryBuilder] end

    for (target, builder) in _data_conn_builders.pairs() do
      out_bbs_trn(target) = builder
    end

    @printf[I32](("Preparing to update " + _data_conns.size().string() +
      " boundaries\n").cstring())

    let out_bs = consume val out_bs_trn
    let out_bbs = consume val out_bbs_trn

    layout_initializer.update_boundaries(out_bs, out_bbs)

    match router_registry
    | let r: RouterRegistry =>
      r.register_boundaries(out_bs, out_bbs)
    end

    // TODO: This should be somewhere else. It's not clear why updating
    // boundaries should trigger initialization, but this is the point
    // at which initialization is possible for a joining or recovering
    // worker in a multiworker cluster.
    if _is_joining or recovering then
      layout_initializer.initialize(where recovering = recovering)
    end

  be create_connections(
    control_addrs: Map[String, (String, String)] val,
    data_addrs: Map[String, (String, String)] val,
    layout_initializer: LayoutInitializer,
    router_registry: (RouterRegistry | None) = None)
  =>
    try
      _save_connections(control_addrs, data_addrs)

      for (target, address) in control_addrs.pairs() do
        if target != _worker_name then
          _create_control_connection(target, address._1, address._2)
        end
      end

      for (target, address) in data_addrs.pairs() do
        if target != _worker_name then
          _create_data_connection(target, address._1, address._2)
        end
      end

      match router_registry
      | let r: RouterRegistry =>
        _update_boundaries(layout_initializer where router_registry = r)
      else
        _update_boundaries(layout_initializer)
      end

      if not _is_joining then
        let connections_ready_msg = ChannelMsgEncoder.connections_ready(
          _worker_name, _auth)?

        _send_control("initializer", connections_ready_msg)
      end

      @printf[I32]((_worker_name +
        ": Interconnections with other workers created.\n").cstring())
    else
      @printf[I32]("Problem creating interconnections with other workers\n"
        .cstring())
    end

  be save_connections() =>
    _save_connections(_control_addrs, _data_addrs)

  fun _save_connections(control_addrs: Map[String, (String, String)] box,
    data_addrs: Map[String, (String, String)] box)
  =>
    @printf[I32]("Saving connection addresses!\n".cstring())

    let map = recover trn Map[String, Map[String, (String, String)]] end
    let control_map = recover trn Map[String, (String, String)] end
    for (key, value) in control_addrs.pairs() do
      control_map(key) = value
    end
    let data_map = recover trn Map[String, (String, String)] end
    for (key, value) in data_addrs.pairs() do
      data_map(key) = value
    end

    map("control") = consume control_map
    map("data") = consume data_map
    let addresses: Map[String, Map[String, (String, String)]] val =
      consume map

    try
      let connection_addresses_file = FilePath(_auth,
        _connection_addresses_file)?
      let file = File(connection_addresses_file)
      let wb = Writer
      let serialised_connection_addresses: Array[U8] val =
        Serialised(SerialiseAuth(_auth), addresses)?.output(
          OutputSerialisedAuth(_auth))
      wb.write(serialised_connection_addresses)
      file.writev(recover val wb.done() end)
    else
      @printf[I32]("Error saving connection addresses!\n".cstring())
      Fail()
    end

  be quick_initialize_data_connections(li: LayoutInitializer) =>
    for boundary in _data_conns.values() do
      boundary.quick_initialize(li)
    end

  be create_routers_from_blueprints(workers: Array[String] val,
    pr_blueprints: Map[String, PartitionRouterBlueprint] val,
    spr_blueprints: Map[U128, StatelessPartitionRouterBlueprint] val,
    tidr_blueprints: Map[String, TargetIdRouterBlueprint] val,
    local_sinks: Map[RoutingId, Consumer] val,
    router_registry: RouterRegistry, lti: LocalTopologyInitializer)
  =>
    // We delegate to router registry through here to ensure that we've
    // already sent the outgoing boundaries to the router registry when
    // create_connections was called.

    // We must create the target_id_router first
    router_registry.create_target_id_routers_from_blueprint(tidr_blueprints,
      local_sinks, lti)
    router_registry.create_partition_routers_from_blueprints(workers,
      pr_blueprints)
    router_registry.create_stateless_partition_routers_from_blueprints(
      spr_blueprints)

  be recover_connections(layout_initializer: LayoutInitializer)
  =>
    var addresses: Map[String, Map[String, (String, String)]] val =
      recover val Map[String, Map[String, (String, String)]] end
    try
      @printf[I32]("Recovering connection addresses!\n".cstring())
      try
        let connection_addresses_file = FilePath(_auth,
          _connection_addresses_file)?
        if connection_addresses_file.exists() then
          //we are recovering an existing worker topology
          let data = recover val
            let file = File(connection_addresses_file)
            file.read(file.size())
          end
          match Serialised.input(InputSerialisedAuth(_auth), data)(
            DeserialiseAuth(_auth))?
          | let a: Map[String, Map[String, (String, String)]] val =>
            addresses = a
          else
            @printf[I32]("error restoring connection addresses!".cstring())
            Fail()
          end
        end
      else
        Fail()
      end
      let control_addrs = addresses("control")?
      let data_addrs = addresses("data")?
      for (target, address) in control_addrs.pairs() do
        if target != _worker_name then
          _create_control_connection(target, address._1, address._2)
        end
      end

      for (target, address) in data_addrs.pairs() do
        if target != _worker_name then
          _create_data_connection(target, address._1, address._2)
        end
      end

      _update_boundaries(layout_initializer where recovering = true)

      @printf[I32]((_worker_name +
        ": Interconnections with other workers created.\n").cstring())
    else
      @printf[I32](("Problem creating interconnections with other workers " +
        "while recovering\n").cstring())
    end

  be create_control_connection(target_name: String, host: String,
    service: String)
  =>
    _create_control_connection(target_name, host, service)

  fun ref _create_control_connection(target_name: String, host: String,
    service: String)
  =>
    _control_addrs(target_name) = (host, service)
    let tcp_conn_wrapper =
      if _control_conns.contains(target_name) then
        try
          _control_conns(target_name)?
        else
          Fail(); ControlConnection(this)
        end
      else
        ControlConnection(this)
      end
    _control_conns(target_name) = tcp_conn_wrapper
    _register_disposable(tcp_conn_wrapper)
    let control_notifier: TCPConnectionNotify iso =
      ControlSenderConnectNotifier(_auth, target_name, tcp_conn_wrapper)
    let control_conn: TCPConnection =
      TCPConnection(_auth, consume control_notifier, host, service)

  be reconnect_data_connection(target_name: String) =>
    if _data_conns.contains(target_name) then
      try
        let outgoing_boundary = _data_conns(target_name)?
        outgoing_boundary.reconnect()
      end
    else
      @printf[I32]("Target: %s not found in data connection map!\n".cstring(),
        target_name.cstring())
      Fail()
    end

  be create_data_connection(target_name: String, host: String,
    service: String)
  =>
    _create_data_connection(target_name, host, service)

  fun ref _create_data_connection(target_name: String, host: String,
    service: String)
  =>
    _data_addrs(target_name) = (host, service)
    let boundary_builder = OutgoingBoundaryBuilder(_auth, _worker_name,
      MetricsReporter(_app_name, _worker_name, _metrics_conn), host, service,
      _spike_config)
    let outgoing_boundary = boundary_builder(_step_id_gen(), target_name)
    _data_conn_builders(target_name) = boundary_builder
    _register_disposable(outgoing_boundary)
    _data_conns(target_name) = outgoing_boundary

  be create_data_connection_to_joining_worker(target_name: String,
    host: String, service: String, li: LayoutInitializer)
  =>
    _data_addrs(target_name) = (host, service)
    let boundary_builder = OutgoingBoundaryBuilder(_auth, _worker_name,
      MetricsReporter(_app_name, _worker_name, _metrics_conn), host, service,
      _spike_config)
    let outgoing_boundary =
      boundary_builder.build_and_initialize(_step_id_gen(), target_name, li)
    _data_conn_builders(target_name) = boundary_builder
    _register_disposable(outgoing_boundary)
    _data_conns(target_name) = outgoing_boundary

  be update_boundary_ids(boundary_ids: Map[String, U128] val) =>
    for (worker, boundary) in _data_conns.pairs() do
      try
        boundary.register_step_id(boundary_ids(worker)?)
      else
        @printf[I32](("Could not register step id for boundary to " + worker +
          "\n").cstring())
      end
    end

  be inform_joining_worker(conn: TCPConnection, worker: String,
    local_topology: LocalTopology,
    partition_blueprints: Map[String, PartitionRouterBlueprint] val,
    stateless_partition_blueprints:
      Map[U128, StatelessPartitionRouterBlueprint] val,
    tidr_blueprints: Map[String, TargetIdRouterBlueprint] val)
  =>
    _register_disposable(conn)
    if not _control_addrs.contains(worker) then
      let c_addrs = recover trn Map[String, (String, String)] end
      for (w, addr) in _control_addrs.pairs() do
        c_addrs(w) = addr
      end
      c_addrs(_worker_name) = _my_control_addr

      let d_addrs = recover trn Map[String, (String, String)] end
      for (w, addr) in _data_addrs.pairs() do
        d_addrs(w) = addr
      end
      d_addrs(_worker_name) = _my_data_addr

      try
        let inform_msg = ChannelMsgEncoder.inform_joining_worker(_worker_name,
          _app_name, local_topology.for_new_worker(worker)?, _metrics_host,
          _metrics_service, consume c_addrs, consume d_addrs,
          local_topology.worker_names, partition_blueprints,
          stateless_partition_blueprints, tidr_blueprints, _auth)?
        conn.writev(inform_msg)
        @printf[I32](("***Worker %s attempting to join the cluster. Sent " +
          "necessary information.***\n").cstring(), worker.cstring())
      else
        Fail()
      end
    else
      @printf[I32](("Worker trying to join the cluster is using a name " +
        "that's already been reserved\n").cstring())
      try
        let clean_shutdown_msg = ChannelMsgEncoder.clean_shutdown(_auth,
          "Proposed worker name is already reserved by the cluster.")?
        conn.writev(clean_shutdown_msg)
      else
        Fail()
      end
    end

  be inform_contacted_worker_of_initialization(contacted_worker: String) =>
    try
      if not _has_registered_my_addrs() then
        @printf[I32](("Cannot inform contacted worker of join: my addresses " +
          "have not yet been registered. Is there something else listening " +
          "on ports I was assigned?\n").cstring())
        Fail()
      end
      @printf[I32](("Sending message to contacted worker %s, informing " +
        "I have completed initialization\n").cstring(),
        contacted_worker.cstring())
      let msg = ChannelMsgEncoder.joining_worker_initialized(_worker_name,
        _my_control_addr, _my_data_addr, _auth)?
      _send_control(contacted_worker, msg)
    else
      Fail()
    end

  be inform_worker_of_boundary_count(target_worker: String, count: USize) =>
    try
      let msg = ChannelMsgEncoder.replay_boundary_count(_worker_name, count,
        _auth)?
      _send_control(target_worker, msg)
      @printf[I32]("Informed %s that I have %lu boundaries to it\n".cstring(),
        target_worker.cstring(), count)
    else
      Fail()
    end

  fun _has_registered_my_addrs(): Bool =>
    match _my_control_addr
    | (_, "") => false
    | (_, "") => false
    else
      true
    end

  be ack_migration_batch_complete(ack_target: String) =>
    """
    Called when this worker has just joined and it needs to ack to sender_name
    that immigration of a batch is complete
    """
    try
      let ack_migration_batch_complete_msg =
        ChannelMsgEncoder.ack_migration_batch_complete(_worker_name, _auth)?
      _control_conns(ack_target)?.writev(ack_migration_batch_complete_msg)
    else
      Fail()
    end

  be dispose() =>
    _shutdown()

  be shutdown() =>
    _shutdown()

  be clean_files_shutdown(file_cleaner: RecoveryFileCleaner) =>
    try
      let clean_shutdown_msg = ChannelMsgEncoder.clean_shutdown(_auth)?
      _send_control_to_cluster(clean_shutdown_msg)
      file_cleaner.clean_recovery_files()
    else
      Fail()
    end

  fun ref _shutdown() =>
    for (key, conn) in _control_conns.pairs() do
      conn.dispose()
    end

    for d in _disposables.values() do
      d.dispose()
    end

    @printf[I32]("Connections: Finished shutdown procedure.\n".cstring())

  be rotate_log_files(worker_name: String) =>
    """
    Instruct a worker to rotate its log files.
    If worker_name isn't given, do nothing.
    """
    _rotate_log_files(worker_name)

  fun _rotate_log_files(worker_name: String) =>
    if _log_rotation then
      if worker_name == _worker_name then
        _event_log.start_rotation()
      elseif _control_conns.contains(worker_name) then
        try
          let rotate_log_files_msg = ChannelMsgEncoder.rotate_log_files(_auth)?
          _send_control(worker_name, rotate_log_files_msg)
        else
          Fail()
        end
      else
        @printf[I32](("WARNING: LogRotation requested for non-existent " +
          "worker: %s\n").cstring(), worker_name.cstring())
      end
    else
      @printf[I32]("WARNING: LogRotation requested, but log_rotation is off!\n"
        .cstring())
    end
