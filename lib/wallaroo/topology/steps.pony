use "assert"
use "buffered"
use "collections"
use "net"
use "time"
use "sendence/guid"
use "sendence/wall-clock"
use "wallaroo/boundary"
use "wallaroo/fail"
use "wallaroo/initialization"
use "wallaroo/invariant"
use "wallaroo/metrics"
use "wallaroo/network"
use "wallaroo/resilience"
use "wallaroo/routing"
use "wallaroo/tcp-sink"

// TODO: CREDITFLOW- Every runnable step is also a credit flow consumer
// Really this should probably be another method on CreditFlowConsumer
// At which point CreditFlowConsumerStep goes away as well
trait tag RunnableStep
  be run[D: Any val](metric_name: String, pipeline_time_spent: U64, data: D,
    origin: Producer, msg_uid: U128,
    frac_ids: None, seq_id: SeqId, route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)

  be replay_run[D: Any val](metric_name: String, pipeline_time_spent: U64,
    data: D, origin: Producer, msg_uid: U128,
    frac_ids: None, incoming_seq_id: SeqId, route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)

  be request_ack()

interface Initializable
  be application_begin_reporting(initializer: LocalTopologyInitializer)
  be application_created(initializer: LocalTopologyInitializer,
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

  let _routes: MapIs[CreditFlowConsumer, Route] = _routes.create()
  var _upstreams: Array[Producer] = _upstreams.create()

  // Lifecycle
  var _initializer: (LocalTopologyInitializer | None) = None
  var _initialized: Bool = false
  var _ready_to_work_routes: SetIs[RouteLogic] = _ready_to_work_routes.create()

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

  be print_flushing() =>
    _resilience_routes.print_flushing()

  be application_begin_reporting(initializer: LocalTopologyInitializer) =>
    initializer.report_created(this)

  be application_created(initializer: LocalTopologyInitializer,
    omni_router: OmniRouter val)
  =>
    for consumer in _router.routes().values() do
      _routes(consumer) =
        _route_builder(this, consumer, _metrics_reporter)
    end

    match _default_target
    | let r: CreditFlowConsumerStep =>
      _routes(r) = _route_builder(this, r, _metrics_reporter)
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
    _initializer = initializer
    for r in _routes.values() do
      r.application_initialized("Step")
    end

  fun ref report_route_ready_to_work(r: RouteLogic) =>
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
      let next_route = route_builder(this, consumer, _metrics_reporter)
      _routes(consumer) = next_route
      if _initialized then
        Fail()
      end
    end

  // TODO: This needs to dispose of the old routes and replace with new routes
  be update_router(router: Router val) => _router = router

  be update_omni_router(omni_router: OmniRouter val) =>
    _omni_router = omni_router

  be run[D: Any val](metric_name: String, pipeline_time_spent: U64, data: D,
    i_origin: Producer, msg_uid: U128,
    i_frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    let my_latest_ts = ifdef "detailed-metrics" then
        Time.nanos()
      else
        latest_ts
      end

    let my_metrics_id = ifdef "detailed-metrics" then
        _metrics_reporter.step_metric(metric_name, "Before receive at step behavior",
          metrics_id, latest_ts, my_latest_ts)
        metrics_id + 1
      else
        metrics_id
      end

    ifdef "trace" then
      @printf[I32](("Rcvd msg at " + _runner.name() + " step\n").cstring())
    end
    (let is_finished, _, let last_ts) = _runner.run[D](metric_name,
      pipeline_time_spent, data, this, _router, _omni_router,
      i_origin, msg_uid, i_frac_ids, i_seq_id, i_route_id,
      my_latest_ts, my_metrics_id, worker_ingress_ts, _metrics_reporter)
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
      let end_ts = Time.nanos()
      let time_spent = end_ts - worker_ingress_ts

      ifdef "detailed-metrics" then
        _metrics_reporter.step_metric(metric_name, "Before end at Step", 9999,
          last_ts, end_ts)
      end

      _metrics_reporter.pipeline_metric(metric_name,
        time_spent + pipeline_time_spent)
      _metrics_reporter.worker_metric(metric_name, time_spent)
    end

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

  be replay_run[D: Any val](metric_name: String, pipeline_time_spent: U64, data: D,
    i_origin: Producer, msg_uid: U128,
    i_frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    if not _is_duplicate(i_origin, msg_uid, i_frac_ids, i_seq_id,
      i_route_id) then
      _deduplication_list.push((i_origin, msg_uid, i_frac_ids, i_seq_id,
        i_route_id))
      (let is_finished, _, let last_ts) = _runner.run[D](metric_name,
        pipeline_time_spent, data, this, _router, _omni_router,
        i_origin, msg_uid, i_frac_ids, i_seq_id, i_route_id,
        latest_ts, metrics_id, worker_ingress_ts, _metrics_reporter)

      if is_finished then
        //TODO: be more efficient (batching?)
        ifdef "resilience" then
          _resilience_routes.filter(this, next_sequence_id(),
            i_origin, i_route_id, i_seq_id)
        end
        let end_ts = Time.nanos()
        let time_spent = end_ts - worker_ingress_ts

        ifdef "detailed-metrics" then
          _metrics_reporter.step_metric(metric_name, "Before end at Step replay",
            9999, last_ts, end_ts)
        end

        _metrics_reporter.pipeline_metric(metric_name,
          time_spent + pipeline_time_spent)
        _metrics_reporter.worker_metric(metric_name, time_spent)
      end
    else
      ifdef "resilience" then
        ifdef "trace" then
          @printf[I32]("Filtering a dupe in replay\n".cstring())
        end
        // TODO ideally we want filter to create the id
        // but there's problems initializing Routes with a ref
        // back to its container. Especially in Boundary etc
        _resilience_routes.filter(this, next_sequence_id(),
          i_origin, i_route_id, i_seq_id)
      end
    end

  //////////////////////
  // ORIGIN (resilience)
  be request_ack() =>
    _resilience_routes.request_ack(this)
    for route in _routes.values() do
      route.request_ack()
    end

  fun ref _x_resilience_routes(): Routes =>
    _resilience_routes

  fun ref _flush(low_watermark: SeqId) =>
    ifdef "trace" then
      @printf[I32]("flushing at and below: %llu\n".cstring(), low_watermark)
    end
    _alfred.flush_buffer(_id, low_watermark)

  be replay_log_entry(uid: U128, frac_ids: None, statechange_id: U64, payload: ByteSeq val)
  =>
    //TODO: replace origin_id seq_id and route_id in here if needed (amosca believes not)
    if not _is_duplicate(this, uid, frac_ids, 0, 0) then
      _deduplication_list.push((this, uid, frac_ids, 0, 0))
      match _runner
      | let r: ReplayableRunner =>
        r.replay_log_entry(uid, frac_ids, statechange_id, payload, this)
      else
        @printf[I32]("trying to replay a message to a non-replayable
        runner!".cstring())
      end
    end

  be replay_finished() =>
    _deduplication_list.clear()

  be start_without_replay() =>
    _deduplication_list.clear()

  be dispose() =>
    None

  fun ref route_to(c: CreditFlowConsumer): (Route | None) =>
    try
      _routes(c)
    else
      None
    end

  be register_producer(producer: Producer) =>
    ifdef debug then
      Invariant(not _upstreams.contains(producer))
    end

    _upstreams.push(producer)

  be unregister_producer(producer: Producer) =>
    ifdef debug then
      Invariant(_upstreams.contains(producer))
    end

    try
      let i = _upstreams.find(producer)
      _upstreams.delete(i)
    end

  be mute(c: CreditFlowConsumer) =>
    for u in _upstreams.values() do
      u.mute(c)
    end

  be unmute(c: CreditFlowConsumer) =>
    for u in _upstreams.values() do
      u.unmute(c)
    end
