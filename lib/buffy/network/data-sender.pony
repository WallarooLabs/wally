use "net"
use "collections"
use "buffy/messages"

actor DataSender
  let _sender_name: String
  let _target_name: String
  var _conn: TCPConnection
  let _auth: AmbientAuth
  let _held: Queue[Array[U8] val] = Queue[Array[U8] val]
  var _sending: Bool = true

  new create(sender_name: String, target_name: String, conn: TCPConnection,
    auth: AmbientAuth) =>
    _sender_name = sender_name
    _target_name = target_name
    _conn = conn
    _auth = auth

  be write(msg_data: Array[U8] val) =>
    _held.enqueue(msg_data)
    if _sending then
      _conn.write(msg_data)
    end

  be send_ready() => _send_ready()

  fun ref _send_ready() =>
    try
      let msg = WireMsgEncoder.data_sender_ready(_sender_name, _auth)
      _conn.write(msg)
    end

  be ack(msg_count: U64) => _ack(msg_count)

  fun ref _ack(msg_count: U64) =>
    for i in Range(0, msg_count.usize()) do
      try
        @printf[None](("Dequeuing " + i.string() + " of " + msg_count.string() + "!!\n").cstring())
        _held.dequeue()
      else
        @printf[None]("Couldn't dequeue!!\n".cstring())
      end
    end

  be ack_connect(msg_count: U64) =>
    @printf[None](("Sender: connect ack received " + msg_count.string() + "\n").cstring())
    _ack(msg_count)

    if not _sending then
      _enable_sending()
    end

  be reconnect(conn: TCPConnection) =>
    _conn = conn
    _sending = false
    _send_ready()

  fun ref _enable_sending() =>
    let size = _held.size()
    for idx in Range(0, size) do
      try
        let next_msg = _held(idx)
        _conn.write(next_msg)
        @printf[None](("Resending " + idx.string() + " of " + size.string() + "!!\n").cstring())
      else
        @printf[None]("Couldn't resend!!\n".cstring())
      end
    end
    _sending = true

  be dispose() =>
    _conn.dispose()
