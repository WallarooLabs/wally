use "net"
use "sendence/messages"
use "sendence/bytes"

class HomeConnectNotify is TCPConnectionNotify
  let _env: Env
  let _name: String
  let _connections: Connections
  var _header: Bool = true
  var _has_connected: Bool = false
 
  new iso create(env: Env, name: String, connections: Connections) =>
    _env = env
    _name = name
    _connections = connections
   
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
        _env.err.print("Error reading header on phone home channel")
      end
    else
      try
        let external_msg = ExternalMsgDecoder(consume data)
        match external_msg
        | let m: ExternalShutdownMsg val =>
          _connections.shutdown()
        end
      else
        _env.err.print("Phone home connection: error decoding phone home message")
      end

      conn.expect(4)
      _header = true
    end
    true

  fun ref closed(conn: TCPConnection ref) =>
    _env.out.print(_name + ": server closed")
