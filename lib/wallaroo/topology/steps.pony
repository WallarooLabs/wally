use "assert"
use "buffered"
use "time"
use "net"
use "collections"
use "sendence/epoch"
use "wallaroo/backpressure"
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/network"
use "wallaroo/resilience"

// trait RunnableStep
//   be update_router(router: Router val)
//   be run[D: Any val](metric_name: String, source_ts: U64, data: D)
//   be dispose()

// TODO: CREDITFLOW- Every runnable step is also a credit flow consumer
// Really this should probably be another method on CreditFlowConsumer
// At which point CreditFlowConsumerStep goes away as well
trait tag RunnableStep
  // TODO: Fix the Origin None once we know how to look up Proxy
  // for messages crossing boundary
  be run[D: Any val](metric_name: String, source_ts: U64, data: D,
    origin: (Origin tag | None), msg_uid: U128,
    frac_ids: (Array[U64] val | None), seq_id: U64, route_id: U64)

interface Initializable
  be initialize()

type CreditFlowConsumerStep is (RunnableStep & CreditFlowConsumer & Initializable tag)

actor Step is (RunnableStep & ResilientOrigin & CreditFlowProducerConsumer & Initializable)
  """
  # Step

  ## Future work
  * Switch to requesting credits via promise
  """
  let _runner: Runner
  let _hwm: HighWatermarkTable = HighWatermarkTable(10)
  let _lwm: LowWatermarkTable = LowWatermarkTable(10)
  let _seq_translate: SeqTranslationTable = SeqTranslationTable(10)
  let _route_translate: RouteTranslationTable = RouteTranslationTable(10)
  let _origins: OriginSet = OriginSet(10)
  var _router: Router val
  let _route_builder: RouteBuilder val
  let _metrics_reporter: MetricsReporter
  var _outgoing_seq_id: U64
  let _incoming_envelope: MsgEnvelope = MsgEnvelope(this, 0, None, 0, 0)
  let _outgoing_envelope: MsgEnvelope = MsgEnvelope(this, 0, None, 0, 0)
  var _initialized: Bool = false
  let _deduplication_list: Array[MsgEnvelope box] = _deduplication_list.create()
  let _alfred: Alfred
  var _id: (U128 | None)

  // Credit Flow Producer
  let _routes: MapIs[CreditFlowConsumer, Route] = _routes.create()

   // CreditFlow Consumer
  var _upstreams: Array[CreditFlowProducer] = _upstreams.create()
  let _max_distributable_credits: ISize = 500_000
  var _distributable_credits: ISize = _max_distributable_credits

  new create(runner: Runner iso, metrics_reporter: MetricsReporter iso, id: U128,
    route_builder: RouteBuilder val, alfred: Alfred, router: Router val = EmptyRouter)
  =>
    _runner = consume runner
    match _runner
    | let r: ReplayableRunner => r.set_origin_id(id)
    end
    _metrics_reporter = consume metrics_reporter
    _outgoing_seq_id = 0
    _router = router
    _route_builder = route_builder
    _alfred = alfred
    _alfred.register_origin(this, id)
    _id = id

  be initialize() =>
    for consumer in _router.routes().values() do
      _routes(consumer) =
        _route_builder(this, consumer, StepRouteCallbackHandler)
    end

    for r in _routes.values() do
      r.initialize()
    end

    _initialized = true

  be register_routes(router: Router val, route_builder: RouteBuilder val) =>
    for consumer in router.routes().values() do
      let next_route = route_builder(this, consumer, StepRouteCallbackHandler)
      _routes(consumer) = next_route
      if _initialized then
        next_route.initialize()
      end
    end

  // TODO: This needs to dispose of the old routes and replace with new routes
  be update_router(router: Router val) => _router = router

  // TODO: Fix the Origin None once we know how to look up Proxy
  // for messages crossing boundary
  be run[D: Any val](metric_name: String, source_ts: U64, data: D,
    origin: (Origin tag | None), msg_uid: U128,
    frac_ids: (Array[U64] val | None), incoming_seq_id: U64, route_id: U64)
  =>
    _outgoing_seq_id = _outgoing_seq_id + 1
    _incoming_envelope.update(origin, msg_uid, frac_ids, incoming_seq_id, route_id)
    _outgoing_envelope.update(this, msg_uid, frac_ids, _outgoing_seq_id)
    let is_finished = _runner.run[D](metric_name, source_ts, data,
      _incoming_envelope, _outgoing_envelope, this, _router)
    if is_finished then
      ifdef "resilience" then
        _bookkeeping(_incoming_envelope, _outgoing_envelope)
      end
      _metrics_reporter.pipeline_metric(metric_name, source_ts)
    end

  ///////////
  // RECOVERY

  // TODO: Fix the Origin None once we know how to look up Proxy
  // for messages crossing boundary

  fun _is_duplicate(envelope: MsgEnvelope box): Bool =>
    for e in _deduplication_list.values() do
      //TODO: Bloom filter maybe?
      if e.msg_uid == envelope.msg_uid then
        match (e.frac_ids, envelope.frac_ids)
        | (let efa: Array[U64] val, let efb: Array[U64] val) => 
          if efa.size() == efb.size() then
            var found = true
            for i in Range(0,efa.size()) do
              try
                if efa(i) != efb(i) then
                  found = false
                  break
                end
              else
                found = false
                break
              end
            end
            if found then
              return true
            end
          end
        | (None,None) => return true
        end
      end
    end
    false


  be replay_run[D: Any val](metric_name: String, source_ts: U64, data: D,
    origin: (Origin tag | None), msg_uid: U128,
    frac_ids: (Array[U64] val | None), incoming_seq_id: U64, route_id: U64)
  =>
    _outgoing_seq_id = _outgoing_seq_id + 1
    _incoming_envelope.update(origin, msg_uid, frac_ids, incoming_seq_id, route_id)
    _outgoing_envelope.update(this, msg_uid, frac_ids, _outgoing_seq_id)
    if not _is_duplicate(_incoming_envelope) then
      _deduplication_list.push(_incoming_envelope)
      let is_finished = _runner.run[D](metric_name, source_ts, data,
        _incoming_envelope, _outgoing_envelope, this, _router)
      if is_finished then
        _bookkeeping(_incoming_envelope, _outgoing_envelope)
        _metrics_reporter.pipeline_metric(metric_name, source_ts)
      end
    end

  fun ref hwm_get(): HighWatermarkTable =>
    _hwm

  fun ref lwm_get(): LowWatermarkTable =>
    _lwm

  fun ref seq_translate_get(): SeqTranslationTable =>
    _seq_translate

  fun ref route_translate_get(): RouteTranslationTable =>
    _route_translate

  fun ref origins_get(): OriginSet =>
    _origins

  fun ref _flush(low_watermark: U64, origin: Origin tag,
    upstream_route_id: U64 , upstream_seq_id: U64) =>
    match _id
    | let id: U128 => _alfred.flush_buffer(id, low_watermark, origin,
      upstream_route_id, upstream_seq_id)
    else
      @printf[I32]("Tried to flush a non-existing buffer!".cstring())
    end

  be replay_log_entry(uid: U128, frac_ids: (Array[U64] val | None), statechange_id: U64, payload: ByteSeq val)
  =>
    if not _is_duplicate(_incoming_envelope) then
      _deduplication_list.push(_incoming_envelope)
      match _runner
      | let r: ReplayableRunner =>
        r.replay_log_entry(uid, frac_ids, statechange_id, payload, this)
      else
        @printf[I32]("trying to replay a message to a non-replayable runner!".cstring())
      end
    end

  be replay_finished() =>
    _deduplication_list.clear()

  be start_without_replay() =>
    _deduplication_list.clear()

  be dispose() =>
    match _router
    | let r: TCPRouter val =>
      r.dispose()
    // | let sender: DataSender =>
    //   sender.dispose()
    end

  //////////////
  // CREDIT FLOW PRODUCER
  be receive_credits(credits: ISize, from: CreditFlowConsumer) =>
    ifdef debug then
      try
        Assert(_routes.contains(from),
        "Step received credits from consumer it isn't registered with.")
      else
        // TODO: CREDITFLOW - What is our error response here?
        return
      end
    end

    try
      let route = _routes(from)
      route.receive_credits(credits)
    end

  fun ref route_to(c: CreditFlowConsumerStep): (Route | None) =>
    try
      _routes(c)
    else
      None
    end

  //////////////
  // CREDIT FLOW CONSUMER
  be register_producer(producer: CreditFlowProducer) =>
    ifdef debug then
      try
        Assert(not _upstreams.contains(producer),
          "Producer attempted registered with step more than once")
      else
        // TODO: CREDITFLOW - What is our error response here?
        return
      end
    end

    _upstreams.push(producer)

  be unregister_producer(producer: CreditFlowProducer,
    credits_returned: ISize)
  =>
    ifdef debug then
      try
        Assert(_upstreams.contains(producer),
          "Producer attempted to unregistered with step " +
          "it isn't registered with")
      else
        // TODO: CREDITFLOW - What is our error response here?
        return
      end
    end

    try
      let i = _upstreams.find(producer)
      _upstreams.delete(i)
      _recoup_credits(credits_returned)
    end

  fun ref _recoup_credits(recoup: ISize) =>
    _distributable_credits = _distributable_credits + recoup

  be credit_request(from: CreditFlowProducer) =>
    """
    Receive a credit request from a producer. For speed purposes, we assume
    the producer is already registered with us.
    """
    ifdef debug then
      try
        Assert(_upstreams.contains(from),
          "Credit request from unregistered producer")
      else
        // TODO: CREDITFLOW - What is our error response here?
        return
      end
    end

    // TODO: CREDITFLOW - this is a very naive strategy
    // Could quite possibly deadlock. Would need to look into that more.
    let lccl = _lowest_route_credit_level()
    let desired_give_out = _distributable_credits / _upstreams.size().isize()
    let give_out = if lccl > desired_give_out then
      desired_give_out
    else
      lccl
    end

    from.receive_credits(give_out, this)
    _distributable_credits = _distributable_credits - give_out

  fun _lowest_route_credit_level(): ISize =>
    var lowest: ISize = 0

    for route in _routes.values() do
      if route.credits() < lowest then
        lowest = route.credits()
      end
    end

    lowest

