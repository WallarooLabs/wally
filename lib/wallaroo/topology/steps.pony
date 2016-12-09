use "assert"
use "buffered"
use "time"
use "net"
use "collections"
use "sendence/epoch"
use "sendence/guid"
use "wallaroo/backpressure"
use "wallaroo/boundary"
use "wallaroo/fail"
use "wallaroo/initialization"
use "wallaroo/invariant"
use "wallaroo/metrics"
use "wallaroo/network"
use "wallaroo/resilience"
use "wallaroo/tcp-sink"

// TODO: CREDITFLOW- Every runnable step is also a credit flow consumer
// Really this should probably be another method on CreditFlowConsumer
// At which point CreditFlowConsumerStep goes away as well
trait tag RunnableStep
  be run[D: Any val](metric_name: String, source_ts: U64, data: D,
    origin: Producer, msg_uid: U128,
    frac_ids: None, seq_id: SeqId, route_id: RouteId)

  be replay_run[D: Any val](metric_name: String, source_ts: U64, data: D,
    origin: Producer, msg_uid: U128,
    frac_ids: None, incoming_seq_id: SeqId, route_id: RouteId)


interface Initializable
  be application_begin_reporting(initializer: LocalTopologyInitializer)
  be application_created(initializer: LocalTopologyInitializer,
    outgoing_boundaries: Map[String, OutgoingBoundary] val,
    omni_router: OmniRouter val)

  be application_initialized(initializer: LocalTopologyInitializer)
  be application_ready_to_work(initializer: LocalTopologyInitializer)

type CreditFlowConsumerStep is (RunnableStep & CreditFlowConsumer & Initializable tag)

