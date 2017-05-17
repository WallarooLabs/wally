use "net"
use "sendence/messages"
use "sendence/bytes"
use "wallaroo/fail"

class HomeConnectNotify is TCPConnectionNotify
  let _name: String
  let _connections: Connections
  var _header: Bool = true
  var _has_connected: Bool = false

  new iso create(name: String, connections: Connections) =>
    _name = name
    _connections = connections

  fun ref connected(conn: TCPConnection ref) =>
    if not _has_connected then
      conn.expect(4)
      _has_connected = true
    end

  fun ref connect_failed(conn: TCPConnection ref) =>
    @printf[I32]("Unable to connect to phone home address\n".cstring())

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso,
    n: USize): Bool
  =>
    if _header then
      try
        let expect = Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()
        conn.expect(expect)
        _header = false
      else
        @printf[I32]("Error reading header on phone home channel\n".cstring())
      end
    else
      try
        let external_msg = ExternalMsgDecoder(consume data)
        match external_msg
        | let m: ExternalShutdownMsg val =>
          @printf[I32]("Received ExternalShutdownMsg\n".cstring())
          _connections.shutdown()
        end
      else
        @printf[I32](("Phone home connection: error decoding phone home " +
          "message\n").cstring())
      end

      conn.expect(4)
      _header = true
    end
    true

  fun ref closed(conn: TCPConnection ref) =>
    @printf[I32](("HomeConnectNotify: " + _name + ": server closed\n").cstring())