// TODO: If this sticks around after boundary work, it will have to become
// an ResilientOrigin to compile, but that seems weird so we need to
// rethink it
actor PartitionProxy is (CreditFlowProducer & Initializable)
  let _worker_name: String
  var _router: (Router val | None) = None
  let _metrics_reporter: MetricsReporter
  let _auth: AmbientAuth
  var _seq_id: U64 = 0
  // TODO: This None will break when we no use None as origin possibility
  let _incoming_envelope: MsgEnvelope = MsgEnvelope(None, 0, None, 0, 0)
  let _outgoing_envelope: MsgEnvelope = MsgEnvelope(None, 0, None, 0, 0)

  new create(worker_name: String, metrics_reporter: MetricsReporter iso,
    auth: AmbientAuth)
  =>
    _worker_name = worker_name
    _metrics_reporter = consume metrics_reporter
    _auth = auth

  be initialize() => None

  be update_router(router: Router val) =>
    _router = router

  // TODO: If this lives on, then producer/consumer work needs
  // to be integrated here
  be receive_credits(credits: ISize, from: CreditFlowConsumer) => None
  fun ref credits_used(c: CreditFlowConsumer, num: ISize = 1) => None
  fun route_to(c: CreditFlowConsumerStep): (Route | None) => None

  be forward[D: Any val](metric_name: String, source_ts: U64, data: D,
    target_step_id: U128, from_step_id: U128, msg_uid: U128,
    frac_ids: (Array[U64] val | None), seq_id: U64,
    route_id: U64)
  =>
    _seq_id = _seq_id + 1

    // TODO: This None will break when we no use None as origin possibility
    _incoming_envelope.update(None, msg_uid, frac_ids, seq_id, route_id)
    _outgoing_envelope.update(None, msg_uid, frac_ids, _seq_id)

    let is_finished =
      try
        let return_proxy_address = ProxyAddress(_worker_name, from_step_id)

        // TODO: This forward_msg should be created in a router, which is
        // the thing normally responsible for creating the outgoing
        // envelope arguments
        let forward_msg = ChannelMsgEncoder.data_channel[D](target_step_id,
          _worker_name, source_ts, data, metric_name, _auth,
          return_proxy_address, msg_uid, frac_ids, seq_id)

        match _router
        | let r: Router val =>
          r.route[Array[ByteSeq] val](metric_name, source_ts,
            forward_msg, _incoming_envelope, _outgoing_envelope,
            this)
          false
        else
          @printf[I32]("PartitionProxy has no router\n".cstring())
          true
        end
      else
        @printf[I32]("Problem encoding forwarded message\n".cstring())
        true
      end

    if is_finished then
      _metrics_reporter.pipeline_metric(metric_name, source_ts)
    end

  be dispose() =>
    match _router
    | let r: TCPRouter val =>
      r.dispose()
    // | let sender: DataSender =>
    //   sender.dispose()
    end

primitive StepRouteCallbackHandler is RouteCallbackHandler
  fun shutdown(producer: CreditFlowProducer ref) =>
    // TODO: CREDITFLOW - What is our error handling?
    None

  fun credits_replenished(producer: CreditFlowProducer ref) =>
    None

  fun credits_exhausted(producer: CreditFlowProducer ref) =>
    None
