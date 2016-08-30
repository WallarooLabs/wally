use "net"
use "sendence/messages"
use "sendence/bytes"
use "logger"

class HomeConnectNotify is TCPConnectionNotify
  let _env: Env
  let _name: String
  let _coordinator: Coordinator
  var _header: Bool = true
  var _has_connected: Bool = false
  let _logger: Logger[String]
 
  new iso create(env: Env, name: String,
    coordinator: Coordinator, logger': Logger[String]) =>
    _env = env
    _name = name
    _coordinator = coordinator
    _logger = logger'
   
  fun ref connected(conn: TCPConnection ref) =>
    if not _has_connected then
      conn.expect(4)
      _has_connected = true
    end
  
  fun ref received(conn: TCPConnection ref, data: Array[U8] iso): Bool =>
    if _header then
      try
        let expect = Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()
        conn.expect(expect)
        _header = false
      else
        _logger(Error) and _logger.log("Error reading header on phone home channel")
      end
    else
      try
        let external_msg = ExternalMsgDecoder(consume data)
        match external_msg
        | let m: ExternalShutdownMsg val =>
          _coordinator.shutdown()
        end
      else
        _logger(Error) and _logger.log("Phone home connection: error decoding phone home message")
      end

      conn.expect(4)
      _header = true
    end
    true

  fun ref closed(conn: TCPConnection ref) =>
    _logger(Info) and _logger.log(_name + ": server closed")
