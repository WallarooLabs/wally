use "collections"
use "net"
use "time"
use "wallaroo/data_channel"
use "wallaroo/fail"
use "wallaroo/invariant"
use "wallaroo/messages"
use "wallaroo/network"
use "wallaroo/resilience"
use "wallaroo/routing"
use "wallaroo/topology"


actor DataReceiver is Producer
  let _auth: AmbientAuth
  let _worker_name: String
  var _sender_name: String
  var _sender_step_id: U128 = 0
  let _connections: Connections
  var _router: DataRouter val =
    DataRouter(recover Map[U128, ConsumerStep tag] end)
  var _last_id_seen: U64 = 0
  var _last_id_acked: U64 = 0
  var _connected: Bool = false
  var _reconnecting: Bool = false
  let _alfred: Alfred
  var _ack_counter: USize = 0
  // TODO: Get this information via data_connect()
  var _boundary_queue_max: USize = 16_000
  var _request_threshold: USize = 8_000
  var _request_pause: USize = 4_000
  var _last_request: USize = 0

  // TODO: Test replacing this with state machine class
  // to avoid matching on every ack
  var _latest_conn: (DataChannel | None) = None
  var _replay_pending: Bool = false

  let _resilience_routes: DataReceiverRoutes = DataReceiverRoutes

  // Timer to periodically request acks to prevent deadlock.
  var _timer_init: _TimerInit = _UninitializedTimerInit
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

  be data_connect(sender_step_id: U128, conn: DataChannel) =>
    _sender_step_id = sender_step_id
    _latest_conn = conn
    if _replay_pending then
      request_replay()
    end

  fun ref init_timer() =>
    ifdef "resilience" then
      let t = Timer(_RequestAck(this), 0, 15_000_000)
      _timers(consume t)
    end
    // We are finished initializing timer, so set it to _EmptyTimerInit
    // so we don't create two timers.
    _timer_init = _EmptyTimerInit

  be update_watermark(route_id: RouteId, seq_id: SeqId) =>
    _resilience_routes.receive_ack(route_id, seq_id)
    try
      let watermark = _resilience_routes.propose_new_watermark()

      if watermark > _last_id_acked then
        ifdef "trace" then
          @printf[I32]("DataReceiver acking seq_id %lu\n".cstring(),
            watermark)
        end

        let ack_msg = ChannelMsgEncoder.ack_watermark(_worker_name,
          _sender_step_id, watermark, _auth)
        match _latest_conn
        | let conn: DataChannel =>
          conn.writev(ack_msg)
        else
          Fail()
        end
        _last_id_acked = watermark
      end
    else
      @printf[I32]("Error creating ack watermark message\n".cstring())
    end

  be request_replay() =>
    try
      match _latest_conn
      | let conn: DataChannel =>
        @printf[I32](("data receiver for worker %s requesting replay from " +
                      "sender %s\n").cstring(), _worker_name.cstring(),
                      _sender_name.cstring())
        let request_msg = ChannelMsgEncoder.request_replay(_worker_name,
          _sender_step_id, _auth)
        conn.writev(request_msg)
        _replay_pending = false
      else
        _replay_pending = true
      end

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

  fun ref bookkeeping(route_id: RouteId, seq_id: SeqId) =>
    """
    Process envelopes and keep track of things
    """
    ifdef "trace" then
      @printf[I32]("Bookkeeping called for DataReceiver route %lu\n".cstring(),
        route_id)
    end
    ifdef "resilience" then
      _resilience_routes.send(route_id, seq_id)
    end

  be update_router(router: DataRouter val) =>
    // TODO: This commented line conflicts with invariant downstream. The
    // idea is to unregister if we've registered but not otherwise.
    // The invariant says you can only call this method on a step if
    // you've already registered. If we allow calling it whether or not
    // you've registered, this will work, but that might cause other
    // problems. However, otherwise, when updating, we might register twice
    // with the same step or never unregister with one we'll no longer
    // be sending to.
    // Currently, this behavior should only be called once in the lifecycle
    // of a DataReceiver, so we would only need this if that were to change.
    //_router.unregister_producer(this, 0)

    // We currently assume stop the world and finishing all in-flight
    // processing before any route migration.
    ifdef debug then
      Invariant(_resilience_routes.is_fully_acked())
    end

    _router = router
    _router.register_producer(this)
    for id in _router.route_ids().values() do
      if not _resilience_routes.contains(id) then
        _resilience_routes.add_route(id)
      end
    end

  be received(d: DeliveryMsg val, pipeline_time_spent: U64, seq_id: U64,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    _timer_init(this)
    ifdef "trace" then
      @printf[I32]("Rcvd msg at DataReceiver\n".cstring())
    end
    if seq_id >= _last_id_seen then
      _ack_counter = _ack_counter + 1
      _last_id_seen = seq_id
      _router.route(d, pipeline_time_spent, this, seq_id, latest_ts,
        metrics_id, worker_ingress_ts)
      _maybe_ack()
    end

  be request_ack() =>
    if _last_id_acked < _last_id_seen then
      _request_ack()
    end

  fun ref _request_ack() =>
    _router.request_ack(_resilience_routes.unacked_route_ids())
    _last_request = _ack_counter

  be replay_received(r: ReplayableDeliveryMsg val, pipeline_time_spent: U64,
    seq_id: U64, latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    if seq_id >= _last_id_seen then
      _last_id_seen = seq_id
      _router.replay_route(r, pipeline_time_spent, this, seq_id, latest_ts,
        metrics_id, worker_ingress_ts)
    end

  fun ref _maybe_ack() =>
    ifdef not "resilience" then
      if (_ack_counter % 512) == 0 then
        _ack_latest()
      end
    end

  fun ref _ack_latest() =>
    try
      if _last_id_seen > _last_id_acked then
        ifdef "trace" then
          @printf[I32]("DataReceiver acking seq_id %lu\n".cstring(),
            _last_id_seen)
        end
        _last_id_acked = _last_id_seen
        let ack_msg = ChannelMsgEncoder.ack_watermark(_worker_name,
          _sender_step_id, _last_id_seen, _auth)
        match _latest_conn
        | let conn: DataChannel =>
          conn.writev(ack_msg)
        else
          Fail()
        end
      end
    else
      @printf[I32]("Error creating ack watermark message\n".cstring())
    end

  be dispose() =>
    _timers.dispose()

  fun ref route_to(c: Consumer): (Route | None) =>
    None

  fun ref next_sequence_id(): U64 =>
    0

  fun ref current_sequence_id(): U64 =>
    0

  be mute(c: Consumer) =>
    match _latest_conn
    | let conn: DataChannel =>
      conn.mute(c)
    end

  be unmute(c: Consumer) =>
    match _latest_conn
    | let conn: DataChannel =>
      conn.unmute(c)
    end

trait _TimerInit
  fun apply(d: DataReceiver ref)

class _UninitializedTimerInit is _TimerInit
  fun apply(d: DataReceiver ref) =>
    d.init_timer()

class _EmptyTimerInit is _TimerInit
  fun apply(d: DataReceiver ref) => None

class _RequestAck is TimerNotify
  let _d: DataReceiver

  new iso create(d: DataReceiver) =>
    _d = d

  fun ref apply(timer: Timer, count: U64): Bool =>
    _d.request_ack()
    true
