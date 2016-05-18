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
  let _data_connections: Map[String, DataSender]
    = Map[String, DataSender]
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
        SpikeWrapper(IntraclusterDataSenderConnectNotify(_env, _node_name,
          "leader", this), _spike_config)
      let data_conn: TCPConnection =
        TCPConnection(_auth, consume data_notifier, _leader_data_host,
          _leader_data_service)
      _data_connections("leader") = DataSender(data_conn)
    end

  be shutdown() =>
    match _topology_manager
    | let t: TopologyManager =>
      t.shutdown()
    else
      finish_shutdown()
    end

  be finish_shutdown() =>
    let shutdown_msg = WireMsgEncoder.shutdown(_node_name)

    for listener in _listeners.values() do
      listener.dispose()
    end

    for (key, conn) in _control_connections.pairs() do
      conn.write(shutdown_msg)
      conn.dispose()
    end
    for (k, sender) in _data_connections.pairs() do
      sender.write(shutdown_msg)
      sender.dispose()
    end
    for c in _connections.values() do
      c.dispose()
    end

    match _phone_home_connection
    | let phc: TCPConnection =>
      phc.write(WireMsgEncoder.done_shutdown(_node_name))
      phc.dispose()
    end

  be identify_data_channel(host: String, service: String) =>
    try
      let message = WireMsgEncoder.identify_data(_node_name, host, service)
      _control_connections("leader").write(message)
    else
      _env.out.print("Coordinator: control connection to leader was not set up")
    end

  be identify_control_channel(host: String, service: String) =>
    try
      let message = WireMsgEncoder.identify_control(_node_name, host, service)
      _control_connections("leader").write(message)
    else
      _env.out.print("Coordinator: control connection to leader was not set up")
    end

  be send_control_message(target_name: String, msg: Array[U8] val) =>
    try
      _control_connections(target_name).write(msg)
    end

  be send_data_message(target_name: String, msg: Array[U8] val) =>
    try
      _data_connections(target_name).write(msg)
    else
      _env.out.print("Coordinator: no data conn for " + target_name)
    end

  be deliver(step_id: I32, msg: StepMessage val) =>
    _step_manager(step_id, msg)

  be send_phone_home_message(msg: Array[U8] val) =>
    match _phone_home_connection
    | let phc: TCPConnection =>
      phc.write(msg)
    end

  be reconnect_data(target_name: String) =>
    try
      (let target_host: String, let target_service: String) =
        _data_addrs(target_name)
      let notifier: TCPConnectionNotify iso =
        SpikeWrapper(IntraclusterDataSenderConnectNotify(_env, _node_name,
          target_name, this), _spike_config)
      let conn: TCPConnection =
        TCPConnection(_auth, consume notifier, target_host,
          target_service)
      _data_connections(target_name) = DataSender(conn)
    else
      _env.err.print("Coordinator: couldn't reconnect to " + target_name)
    end

  be add_step(step_id: I32, comp_type: String) =>
    _step_manager.add_step(step_id, comp_type)

  be add_proxy(p_step_id: I32, p_target_id: I32, target_node_name: String,
    target_host: String, target_service: String) =>
    if _data_connections.contains(target_node_name) then
      _step_manager.add_proxy(p_step_id, p_target_id, target_node_name, this)
    else
      _data_addrs(target_node_name) = (target_host, target_service)
      let notifier: TCPConnectionNotify iso =
        SpikeWrapper(IntraclusterDataSenderConnectNotify(_env, _node_name,
          target_node_name, this), _spike_config)
      let conn: TCPConnection =
        TCPConnection(_auth, consume notifier, target_host, target_service)
      _data_connections(target_node_name) = DataSender(conn)
      _step_manager.add_proxy(p_step_id, p_target_id, target_node_name, this)
    end

  be add_sink(sink_id: I32, step_id: I32, auth: AmbientAuth) =>
    _step_manager.add_sink(sink_id, step_id, auth)

  be connect_steps(step_id: I32, target_id: I32) =>
    _step_manager.connect_steps(step_id, target_id)

  be add_phone_home_connection(conn: TCPConnection) =>
    _phone_home_connection = conn

  be add_listener(listener: TCPListener) =>
    _listeners.push(listener)

  be add_connection(conn: TCPConnection) =>
    _connections.push(conn)

  be add_control_connection(target_name: String, target_host: String,
    target_service: String) =>
    _control_addrs(target_name) = (target_host, target_service)
    let notifier: TCPConnectionNotify iso =
      WorkerConnectNotify(_env, _auth, _node_name, target_host,
        target_service, this, _metrics_collector)
    let conn: TCPConnection =
      TCPConnection(_auth, consume notifier, target_host,
        target_service)
    _control_connections(target_name) = conn

  be add_data_connection(target_name: String, target_host: String,
    target_service: String) =>
    _data_addrs(target_name) = (target_host, target_service)
    let notifier: TCPConnectionNotify iso =
      SpikeWrapper(IntraclusterDataSenderConnectNotify(_env, _node_name,
        target_name, this), _spike_config)
    let conn: TCPConnection =
      TCPConnection(_auth, consume notifier, target_host,
        target_service)
    _data_connections(target_name) = DataSender(conn)

  be add_topology_manager(tm: TopologyManager) =>
    _topology_manager = tm
