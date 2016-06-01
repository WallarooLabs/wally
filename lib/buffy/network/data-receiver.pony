use "net"
use "collections"
use "buffy/messages"
use "../topology"

actor DataReceiver
  let _sender_name: String
  let _coordinator: Coordinator
  var _last_id_seen: U64 = 0
  var _connected: Bool = false
  var _reconnecting: Bool = false

  new create(sender_name: String, coordinator: Coordinator) =>
    _sender_name = sender_name
    _coordinator = coordinator

  be received(data_ch_id: U64, step_id: U64, msg: StepMessage val,
    step_manager: StepManager tag) =>
    if data_ch_id > _last_id_seen then
      _last_id_seen = data_ch_id
      if (_last_id_seen % 150) == 0 then
        _ack()
      end
      step_manager(step_id, msg)
    end

  fun ref _ack() =>
    _coordinator.ack_msg_id(_sender_name, _last_id_seen)

  be open_connection() =>
    if _connected == true then
      _reconnecting = true
    else
      _connect_ack()
      _connected = true
      _reconnecting = false
    end

  be close_connection() =>
    if _reconnecting == true then
      _connect_ack()
      _reconnecting = false
      _connected = true
    else
      _connected = false
    end

  be connect_ack() => _connect_ack()

  fun ref _connect_ack() =>
    _coordinator.ack_connect_msg_id(_sender_name, _last_id_seen)
