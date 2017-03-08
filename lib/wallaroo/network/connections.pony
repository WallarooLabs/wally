use "buffered"
use "collections"
use "files"
use "net"
use "serialise"
use "sendence/guid"
use "sendence/messages"
use "wallaroo/boundary"
use "wallaroo/fail"
use "wallaroo/initialization"
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/tcp_source"
use "wallaroo/topology"

actor Connections
  let _app_name: String
  let _worker_name: String
  let _env: Env
  let _auth: AmbientAuth
  let _is_initializer: Bool
  let _control_conns: Map[String, TCPConnection] = _control_conns.create()
  let _data_conns: Map[String, OutgoingBoundary] = _data_conns.create()
  var _phone_home: (TCPConnection | None) = None
  let _metrics_conn: MetricsSink
  let _metrics_host: String
  let _metrics_service: String
  let _init_d_host: String
  let _init_d_service: String
  let _listeners: Array[TCPListener] = Array[TCPListener]
  let _guid_gen: GuidGenerator = GuidGenerator
  let _connection_addresses_file: String

  new create(app_name: String, worker_name: String,
    env: Env, auth: AmbientAuth, c_host: String, c_service: String,
    d_host: String, d_service: String, ph_host: String, ph_service: String,
    metrics_conn: MetricsSink, metrics_host: String, metrics_service: String,
    is_initializer: Bool, connection_addresses_file: String)
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

    if not _is_initializer then
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
      _env.out.print("Set up phone home connection on " + ph_host
        + ":" + ph_service)
    end

  be register_source_listener(listener: TCPSourceListener) =>
    // TODO: Handle source listeners for shutdown
    None

  be register_listener(listener: TCPListener) =>
    _listeners.push(listener)

  be make_and_register_recoverable_listener(auth: TCPListenerAuth,
    notifier: TCPListenNotify iso, recovery_addr_file: FilePath val,
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

  be create_initializer_data_channel(
    data_receivers: Map[String, DataReceiver] val,
    worker_initializer: WorkerInitializer, data_channel_file: FilePath,
    local_topology_initializer: LocalTopologyInitializer tag)
  =>
    let data_notifier: TCPListenNotify iso =
      DataChannelListenNotifier(_worker_name, _auth, this,
        _is_initializer, data_receivers,
        MetricsReporter(_app_name, _worker_name, _metrics_conn),
        data_channel_file, local_topology_initializer)
    // TODO: we need to get the init and max sizes from OS max
    // buffer size
    register_listener(TCPListener(_auth, consume data_notifier,
      _init_d_host, _init_d_service, 0, 1_048_576, 1_048_576))

    worker_initializer.identify_data_address("initializer", _init_d_host,
      _init_d_service)

  be send_control(worker: String, data: Array[ByteSeq] val) =>
    try
      _control_conns(worker).writev(data)
      @printf[I32](("Sent control message to " + worker + "\n").cstring())
    else
      @printf[I32](("No control connection for worker " + worker + "\n").cstring())
    end

  be send_data(worker: String, data: Array[ByteSeq] val) =>
    try
      _data_conns(worker).writev(data)
      // @printf[I32](("Sent protocol message over outgoing boundary to " + worker + "\n").cstring())
    else
      @printf[I32](("No outgoing boundary to worker " + worker + "\n").cstring())
    end

  be notify_cluster_of_new_stateful_step[K: (Hashable val & Equatable[K] val)](
    id: U128, key: K, state_name: String)
  =>
    try
      let new_step_msg = ChannelMsgEncoder.new_stateful_step[K](id,
        _worker_name, key, state_name, _auth)
      for ch in _control_conns.values() do
        ch.writev(new_step_msg)
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

  be update_boundaries(local_topology_initializer: LocalTopologyInitializer,
    recovering: Bool = false)
  =>
    let out_bs: Map[String, OutgoingBoundary] trn =
      recover Map[String, OutgoingBoundary] end

    for (target, boundary) in _data_conns.pairs() do
      out_bs(target) = boundary
    end

    local_topology_initializer.update_boundaries(consume out_bs)
    local_topology_initializer.initialize(where recovering = recovering)

  be create_connections(
    addresses: Map[String, Map[String, (String, String)]] val,
    local_topology_initializer: LocalTopologyInitializer)
  =>
    try
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
      let control_addrs = addresses("control")
      let data_addrs = addresses("data")
      for (target, address) in control_addrs.pairs() do
        if target != _worker_name then
          create_control_connection(target, address._1, address._2)
        end
      end

      for (target, address) in data_addrs.pairs() do
        if target != _worker_name then
          create_data_connection(target, address._1, address._2)
        end
      end

      update_boundaries(local_topology_initializer)

      let connections_ready_msg = ChannelMsgEncoder.connections_ready(
        _worker_name, _auth)

      send_control("initializer", connections_ready_msg)

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
          create_control_connection(target, address._1, address._2)
        end
      end

      for (target, address) in data_addrs.pairs() do
        if target != _worker_name then
          create_data_connection(target, address._1, address._2)
        end
      end

      update_boundaries(local_topology_initializer where recovering = true)

      _env.out.print(_worker_name + ": Interconnections with other workers created.")
    else
      _env.out.print("Problem creating interconnections with other workers")
    end

  be create_control_connection(target_name: String, host: String,
    service: String)
  =>
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
    let outgoing_boundary = OutgoingBoundary(_auth,
      _worker_name, MetricsReporter(_app_name,
      _worker_name, _metrics_conn),
      host, service)
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

  be inform_joining_worker(conn: TCPConnection, worker: String) =>
    try
      let inform_msg = ChannelMsgEncoder.inform_joining_worker(_app_name,
        _metrics_host, _metrics_service, _auth)
      conn.writev(inform_msg)
      @printf[I32]("Worker %s joined the cluster\n".cstring(), worker.cstring())
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

