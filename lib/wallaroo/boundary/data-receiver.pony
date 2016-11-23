use "collections"
use "net"
use "time"
use "wallaroo/backpressure"
use "wallaroo/messages"
use "wallaroo/network"
use "wallaroo/resilience"
use "wallaroo/topology"


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
  let _alfred: Alfred
  let _timers: Timers = Timers
  // Origin (Resilience)
  var _flushing: Bool = false
  let _watermarks: Watermarks = _watermarks.create()
  let _hwmt: HighWatermarkTable = _hwmt.create()
  var _wmcounter: U64 = 0

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

  fun ref _flush(low_watermark: U64, origin: Origin,
    upstream_route_id: RouteId , upstream_seq_id: SeqId) =>
    """This is not a real Origin, so it doesn't write any State"""
    None

  //////////////
  // ORIGIN (resilience)
  fun ref flushing(): Bool =>
    _flushing

  fun ref not_flushing() =>
    _flushing = false

  fun ref watermarks(): Watermarks =>
    _watermarks

  fun ref hwmt(): HighWatermarkTable =>
    _hwmt

  fun ref _watermarks_counter(): U64 =>
    _wmcounter = _wmcounter + 1

  be update_router(router: DataRouter val) =>
    _router = router

  be received(d: DeliveryMsg val, seq_id: U64)
  =>
    ifdef "trace" then
      @printf[I32]("Rcvd msg at DataReceiver\n".cstring())
    end
    if seq_id >= _last_id_seen then
      _last_id_seen = seq_id
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
