/*

Copyright (C) 2016-2017, Wallaroo Labs
Copyright (C) 2016-2017, The Pony Developers
Copyright (c) 2014-2015, Causality Ltd.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/

use "buffered"
use "collections"
use "net"
use "promises"
use "serialise"
use "time"
use "wallaroo/core/boundary"
use "wallaroo/core/common"
use "wallaroo/core/partitioning"
use "wallaroo/core/initialization"
use "wallaroo/core/invariant"
use "wallaroo/core/metrics"
use "wallaroo/core/routing"
use "wallaroo/core/source"
use "wallaroo/core/topology"
use "wallaroo/core/barrier"
use "wallaroo/core/data_receiver"
use "wallaroo/core/recovery"
use "wallaroo/core/router_registry"
use "wallaroo/core/checkpoint"
use "wallaroo_labs/mort"
use "wallaroo_labs/time"

use @pony_asio_event_create[AsioEventID](owner: AsioEventNotify, fd: U32,
  flags: U32, nsec: U64, noisy: Bool)
use @pony_asio_event_fd[U32](event: AsioEventID)
use @pony_asio_event_unsubscribe[None](event: AsioEventID)
use @pony_asio_event_resubscribe_read[None](event: AsioEventID)
use @pony_asio_event_resubscribe_write[None](event: AsioEventID)
use @pony_asio_event_destroy[None](event: AsioEventID)

interface val GenSourceGeneratorBuilder[V: Any val]
  fun apply(): GenSourceGenerator[V]

interface GenSourceGenerator[V: Any val]
  fun ref initial_value(): (V | None)
  fun ref apply(v: V): (V | None)

primitive EmptyGenSourceGeneratorBuilder[V: Any val]
  fun apply(): GenSourceGenerator[V] =>
    EmptyGenSource[V]

class ref EmptyGenSource[V: Any val]
  fun initial_value(): None => None
  fun ref apply(v: V): None => None

actor GenSource[V: Any val] is Source
  """
  # GenSource
  """
  var _cur_value: (V | None)
  let _generator: GenSourceGenerator[V]

  let _source_id: RoutingId
  let _auth: AmbientAuth
  let _routing_id_gen: RoutingIdGenerator = RoutingIdGenerator
  var _router: Router

  let _routes: SetIs[Consumer] = _routes.create()
  // _outputs keeps track of all output targets by step id. There might be
  // duplicate consumers in this map (unlike _routes) since there might be
  // multiple target step ids over a boundary
  let _outputs: Map[RoutingId, Consumer] = _outputs.create()
  let _outgoing_boundaries: Map[String, OutgoingBoundary] =
    _outgoing_boundaries.create()
  let _layout_initializer: LayoutInitializer
  var _unregistered: Bool = false

  let _metrics_reporter: MetricsReporter

  let _pending_barriers: Array[BarrierToken] = _pending_barriers.create()

  // Start muted. Wait for unmute to begin processing
  var _muted: Bool = true
  var _disposed: Bool = false
  let _muted_by: SetIs[Any tag] = _muted_by.create()

  var _is_pending: Bool = true

  let _router_registry: RouterRegistry

  let _event_log: EventLog

  // Producer (Resilience)
  var _seq_id: SeqId = 1 // 0 is reserved for "not seen yet"

  // Checkpoint
  var _next_checkpoint_id: CheckpointId = 1

  let _pipeline_name: String
  let _source_name: SourceName
  let _runner: Runner
  let _msg_id_gen: MsgIdGenerator = MsgIdGenerator

  new create(source_id: RoutingId, auth: AmbientAuth, pipeline_name: String,
    runner_builder: RunnerBuilder, partitioner_builder: PartitionerBuilder,
    router': Router, target_router: Router,
    generator_builder: GenSourceGeneratorBuilder[V], event_log: EventLog,
    outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder] val,
    layout_initializer: LayoutInitializer,
    metrics_reporter': MetricsReporter iso, router_registry: RouterRegistry)
  =>
    _pipeline_name = pipeline_name
    _source_name = pipeline_name + " source"

    _generator = generator_builder()
    _cur_value = _generator.initial_value()

    _source_id = source_id
    _auth = auth
    _event_log = event_log
    _metrics_reporter = consume metrics_reporter'

    _layout_initializer = layout_initializer
    _router_registry = router_registry

    _runner = runner_builder(event_log, auth, None, target_router,
      partitioner_builder)
    _router = router'

    for (target_worker_name, builder) in outgoing_boundary_builders.pairs() do
      if not _outgoing_boundaries.contains(target_worker_name) then
        let new_boundary =
          builder.build_and_initialize(_routing_id_gen(), target_worker_name,
            _layout_initializer)
        router_registry.register_disposable(new_boundary)
        _outgoing_boundaries(target_worker_name) = new_boundary
      end
    end

    _router = router'
    _update_router(router')

    // register resilient with event log
    _event_log.register_resilient_source(_source_id, this)

    _mute()
    ifdef "resilience" then
      _mute_local()
    end

  fun ref metrics_reporter(): MetricsReporter =>
    _metrics_reporter

  be next_message() =>
    if not _muted and not _disposed then
      process_message()
    end

  fun ref process_message() =>
    _metrics_reporter.pipeline_ingest(_pipeline_name, _source_name)
    let ingest_ts = WallClock.nanoseconds()

    let pipeline_time_spent: U64 = 0
    var latest_metrics_id: U16 = 1

    let watermark_ts = ingest_ts

    ifdef "trace" then
      @printf[I32](("Rcvd msg at " + _pipeline_name + " source\n").cstring())
    end

    let decode_end_ts = WallClock.nanoseconds()
    _metrics_reporter.step_metric(_pipeline_name,
      "Decode Time in TCP Source", latest_metrics_id, ingest_ts,
      decode_end_ts)
    latest_metrics_id = latest_metrics_id + 1

    let next = _cur_value
    match next
    | let next': V =>
      _cur_value = _generator(next')
      (let is_finished, let last_ts) =
        _runner.run[V](_pipeline_name, pipeline_time_spent, next',
          "gen-source-key", ingest_ts, watermark_ts, _source_id, this, _router,
          _msg_id_gen(), None, decode_end_ts, latest_metrics_id, ingest_ts,
          _metrics_reporter)

      if is_finished then
        let end_ts = WallClock.nanoseconds()
        let time_spent = end_ts - ingest_ts

        ifdef "detailed-metrics" then
          _metrics_reporter.step_metric(_pipeline_name,
            "Before end at TCP Source", 9999,
            last_ts, end_ts)
        end

        _metrics_reporter.pipeline_metric(_pipeline_name, time_spent +
          pipeline_time_spent)
        _metrics_reporter.worker_metric(_pipeline_name, time_spent)
      end
      // TODO: Use Timer instead of processing as fast as possible
      next_message()
    else
      @printf[I32]("GenSource produced a None. Stopping GenSource.\n".cstring())
    end

  be first_checkpoint_complete() =>
    """
    In case we pop into existence midway through a checkpoint, we need to
    wait until this is called to start processing.
    """
    _unmute_local()
    _is_pending = false
    for (id, c) in _outputs.pairs() do
      Route.register_producer(_source_id, id, this, c)
    end

  be update_router(router': Router) =>
    _update_router(router')

  fun ref _update_router(router': Router) =>
    let new_router =
      match router'
      | let pr: StatePartitionRouter =>
        pr.update_boundaries(_auth, _outgoing_boundaries)
      | let spr: StatelessPartitionRouter =>
        spr.update_boundaries(_outgoing_boundaries)
      else
        router'
      end

    let old_router = _router
    _router = new_router
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

  be remove_route_to_consumer(id: RoutingId, c: Consumer) =>
    if _outputs.contains(id) then
      ifdef debug then
        Invariant(_routes.contains(c))
      end
      _unregister_output(id, c)
    end

  fun ref _register_output(id: RoutingId, c: Consumer) =>
    if not _disposed then
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
      _routes.set(c)
      if not _is_pending then
        Route.register_producer(_source_id, id, this, c)
      end
    end

  be register_downstream() =>
    _reregister_as_producer()

  fun ref _reregister_as_producer() =>
    if not _disposed then
      for (id, c) in _outputs.pairs() do
        match c
        | let ob: OutgoingBoundary =>
          if not _is_pending then
            ob.forward_register_producer(_source_id, id, this)
          end
        else
          if not _is_pending then
            c.register_producer(_source_id, this)
          end
        end
      end
    end

  be register_downstreams(promise: Promise[Source]) =>
    promise(this)

  fun ref _unregister_output(id: RoutingId, c: Consumer) =>
    try
      Route.unregister_producer(_source_id, id, this, c)
      _outputs.remove(id)?
      _remove_route_if_no_output(c)
    else
      Fail()
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
    _routes.unset(c)

  be add_boundary_builders(
    boundary_builders: Map[String, OutgoingBoundaryBuilder] val)
  =>
    """
    Build a new boundary for each builder that corresponds to a worker we
    don't yet have a boundary to. Each GenSource has its own
    OutgoingBoundary to each worker to allow for higher throughput.
    """
    for (target_worker_name, builder) in boundary_builders.pairs() do
      if not _outgoing_boundaries.contains(target_worker_name) then
        let boundary = builder.build_and_initialize(_routing_id_gen(),
          target_worker_name, _layout_initializer)
        _router_registry.register_disposable(boundary)
        _outgoing_boundaries(target_worker_name) = boundary
        _routes.set(boundary)
      end
    end

  be add_boundaries(bs: Map[String, OutgoingBoundary] val) =>
    None

  be remove_boundary(worker: String) =>
    _remove_boundary(worker)

  fun ref _remove_boundary(worker: String) =>
    None

  be reconnect_boundary(target_worker_name: String) =>
    try
      _outgoing_boundaries(target_worker_name)?.reconnect()
    else
      Fail()
    end

  be disconnect_boundary(worker: WorkerName) =>
    try
      _outgoing_boundaries(worker)?.dispose()
      _outgoing_boundaries.remove(worker)?
    else
      ifdef debug then
        @printf[I32]("GenSource couldn't find boundary to %s to disconnect\n"
          .cstring(), worker.cstring())
      end
    end

  fun ref _unregister_all_outputs() =>
    """
    This method should only be called if we are removing this source from the
    active graph (or on dispose())
    """
    let outputs_to_remove = Map[RoutingId, Consumer]
    for (id, consumer) in _outputs.pairs() do
      outputs_to_remove(id) = consumer
    end
    for (id, consumer) in outputs_to_remove.pairs() do
      _unregister_output(id, consumer)
    end

  be dispose_with_promise(promise: Promise[None]) =>
    _dispose()
    promise(None)

  be dispose() =>
    _dispose()

  fun ref _dispose() =>
    """
    - Close the connection gracefully.
    """
    if not _disposed then
      _router_registry.unregister_source(this, _source_id)
      _event_log.unregister_resilient(_source_id, this)
      _unregister_all_outputs()
      @printf[I32]("Shutting down GenSource\n".cstring())
      for b in _outgoing_boundaries.values() do
        b.dispose()
      end
      _disposed = true
    end

  fun ref has_route_to(c: Consumer): Bool =>
    _routes.contains(c)

  fun ref next_sequence_id(): SeqId =>
    _seq_id = _seq_id + 1

  fun ref current_sequence_id(): SeqId =>
    _seq_id

  be report_status(code: ReportStatusCode) =>
    match code
    | BoundaryCountStatus =>
      var b_count: USize = 0
      for r in _routes.values() do
        match r
        | let ob: OutgoingBoundary => b_count = b_count + 1
        end
      end
      @printf[I32]("GenSource %s has %s boundaries.\n".cstring(),
        _source_id.string().cstring(), b_count.string().cstring())
    end

  be update_worker_data_service(worker: WorkerName,
    host: String, service: String)
  =>
    @printf[I32]("SLF: GenSource: update_worker_data_service: %s -> %s %s\n".cstring(), worker.cstring(), host.cstring(), service.cstring())
    try
      let b = _outgoing_boundaries(worker)?
      b.update_worker_data_service(worker, host, service)
    else
      Fail()
    end

  //////////////
  // BARRIER
  //////////////
  be initiate_barrier(token: BarrierToken) =>
    ifdef "checkpoint_trace" then
      @printf[I32]("GenSource received initiate_barrier %s\n".cstring(),
        token.string().cstring())
    end
    if not _is_pending then
      _initiate_barrier(token)
    end

  fun ref _initiate_barrier(token: BarrierToken) =>
    if not _disposed then
      match token
      | let srt: CheckpointRollbackBarrierToken =>
        _prepare_for_rollback()
      end

      match token
      | let sbt: CheckpointBarrierToken =>
        checkpoint_state(sbt.id)
      end
      for (o_id, o) in _outputs.pairs() do
        match o
        | let ob: OutgoingBoundary =>
          ob.forward_barrier(o_id, _source_id, token)
        else
          o.receive_barrier(_source_id, this, token)
        end
      end
    end

  be barrier_complete(token: BarrierToken) =>
    ifdef "checkpoint_trace" then
      @printf[I32]("barrier_complete at GenSource %s\n".cstring(),
        _source_id.string().cstring())
    end
    None

  //////////////
  // CHECKPOINTS
  //////////////
  fun ref checkpoint_state(checkpoint_id: CheckpointId) =>
    """
    GenSources don't currently write out any data as part of the checkpoint.
    """
    _next_checkpoint_id = checkpoint_id + 1
    _event_log.checkpoint_state(_source_id, checkpoint_id, _serialize())

  fun ref _serialize(): Array[ByteSeq] val =>
    let res = recover iso Array[ByteSeq] end
    try
      let bytes = Serialised(SerialiseAuth(_auth), _cur_value)?
        .output(OutputSerialisedAuth(_auth))
      res.push(bytes)
    else
      Fail()
    end
    consume res

  be prepare_for_rollback() =>
    _prepare_for_rollback()

  fun ref _prepare_for_rollback() =>
    None

  be rollback(payload: ByteSeq val, event_log: EventLog,
    checkpoint_id: CheckpointId)
  =>
    """
    There is nothing for a GenSource to rollback to.
    """
    _next_checkpoint_id = checkpoint_id + 1

    try
      _cur_value = _deserialize(payload)?
    else
      Fail()
    end

    event_log.ack_rollback(_source_id)

  fun _deserialize(data: ByteSeq val): V ? =>
    try
      match Serialised.input(InputSerialisedAuth(_auth),
        data as Array[U8] val)(DeserialiseAuth(_auth))?
      | let v: V => v
      else
        error
      end
    else
      error
    end

  ///////////////
  // WATERMARKS
  ///////////////
  fun ref check_effective_input_watermark(current_ts: U64): U64 =>
    current_ts

  fun ref update_output_watermark(w: U64): (U64, U64) =>
    (w, w)

  //////////
  // MUTING
  //////////
  fun ref _mute() =>
    ifdef debug then
      @printf[I32]("Muting GenSource\n".cstring())
    end
    _muted = true

  fun ref _unmute() =>
    ifdef debug then
      @printf[I32]("Unmuting GenSource\n".cstring())
    end
    let was_muted = _muted
    _muted = false
    if was_muted then
      next_message()
    end

  fun ref _mute_local() =>
    _muted_by.set(this)
    _mute()

  fun ref _unmute_local() =>
    _muted_by.unset(this)

    if _muted_by.size() == 0 then
      _unmute()
    end

  be mute(a: Any tag) =>
    _muted_by.set(a)
    _mute()

  be unmute(a: Any tag) =>
    _muted_by.unset(a)

    if _muted_by.size() == 0 then
      _unmute()
    end

  fun ref is_muted(): Bool =>
    _muted