actor Step is (RunnableStep & Resilient & Producer &
  Consumer & Initializable)
  """
  # Step

  ## Future work
  * Switch to requesting credits via promise
  """
  let _runner: Runner
  var _router: Router val
  // For use if this is a state step, otherwise EmptyOmniRouter
  var _omni_router: OmniRouter val
  var _route_builder: RouteBuilder val
  let _metrics_reporter: MetricsReporter
  let _default_target: (Step | None)
  // list of envelopes
  // (origin, msg_uid, frac_ids, seq_id, route_id)
  let _deduplication_list: Array[(Producer, U128, (Array[U64] val | None),
    SeqId, RouteId)] = _deduplication_list.create()
  let _alfred: Alfred
  var _id: U128
  var _seq_id: SeqId = 1 // 0 is reserved for "not seen yet"

  let _filter_route_id: RouteId = GuidGenerator.u64()

  // Credit Flow Producer
  let _routes: MapIs[CreditFlowConsumer, Route] = _routes.create()

   // CreditFlow Consumer
  var _upstreams: Array[Producer] = _upstreams.create()
  var _max_distributable_credits: ISize = 2_024
  var _distributable_credits: ISize = 0
  var _minimum_credit_response: ISize = 250
  var _waiting_producers: Array[Producer] = _waiting_producers.create()
  var _max_credit_response: ISize = _max_distributable_credits

  // Lifecycle
  var _initializer: (LocalTopologyInitializer | None) = None
  var _initialized: Bool = false
  var _ready_to_work_routes: SetIs[Route] = _ready_to_work_routes.create()

  // Resilience routes
  // TODO: This needs to be merged with credit flow producer routes
  let _resilience_routes: Routes = Routes

  new create(runner: Runner iso, metrics_reporter: MetricsReporter iso,
    id: U128, route_builder: RouteBuilder val, alfred: Alfred,
    router: Router val = EmptyRouter, default_target: (Step | None) = None,
    omni_router: OmniRouter val = EmptyOmniRouter)
  =>
    _runner = consume runner
    match _runner
    | let r: ReplayableRunner => r.set_step_id(id)
    end
    _metrics_reporter = consume metrics_reporter
    _router = _runner.clone_router_and_set_input_type(router)
    _omni_router = omni_router
    _route_builder = route_builder
    _alfred = alfred
    _alfred.register_origin(this, id)
    _id = id
    _default_target = default_target

  //
  // Application startup lifecycle event
  //

  be application_begin_reporting(initializer: LocalTopologyInitializer) =>
    initializer.report_created(this)

  be application_created(initializer: LocalTopologyInitializer,
    outgoing_boundaries: Map[String, OutgoingBoundary] val,
    omni_router: OmniRouter val)
  =>
    let callback_handler = StepRouteCallbackHandler
    for consumer in _router.routes().values() do
      _routes(consumer) =
        _route_builder(this, consumer, callback_handler)
    end

    for (worker, boundary) in outgoing_boundaries.pairs() do
      _routes(boundary) =
        _route_builder(this, boundary, callback_handler)
    end

    match _default_target
    | let r: CreditFlowConsumerStep =>
      _routes(r) = _route_builder(this, r, callback_handler)
    end

    for r in _routes.values() do
      r.application_created()
      ifdef "resilience" then
        _resilience_routes.add_route(r)
      end
    end

    _omni_router = omni_router

    _initialized = true
    initializer.report_initialized(this)

  be application_initialized(initializer: LocalTopologyInitializer) =>
    for r in _routes.values() do
      r.application_initialized(_max_distributable_credits, "Step")
    end
    _initializer = initializer

  fun ref report_route_ready_to_work(r: Route) =>
    if not _ready_to_work_routes.contains(r) then
      _ready_to_work_routes.set(r)
      // @printf[I32]("Reporting. routes: %d, ready: %d\n".cstring(),
        // _routes.size(), _ready_to_work_routes.size())

      if _ready_to_work_routes.size() == _routes.size() then
        match _initializer
        | let lti: LocalTopologyInitializer =>
          lti.report_ready_to_work(this)
        else
          Fail()
        end
      end
    else
      // A route should only signal this once
      Fail()
    end

  be application_ready_to_work(initializer: LocalTopologyInitializer) =>
    None

  be update_route_builder(route_builder: RouteBuilder val) =>
    _route_builder = route_builder

  be register_routes(router: Router val, route_builder: RouteBuilder val) =>
    for consumer in router.routes().values() do
      let next_route = route_builder(this, consumer, StepRouteCallbackHandler)
      _routes(consumer) = next_route
      if _initialized then
        Fail()
      end
    end

  // TODO: This needs to dispose of the old routes and replace with new routes
  be update_router(router: Router val) => _router = router

  be update_omni_router(omni_router: OmniRouter val) =>
    _omni_router = omni_router

  be run[D: Any val](metric_name: String, source_ts: U64, data: D,
    i_origin: Producer, msg_uid: U128,
    i_frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId)
  =>
    ifdef "trace" then
      @printf[I32](("Rcvd msg at " + _runner.name() + " step\n").cstring())
    end
    (let is_finished, _) = _runner.run[D](metric_name,
      source_ts, data, this, _router, _omni_router,
      i_origin, msg_uid, i_frac_ids, i_seq_id, i_route_id)
    if is_finished then
      ifdef "resilience" then
        ifdef "trace" then
          @printf[I32]("Filtering\n".cstring())
        end
        // TODO ideally we want filter to create the id
        // but there's problems initializing Routes with a ref
        // back to its container. Especially in Boundary etc
        _resilience_routes.filter(this, next_sequence_id(),
          i_origin, i_route_id, i_seq_id)
      end
      _metrics_reporter.pipeline_metric(metric_name, source_ts)
      ifdef "backpressure" then
        recoup_credits(1)
      end
    end
    // DO NOT REMOVE. THIS GC TRIGGERING IS INTENTIONAL.
    @pony_triggergc[None](this)

  fun ref next_sequence_id(): U64 =>
    _seq_id = _seq_id + 1

  ///////////
  // RECOVERY
  fun _is_duplicate(origin: Producer, msg_uid: U128,
    frac_ids: None, seq_id: SeqId, route_id: RouteId): Bool
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
    i_origin: Producer, msg_uid: U128,
    i_frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId)
  =>
    if not _is_duplicate(i_origin, msg_uid, i_frac_ids, i_seq_id,
      i_route_id) then
      _deduplication_list.push((i_origin, msg_uid, i_frac_ids, i_seq_id,
        i_route_id))
      (let is_finished, _) = _runner.run[D](metric_name, source_ts, data,
        this, _router, _omni_router,
        i_origin, msg_uid, i_frac_ids, i_seq_id, i_route_id)

      if is_finished then
        //TODO: be more efficient (batching?)
        ifdef "resilience" then
          _resilience_routes.filter(this, next_sequence_id(),
            i_origin, i_route_id, i_seq_id)
        end
        ifdef "backpressure" then
          recoup_credits(1)
        end
        _metrics_reporter.pipeline_metric(metric_name, source_ts)
      end
    end

  //////////////
  // ORIGIN (resilience)
  fun ref _x_resilience_routes(): Routes =>
    _resilience_routes

  fun ref _flush(low_watermark: SeqId) =>
    ifdef "trace" then
      @printf[I32]("flushing at and below: %llu\n".cstring(), low_watermark)
    end
    match _id
    | let id: U128 =>
      _alfred.flush_buffer(id, low_watermark)
    else
      @printf[I32]("Tried to flush a non-existing buffer!".cstring())
    end

  be replay_log_entry(uid: U128, frac_ids: None, statechange_id: U64, payload: ByteSeq val)
  =>
    // TODO: We need to handle the entire incoming envelope here
    None

  be replay_finished() =>
    _deduplication_list.clear()

  be start_without_replay() =>
    _deduplication_list.clear()

  be dispose() =>
    None

  //////////////
  // CREDIT FLOW PRODUCER
  be receive_credits(credits: ISize, from: CreditFlowConsumer) =>
    ifdef debug then
      Invariant(_routes.contains(from))
    end

    try
      let route = _routes(from)
      route.receive_credits(credits)
    else
      Fail()
    end

  fun ref route_to(c: CreditFlowConsumerStep): (Route | None) =>
    try
      _routes(c)
    else
      None
    end

  //////////////
  // CREDIT FLOW CONSUMER
  be register_producer(producer: Producer) =>
    ifdef debug then
      Invariant(not _upstreams.contains(producer))
    end
    ifdef "credit_trace" then
      @printf[I32]("Registered producer!\n".cstring())
    end
    _upstreams.push(producer)
    _max_credit_response =
      _max_distributable_credits / _upstreams.size().isize()
     if (_max_credit_response < _minimum_credit_response) then
       Fail()
     end

  be unregister_producer(producer: Producer,
    credits_returned: ISize)
  =>
    ifdef debug then
      Invariant(_upstreams.contains(producer))
    end

    try
      let i = _upstreams.find(producer)
      _upstreams.delete(i)
      recoup_credits(credits_returned)
    end
    _max_credit_response =
      _max_distributable_credits / _upstreams.size().isize()

  be credit_request(from: Producer) =>
    """
    Receive a credit request from a producer. For speed purposes, we assume
    the producer is already registered with us.
    """
    ifdef debug then
      Invariant(_upstreams.contains(from))
    end

    if _can_distribute_credits() and (_waiting_producers.size() == 0) then
      _distribute_credits_to(from)
    else
      _waiting_producers.push(from)
    end

  fun ref _can_distribute_credits(): Bool =>
    // TODO: should this account for route levels?
    _above_minimum_response_level()

  fun ref _distribute_credits() =>
    ifdef debug then
      Invariant(_can_distribute_credits())
    end

    while (_waiting_producers.size() > 0) and _can_distribute_credits() do
      try
        let producer = _waiting_producers.shift()
        _distribute_credits_to(producer)
      else
        Fail()
      end
    end

  fun ref _distribute_credits_to(producer: Producer) =>
    ifdef debug then
      Invariant(_can_distribute_credits())
    end

    let give_out =
      _distributable_credits
        .min(_max_credit_response)
        .max(_minimum_credit_response)

    ifdef debug then
      Invariant(give_out >= _minimum_credit_response)
    end

    ifdef "credit_trace" then
      @printf[I32]((
        "Step: Credits requested." +
        " Giving %llu out of %llu\n"
        ).cstring(),
        give_out, _distributable_credits)
    end

    producer.receive_credits(give_out, this)
    _distributable_credits = _distributable_credits - give_out

  be return_credits(credits: ISize) =>
    recoup_credits(credits)

  fun ref recoup_credits(recoup: ISize) =>
    _distributable_credits = _distributable_credits + recoup
    if _distributable_credits > _max_distributable_credits then
      _distributable_credits = _max_distributable_credits
    end
    if (_waiting_producers.size() > 0) and _above_minimum_response_level() then
      _distribute_credits()
    end

  fun _above_minimum_response_level(): Bool =>
    _distributable_credits >= _minimum_credit_response

class StepRouteCallbackHandler is RouteCallbackHandler
  fun ref register(producer: Producer ref, r: Route tag) =>
    None

  fun shutdown(producer: Producer ref) =>
    // TODO: CREDITFLOW - What is our error handling?
    None

  fun ref credits_initialized(producer: Producer ref, r: Route tag) =>
    None

  fun ref credits_replenished(producer: Producer ref) =>
    None

  fun ref credits_exhausted(producer: Producer ref) =>
    None
