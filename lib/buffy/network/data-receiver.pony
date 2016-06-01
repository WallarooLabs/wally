use "net"
use "collections"

actor DataReceiver
  let _sender_name: String
  let _coordinator: Coordinator
  var _seen_since_last_ack: U64 = 0
  var _connected: Bool = false
  var _reconnecting: Bool = false

  new create(sender_name: String, coordinator: Coordinator) =>
    _sender_name = sender_name
    _coordinator = coordinator

  be received() =>
    _seen_since_last_ack = _seen_since_last_ack + 1
    if _seen_since_last_ack > 150 then
      ack()
    end

  be ack() =>
    _coordinator.ack_msg_count(_sender_name, _seen_since_last_ack)
    _seen_since_last_ack = 0

  be open_connection() =>
    if _connected == true then
      _reconnecting = true
    else
      connect_ack()
      _connected = true
      _reconnecting = false
    end

  be close_connection() =>
    if _reconnecting == true then
      connect_ack()
      _reconnecting = false
      _connected = true
    else
      _connected = false
    end

  be connect_ack() =>
    @printf[None](("Receiver: connect acking " + _seen_since_last_ack.string() + "\n").cstring())
    _coordinator.ack_connect_msg_count(_sender_name, _seen_since_last_ack)
    _seen_since_last_ack = 0
