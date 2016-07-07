use "net"
use "sendence/messages"
use "sendence/bytes"

class SinkNodeHomeConnectNotify is TCPConnectionNotify
  let _env: Env
  let _name: String
  let _coordinator: WithPhoneHomeSinkNodeCoordinator
  var _header: Bool = true
  var _has_connected: Bool = false

  new iso create(env: Env, name: String,
    coordinator: WithPhoneHomeSinkNodeCoordinator) =>
    _env = env
    _name = name
    _coordinator = coordinator

  fun ref connect_failed(conn: TCPConnection ref) =>
    _coordinator.phone_home_failed(conn)

  fun ref connected(conn: TCPConnection ref) =>
    conn.expect(4)
    _coordinator.phone_home_ready(conn)

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso) =>
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
          _coordinator.shutdown()
        end
      else
        _env.err.print("Phone home connection: error decoding phone home message")
      end

      conn.expect(4)
      _header = true
    end

  fun ref closed(conn: TCPConnection ref) =>
    _env.out.print(_name + ": server closed")
