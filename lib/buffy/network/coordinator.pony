use "net"
use "buffy/messages"
use "buffy/metrics"
use "../topology"
use "spike"
use "collections"

actor Coordinator
  let _env: Env
  let _auth: AmbientAuth
  let _node_name: String
  let _leader_control_host: String
  let _leader_control_service: String
  let _leader_data_host: String
  let _leader_data_service: String
  let _step_manager: StepManager
  let _listeners: Array[TCPListener] = Array[TCPListener]
  var _phone_home_connection: (TCPConnection | None) = None
  var _topology_manager: (TopologyManager | None) = None
  let _connections: Array[TCPConnection] = Array[TCPConnection]
  let _control_connections: Map[String, TCPConnection tag]
    = Map[String, TCPConnection tag]
  let _data_connection_senders: Map[String, DataSender]
    = Map[String, DataSender]
  let _data_connection_receivers: Map[String, DataReceiver]
    = Map[String, DataReceiver]
  let _control_addrs: Map[String, (String, String)] = Map[String, (String, String)]
  let _data_addrs: Map[String, (String, String)] = Map[String, (String, String)]
  let _spike_config: SpikeConfig val
  let _metrics_collector: MetricsCollector
  let _is_worker: Bool

  new create(name: String, env: Env, auth: AmbientAuth, leader_control_host: String,
    leader_control_service: String, leader_data_host: String,
    leader_data_service: String, step_manager: StepManager,
    spike_config: SpikeConfig val, metrics_collector: MetricsCollector,
    is_worker: Bool) =>
    _node_name = name
    _env = env
    _auth = auth
    _leader_control_host = leader_control_host
    _leader_control_service = leader_control_service
    _leader_data_host = leader_data_host
    _leader_data_service = leader_data_service
    _step_manager = step_manager
    _spike_config = spike_config
    _metrics_collector = metrics_collector
    _is_worker = is_worker

    if _is_worker then
      _control_addrs("leader") = (_leader_control_host, _leader_control_service)
      _data_addrs("leader") = (_leader_data_host, _leader_data_service)

      let control_notifier: TCPConnectionNotify iso =
        WorkerConnectNotify(_env, _auth, _node_name, _leader_control_host,
          _leader_control_service, this, metrics_collector)
      let control_conn: TCPConnection =
        TCPConnection(_auth, consume control_notifier, _leader_control_host,
          _leader_control_service)
      _control_connections("leader") = control_conn

      let data_notifier: TCPConnectionNotify iso =
        SpikeWrapper(IntraclusterDataSenderConnectNotify(_env, _auth, _node_name,
          "leader", this), _spike_config)
      let data_conn: TCPConnection =
        TCPConnection(_auth, consume data_notifier, _leader_data_host,
          _leader_data_service)
      _data_connection_senders("leader") = DataSender("leader", data_conn)
      _data_connection_receivers("leader") = DataReceiver("leader", this)
    end


  //////////////
  // INITIALIZE
  //////////////
  be initialize_topology_connections() =>
    try
      let confirm_msg = WireMsgEncoder.finished_connections(_node_name, _auth)
      for (connector, conn) in _control_connections.pairs() do
        for (target, addr) in _control_addrs.pairs() do
          if connector != target then
            let msg = WireMsgEncoder.identify_control(target, addr._1, addr._2, _auth)
            conn.write(msg)
          end
        end
        for (target, addr) in _data_addrs.pairs() do
          if connector != target then
            let msg = WireMsgEncoder.identify_data(target, addr._1, addr._2, _auth)
            conn.write(msg)
          end
        end
        conn.write(confirm_msg)
      end
    end

  be identify_data_channel(host: String, service: String) =>
    try
      let message = WireMsgEncoder.identify_data(_node_name, host, service, _auth)
      _control_connections("leader").write(message)
    else
      _env.out.print("Coordinator: control connection to leader was not set up")
    end

  be identify_control_channel(host: String, service: String) =>
    try
      let message = WireMsgEncoder.identify_control(_node_name, host, service, _auth)
      _control_connections("leader").write(message)
    else
      _env.out.print("Coordinator: control connection to leader was not set up")
    end

  be ack_finished_connections(target_name: String) =>
    _env.out.print("Acking connections finished!")
    try
      let ack_msg = WireMsgEncoder.ack_finished_connections(_node_name, _auth)
      _control_connections(target_name).write(ack_msg)
    end

  be ack_initialization_msgs_finished(target_name: String) =>
    _env.out.print("Acking initialization messages finished!")
    try
      let ack_msg = WireMsgEncoder.ack_initialized(_node_name, _auth)
      _control_connections(target_name).write(ack_msg)
    end


  ////////////
  // TOPOLOGY
  ////////////
  be add_topology_manager(tm: TopologyManager) =>
    _topology_manager = tm

  be add_step(step_id: U64, comp_type: String) =>
    _step_manager.add_step(step_id, comp_type)

  be add_proxy(p_step_id: U64, p_target_id: U64, target_node_name: String) =>
    _step_manager.add_proxy(p_step_id, p_target_id, target_node_name, this)

  be add_sink(sink_id: U64, step_id: U64, auth: AmbientAuth) =>
    _step_manager.add_sink(sink_id, step_id, auth)

  be connect_steps(step_id: U64, target_id: U64) =>
    _step_manager.connect_steps(step_id, target_id)


  ///////////////
  // CONNECTIONS
  ///////////////
  be add_listener(listener: TCPListener) =>
    _listeners.push(listener)

  be add_connection(conn: TCPConnection) =>
    _connections.push(conn)

  be add_phone_home_connection(conn: TCPConnection) =>
    _phone_home_connection = conn

  be establish_control_connection(target_name: String, target_host: String,
    target_service: String) =>
    _control_addrs(target_name) = (target_host, target_service)
    let notifier: TCPConnectionNotify iso =
      WorkerConnectNotify(_env, _auth, _node_name, target_host,
        target_service, this, _metrics_collector)
    let conn: TCPConnection =
      TCPConnection(_auth, consume notifier, target_host,
        target_service)
    add_control_connection(target_name, conn)

  be add_control_connection(target_name: String, conn: TCPConnection) =>
    if not _control_connections.contains(target_name) then
      _control_connections(target_name) = conn
      _ack_control_channel()
    end

  fun _ack_control_channel() =>
    match _topology_manager
    | let t: TopologyManager =>
      t.ack_control()
    end

  be establish_data_connection(target_name: String, target_host: String,
    target_service: String) =>
    _data_addrs(target_name) = (target_host, target_service)
    let notifier: TCPConnectionNotify iso =
      IntraclusterDataSenderConnectNotify(_env, _auth, _node_name, target_name, this)
    let conn: TCPConnection =
      TCPConnection(_auth, consume notifier, target_host,
        target_service)
    _data_connection_senders(target_name) = DataSender(target_name, conn)
    _data_connection_receivers(target_name) = DataReceiver(target_name, this)
    _ack_data_channel()

  fun _ack_data_channel() =>
    match _topology_manager
    | let t: TopologyManager =>
      t.ack_data()
    end


  ////////
  // SEND
  ////////
  be send_control_message(target_name: String, msg: Array[U8] val) =>
    try
      _control_connections(target_name).write(msg)
    else
      _env.out.print("Coordinator: no control conn to " + target_name)
    end

  be send_data_message(target_name: String, msg: Array[U8] val) =>
    try
      _data_connection_senders(target_name).write(msg)
    else
      _env.out.print("Coordinator: no data conn for " + target_name)
    end

  be deliver(step_id: U64, from_name: String, msg: StepMessage val) =>
    try _data_connection_receivers(from_name).received() end
    _step_manager(step_id, msg)

  be send_phone_home_message(msg: Array[U8] val) =>
    match _phone_home_connection
    | let phc: TCPConnection =>
      phc.write(msg)
    end

  be enable_sending(target_name: String) =>
    try _data_connection_senders(target_name).enable_sending() end

  be ack_msg_count(sender_name: String, seen_since_last_ack: U64) =>
    try
      let message = WireMsgEncoder.ack_messages_received(_node_name, seen_since_last_ack, _auth)
      _control_connections(sender_name).write(message)
    end

  be process_data_ack(receiver_name: String, msg_count: U64) =>
    try _data_connection_senders(receiver_name).ack(msg_count) end


  /////////////
  // RECONNECT
  /////////////
  be reconnect_data(target_name: String) =>
    @printf[None](("!!Reconnecting to " + target_name + "!!\n").cstring())
    try
      (let target_host: String, let target_service: String) =
        _data_addrs(target_name)
      let notifier: TCPConnectionNotify iso =
        IntraclusterDataSenderConnectNotify(_env, _auth, _node_name, target_name, this)
      let conn: TCPConnection =
        TCPConnection(_auth, consume notifier, target_host,
          target_service)
      _data_connection_senders(target_name).reconnect(conn)
      let reconnect_message = WireMsgEncoder.reconnect_data(_node_name, _auth)
      try _control_connections(target_name).write(reconnect_message) end
    else
      _env.err.print("Coordinator: couldn't reconnect to " + target_name)
    end

  be negotiate_data_reconnection(from_name: String) =>
    @printf[None](("!!Acking reconnection to sender " + from_name + "!!\n").cstring())
    try
      _data_connection_receivers(from_name).reconnect_ack()
    else
      _env.out.print("Can't negotiate since there's no DataReceiver!")
    end

  be ack_reconnect_msg_count(sender_name: String, seen_since_last_ack: U64) =>
    try
      let message = WireMsgEncoder.ack_reconnect_messages_received(_node_name,
        seen_since_last_ack, _auth)
      _control_connections(sender_name).write(message)
    end

  be process_data_reconnect_ack(receiver_name: String, seen_since_last_ack: U64) =>
    try
      _data_connection_senders(receiver_name).ack_reconnect(seen_since_last_ack)
    end



  ////////////
  // SHUTDOWN
  ////////////
  be shutdown() =>
    match _topology_manager
    | let t: TopologyManager =>
      t.shutdown()
    else
      finish_shutdown()
    end

  be finish_shutdown() =>
    try
      let shutdown_msg = WireMsgEncoder.shutdown(_node_name, _auth)

      for listener in _listeners.values() do
        listener.dispose()
      end

      for (key, conn) in _control_connections.pairs() do
        conn.write(shutdown_msg)
        conn.dispose()
      end
      for (k, sender) in _data_connection_senders.pairs() do
        sender.write(shutdown_msg)
        sender.dispose()
      end
      for c in _connections.values() do
        c.dispose()
      end

      match _phone_home_connection
      | let phc: TCPConnection =>
        phc.write(WireMsgEncoder.done_shutdown(_node_name, _auth))
        phc.dispose()
      end
    else
      _env.out.print("Coordinator: problem shutting down!")
    end
