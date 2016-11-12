use "assert"
use "buffered"
use "time"
use "net"
use "collections"
use "sendence/epoch"
use "wallaroo/backpressure"
use "wallaroo/boundary"
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/network"
use "wallaroo/resilience"
use "wallaroo/tcp-sink"

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
    origin: Origin tag, msg_uid: U128,
    frac_ids: None, seq_id: U64, route_id: U64)

  be replay_run[D: Any val](metric_name: String, source_ts: U64, data: D,
    origin: Origin tag, msg_uid: U128,
    frac_ids: None, incoming_seq_id: U64, route_id: U64)


interface Initializable
  be initialize(outgoing_boundaries: Map[String, OutgoingBoundary] val,
    tcp_sinks: Array[TCPSink] val)

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
  var _route_builder: RouteBuilder val
  let _metrics_reporter: MetricsReporter
  let _default_target: (Step | None)
  var _outgoing_seq_id: U64
  var _outgoing_route_id: U64
  var _initialized: Bool = false
  // list of envelopes
  // (origin, msg_uid, frac_ids, seq_id, route_id)
  let _deduplication_list: Array[(Origin tag, U128, (Array[U64] val | None),
    U64, U64)] = _deduplication_list.create()
  let _alfred: Alfred
  var _id: (U128 | None)

  // Credit Flow Producer
  let _routes: MapIs[CreditFlowConsumer, Route] = _routes.create()

   // CreditFlow Consumer
  var _upstreams: Array[CreditFlowProducer] = _upstreams.create()
  let _max_distributable_credits: ISize = 500_000
  var _distributable_credits: ISize = _max_distributable_credits

  new create(runner: Runner iso, metrics_reporter: MetricsReporter iso, id: U128,
    route_builder: RouteBuilder val, alfred: Alfred, router: Router val = EmptyRouter, default_target: (Step | None) = None)
  =>
    _runner = consume runner
    match _runner
    | let r: ReplayableRunner => r.set_origin_id(id)
    end
    _metrics_reporter = consume metrics_reporter
    _outgoing_seq_id = 0
    _outgoing_route_id = 0
    _router = router
    _route_builder = route_builder
    _alfred = alfred
    _alfred.register_origin(this, id)
    _id = id
    _default_target = default_target

  be initialize(outgoing_boundaries: Map[String, OutgoingBoundary] val,
    tcp_sinks: Array[TCPSink] val) 
  =>
    for consumer in _router.routes().values() do
      _routes(consumer) =
        _route_builder(this, consumer, StepRouteCallbackHandler)
    end

    for (worker, boundary) in outgoing_boundaries.pairs() do
      _routes(boundary) =
        _route_builder(this, boundary, StepRouteCallbackHandler)
    end

    match _default_target
    | let r: CreditFlowConsumerStep =>
      _routes(r) = _route_builder(this, r, StepRouteCallbackHandler)
    end

    for sink in tcp_sinks.values() do
      _routes(sink) = _route_builder(this, sink, StepRouteCallbackHandler)
    end

    for r in _routes.values() do
      r.initialize()
    end

    _initialized = true

  be update_route_builder(route_builder: RouteBuilder val) =>
    _route_builder = route_builder

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
    origin: Origin tag, msg_uid: U128,
    frac_ids: None, incoming_seq_id: U64, route_id: U64)
  =>
    _outgoing_seq_id = _outgoing_seq_id + 1
    let is_finished = _runner.run[D](metric_name, source_ts, data,
      this, _router,
      // incoming envelope
      origin, msg_uid, frac_ids, incoming_seq_id, route_id,
      // outgoing envelope
      this, msg_uid, frac_ids, _outgoing_seq_id)
    if is_finished then
      //TODO: be more efficient (batching?)
      //this makes sure we never skip watermarks because everything is always
      //finished
      ifdef "resilience" then
        _bookkeeping(origin, msg_uid, frac_ids, incoming_seq_id, route_id,
          this, msg_uid, frac_ids, _outgoing_seq_id, 0)
        update_watermark(0, _outgoing_seq_id)
      end
      _metrics_reporter.pipeline_metric(metric_name, source_ts)
    else
      ifdef "resilience" then
        _bookkeeping(
          // incoming envelope
          origin, msg_uid, frac_ids, incoming_seq_id, route_id,
          // outgoing envelope
          // TODO: We need the real route id
          this, msg_uid, frac_ids, _outgoing_seq_id, _outgoing_route_id)
      end
    end

  ///////////
  // RECOVERY

  // TODO: Fix the Origin None once we know how to look up Proxy
  // for messages crossing boundary

  fun _is_duplicate(origin: Origin tag, msg_uid: U128,
    frac_ids: None, seq_id: U64, route_id: U64): Bool
  =>
    for e in _deduplication_list.values() do
      //TODO: Bloom filter maybe?
      if e._2 == msg_uid then
        // No frac_ids yet
        return true
        // match (e._3, frac_ids)
        // | (let efa: Array[U64] val, let efb: Array[U64] val) =>
        //   if efa.size() == efb.size() then
        //     var found = true
        //     for i in Range(0,efa.size()) do
        //       try
        //         if efa(i) != efb(i) then
        //           found = false
        //           break
        //         end
        //       else
        //         found = false
        //         break
        //       end
        //     end
        //     if found then
        //       return true
        //     end
        //   end
        // | (None,None) => return true
        // end
      end
    end
    false

  be replay_run[D: Any val](metric_name: String, source_ts: U64, data: D,
    origin: Origin tag, msg_uid: U128,
    frac_ids: None, incoming_seq_id: U64, route_id: U64)
  =>
    _outgoing_seq_id = _outgoing_seq_id + 1
    if not _is_duplicate(origin, msg_uid, frac_ids, incoming_seq_id,
      route_id) then
      _deduplication_list.push((origin, msg_uid, frac_ids, incoming_seq_id,
        route_id))
      let is_finished = _runner.run[D](metric_name, source_ts, data,
        this, _router,
        // incoming envelope
        origin, msg_uid, frac_ids, incoming_seq_id, route_id,
        // outgoing envelope
        this, msg_uid, frac_ids, _outgoing_seq_id)
      if is_finished then
        _metrics_reporter.pipeline_metric(metric_name, source_ts)
      else
        _bookkeeping(
          // incoming envelope
          origin, msg_uid, frac_ids, incoming_seq_id, route_id,
          // outgoing envelope; outgoing_route_id was set by Router
          this, msg_uid, frac_ids, _outgoing_seq_id, _outgoing_route_id)
      end
    end

  //////////////
  // ORIGIN (resilience)

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
    ifdef "resilience-debug" then
      @printf[I32]("flushing below: %llu\n".cstring(), low_watermark)
    end
    match _id
    | let id: U128 => _alfred.flush_buffer(id, low_watermark, origin,
      upstream_route_id, upstream_seq_id)
    else
      @printf[I32]("Tried to flush a non-existing buffer!".cstring())
    end

  be replay_log_entry(uid: U128, frac_ids: None, statechange_id: U64, payload: ByteSeq val)
  =>
    // TODO: We need to handle the entire incoming envelope here
    None
    // if not _is_duplicate(_incoming_envelope) then
    //   _deduplication_list.push(_incoming_envelope)
    //   match _runner
    //   | let r: ReplayableRunner =>
    //     r.replay_log_entry(uid, frac_ids, statechange_id, payload, this)
    //   else
    //     @printf[I32]("trying to replay a message to a non-replayable runner!".cstring())
    //   end
    // end

  be replay_finished() =>
    _deduplication_list.clear()

  be start_without_replay() =>
    _deduplication_list.clear()

  be dispose() =>
    None
    // match _router
    // | let sender: DataSender =>
    //   sender.dispose()
    // end

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

  fun ref update_route_id(route_id: U64) =>
    """
    We call this from the Route once a message has been sent downstream.
    """
    _outgoing_route_id = route_id

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

primitive StepRouteCallbackHandler is RouteCallbackHandler
  fun shutdown(producer: CreditFlowProducer ref) =>
    // TODO: CREDITFLOW - What is our error handling?
    None

  fun credits_replenished(producer: CreditFlowProducer ref) =>
    None

  fun credits_exhausted(producer: CreditFlowProducer ref) =>
    None
