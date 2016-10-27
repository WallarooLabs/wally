use "net"
use "collections"
use "buffy/messages"
use "sendence/queue"

actor DataSender
  let _sender_name: String
  let _target_name: String
  var _conn: TCPConnection
  let _auth: AmbientAuth
  let _held: Queue[_TCPMsg] = Queue[_TCPMsg]
  var _sending: Bool = true
  var _msg_id: U64 = 1

  new create(sender_name: String, target_name: String, conn: TCPConnection,
    auth: AmbientAuth) =>
    _sender_name = sender_name
    _target_name = target_name
    _conn = conn
    _auth = auth

  be forward[D: Any val](step_id: U64, from_node_name: String, msg_id: U64, 
    source_ts: U64, ingress_ts: U64, msg_data: D) =>
    try
      let data_msg = WireMsgEncoder.data_channel[D](_msg_id, step_id, 
        from_node_name, msg_id, source_ts, ingress_ts, msg_data, _auth)
      _held.enqueue(_TCPMsg(_msg_id, data_msg))
      _msg_id = _msg_id + 1
      if _sending then
        _conn.writev(data_msg)
      end
    end

  be writev(msg: Array[ByteSeq] val) =>
    _conn.writev(msg)

  be send_ready() => _send_ready()

  fun ref _send_ready() =>
    try
      let msg = WireMsgEncoder.data_sender_ready(_sender_name, _auth)
      _conn.writev(msg)
    end

  be ack(msg_id: U64) => _ack(msg_id)

  fun ref _ack(msg_id: U64) =>
    var i: USize = 0
    while i < _held.size() do
      try
        if _held.peek().msg_id <= msg_id then
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
        let next_msg = _held(idx).data
        _conn.writev(next_msg)
      else
        @printf[I32]("Couldn't resend!\n".cstring())
      end
    end
    _sending = true

  be dispose() =>
    _conn.dispose()

class _TCPMsg
  let msg_id: U64
  let data: Array[ByteSeq] val

  new create(m_id: U64, d: Array[ByteSeq] val) =>
    msg_id = m_id
    data = d
