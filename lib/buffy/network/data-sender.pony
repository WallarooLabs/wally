use "net"
use "collections"
use "buffy/messages"

actor DataSender
  let _sender_name: String
  let _target_name: String
  var _conn: TCPConnection
  let _auth: AmbientAuth
  let _held: Queue[(U64, Array[U8] val)] = Queue[(U64, Array[U8] val)]
  var _sending: Bool = true
  var _msg_id: U64 = 1

  new create(sender_name: String, target_name: String, conn: TCPConnection,
    auth: AmbientAuth) =>
    _sender_name = sender_name
    _target_name = target_name
    _conn = conn
    _auth = auth

  be forward(f: Forward val) =>
    try
      let data_msg = WireMsgEncoder.data_channel(_msg_id, f, _auth)
      _held.enqueue((_msg_id, data_msg))
      _msg_id = _msg_id + 1
      if _sending then
        _conn.write(data_msg)
      end
    end

  be write(msg: Array[U8] val) =>
    _conn.write(msg)

  be send_ready() => _send_ready()

  fun ref _send_ready() =>
    try
      let msg = WireMsgEncoder.data_sender_ready(_sender_name, _auth)
      _conn.write(msg)
    end

  be ack(msg_id: U64) => _ack(msg_id)

  fun ref _ack(msg_id: U64) =>
    var i: USize = 0
    while i < _held.size() do
      try
        if _held.peek()._1 <= msg_id then
          _held.dequeue()
          i = i + 1
        else
          break
        end
      end
    end

  be ack_connect(msg_id: U64) =>
    _ack(msg_id)

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
        let next_msg = _held(idx)._2
        _conn.write(next_msg)
      else
        @printf[None]("Couldn't resend!!\n".cstring())
      end
    end
    _sending = true

  be dispose() =>
    _conn.dispose()
