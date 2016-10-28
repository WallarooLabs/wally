use "collections"
use "net"
use "wallaroo/messages"
use "wallaroo/network"
use "wallaroo/topology"
use "time"

actor DataReceiver
  var _sender_name: String = ""
  let _connections: Connections
  var _router: DataRouter val = DataRouter(recover Map[U128, Step tag] end)
  var _last_id_seen: U64 = 0
  var _connected: Bool = false
  var _reconnecting: Bool = false
  // let _timers: Timers = Timers
  // let _incoming_envelope: MsgEnvelope ref = MsgEnvelope(None, 0, None, 0, 0)
  // let _outgoing_envelope: MsgEnvelope ref = MsgEnvelope(None, 0, None, 0, 0)

  new create(connections: Connections) =>
    _connections = connections
    // let t = Timer(_Ack(this), 1_000_000_000, 1_000_000_000)
    // _timers(consume t)

  be update_router(router: DataRouter val) =>
    _router = router

  be register_sender_name(name: String) =>
    _sender_name = name

  be received(d: DeliveryMsg val)
  =>  
    //TODO: read envelope from data
    //TODO: manage values for outgoing envelope at router?
    // _incoming_envelope.update(None, 0, None, 0, 0)
    // _outgoing_envelope.update(None, 0, None, 0, 0)

    if d.seq_id() > _last_id_seen then
      _last_id_seen = d.seq_id()
      _router.route(d)
      // match _router.route(target_step_id)
      // | let s: Step tag =>
      //   s.run[D](metric_name, source_ts, msg_data)
    end

  be ack() => _ack()

  fun ref _ack() =>
    None
    // _connections.ack_msg_id(_sender_name, _last_id_seen)

  be open_connection() =>
    if _connected == true then
      _reconnecting = true
    else
      // _connect_ack()
      _connected = true
      _reconnecting = false
    end

  be close_connection() =>
    if _reconnecting == true then
      // _connect_ack()
      _reconnecting = false
      _connected = true
    else
      _connected = false
    end

  // be connect_ack() => _connect_ack()

  // fun ref _connect_ack() =>
  //   _connections.ack_connect_msg_id(_sender_name, _last_id_seen)

  be dispose() => 
    None
    // _timers.dispose()

class _Ack is TimerNotify
  let _receiver: DataReceiver

  new iso create(receiver: DataReceiver) =>
    _receiver = receiver

  fun ref apply(timer: Timer, count: U64): Bool =>
    _receiver.ack()
    true