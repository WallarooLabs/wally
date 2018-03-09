/*

Copyright 2017 The Wallaroo Authors.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
 implied. See the License for the specific language governing
 permissions and limitations under the License.

*/

use "assert"
use "buffered"
use "collections"
use "net"
use "serialise"
use "time"
use "wallaroo_labs/guid"
use "wallaroo_labs/time"
use "wallaroo/core/boundary"
use "wallaroo/core/common"
use "wallaroo/core/state"
use "wallaroo/ent/data_receiver"
use "wallaroo/ent/network"
use "wallaroo/ent/rebalancing"
use "wallaroo/ent/recovery"
use "wallaroo/ent/watermarking"
use "wallaroo_labs/mort"
use "wallaroo/core/initialization"
use "wallaroo/core/invariant"
use "wallaroo/core/metrics"
use "wallaroo/core/routing"
use "wallaroo/core/sink/tcp_sink"

actor Step is (Producer & Consumer)
  let _auth: AmbientAuth
  var _id: U128
  let _runner: Runner
  var _router: Router = EmptyRouter
  // For use if this is a state step, otherwise EmptyOmniRouter
  var _omni_router: OmniRouter
  var _route_builder: RouteBuilder
  let _metrics_reporter: MetricsReporter
  // list of envelopes
  let _deduplication_list: DeduplicationList = _deduplication_list.create()
  let _event_log: EventLog
  var _seq_id_generator: StepSeqIdGenerator = StepSeqIdGenerator

  var _step_message_processor: StepMessageProcessor = EmptyStepMessageProcessor

  let _routes: MapIs[Consumer, Route] = _routes.create()
  var _upstreams: SetIs[Producer] = _upstreams.create()

  // Lifecycle
  var _initializer: (LocalTopologyInitializer | None) = None
  var _initialized: Bool = false
  var _seq_id_initialized_on_recovery: Bool = false
  var _ready_to_work_routes: SetIs[RouteLogic] = _ready_to_work_routes.create()
  var _finished_ack_waiter: FinishedAckWaiter
  let _recovery_replayer: RecoveryReplayer

  let _acker_x: Acker = Acker

  let _outgoing_boundaries: Map[String, OutgoingBoundary] =
    _outgoing_boundaries.create()

  new create(auth: AmbientAuth, runner: Runner iso,
    metrics_reporter: MetricsReporter iso,
    id: U128, route_builder: RouteBuilder, event_log: EventLog,
    recovery_replayer: RecoveryReplayer,
    outgoing_boundaries: Map[String, OutgoingBoundary] val,
    router: Router = EmptyRouter,
    omni_router: OmniRouter = EmptyOmniRouter)
  =>
    _auth = auth
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
    _finished_ack_waiter = FinishedAckWaiter(_id)

    for (worker, boundary) in outgoing_boundaries.pairs() do
      _outgoing_boundaries(worker) = boundary
    end
    _event_log.register_producer(this, id)

    let initial_router = _runner.clone_router_and_set_input_type(router)
    _update_router(initial_router)

    for consumer in _router.routes().values() do
      if not _routes.contains(consumer) then
        _routes(consumer) =
          _route_builder(this, consumer, _metrics_reporter)
      end
    end

    for boundary in _outgoing_boundaries.values() do
      if not _routes.contains(boundary) then
        _routes(boundary) =
          _route_builder(this, boundary, _metrics_reporter)
      end
    end

    for r in _routes.values() do
      ifdef "resilience" then
        _acker_x.add_route(r)
      end
    end

    _step_message_processor = NormalStepMessageProcessor(this)

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
      if not _routes.contains(boundary) then
        _routes(boundary) =
          _route_builder(this, boundary, _metrics_reporter)
      end
    end

    for r in _routes.values() do
      r.application_created()
      ifdef "resilience" then
        _acker_x.add_route(r)
      end
    end

    // @printf[I32]("!@ step application_created routes: %s\n".cstring(), _routes.size().string().cstring())

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

    // @printf[I32]("!@ step register_routes routes: %s\n".cstring(), _routes.size().string().cstring())

  be update_router(router: Router) =>
    _update_router(router)

  fun ref _update_router(router: Router) =>
    try
      let old_router = _router
      _router = router
      for outdated_consumer in old_router.routes_not_in(_router).values() do
        let outdated_route = _routes(outdated_consumer)?
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

    // @printf[I32]("!@ step _update_router routes: %s\n".cstring(), _routes.size().string().cstring())

  be update_omni_router(omni_router: OmniRouter) =>
    let old_router = _omni_router
    _omni_router = omni_router
    for outdated_consumer in old_router.routes_not_in(_omni_router).values()
    do
      try
        let outdated_route = _routes(outdated_consumer)?
        _acker_x.remove_route(outdated_route)
      end
    end
    _add_boundaries(omni_router.boundaries())

  be add_boundaries(boundaries: Map[String, OutgoingBoundary] val) =>
    _add_boundaries(boundaries)

  fun ref _add_boundaries(boundaries: Map[String, OutgoingBoundary] val) =>
    for (worker, boundary) in boundaries.pairs() do
      if not _outgoing_boundaries.contains(worker) then
        _outgoing_boundaries(worker) = boundary
        let new_route = _route_builder(this, boundary, _metrics_reporter)
        _acker_x.add_route(new_route)
        _routes(boundary) = new_route
      end
    end
    // @printf[I32]("!@ step add_boundaries routes: %s\n".cstring(), _routes.size().string().cstring())

  be remove_boundary(worker: String) =>
    if _outgoing_boundaries.contains(worker) then
      try
        let boundary = _outgoing_boundaries(worker)?
        _routes(boundary)?.dispose()
        _routes.remove(boundary)?
        _outgoing_boundaries.remove(worker)?
      else
        Fail()
      end
    //!@
    else
      // @printf[I32]("!@ !!!!!!!! FAIL CAN'T REMOVE! %s from %s\n".cstring(), worker.cstring(), _id.string().cstring())
      None
    end

    // @printf[I32]("!@ step remove_boundary routes: %s\n".cstring(), _routes.size().string().cstring())

  be remove_route_for(step: Consumer) =>
    try
      _routes.remove(step)?
    else
      @printf[I32](("Tried to remove route for step but there was no route " +
        "to remove\n").cstring())
    end

    // @printf[I32]("!@ step remove_route_for routes: %s\n".cstring(), _routes.size().string().cstring())

  be run[D: Any val](metric_name: String, pipeline_time_spent: U64, data: D,
    i_producer: Producer, msg_uid: MsgId, frac_ids: FractionalMessageId,
    i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    ifdef "trace" then
      @printf[I32]("Received msg at Step\n".cstring())
    end
    _step_message_processor.run[D](metric_name, pipeline_time_spent, data,
      i_producer, msg_uid, frac_ids, i_seq_id, i_route_id, latest_ts,
      metrics_id, worker_ingress_ts)

  fun ref process_message[D: Any val](metric_name: String,
    pipeline_time_spent: U64, data: D, i_producer: Producer, msg_uid: MsgId,
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

    (let is_finished, let last_ts) = _runner.run[D](metric_name,
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
  fun ref _is_duplicate(msg_uid: MsgId, frac_ids: FractionalMessageId): Bool =>
    MessageDeduplicator.is_duplicate(msg_uid, frac_ids, _deduplication_list)

  be replay_run[D: Any val](metric_name: String, pipeline_time_spent: U64,
    data: D, i_producer: Producer, msg_uid: MsgId,
    frac_ids: FractionalMessageId, i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    if not _is_duplicate(msg_uid, frac_ids) then
      _deduplication_list.push((msg_uid, frac_ids))

      process_message[D](metric_name, pipeline_time_spent, data, i_producer,
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
      ifdef "resilience" then
        StepLogEntryReplayer(_runner, _deduplication_list, uid, frac_ids,
          statechange_id, payload, this)
      end
    end

  be initialize_seq_id_on_recovery(seq_id: SeqId) =>
    ifdef debug then
      Invariant(_seq_id_initialized_on_recovery == false)
    end
    _seq_id_generator = StepSeqIdGenerator(seq_id)
    _seq_id_initialized_on_recovery = true

  be clear_deduplication_list() =>
    _deduplication_list.clear()

  be dispose() =>
    None

  fun ref route_to(c: Consumer): (Route | None) =>
    try
      _routes(c)?
    else
      None
    end

  be register_producer(producer: Producer) =>
    _upstreams.set(producer)

  be unregister_producer(producer: Producer) =>
    // TODO: Investigate whether we need this Invariant or why it's sometimes
    // violated during shrink.
    // ifdef debug then
    //   Invariant(_upstreams.contains(producer))
    // end
    _upstreams.unset(producer)

  //!@
  be report_status(code: ReportStatusCode) =>
    match code
    | FinishedAcksStatus =>
      _finished_ack_waiter.report_status(code)
    //!@
    | BoundaryCountStatus =>
      var b_count: USize = 0
      for r in _routes.values() do
        match r
        | let br: BoundaryRoute => b_count = b_count + 1
        end
      end
      @printf[I32]("!@ Step %s has %s boundaries.\n".cstring(), _id.string().cstring(), b_count.string().cstring())
    end
    for r in _routes.values() do
      r.report_status(code)
    end

  be request_finished_ack(upstream_request_id: RequestId, requester_id: StepId,
    requester: FinishedAckRequester)
  =>
    match _step_message_processor
    | let nmp: NormalStepMessageProcessor =>
      _step_message_processor = QueueingStepMessageProcessor(this)
    end
    // @printf[I32]("!@ request_finished_ack STEP %s, upstream_request_id: %s, requester_id: %s\n".cstring(), _id.string().cstring(), upstream_request_id.string().cstring(), requester_id.string().cstring())
    if not _finished_ack_waiter.already_added_request(requester_id) then
      _finished_ack_waiter.add_new_request(requester_id, upstream_request_id,
        requester)
      if _routes.size() > 0 then
        for r in _routes.values() do
          let request_id = _finished_ack_waiter.add_consumer_request(
            requester_id)
          r.request_finished_ack(request_id, _id, this)
        end
      else
        _finished_ack_waiter.try_finish_request_early(requester_id)
      end
    else
      requester.receive_finished_ack(upstream_request_id)
    end

  be request_finished_ack_complete(requester_id: StepId,
    requester: FinishedAckRequester)
  =>
    // @printf[I32]("!@ request_finished_ack_complete STEP\n".cstring())
    match _step_message_processor
    | let qmp: QueueingStepMessageProcessor =>
      // Process all queued messages
      qmp.flush()

      _finished_ack_waiter.clear()
      _step_message_processor = NormalStepMessageProcessor(this)
      for r in _routes.values() do
        r.request_finished_ack_complete(_id, this)
      end
    end

  be try_finish_request_early(requester_id: StepId) =>
    _finished_ack_waiter.try_finish_request_early(requester_id)

  be receive_finished_ack(request_id: RequestId) =>
    // @printf[I32]("!@ receive_finished_ack STEP %s\n".cstring(), _id.string().cstring())
    _finished_ack_waiter.unmark_consumer_request(request_id)

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
    ifdef "autoscale" then
      try
        match Serialised.input(InputSerialisedAuth(_auth),
          state as Array[U8] val)(DeserialiseAuth(_auth))?
        | let shipped_state: ShippedState =>
          _step_message_processor = QueueingStepMessageProcessor(this,
            shipped_state.pending_messages)
          StepStateMigrator.receive_state(_runner, shipped_state.state_bytes)
        else
          Fail()
        end
      else
        Fail()
      end
    end

  be send_state_to_neighbour(neighbour: Step) =>
    ifdef "autoscale" then
      match _step_message_processor
      | let nmp: NormalStepMessageProcessor =>
        // TODO: Should this be possible?
        StepStateMigrator.send_state_to_neighbour(_runner, neighbour,
          Array[QueuedStepMessage], _auth)
      | let qmp: QueueingStepMessageProcessor =>
        StepStateMigrator.send_state_to_neighbour(_runner, neighbour,
          qmp.messages, _auth)
      end
    end

  be send_state[K: (Hashable val & Equatable[K] val)](
    boundary: OutgoingBoundary, state_name: String, key: K)
  =>
    ifdef "autoscale" then
      match _step_message_processor
      | let nmp: NormalStepMessageProcessor =>
        // TODO: Should this be possible?
        StepStateMigrator.send_state[K](_runner, _id, boundary, state_name,
          key, Array[QueuedStepMessage], _auth)
      | let qmp: QueueingStepMessageProcessor =>
        StepStateMigrator.send_state[K](_runner, _id, boundary, state_name,
          key, qmp.messages, _auth)
      end
    end

  // Log-rotation
  be snapshot_state() =>
    ifdef "resilience" then
      StepStateSnapshotter(_runner, _id, _seq_id_generator, _event_log)
    end
