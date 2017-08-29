use "assert"
use "buffered"
use "collections"
use "net"
use "time"
use "sendence/guid"
use "sendence/time"
use "wallaroo/boundary"
use "wallaroo/ent/data_receiver"
use "wallaroo/core"
use "wallaroo/fail"
use "wallaroo/initialization"
use "wallaroo/invariant"
use "wallaroo/metrics"
use "wallaroo/ent/network"
use "wallaroo/recovery"
use "wallaroo/routing"
use "wallaroo/tcp_sink"
use "wallaroo/ent/watermarking"

actor Step is (Producer & Consumer)
  var _id: U128
  let _runner: Runner
  var _router: Router = EmptyRouter
  // For use if this is a state step, otherwise EmptyOmniRouter
  var _omni_router: OmniRouter
  var _route_builder: RouteBuilder
  let _metrics_reporter: MetricsReporter
  // If this is a state step and the state partition uses a default step,
  // then this is used to create a route to that step during initialization.
  let _default_target: (Step | None)
  // list of envelopes
  let _deduplication_list: Array[(Producer, U128, FractionalMessageId,
    SeqId, RouteId)] = _deduplication_list.create()
  let _event_log: EventLog
  let _seq_id_generator: StepSeqIdGenerator = StepSeqIdGenerator

  let _routes: MapIs[Consumer, Route] = _routes.create()
  var _upstreams: SetIs[Producer] = _upstreams.create()

  // Lifecycle
  var _initializer: (LocalTopologyInitializer | None) = None
  var _initialized: Bool = false
  var _ready_to_work_routes: SetIs[RouteLogic] = _ready_to_work_routes.create()
  let _recovery_replayer: RecoveryReplayer

  let _acker_x: Acker = Acker

  let _outgoing_boundaries: Map[String, OutgoingBoundary] =
    _outgoing_boundaries.create()

  new create(runner: Runner iso, metrics_reporter: MetricsReporter iso,
    id: U128, route_builder: RouteBuilder, event_log: EventLog,
    recovery_replayer: RecoveryReplayer,
    outgoing_boundaries: Map[String, OutgoingBoundary] val,
    router: Router = EmptyRouter, default_target: (Step | None) = None,
    omni_router: OmniRouter = EmptyOmniRouter)
  =>
    _runner = consume runner
    match _runner
    | let r: ReplayableRunner => r.set_step_id(id)
    end
    _metrics_reporter = consume metrics_reporter
    _omni_router = omni_router
    _route_builder = route_builder
    _event_log = event_log
    _recovery_replayer = recovery_replayer
    _recovery_replayer.register_step(this)
    _id = id
    _default_target = default_target
    for (state_name, boundary) in _outgoing_boundaries.pairs() do
      _outgoing_boundaries(state_name) = boundary
    end
    _event_log.register_producer(this, id)

    let initial_router = _runner.clone_router_and_set_input_type(router)
    _update_router(initial_router)

  //
  // Application startup lifecycle event
  //

  be application_begin_reporting(initializer: LocalTopologyInitializer) =>
    initializer.report_created(this)

  be application_created(initializer: LocalTopologyInitializer,
    omni_router: OmniRouter)
  =>
    for consumer in _router.routes().values() do
      if not _routes.contains(consumer) then
        _routes(consumer) =
          _route_builder(this, consumer, _metrics_reporter)
      end
    end

    for boundary in _outgoing_boundaries.values() do
      _routes(boundary) =
        _route_builder(this, boundary, _metrics_reporter)
    end

    match _default_target
    | let r: Consumer =>
      _routes(r) = _route_builder(this, r, _metrics_reporter)
    end

    for r in _routes.values() do
      r.application_created()
      ifdef "resilience" then
        _acker_x.add_route(r)
      end
    end

    _omni_router = omni_router

    _initialized = true
    initializer.report_initialized(this)

  be application_initialized(initializer: LocalTopologyInitializer) =>
    _initializer = initializer
    if _routes.size() > 0 then
      for r in _routes.values() do
        r.application_initialized("Step")
      end
    else
      _report_ready_to_work()
    end

  fun ref report_route_ready_to_work(r: RouteLogic) =>
    if not _ready_to_work_routes.contains(r) then
      _ready_to_work_routes.set(r)

      if _ready_to_work_routes.size() == _routes.size() then
        _report_ready_to_work()
      end
    else
      // A route should only signal this once
      Fail()
    end

  fun ref _report_ready_to_work() =>
    match _initializer
    | let lti: LocalTopologyInitializer =>
      lti.report_ready_to_work(this)
    else
      Fail()
    end

  be application_ready_to_work(initializer: LocalTopologyInitializer) =>
    None

  be update_route_builder(route_builder: RouteBuilder) =>
    _route_builder = route_builder

  be register_routes(router: Router, route_builder: RouteBuilder) =>
    ifdef debug then
      if _initialized then
        Fail()
      end
    end

    for consumer in router.routes().values() do
      let next_route = route_builder(this, consumer, _metrics_reporter)
      if not _routes.contains(consumer) then
        _routes(consumer) = next_route
        ifdef "resilience" then
          _acker_x.add_route(next_route)
        end
      end
    end

  be update_router(router: Router) =>
    _update_router(router)

  fun ref _update_router(router: Router) =>
    try
      let old_router = _router
      _router = router
      for outdated_consumer in old_router.routes_not_in(_router).values() do
        let outdated_route = _routes(outdated_consumer)
        _acker_x.remove_route(outdated_route)
      end
      for consumer in _router.routes().values() do
        if not _routes.contains(consumer) then
          let new_route = _route_builder(this, consumer, _metrics_reporter)
          _acker_x.add_route(new_route)
          _routes(consumer) = new_route
        end
      end
    else
      Fail()
    end

  be update_omni_router(omni_router: OmniRouter) =>
    try
      let old_router = _omni_router
      _omni_router = omni_router
      for outdated_consumer in old_router.routes_not_in(_omni_router).values()
      do
        let outdated_route = _routes(outdated_consumer)
        _acker_x.remove_route(outdated_route)
      end
    else
      Fail()
    end

  be add_boundaries(boundaries: Map[String, OutgoingBoundary] val) =>
    for (state_name, boundary) in boundaries.pairs() do
      if not _outgoing_boundaries.contains(state_name) then
        _outgoing_boundaries(state_name) = boundary
        let new_route = _route_builder(this, boundary, _metrics_reporter)
        _acker_x.add_route(new_route)
        _routes(boundary) = new_route
      end
    end

  be remove_route_for(step: Consumer) =>
    try
      _routes.remove(step)
    else
      @printf[I32](("Tried to remove route for step but there was no route " +
        "to remove\n").cstring())
    end

  be run[D: Any val](metric_name: String, pipeline_time_spent: U64, data: D,
    i_producer: Producer, msg_uid: U128, frac_ids: FractionalMessageId,
    i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    _run[D](metric_name, pipeline_time_spent, data, i_producer,
      msg_uid, frac_ids, i_seq_id, i_route_id,
      latest_ts, metrics_id, worker_ingress_ts)

  fun ref _run[D: Any val](metric_name: String, pipeline_time_spent: U64,
    data: D, i_producer: Producer, msg_uid: U128,
    frac_ids: FractionalMessageId, i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    _seq_id_generator.new_incoming_message()

    let my_latest_ts = ifdef "detailed-metrics" then
        Time.nanos()
      else
        latest_ts
      end

    let my_metrics_id = ifdef "detailed-metrics" then
        _metrics_reporter.step_metric(metric_name,
          "Before receive at step behavior", metrics_id, latest_ts,
          my_latest_ts)
        metrics_id + 1
      else
        metrics_id
      end

    ifdef "trace" then
      @printf[I32](("Rcvd msg at " + _runner.name() + " step\n").cstring())
    end

    (let is_finished, _, let last_ts) = _runner.run[D](metric_name,
      pipeline_time_spent, data, this, _router, _omni_router,
      msg_uid, frac_ids, my_latest_ts, my_metrics_id, worker_ingress_ts,
      _metrics_reporter)

    if is_finished then
      ifdef "resilience" then
        ifdef "trace" then
          @printf[I32]("Filtering\n".cstring())
        end
        _acker_x.filtered(this, current_sequence_id())
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

    ifdef "resilience" then
      _acker_x.track_incoming_to_outgoing(current_sequence_id(), i_producer,
        i_route_id, i_seq_id)
    end

  fun ref next_sequence_id(): SeqId =>
    _seq_id_generator.new_id()

  fun ref current_sequence_id(): SeqId =>
    _seq_id_generator.latest_for_run()

  ///////////
  // RECOVERY
  fun _is_duplicate(msg_uid: U128, frac_ids: FractionalMessageId): Bool =>
    for e in _deduplication_list.values() do
      //TODO: Bloom filter maybe?
      if e._2 == msg_uid then
        match (e._3, frac_ids)
        | (None, None) =>
          ifdef debug then
            @printf[I32]("Deduplication true: No frac ids (None, None)\n".cstring())
          end
          return true
        | (let x: Array[U32] val, let y: Array[U32] val) =>
          if x.size() != y.size() then
            ifdef debug then
              @printf[I32](("Deduplication false: x.size() != y.size() [%d"
                + " != %d]\n").cstring(), x.size(), y.size())
            end
            return false
          end

          ifdef debug then
            @printf[I32]("Frac Ids lists\n".cstring())
            var ii = USize(0)
            while (ii < x.size()) do
              try
                @printf[I32]("x: %d\ty: %d\n".cstring(), x(ii), y(ii))
              else
                // unreachable
                Fail()
              end
              ii = ii + 1
            end
          end

          var i = USize(0)
          while (i < x.size()) do
            try
              if x(i) != y(i) then
                ifdef debug then
                  @printf[I32]("Deduplication false 2: x(i) != y(i) [%d: %d != %d]\n"
                    .cstring(), i, x(i), y(i))
                end
                return false
              end
            else
              // unreachable
              Fail()
            end
            i = i + 1
          end

          ifdef debug then
            @printf[I32]("Deduplication true: frac_ids match\n".cstring())
          end
          return true
        else
          Fail()
        end
      end
    end
    ifdef debug then
      @printf[I32]("Deduplication false: end of deduplication_list\n".cstring())
    end
    false

  be replay_run[D: Any val](metric_name: String, pipeline_time_spent: U64,
    data: D, i_producer: Producer, msg_uid: U128, frac_ids: FractionalMessageId,
    i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    ifdef debug then
      @printf[I32]("replay_run. msg_uid: %llu, frac_ids: %s\n".cstring(),
        msg_uid, FractionalMessageIdToString(frac_ids).cstring())
    end
    if not _is_duplicate(msg_uid, frac_ids) then
      _deduplication_list.push((i_producer, msg_uid, frac_ids, i_seq_id,
        i_route_id))

      _run[D](metric_name, pipeline_time_spent, data, i_producer,
        msg_uid, frac_ids, i_seq_id, i_route_id,
        latest_ts, metrics_id, worker_ingress_ts)
    else
      ifdef "trace" then
        @printf[I32]("Filtering a dupe in replay\n".cstring())
      end

      _seq_id_generator.new_incoming_message()

      ifdef "resilience" then
        _acker_x.filtered(this, current_sequence_id())
        _acker_x.track_incoming_to_outgoing(current_sequence_id(),
          i_producer, i_route_id, i_seq_id)
      end
    end

  //////////////////////
  // ORIGIN (resilience)
  be request_ack() =>
    _acker_x.request_ack(this)
    for route in _routes.values() do
      route.request_ack()
    end

  fun ref _acker(): Acker =>
    _acker_x

  fun ref flush(low_watermark: SeqId) =>
    ifdef "trace" then
      @printf[I32]("flushing at and below: %llu\n".cstring(), low_watermark)
    end
    _event_log.flush_buffer(_id, low_watermark)

  be replay_log_entry(uid: U128, frac_ids: FractionalMessageId,
    statechange_id: U64, payload: ByteSeq val)
  =>
    if not _is_duplicate(uid, frac_ids) then
      _deduplication_list.push((this, uid, frac_ids, 0, 0))
      match _runner
      | let r: ReplayableRunner =>
        r.replay_log_entry(uid, frac_ids, statechange_id, payload, this)
      else
        @printf[I32]("trying to replay a message to a non-replayable
        runner!".cstring())
      end
    end

  be clear_deduplication_list() =>
    _deduplication_list.clear()

  be dispose() =>
    None

  fun ref route_to(c: Consumer): (Route | None) =>
    try
      _routes(c)
    else
      None
    end

  be register_producer(producer: Producer) =>
    _upstreams.set(producer)

  be unregister_producer(producer: Producer) =>
    ifdef debug then
      Invariant(_upstreams.contains(producer))
    end

    _upstreams.unset(producer)

  be mute(c: Consumer) =>
    for u in _upstreams.values() do
      u.mute(c)
    end

  be unmute(c: Consumer) =>
    for u in _upstreams.values() do
      u.unmute(c)
    end

  ///////////////
  // GROW-TO-FIT
  be receive_state(state: ByteSeq val) =>
    ifdef "trace" then
      @printf[I32]("Received new state\n".cstring())
    end
    match _runner
    | let r: SerializableStateRunner =>
      r.replace_serialized_state(state)
    else
      Fail()
    end

  be send_state_to_neighbour(neighbour: Step) =>
    match _runner
    | let r: SerializableStateRunner =>
      neighbour.receive_state(r.serialize_state())
    else
      Fail()
    end

  be send_state[K: (Hashable val & Equatable[K] val)](
    boundary: OutgoingBoundary, state_name: String, key: K)
  =>
    match _runner
    | let r: SerializableStateRunner =>
      let state: ByteSeq val = r.serialize_state()
      boundary.migrate_step[K](_id, state_name, key, state)
    else
      Fail()
    end

  // Log-rotation
  be snapshot_state() =>
    match _runner
    | let r: SerializableStateRunner =>
      let wb = Writer
      let serialized: ByteSeq val = r.serialize_state()
      wb.write(serialized)
      let payload = wb.done()
      let oid: U128 = _id
      let uid: U128 = -1
      let statechange_id: U64 = -1
      let seq_id: U64 = _seq_id_generator.last_id()
      _event_log.snapshot_state(oid, uid, statechange_id, seq_id,
        consume payload)
    else
      @printf[I32](("Could not complete log rotation. StateRunner is not " +
        "Serializable.\n").cstring())
      Fail()
    end
