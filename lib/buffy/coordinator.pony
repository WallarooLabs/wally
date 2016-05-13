use "net"
use "buffy/messages"
use "spike"

actor Coordinator
  let _env: Env
  let _auth: AmbientAuth
  let _node_name: String
  let _leader_host: String
  let _leader_service: String
  let _step_manager: StepManager
  let _listeners: Array[TCPListener] = Array[TCPListener]
  let _connections: Array[TCPConnection] = Array[TCPConnection]
  var _phone_home_connection: (TCPConnection | None) = None
  var _topology_manager: (TopologyManager | None) = None

  new create(name: String, env: Env, auth: AmbientAuth, leader_host: String,
    leader_service: String, step_manager: StepManager) =>
    _node_name = name
    _env = env
    _auth = auth
    _leader_host = leader_host
    _leader_service = leader_service
    _step_manager = step_manager

  be shutdown() =>
    match _topology_manager
    | let t: TopologyManager =>
      t.shutdown()
    else
      finish_shutdown()
    end

  be finish_shutdown() =>
    for listener in _listeners.values() do
      listener.dispose()
    end
    for conn in _connections.values() do
      conn.dispose()
    end

    match _phone_home_connection
    | let phc: TCPConnection =>
      phc.write(WireMsgEncoder.done_shutdown(_node_name))
      phc.dispose()
    end

  be identify_data_channel(host: String, service: String,
    spike_config: SpikeConfig val) =>
    let notifier: TCPConnectionNotify iso =
      SpikeWrapper(IntraclusterDataConnectNotify(_env, _node_name,
        _step_manager, this), spike_config)
    let conn: TCPConnection =
      TCPConnection(_auth, consume notifier, _leader_host, _leader_service)

    let message = WireMsgEncoder.identify_data(_node_name, host, service)
    conn.write(message)

  be add_phone_home_connection(conn: TCPConnection) =>
    _phone_home_connection = conn

  be add_listener(listener: TCPListener) =>
    _listeners.push(listener)

  be add_connection(conn: TCPConnection) =>
    _connections.push(conn)

  be add_topology_manager(tm: TopologyManager) =>
    _topology_manager = tm
