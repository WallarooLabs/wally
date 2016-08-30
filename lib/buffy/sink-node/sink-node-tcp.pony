use "net"
use "collections"
use "sendence/messages"
use "sendence/bytes"
use "sendence/epoch"
use "buffy/topology"
use "logger"

class SinkNodeNotifier is TCPListenNotify
  let _env: Env
  let _auth: AmbientAuth
  let _sink_node_step: StringInStep tag
  let _host: String
  let _service: String
  let _coordinator: SinkNodeCoordinator
  let _logger: Logger[String]

  new iso create(env: Env, auth: AmbientAuth, 
    sink_node_step: StringInStep tag, host: String, service: String,
    coordinator: SinkNodeCoordinator, logger': Logger[String]) =>
    _env = env
    _auth = auth
    _sink_node_step = sink_node_step
    _host = host
    _service = service
    _coordinator = coordinator
    _logger = logger'

  fun ref listening(listen: TCPListener ref) =>
    _coordinator.buffy_ready(listen)
    _logger(Info) and _logger.log("Sink node: listening on " + _host + ":" + _service)

  fun ref not_listening(listen: TCPListener ref) =>
    _coordinator.buffy_failed(listen)
    _logger(Info) and _logger.log("Sink node: couldn't listen")

  fun ref connected(listen: TCPListener ref) : TCPConnectionNotify iso^ =>
    SinkNodeConnectNotify(_env, _auth, _sink_node_step, _logger)

class SinkNodeConnectNotify is TCPConnectionNotify
  let _env: Env
  let _auth: AmbientAuth
  let _sink_node_step: StringInStep tag
  var _header: Bool = true
  var _msg_count: USize = 0
  let _logger: Logger[String]

  new iso create(env: Env, auth: AmbientAuth, sink_node_step: StringInStep tag, logger': Logger[String]) =>
    _env = env
    _auth = auth
    _sink_node_step = sink_node_step
    _logger = logger'

  fun ref accepted(conn: TCPConnection ref) =>
    conn.expect(4)

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso): Bool =>
    if _header then
      try
        let expect = Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()
        conn.expect(expect)
        _header = false
      else
        _logger(Error) and _logger.log("Error reading header from external source")
      end
    else
      try
        let decoded: Array[String] val = FallorMsgDecoder(consume data)
        _sink_node_step(decoded)
      else
        _logger(Error) and _logger.log("sink node: Unable to decode message")
      end

      conn.expect(4)
      _header = true
      _msg_count = _msg_count + 1
      if _msg_count >= 5 then
        _msg_count = 0
        return false
      end
    end
    true

  fun ref connected(conn: TCPConnection ref) =>
    _logger(Info) and _logger.log("Sink node: connected.")

  fun ref connect_failed(conn: TCPConnection ref) =>
    _logger(Info) and _logger.log("Sink node: connection failed.")

  fun ref closed(conn: TCPConnection ref) =>
    _logger(Info) and _logger.log("Sink node: server closed")


class SinkNodeOutConnectNotify is TCPConnectionNotify
  let _env: Env
  let _coordinator: SinkNodeCoordinator
  let _logger: Logger[String]

  new iso create(env: Env, coordinator: SinkNodeCoordinator, logger': Logger[String]) =>
    _env = env
    _coordinator = coordinator
    _logger = logger'

  fun ref accepted(conn: TCPConnection ref) =>
    _logger(Info) and _logger.log("sink out: sink connection accepted")

  fun ref connected(conn: TCPConnection ref) =>
    _coordinator.add_connection(conn)

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso): Bool =>
    _logger(Info) and _logger.log("sink out: received")
    true

  fun ref closed(conn: TCPConnection ref) =>
    _logger(Info) and _logger.log("sink out: server closed")

