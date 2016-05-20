use "net"
use "collections"

actor DataReceiver
  let _sender_name: String
  let _coordinator: Coordinator
  var _seen_since_last_ack: U64 = 0

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

  be reconnect_ack() =>
    _coordinator.ack_reconnect_msg_count(_sender_name, _seen_since_last_ack)
    _seen_since_last_ack = 0
