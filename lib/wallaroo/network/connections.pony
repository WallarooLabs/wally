use "buffered"
use "collections"
use "files"
use "net"
use "serialise"
use "sendence/guid"
use "sendence/messages"
use "wallaroo/boundary"
use "wallaroo/data_channel"
use "wallaroo/fail"
use "wallaroo/initialization"
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/spike"
use "wallaroo/tcp_source"
use "wallaroo/topology"

actor Connections
  let _app_name: String
  let _worker_name: String
  let _env: Env
  let _auth: AmbientAuth
  let _is_initializer: Bool
  var _my_control_addr: (String, String) = ("", "")
  var _my_data_addr: (String, String) = ("", "")
  let _control_addrs: Map[String, (String, String)] = _control_addrs.create()
  let _data_addrs: Map[String, (String, String)] = _data_addrs.create()
  let _control_conns: Map[String, TCPConnection] = _control_conns.create()
  let _data_conns: Map[String, OutgoingBoundary] = _data_conns.create()
  var _phone_home: (TCPConnection | None) = None
  let _metrics_conn: MetricsSink
  let _metrics_host: String
  let _metrics_service: String
  let _init_d_host: String
  let _init_d_service: String
  let _listeners: Array[TCPListener] = Array[TCPListener]
  let _data_channel_listeners: Array[DataChannelListener] =
    Array[DataChannelListener]
  let _guid_gen: GuidGenerator = GuidGenerator
  let _connection_addresses_file: String
  let _is_joining: Bool
  let _spike_config: (SpikeConfig | None)

  new create(app_name: String, worker_name: String,
    env: Env, auth: AmbientAuth, c_host: String, c_service: String,
    d_host: String, d_service: String, ph_host: String, ph_service: String,
    metrics_conn: MetricsSink, metrics_host: String, metrics_service: String,
    is_initializer: Bool, connection_addresses_file: String,
    is_joining: Bool, spike_config: (SpikeConfig | None) = None)
  =>
    _app_name = app_name
    _worker_name = worker_name
    _env = env
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

    if _is_initializer then
      _my_control_addr = (c_host, c_service)
      _my_data_addr = (d_host, d_service)
    else
      create_control_connection("initializer", c_host, c_service)
    end

    if (ph_host != "") and (ph_service != "") then
      let phone_home = TCPConnection(auth,
        HomeConnectNotify(env, _worker_name, this), ph_host, ph_service)
      _phone_home = phone_home
      if is_initializer then
        let ready_msg = ExternalMsgEncoder.ready(_worker_name)
        phone_home.writev(ready_msg)
      end
      @printf[I32](("Set up phone home connection on " + ph_host
        + ":" + ph_service + "\n").cstring())
    end

  be register_my_control_addr(host: String, service: String) =>
    _my_control_addr = (host, service)

  be register_my_data_addr(host: String, service: String) =>
    _my_data_addr = (host, service)

  be register_source_listener(listener: TCPSourceListener) =>
    // TODO: Handle source listeners for shutdown
    None

  be register_listener(listener: (TCPListener | DataChannelListener)) =>
    match listener
    | let tcp: TCPListener =>
      _listeners.push(tcp)
    | let dc: DataChannelListener =>
      _data_channel_listeners.push(dc)
    else
      Fail()
    end

  be make_and_register_recoverable_listener(auth: TCPListenerAuth,
    notifier: TCPListenNotify iso,
    recovery_addr_file: FilePath val,
    host: String val = "", port: String val = "0")
  =>
    // TODO: Not sure if this is the right way to check this
    ifdef not "resilience" then
      Fail()
    end
    if recovery_addr_file.exists() then
      try
        let file = File(recovery_addr_file)
        let host' = file.line()
        let port' = file.line()

        @printf[I32]("Restarting a listener ...\n\n".cstring())

        _listeners.push(TCPListener(auth, consume notifier, consume host',
          consume port'))
      else
        @printf[I32]("could not recover host and port from file (replace with Fail())\n".cstring())
      end
    else
      _listeners.push(TCPListener(auth, consume notifier, host, port))
    end

  be make_and_register_recoverable_data_channel_listener(auth: TCPListenerAuth,
    notifier: DataChannelListenNotify iso,
    data_receivers: Map[String, DataReceiver] val,
    router_registry: RouterRegistry,
    recovery_addr_file: FilePath val,
    host: String val = "", port: String val = "0")
  =>
    // TODO: Not sure if this is the right way to check this
    ifdef not "resilience" then
      Fail()
    end
    if recovery_addr_file.exists() then
      try
        let file = File(recovery_addr_file)
        let host' = file.line()
        let port' = file.line()

        @printf[I32]("Restarting a data channel listener ...\n\n".cstring())
        let dch_listener = DataChannelListener(auth, consume notifier,
          data_receivers, router_registry, consume host',
          consume port')
        router_registry.register_data_channel_listener(dch_listener)
        _data_channel_listeners.push(dch_listener)
      else
        @printf[I32]("could not recover host and port from file (replace with Fail())\n".cstring())
      end
    else
      let dch_listener = DataChannelListener(auth, consume notifier,
        data_receivers, router_registry, host, port)
      router_registry.register_data_channel_listener(dch_listener)
      _data_channel_listeners.push(dch_listener)
    end

  be create_initializer_data_channel(
    data_receivers: Map[String, DataReceiver] val,
    router_registry: RouterRegistry,
    worker_initializer: WorkerInitializer, data_channel_file: FilePath,
    local_topology_initializer: LocalTopologyInitializer tag)
  =>
    let data_notifier: DataChannelListenNotifier iso =
      DataChannelListenNotifier(_worker_name, _auth, this,
        _is_initializer,
        MetricsReporter(_app_name, _worker_name, _metrics_conn),
        data_channel_file, local_topology_initializer)
    // TODO: we need to get the init and max sizes from OS max
    // buffer size
    let dch_listener = DataChannelListener(_auth, consume data_notifier,
      data_receivers, router_registry,
      _init_d_host, _init_d_service, 0, 1_048_576, 1_048_576)
    router_registry.register_data_channel_listener(dch_listener)
    register_listener(dch_listener)

    worker_initializer.identify_data_address("initializer", _init_d_host,
      _init_d_service)

  be send_control(worker: String, data: Array[ByteSeq] val) =>
    _send_control(worker, data)

  fun _send_control(worker: String, data: Array[ByteSeq] val) =>
    try
      _control_conns(worker).writev(data)
      @printf[I32](("Sent control message to " + worker + "\n").cstring())
    else
      @printf[I32](("No control connection for worker " + worker + "\n").cstring())
    end

  be send_control_to_cluster(data: Array[ByteSeq] val) =>
    _send_control_to_cluster(data)

  fun _send_control_to_cluster(data: Array[ByteSeq] val) =>
    for worker in _control_conns.keys() do
      _send_control(worker, data)
    end

  be send_data(worker: String, data: Array[ByteSeq] val) =>
    _send_data(worker, data)

  fun _send_data(worker: String, data: Array[ByteSeq] val) =>
    try
      _data_conns(worker).writev(data)
      // @printf[I32](("Sent protocol message over outgoing boundary to " + worker + "\n").cstring())
    else
      @printf[I32](("No outgoing boundary to worker " + worker + "\n").cstring())
    end

  be send_data_to_cluster(data: Array[ByteSeq] val) =>
    for worker in _data_conns.keys() do
      _send_data(worker, data)
    end

  be notify_cluster_of_new_stateful_step[K: (Hashable val & Equatable[K] val)](
    id: U128, key: K, state_name: String, exclusions: Array[String] val =
    recover Array[String] end)
  =>
    try
      let new_step_msg = ChannelMsgEncoder.announce_new_stateful_step[K](id,
        _worker_name, key, state_name, _auth)
      for (target, ch) in _control_conns.pairs() do
        // Only send to workers that don't already know about this step
        if not exclusions.contains(target) then
          ch.writev(new_step_msg)
        end
      end
      let migration_complete_msg =
        ChannelMsgEncoder.step_migration_complete(id, _auth)
      for origin in exclusions.values() do
        _control_conns(origin).writev(migration_complete_msg)
      end
    else
      Fail()
    end

  be stop_the_world(exclusions: Array[String] val) =>
    try
      let mute_request_msg =
        ChannelMsgEncoder.mute_request(_worker_name, _auth)
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
      let unmute_request_msg = ChannelMsgEncoder.unmute_request(_worker_name, _auth)
      for (target, ch) in _control_conns.pairs() do
        if target != _worker_name then
          ch.writev(unmute_request_msg)
        end
      end
    else
      Fail()
    end

  be send_phone_home(msg: Array[ByteSeq] val) =>
    match _phone_home
    | let tcp: TCPConnection =>
      tcp.writev(msg)
    else
      _env.err.print("There is no phone home connection to send on!")
    end

  be create_boundary_to_new_worker(target: String,
    local_topology_initializer: LocalTopologyInitializer)
  =>
    try
      (let host, let service) = _data_addrs(target)
      let boundary = OutgoingBoundary(_auth,
        _worker_name, MetricsReporter(_app_name,
        _worker_name, _metrics_conn),
        host, service where spike_config = _spike_config)
      boundary.register_step_id(_guid_gen.u128())
      boundary.quick_initialize(local_topology_initializer)
      local_topology_initializer.add_boundary_to_new_worker(target, boundary)
    else
      @printf[I32]("Can't find data address for worker\n".cstring())
      Fail()
    end

  be update_boundaries(local_topology_initializer: LocalTopologyInitializer,
    recovering: Bool = false)
  =>
    _update_boundaries(local_topology_initializer, recovering)

  fun _update_boundaries(local_topology_initializer: LocalTopologyInitializer,
    recovering: Bool = false)
  =>
    let out_bs: Map[String, OutgoingBoundary] trn =
      recover Map[String, OutgoingBoundary] end

    for (target, boundary) in _data_conns.pairs() do
      out_bs(target) = boundary
    end

    @printf[I32](("Preparing to update " + _data_conns.size().string() +
      " boundaries\n").cstring())

    local_topology_initializer.update_boundaries(consume out_bs)
    // TODO: This should be somewhere else. It's not clear why updating
    // boundaries should trigger initialization, but this is the point
    // at which initialization is possible for a joining or recovering
    // worker
    if _is_joining or recovering then
      local_topology_initializer.initialize(where recovering = recovering)
    end

  be create_connections(
    control_addrs: Map[String, (String, String)] val,
    data_addrs: Map[String, (String, String)] val,
    local_topology_initializer: LocalTopologyInitializer)
  =>
    try
      let map: Map[String, Map[String, (String, String)]] trn =
        recover Map[String, Map[String, (String, String)]] end
      let control_map: Map[String, (String, String)] trn =
        recover Map[String, (String, String)] end
      for (key, value) in control_addrs.pairs() do
        control_map(key) = value
      end
      let data_map: Map[String, (String, String)] trn =
        recover Map[String, (String, String)] end
      for (key, value) in data_addrs.pairs() do
        data_map(key) = value
      end

      map("control") = consume control_map
      map("data") = consume data_map
      let addresses: Map[String, Map[String, (String, String)]] val =
        consume map

      ifdef "resilience" then
        @printf[I32]("Saving connection addresses!\n".cstring())
        try
          let connection_addresses_file = FilePath(_auth, _connection_addresses_file)
          let file = File(connection_addresses_file)
          let wb = Writer
          let serialised_connection_addresses: Array[U8] val =
            Serialised(SerialiseAuth(_auth), addresses).output(
              OutputSerialisedAuth(_auth))
          wb.write(serialised_connection_addresses)
          file.writev(recover val wb.done() end)
        else
          @printf[I32]("Error saving connection addresses!\n".cstring())
          Fail()
        end
      end
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

      _update_boundaries(local_topology_initializer)

      if not _is_joining then
        let connections_ready_msg = ChannelMsgEncoder.connections_ready(
          _worker_name, _auth)

        _send_control("initializer", connections_ready_msg)
      end

      _env.out.print(_worker_name + ": Interconnections with other workers created.")
    else
      _env.out.print("Problem creating interconnections with other workers")
    end

  be recover_connections(local_topology_initializer: LocalTopologyInitializer)
  =>
    var addresses: Map[String, Map[String, (String, String)]] val =
      recover val Map[String, Map[String, (String, String)]] end
    try
      ifdef "resilience" then
        @printf[I32]("Recovering connection addresses!\n".cstring())
        try
          let connection_addresses_file = FilePath(_auth, _connection_addresses_file)
          if connection_addresses_file.exists() then
            //we are recovering an existing worker topology
            let data = recover val
              let file = File(connection_addresses_file)
              file.read(file.size())
            end
            match Serialised.input(InputSerialisedAuth(_auth), data)(
              DeserialiseAuth(_auth))
            | let a: Map[String, Map[String, (String, String)]] val =>
              addresses = a
            else
              @printf[I32]("error restoring connection addresses!".cstring())
              Fail()
            end
          end
        else
          @printf[I32]("error restoring connection addresses!".cstring())
          Fail()
        end
      else
        Fail()
      end
      let control_addrs = addresses("control")
      let data_addrs = addresses("data")
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

      _update_boundaries(local_topology_initializer where recovering = true)

      _env.out.print(_worker_name + ": Interconnections with other workers created.")
    else
      _env.out.print("Problem creating interconnections with other workers")
    end

  be create_control_connection(target_name: String, host: String,
    service: String)
  =>
    _create_control_connection(target_name, host, service)

  fun ref _create_control_connection(target_name: String, host: String,
    service: String)
  =>
    _control_addrs(target_name) = (host, service)
    let control_notifier: TCPConnectionNotify iso =
      ControlSenderConnectNotifier(_env, _auth, target_name)
    let control_conn: TCPConnection =
      TCPConnection(_auth, consume control_notifier, host, service)
    _control_conns(target_name) = control_conn

  be reconnect_data_connection(target_name: String) =>
    if _data_conns.contains(target_name) then
      try
        let outgoing_boundary = _data_conns(target_name)
        outgoing_boundary.reconnect()
      end
    else
      @printf[I32]("Target: %s not found in data connection map!\n".cstring(), target_name.cstring())
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
    let outgoing_boundary = OutgoingBoundary(_auth,
      _worker_name, MetricsReporter(_app_name,
      _worker_name, _metrics_conn),
      host, service
      where spike_config = _spike_config)
    outgoing_boundary.register_step_id(_guid_gen.u128())
    _data_conns(target_name) = outgoing_boundary

  be update_boundary_ids(boundary_ids: Map[String, U128] val) =>
    for (worker, boundary) in _data_conns.pairs() do
      try
        boundary.register_step_id(boundary_ids(worker))
      else
        @printf[I32](("Could not register step id for boundary to " + worker + "\n").cstring())
      end
    end

  be inform_joining_worker(conn: TCPConnection, worker: String,
    local_topology: LocalTopology val)
  =>
    let c_addrs: Map[String, (String, String)] trn =
      recover Map[String, (String, String)] end
    for (w, addr) in _control_addrs.pairs() do
      c_addrs(w) = addr
    end
    c_addrs(_worker_name) = _my_control_addr

    let d_addrs: Map[String, (String, String)] trn =
      recover Map[String, (String, String)] end
    for (w, addr) in _data_addrs.pairs() do
      d_addrs(w) = addr
    end
    d_addrs(_worker_name) = _my_data_addr

    try
      let inform_msg = ChannelMsgEncoder.inform_joining_worker(_worker_name,
        _app_name, local_topology.for_new_worker(worker), _metrics_host,
        _metrics_service, consume c_addrs, consume d_addrs,
        local_topology.worker_names, _auth)
      conn.writev(inform_msg)
      @printf[I32]("***Worker %s attempting to join the cluster. Sent necessary information.***\n".cstring(), worker.cstring())
    else
      Fail()
    end

  be inform_cluster_of_join() =>
    try
      let msg = ChannelMsgEncoder.joining_worker_initialized(_worker_name,
        _my_control_addr, _my_data_addr, _auth)
      _send_control_to_cluster(msg)
    else
      Fail()
    end

  be ack_migration_batch_complete(ack_target: String) =>
    """
    Called when this worker has just joined and it needs to ack to sender_name
    that immigration of a batch is complete
    """
    try
      let ack_migration_batch_complete_msg =
        ChannelMsgEncoder.ack_migration_batch_complete(_worker_name, _auth)
      _control_conns(ack_target).writev(ack_migration_batch_complete_msg)
    else
      Fail()
    end

  be ack_watermark_to_boundary(receiver_name: String, seq_id: U64) =>
    None
/*    try
      _data_conns(receiver_name).ack(seq_id)
    else
      @printf[I32](("No outgoing boundary to worker " + receiver_name + "\n").cstring())
    end*/

  be request_replay(receiver_name: String) =>
    try
      _data_conns(receiver_name).replay_msgs()
    else
      @printf[I32](("No outgoing boundary to worker " + receiver_name + "\n").cstring())
    end

  be shutdown() =>
    for listener in _listeners.values() do
      listener.dispose()
    end

    for data_channel_listener in _data_channel_listeners.values() do
      data_channel_listener.dispose()
    end

    for (key, conn) in _control_conns.pairs() do
      conn.dispose()
    end

    // for (key, receiver) in _data_connection_receivers.pairs() do
    //   receiver.dispose()
    // end

    match _phone_home
    | let phc: TCPConnection =>
      phc.writev(ExternalMsgEncoder.done_shutdown(_worker_name))
      phc.dispose()
    end

    _env.out.print("Connections: Finished shutdown procedure.")

