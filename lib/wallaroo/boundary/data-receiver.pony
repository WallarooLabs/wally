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
  let _timers: Timers = Timers

  new create(auth: AmbientAuth, worker_name: String, sender_name: String, 
    connections: Connections, alfred: Alfred) 
  =>
    _auth = auth
    _worker_name = worker_name
    _sender_name = sender_name
    _connections = connections
    _alfred = alfred
    _alfred.register_incoming_boundary(this)
    ifdef "resilience" then
      None
    else
      let t = Timer(_Ack(this), 1_000_000_000, 1_000_000_000)
      _timers(consume t)
    end

  be data_connect(sender_step_id: U128) =>
    _sender_step_id = sender_step_id
    @printf[I32](("DataReceiver got DataConnectMsg from " + _sender_name + "\n").cstring())

  be update_watermark(route_id: U64, seq_id: U64) =>
    try
      let ack_msg = ChannelMsgEncoder.ack_watermark(_worker_name, _sender_step_id, seq_id, _auth)
      _connections.send_data(_sender_name, ack_msg)
    else
      @printf[I32]("Error creating ack watermark message\n".cstring())
    end

  be request_replay() =>
    try
      let request_msg = ChannelMsgEncoder.request_replay(_worker_name,
        _sender_step_id, _auth)
      _connections.send_data(_sender_name, request_msg)
    else
      @printf[I32]("Error creating request replay message\n".cstring())
    end

  be upstream_replay_finished() =>
    _alfred.upstream_replay_finished(this)

  fun ref _flush(low_watermark: U64, origin: Origin tag,
    upstream_route_id: U64 , upstream_seq_id: U64) =>
    """This is not a real Origin, so it doesn't write any State"""
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
    @printf[I32]("!!DataReceiver\n".cstring())
    if seq_id >= _last_id_seen then
      _last_id_seen = seq_id
      @printf[I32]("!!DataReceiver ROUTING\n".cstring())
      _router.route(d, this, seq_id)
    end

  be replay_received(r: ReplayableDeliveryMsg val, seq_id: U64)
  =>  
    if seq_id >= _last_id_seen then
      _last_id_seen = seq_id
      _router.replay_route(r, this, seq_id)
    end

  be ack_latest() => _ack_latest()

  fun ref _ack_latest() =>
    try
      if _last_id_seen > 0 then
        let ack_msg = ChannelMsgEncoder.ack_watermark(_worker_name, 
          _sender_step_id, _last_id_seen, _auth)
        _connections.send_data(_sender_name, ack_msg)
      end
    else
      @printf[I32]("Error creating ack watermark message\n".cstring())
    end

 be dispose() => 
   _timers.dispose()


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

class _Ack is TimerNotify
 let _receiver: DataReceiver

 new iso create(receiver: DataReceiver) =>
   _receiver = receiver

 fun ref apply(timer: Timer, count: U64): Bool =>
   _receiver.ack_latest()
   true
