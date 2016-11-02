use "collections"
use "net"
use "time"
use "wallaroo/network"
use "wallaroo/topology"
use "wallaroo/resilience"
use "wallaroo/messages"

actor DataReceiver is Origin
  let _auth: AmbientAuth  
  let _worker_name: String
  var _sender_name: String
  var _sender_step_id: U128 = 0
  let _connections: Connections
  var _router: DataRouter val = 
    DataRouter(recover Map[U128, CreditFlowConsumerStep tag] end)
  var _last_id_seen: U64 = 0
  var _connected: Bool = false
  var _reconnecting: Bool = false
  let _hwm: HighWatermarkTable = HighWatermarkTable(1)
  let _lwm: LowWatermarkTable = LowWatermarkTable(1)
  let _origins: OriginSet = OriginSet(1)
  let _seq_translate: SeqTranslationTable = SeqTranslationTable(1)
  let _route_translate: RouteTranslationTable = RouteTranslationTable(1)
  let _alfred: Alfred

  new create(auth: AmbientAuth, worker_name: String, sender_name: String, 
    connections: Connections, alfred: Alfred) 
  =>
    _auth = auth
    _worker_name = worker_name
    _sender_name = sender_name
    _connections = connections
    _alfred = alfred
    _alfred.register_incoming_boundary(this)

  be data_connect(sender_step_id: U128) =>
    _sender_step_id = sender_step_id
    @printf[I32](("DataReceiver got DataConnectMsg from " + _sender_name + "\n").cstring())

  be request_replay() =>
    try
      let request_msg = ChannelMsgEncoder.request_replay(_worker_name,
        _sender_step_id, _auth)
      _connections.send_data(_sender_name, request_msg)
    else
      @printf[I32]("Error creating request replay message\n".cstring())
    end

  //TODO: this should be triggered by ReplayCompleteMsg
  be upstream_replay_finished() =>
    _alfred.upstream_replay_finished(this)

  fun ref _flush(low_watermark: U64, origin: Origin tag,
    upstream_route_id: U64 , upstream_seq_id: U64) =>
    """This is not a real Origin, so it doesn't write any State"""
    None

  be update_watermark(route_id: U64, seq_id: U64) =>
    //TODO: send watermark via TCP
    None

  fun ref hwm_get(): HighWatermarkTable => _hwm
  fun ref lwm_get(): LowWatermarkTable => _lwm
  fun ref origins_get(): OriginSet => _origins
  fun ref seq_translate_get(): SeqTranslationTable => _seq_translate
  fun ref route_translate_get(): RouteTranslationTable => _route_translate

  be update_router(router: DataRouter val) =>
    _router = router

  be received(d: DeliveryMsg val, seq_id: U64)
  =>  
    if seq_id > _last_id_seen then
      _last_id_seen = seq_id
      _router.route(d, this, seq_id)
      // match _router.route(target_step_id)
      // | let s: Step tag =>
      //   s.run[D](metric_name, source_ts, msg_data)
    end

//  be ack() => _ack()
//
//  fun ref _ack() =>
//    None
//    // _connections.ack_msg_id(_sender_name, _last_id_seen)
//
//  be open_connection() =>
//    if _connected == true then
//      _reconnecting = true
//    else
//      // _connect_ack()
//      _connected = true
//      _reconnecting = false
//    end
//
//  be close_connection() =>
//    if _reconnecting == true then
//      // _connect_ack()
//      _reconnecting = false
//      _connected = true
//    else
//      _connected = false
//    end
//
//  // be connect_ack() => _connect_ack()
//
//  // fun ref _connect_ack() =>
//  //   _connections.ack_connect_msg_id(_sender_name, _last_id_seen)
//
//  be dispose() => 
//    None
//    // _timers.dispose()
//
//class _Ack is TimerNotify
//  let _receiver: DataReceiver
//
//  new iso create(receiver: DataReceiver) =>
//    _receiver = receiver
//
//  fun ref apply(timer: Timer, count: U64): Bool =>
//    _receiver.ack()
//    true
