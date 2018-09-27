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
use "wallaroo/ent/barrier"
use "wallaroo/ent/data_receiver"
use "wallaroo/ent/network"
use "wallaroo/ent/rebalancing"
use "wallaroo/ent/recovery"
use "wallaroo/ent/router_registry"
use "wallaroo/ent/checkpoint"
use "wallaroo_labs/mort"
use "wallaroo/core/initialization"
use "wallaroo/core/invariant"
use "wallaroo/core/metrics"
use "wallaroo/core/routing"
use "wallaroo/core/sink/tcp_sink"

actor Step is (Producer & Consumer & BarrierProcessor)
  let _auth: AmbientAuth
  var _id: U128
  let _runner: Runner
  var _router: Router = EmptyRouter
  // For use if this is a state step, otherwise EmptyTargetIdRouter
  var _target_id_router: TargetIdRouter
  let _metrics_reporter: MetricsReporter
  // list of envelopes
  let _deduplication_list: DeduplicationList = _deduplication_list.create()
  let _event_log: EventLog
  var _seq_id_generator: StepSeqIdGenerator = StepSeqIdGenerator

  var _step_message_processor: StepMessageProcessor = EmptyStepMessageProcessor

  // _routes contains one route per Consumer
  let _routes: MapIs[Consumer, Route] = _routes.create()
  // _outputs keeps track of all output targets by step id. There might be
  // duplicate consumers in this map (unlike _routes) since there might be
  // multiple target step ids over a boundary
  let _outputs: Map[RoutingId, Consumer] = _outputs.create()
  // _routes contains one upstream per producer
  var _upstreams: SetIs[Producer] = _upstreams.create()
  // _inputs keeps track of all inputs by step id. There might be
  // duplicate producers in this map (unlike upstreams) since there might be
  // multiple upstream step ids over a boundary
  let _inputs: Map[RoutingId, Producer] = _inputs.create()

  // Lifecycle
  var _initializer: (LocalTopologyInitializer | None) = None
  var _initialized: Bool = false
  var _seq_id_initialized_on_recovery: Bool = false
  var _ready_to_work_routes: SetIs[RouteLogic] = _ready_to_work_routes.create()
  let _recovery_replayer: RecoveryReconnecter

  var _barrier_forwarder: (BarrierStepForwarder | None) = None

  let _outgoing_boundaries: Map[String, OutgoingBoundary] =
    _outgoing_boundaries.create()

  let _router_registry: RouterRegistry

  // Checkpoint
  var _next_checkpoint_id: CheckpointId = 1

  new create(auth: AmbientAuth, runner: Runner iso,
    metrics_reporter: MetricsReporter iso,
    id: U128, event_log: EventLog,
    recovery_replayer: RecoveryReconnecter,
    outgoing_boundaries: Map[String, OutgoingBoundary] val,
    router_registry: RouterRegistry,
    router': Router = EmptyRouter,
    target_id_router: TargetIdRouter = EmptyTargetIdRouter)
  =>
    _auth = auth
    _runner = consume runner
    match _runner
    | let r: RollbackableRunner => r.set_step_id(id)
    end
    _metrics_reporter = consume metrics_reporter
    _target_id_router = target_id_router
    _event_log = event_log
    _recovery_replayer = recovery_replayer
    _recovery_replayer.register_step(this)
    _router_registry = router_registry
    _id = id

    for (worker, boundary) in outgoing_boundaries.pairs() do
      _outgoing_boundaries(worker) = boundary
    end
    _event_log.register_resilient(id, this)

    let initial_router = _runner.clone_router_and_set_input_type(router')
    _update_router(initial_router)

    for (c_id, consumer) in _router.routes().pairs() do
      _register_output(c_id, consumer)
    end

    _step_message_processor = NormalStepMessageProcessor(this)
    _barrier_forwarder = BarrierStepForwarder(_id, this)

  //
  // Application startup lifecycle event
  //
  be application_begin_reporting(initializer: LocalTopologyInitializer) =>
    initializer.report_created(this)

  be application_created(initializer: LocalTopologyInitializer) =>
    for r in _routes.values() do
      r.application_created()
    end

    _initialized = true
    initializer.report_initialized(this)

  be application_initialized(initializer: LocalTopologyInitializer) =>
    _prepare_ready_to_work(initializer)

  be quick_initialize(initializer: LocalTopologyInitializer) =>
    _prepare_ready_to_work(initializer)

  fun ref _prepare_ready_to_work(initializer: LocalTopologyInitializer) =>
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
    | let rrtw: LocalTopologyInitializer =>
      rrtw.report_ready_to_work(this)
    else
      Fail()
    end

  be application_ready_to_work(initializer: LocalTopologyInitializer) =>
    None

  be update_router(router': Router) =>
    _update_router(router')

  fun ref _update_router(router': Router) =>
    let old_router = _router
    _router = router'
    for (old_id, outdated_consumer) in
      old_router.routes_not_in(_router).pairs()
    do
      if _outputs.contains(old_id) then
        _unregister_output(old_id, outdated_consumer)
      end
    end
    for (c_id, consumer) in _router.routes().pairs() do
      _register_output(c_id, consumer)
    end

    match _barrier_forwarder
    | let bf: BarrierStepForwarder =>
      if bf.barrier_in_progress() then
        bf.check_completion(inputs())
      end
    end

  fun ref _register_output(id: RoutingId, c: Consumer) =>
    if _outputs.contains(id) then
      try
        let old_c = _outputs(id)?
        if old_c is c then
          // We already know about this output.
          return
        end
        _unregister_output(id, old_c)
      else
        Unreachable()
      end
    end

    _outputs(id) = c
    if not _routes.contains(c) then
      let new_route = RouteBuilder(_id, this, c, _metrics_reporter)
      _routes(c) = new_route
      new_route.register_producer(id)
    else
      try
        _routes(c)?.register_producer(id)
      else
        Unreachable()
      end
    end

  fun ref _unregister_output(id: RoutingId, c: Consumer) =>
    try
      _routes(c)?.unregister_producer(id)
      _outputs.remove(id)?
      _remove_route_if_no_output(c)
    else
      Fail()
    end

  fun ref _unregister_all_outputs() =>
    """
    This method should only be called if we are removing this step from the
    active graph (or on dispose())
    """
    let outputs_to_remove = Map[RoutingId, Consumer]
    for (id, consumer) in _outputs.pairs() do
      outputs_to_remove(id) = consumer
    end
    for (id, consumer) in outputs_to_remove.pairs() do
      _unregister_output(id, consumer)
    end

  be register_downstream() =>
    _reregister_as_producer()

  fun ref _reregister_as_producer() =>
    for (id, c) in _outputs.pairs() do
      match c
      | let ob: OutgoingBoundary =>
        ob.forward_register_producer(_id, id, this)
      else
        c.register_producer(_id, this)
      end
    end

  be remove_route_to_consumer(id: RoutingId, c: Consumer) =>
    if _outputs.contains(id) then
      ifdef debug then
        Invariant(_routes.contains(c))
      end
      _unregister_output(id, c)
    end

  fun ref _remove_route_if_no_output(c: Consumer) =>
    var have_output = false
    for consumer in _outputs.values() do
      if consumer is c then have_output = true end
    end
    if not have_output then
      _remove_route(c)
    end

  fun ref _remove_route(c: Consumer) =>
    try
      _routes.remove(c)?._2
    else
      Fail()
    end

  be update_target_id_router(target_id_router: TargetIdRouter) =>
    let old_router = _target_id_router
    _target_id_router = target_id_router
    for (old_id, outdated_consumer) in
      old_router.routes_not_in(_target_id_router).pairs()
    do
      if _outputs.contains(old_id) then
        _unregister_output(old_id, outdated_consumer)
      end
    end

    for (id, consumer) in target_id_router.routes().pairs() do
      _register_output(id, consumer)
    end

    _add_boundaries(target_id_router.boundaries())

  be add_boundaries(boundaries: Map[String, OutgoingBoundary] val) =>
    _add_boundaries(boundaries)

  fun ref _add_boundaries(boundaries: Map[String, OutgoingBoundary] val) =>
    for (worker, boundary) in boundaries.pairs() do
      if not _outgoing_boundaries.contains(worker) then
        _outgoing_boundaries(worker) = boundary
        let new_route = RouteBuilder(_id, this, boundary, _metrics_reporter)
        _routes(boundary) = new_route
      end
    end

  be remove_boundary(worker: String) =>
    _remove_boundary(worker)

  fun ref _remove_boundary(worker: String) =>
    None

  be remove_route_for(step: Consumer) =>
    try
      _routes.remove(step)?
    else
      @printf[I32](("Tried to remove route for step but there was no route " +
        "to remove\n").cstring())
    end

  be run[D: Any val](metric_name: String, pipeline_time_spent: U64, data: D,
    i_producer_id: RoutingId, i_producer: Producer, msg_uid: MsgId,
    frac_ids: FractionalMessageId, i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    ifdef "trace" then
      @printf[I32]("Received msg at Step\n".cstring())
    end
    _step_message_processor.run[D](metric_name, pipeline_time_spent, data,
      i_producer_id, i_producer, msg_uid, frac_ids, i_seq_id, i_route_id,
      latest_ts, metrics_id, worker_ingress_ts)

  fun ref process_message[D: Any val](metric_name: String,
    pipeline_time_spent: U64, data: D, i_producer_id: RoutingId,
    i_producer: Producer, msg_uid: MsgId, frac_ids: FractionalMessageId,
    i_seq_id: SeqId, i_route_id: RouteId, latest_ts: U64, metrics_id: U16,
    worker_ingress_ts: U64)
  =>
    @printf[I32]("!@ Step %s process_message from %s\n".cstring(), _id.string().cstring(), i_producer_id.string().cstring())
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
      pipeline_time_spent, data, _id, this, _router, _target_id_router,
      msg_uid, frac_ids, my_latest_ts, my_metrics_id, worker_ingress_ts,
      _metrics_reporter)

    if is_finished then
      ifdef "trace" then
        @printf[I32]("Filtering\n".cstring())
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

  fun inputs(): Map[RoutingId, Producer] box =>
    _inputs

  fun outputs(): Map[RoutingId, Consumer] box =>
    _outputs

  fun ref next_sequence_id(): SeqId =>
    _seq_id_generator.new_id()

  fun ref current_sequence_id(): SeqId =>
    _seq_id_generator.latest_for_run()

  ///////////
  // RECOVERY
  fun ref _is_duplicate(msg_uid: MsgId, frac_ids: FractionalMessageId): Bool =>
    MessageDeduplicator.is_duplicate(msg_uid, frac_ids, _deduplication_list)

  be replay_run[D: Any val](metric_name: String, pipeline_time_spent: U64,
    data: D, i_producer_id: RoutingId, i_producer: Producer, msg_uid: MsgId,
    frac_ids: FractionalMessageId, i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    if not _is_duplicate(msg_uid, frac_ids) then
      _deduplication_list.push((msg_uid, frac_ids))

      process_message[D](metric_name, pipeline_time_spent, data, i_producer_id,
        i_producer, msg_uid, frac_ids, i_seq_id, i_route_id,
        latest_ts, metrics_id, worker_ingress_ts)
    else
      ifdef "trace" then
        @printf[I32]("Filtering a dupe in replay\n".cstring())
      end

      _seq_id_generator.new_incoming_message()
    end

  be initialize_seq_id_on_recovery(seq_id: SeqId) =>
    ifdef debug then
      Invariant(_seq_id_initialized_on_recovery == false)
    end
    _seq_id_generator = StepSeqIdGenerator(seq_id)
    _seq_id_initialized_on_recovery = true

  fun ref route_to(c: Consumer): (Route | None) =>
    try
      _routes(c)?
    else
      None
    end

  fun has_route_to(c: Consumer): Bool =>
    _routes.contains(c)

  be register_producer(id: RoutingId, producer: Producer) =>
    _inputs(id) = producer
    _upstreams.set(producer)

  be unregister_producer(id: RoutingId, producer: Producer) =>
    if _inputs.contains(id) then
      try
        _inputs.remove(id)?
      else Fail() end
      try
        let b_forwarder = _barrier_forwarder as BarrierStepForwarder
        if b_forwarder.barrier_in_progress() then
          b_forwarder.remove_input(id)
        end
      else Fail() end

      var have_input = false
      for i in _inputs.values() do
        if i is producer then have_input = true end
      end
      if not have_input then
        _upstreams.unset(producer)
      end
    end

  be report_status(code: ReportStatusCode) =>
    match code
    | BoundaryCountStatus =>
      var b_count: USize = 0
      for r in _routes.values() do
        match r
        | let br: BoundaryRoute => b_count = b_count + 1
        end
      end
      @printf[I32]("Step %s has %s boundaries.\n".cstring(), _id.string().cstring(), b_count.string().cstring())
    end
    for r in _routes.values() do
      r.report_status(code)
    end

  be mute(c: Consumer) =>
    for u in _upstreams.values() do
      u.mute(c)
    end

  be unmute(c: Consumer) =>
    for u in _upstreams.values() do
      u.unmute(c)
    end

  be dispose() =>
    @printf[I32]("Disposing Step %s\n".cstring(), _id.string().cstring())
    _event_log.unregister_resilient(_id, this)
    _unregister_all_outputs()

  ///////////////
  // GROW-TO-FIT
  be receive_key_state(state_name: StateName, key: Key,
    state_bytes: ByteSeq val)
  =>
    ifdef "autoscale" then
      StepStateMigrator.receive_state(this, _runner, state_name, key,
        state_bytes)
      @printf[I32]("Received state for step %s\n".cstring(),
        _id.string().cstring())
    end

  be send_state(boundary: OutgoingBoundary, state_name: String, key: Key,
    checkpoint_id: CheckpointId)
  =>
    ifdef "autoscale" then
      match _step_message_processor
      | let nmp: NormalStepMessageProcessor =>
        StepStateMigrator.send_state(this, _runner, _id, boundary, state_name,
          key, checkpoint_id, _auth)
      else
        Fail()
      end
    end

  fun ref register_key(state_name: StateName, key: Key) =>
    _router_registry.register_key(state_name, key)

  fun ref unregister_key(state_name: StateName, key: Key) =>
    _router_registry.unregister_key(state_name, key)

  //////////////
  // BARRIER
  //////////////
  be receive_barrier(step_id: RoutingId, producer: Producer,
    barrier_token: BarrierToken)
  =>
    ifdef "checkpoint_trace" then
      @printf[I32]("Step %s received barrier %s from %s\n".cstring(),
        _id.string().cstring(), barrier_token.string().cstring(),
        step_id.string().cstring())
    end
    process_barrier(step_id, producer, barrier_token)

  fun ref process_barrier(step_id: RoutingId, producer: Producer,
    barrier_token: BarrierToken)
  =>
    if _inputs.contains(step_id) then
      ifdef "checkpoint_trace" then
        @printf[I32]("Receive Barrier %s at Step %s\n".cstring(),
          barrier_token.string().cstring(), _id.string().cstring())
      end
      match barrier_token
      | let srt: CheckpointRollbackBarrierToken =>
        try
          let b_forwarder = _barrier_forwarder as BarrierStepForwarder
          if b_forwarder.higher_priority(srt)
          then
            _prepare_for_rollback()
          end
        else
          Fail()
        end
      end

      if _step_message_processor.barrier_in_progress() then
        _step_message_processor.receive_barrier(step_id, producer,
          barrier_token)
      else
        match _step_message_processor
        | let nsmp: NormalStepMessageProcessor =>
          try
            _step_message_processor = BarrierStepMessageProcessor(this,
              _barrier_forwarder as BarrierStepForwarder)
            _step_message_processor.receive_new_barrier(step_id, producer,
              barrier_token)
          else
            Fail()
          end
        else
          // !@ Should barriers be possible in other states?
          Fail()
        end
      end
    else
      @printf[I32](("Received barrier from unregistered input %s at step " +
        "%s. \n").cstring(), step_id.string().cstring(),
        _id.string().cstring())
    end

  fun ref barrier_complete(barrier_token: BarrierToken) =>
    ifdef "checkpoint_trace" then
      @printf[I32]("Barrier complete at Step %s\n".cstring(),
        _id.string().cstring())
    end
    ifdef debug then
      Invariant(_step_message_processor.barrier_in_progress())
    end
    match barrier_token
    | let sbt: CheckpointBarrierToken =>
      checkpoint_state(sbt.id)
    end
    let queued = _step_message_processor.queued()
    _step_message_processor = NormalStepMessageProcessor(this)
    for q in queued.values() do
      match q
      | let qm: QueuedMessage =>
        qm.process_message(this)
      | let qb: QueuedBarrier =>
        qb.inject_barrier(this)
      end
    end

  fun ref _clear_barriers() =>
    try
      (_barrier_forwarder as BarrierStepForwarder).clear()
    else
      Fail()
    end
    _step_message_processor = NormalStepMessageProcessor(this)

  //////////////
  // CHECKPOINTS
  //////////////
  fun ref checkpoint_state(checkpoint_id: CheckpointId) =>
    _next_checkpoint_id = checkpoint_id + 1
    ifdef "resilience" then
      StepStateCheckpointer(_runner, _id, checkpoint_id, _event_log)
    end

  be prepare_for_rollback() =>
    _prepare_for_rollback()

  fun ref _prepare_for_rollback() =>
    _clear_barriers()

  be rollback(payload: ByteSeq val, event_log: EventLog,
    checkpoint_id: CheckpointId)
  =>
    _next_checkpoint_id = checkpoint_id + 1
    ifdef "resilience" then
      StepRollbacker(payload, _runner)
    end
    event_log.ack_rollback(_id)
