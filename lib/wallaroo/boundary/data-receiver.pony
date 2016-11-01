use "collections"
use "net"
use "time"
use "wallaroo/network"
use "wallaroo/topology"
use "wallaroo/resilience"
use "wallaroo/messages"

actor DataReceiver is Origin
  var _sender_name: String = ""
  let _connections: Connections
  var _router: DataRouter val = DataRouter(recover Map[U128, Step tag] end)
  var _last_id_seen: U64 = 0
  var _connected: Bool = false
  var _reconnecting: Bool = false
  //TODO: why 10?
  let _hwm: HighWatermarkTable = HighWatermarkTable(10)
  let _lwm: LowWatermarkTable = LowWatermarkTable(10)
  let _origins: OriginSet = OriginSet(10)
  let _seq_translate: SeqTranslationTable = SeqTranslationTable(10)
  let _route_translate: RouteTranslationTable = RouteTranslationTable(10)
  let _alfred: Alfred

  // let _timers: Timers = Timers
  be request_replay() =>
    //TODO: request upstream replays
    None

  //TODO: this should be triggered by a special message
  be upstream_replay_finished() =>
    _alfred.upstream_replay_finished(this)


  fun ref _hwm_get(): HighWatermarkTable => _hwm
  fun ref _lwm_get(): LowWatermarkTable => _lwm
  fun ref _origins_get(): OriginSet => _origins
  fun ref _seq_translate_get(): SeqTranslationTable => _seq_translate
  fun ref _route_translate_get(): RouteTranslationTable => _route_translate

  new create(connections: Connections, alfred: Alfred) =>
    _connections = connections
    _alfred = alfred
    _alfred.register_incoming_boundary(this)
    // let t = Timer(_Ack(this), 1_000_000_000, 1_000_000_000)
    // _timers(consume t)

  be update_router(router: DataRouter val) =>
    _router = router

  be register_sender_name(name: String) =>
    _sender_name = name

  be received(d: DeliveryMsg val)
  =>  
    if d.seq_id() > _last_id_seen then
      _last_id_seen = d.seq_id()
      _router.route(d, this)
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
