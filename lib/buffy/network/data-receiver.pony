use "net"
use "buffy/messages"
use "../topology"
use "time"

actor DataReceiver
  let _sender_name: String
  let _coordinator: Coordinator
  var _last_id_seen: U64 = 0
  var _connected: Bool = false
  var _reconnecting: Bool = false
  let _timers: Timers = Timers

  new create(sender_name: String, coordinator: Coordinator) =>
    _sender_name = sender_name
    _coordinator = coordinator
    let t = Timer(_Ack(this), 1_000_000_000, 1_000_000_000)
    _timers(consume t)

  be received(data_ch_id: U64, step_id: U64, msg_id: U64, source_ts: U64, 
    ingress_ts: U64, msg_data: Any val, step_manager: StepManager tag) =>
    if data_ch_id > _last_id_seen then
      _last_id_seen = data_ch_id
      step_manager(step_id, msg_id, source_ts, ingress_ts, msg_data)
    end

  be ack() => _ack()

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

  be dispose() => _timers.dispose()

class _Ack is TimerNotify
  let _receiver: DataReceiver

  new iso create(receiver: DataReceiver) =>
    _receiver = receiver

  fun ref apply(timer: Timer, count: U64): Bool =>
    _receiver.ack()
    true
