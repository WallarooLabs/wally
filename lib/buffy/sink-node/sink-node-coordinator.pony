use "net"
use "sendence/messages"
use "logger"

primitive SinkNodeCoordinatorFactory
  fun apply(env: Env,
    node_id: (String | None),
    phone_home_addr: (Array[String] | None),
    logger: Logger[String]): SinkNodeCoordinator ?
  =>
    if (node_id isnt None) and (phone_home_addr isnt None) then
      let n = node_id as String
      let ph = phone_home_addr as Array[String]
      let coordinator = WithPhoneHomeSinkNodeCoordinator(env, n, logger)

      let tcp_auth = TCPConnectAuth(env.root as AmbientAuth)
      TCPConnection(
        tcp_auth,
        SinkNodeHomeConnectNotify(env, n, coordinator, logger),
        ph(0),
        ph(1))

      coordinator
    else
      WithoutPhoneHomeSinkNodeCoordinator(env, logger)
    end

interface tag SinkNodeCoordinator
  be shutdown()
  be buffy_ready(listener: TCPListener)
  be buffy_failed(listener: TCPListener)
  be add_connection(conn: TCPConnection)

actor WithoutPhoneHomeSinkNodeCoordinator is SinkNodeCoordinator
  let _env: Env
  var _buffy_listener: (TCPListener | None) = None
  let _connections: Array[TCPConnection] = Array[TCPConnection]
  let _logger: Logger[String]

  new create(env: Env, logger': Logger[String]) =>
    _env = env
    _logger = logger'

  be shutdown() =>
    try
      let l = _buffy_listener as TCPListener
      l.dispose()
    end
    for conn in _connections.values() do conn.dispose() end

  be buffy_ready(listener: TCPListener) =>
    _buffy_listener = listener
    _logger(Info) and _logger.log("Listening for data")

  be buffy_failed(listener: TCPListener) =>
    _logger(Error) and _logger.log("Unable to open listener")
    listener.dispose()

  be add_connection(conn: TCPConnection) =>
    _connections.push(conn)

actor WithPhoneHomeSinkNodeCoordinator is SinkNodeCoordinator
  let _env: Env
  var _from_buffy_listener: (TCPListener | None) = None
  var _phone_home_connection: (TCPConnection | None) = None
  let _node_id: String
  let _connections: Array[TCPConnection] = Array[TCPConnection]
  var _phone_home_is_ready: Bool = false
  var _buffy_is_ready: Bool = false
  let _logger: Logger[String]

  new create(env: Env, node_id: String, logger': Logger[String]) =>
    _env = env
    _node_id = node_id
    _logger = logger'

  be shutdown() =>
    try
      let l = _from_buffy_listener as TCPListener
      l.dispose()
    end
    for conn in _connections.values() do conn.dispose() end
    try
      let conn = _phone_home_connection as TCPConnection
      conn.writev(ExternalMsgEncoder.done_shutdown(_node_id))
      conn.dispose()
    end

  be buffy_ready(listener: TCPListener) =>
    _from_buffy_listener = listener
    _buffy_is_ready = true
    _logger(Info) and _logger.log("Listening for data")
    _alert_ready_if_ready()

  be buffy_failed(listener: TCPListener) =>
    _logger(Error) and _logger.log("Unable to open listener")
    listener.dispose()

  be phone_home_ready(conn: TCPConnection) =>
    _phone_home_connection = conn
    _phone_home_is_ready = true
    _alert_ready_if_ready()

  be phone_home_failed(conn: TCPConnection) =>
    _logger(Error) and _logger.log("Unable to open phone home connection")
    conn.dispose()

  fun _alert_ready_if_ready() =>
    if _phone_home_is_ready and _buffy_is_ready then
      try
        let conn = _phone_home_connection as TCPConnection
        conn.writev(ExternalMsgEncoder.ready(_node_id))
       end
    end

  be add_connection(conn: TCPConnection) =>
    _connections.push(conn)
