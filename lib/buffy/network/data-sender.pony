use "net"
use "collections"

actor DataSender
  var _conn: TCPConnection
  let _held: Array[Array[U8] val] = Array[Array[U8] val]

  new create(conn: TCPConnection) =>
    _conn = conn

  be write(msg_data: Array[U8] val) =>
    _held.unshift(msg_data)
    _conn.write(msg_data)

  be ack(msg_count: USize) =>
    for i in Range(0, msg_count) do
      try
        _held.pop()
      end
    end

  be update_connection(conn: TCPConnection) =>
    _conn = conn

  be dispose() =>
    _conn.dispose()
