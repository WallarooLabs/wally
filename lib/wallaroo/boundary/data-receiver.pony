use "collections"
use "net"
use "time"
use "wallaroo/backpressure"
use "wallaroo/messages"
use "wallaroo/network"
use "wallaroo/resilience"
use "wallaroo/topology"


actor DataReceiver is Producer
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
  var _ack_counter: U64 = 0

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

  be update_watermark(route_id: U64, seq_id: U64) =>
    try
      let ack_msg = ChannelMsgEncoder.ack_watermark(_worker_name,
        _sender_step_id, seq_id, _auth)
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

  fun ref _flush(low_watermark: U64) =>
    """This is not a real Origin, so it doesn't write any State"""
    None

  //////////////
  // ORIGIN (resilience)
  fun ref _x_resilience_routes(): Routes =>
    // TODO: I dont think we need this.
    // Need to discuss with John
    Routes

  be update_router(router: DataRouter val) =>
    _router = router

  be received(d: DeliveryMsg val, seq_id: U64, latest_ts: U64, metrics_id: U16)
  =>
    ifdef "trace" then
      @printf[I32]("Rcvd msg at DataReceiver\n".cstring())
    end
    if seq_id >= _last_id_seen then
      _ack_counter = _ack_counter + 1
      _last_id_seen = seq_id
      _router.route(d, this, seq_id, latest_ts, metrics_id)

      _maybe_ack()
    end

  be replay_received(r: ReplayableDeliveryMsg val, seq_id: U64,
    latest_ts: U64, metrics_id: U16)
  =>
    if seq_id >= _last_id_seen then
      _last_id_seen = seq_id
      _router.replay_route(r, this, seq_id, latest_ts, metrics_id)
    end

  fun ref _maybe_ack() =>
    if (_ack_counter % 512) == 0 then
      _ack_latest()
    end

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

// TODO: From credit flow producer part of Producer
// Remove once traits/interfaces are cleaned up
be receive_credits(credits: ISize, from: CreditFlowConsumer) =>
  None

fun ref recoup_credits(credits: ISize) =>
  None

fun ref route_to(c: CreditFlowConsumerStep): (Route | None) =>
  None

fun ref next_sequence_id(): U64 =>
  0
