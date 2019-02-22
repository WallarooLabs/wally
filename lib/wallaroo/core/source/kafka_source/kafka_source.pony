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

use "buffered"
use "collections"
use "pony-kafka"
use "promises"
use "wallaroo_labs/guid"
use "wallaroo/core/boundary"
use "wallaroo/core/common"
use "wallaroo/core/invariant"
use "wallaroo/core/source"
use "wallaroo/core/barrier"
use "wallaroo/core/recovery"
use "wallaroo/core/router_registry"
use "wallaroo/core/checkpoint"
use "wallaroo_labs/mort"
use "wallaroo/core/initialization"
use "wallaroo/core/metrics"
use "wallaroo/core/routing"
use "wallaroo/core/topology"

actor KafkaSource[In: Any val] is (Source & KafkaConsumer)
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

  let _event_log: EventLog
  let _map_seq_id_offset: Map[SeqId, KafkaOffset] = _map_seq_id_offset.create()

  var _last_flushed_offset: KafkaOffset = 0

  var _last_flushed_seq_id: SeqId = 1

  var _last_processed_offset: KafkaOffset = -1

  var _recovering: Bool

  let _name: String

  let _rb: Reader = Reader
  let _wb: Writer = Writer

  let _metrics_reporter: MetricsReporter

  let _listen: KafkaSourceListener[In]
  let _notify: KafkaSourceNotify[In]

  var _muted: Bool = true
  var _disposed: Bool = false
  let _muted_by: SetIs[Any tag] = _muted_by.create()

  let _router_registry: RouterRegistry

  // Producer (Resilience)
  var _seq_id: SeqId = 1 // 0 is reserved for "not seen yet"

  let _pending_barriers: Array[BarrierToken] = _pending_barriers.create()

  // Checkpoint
  var _next_checkpoint_id: CheckpointId = 1

  var _is_pending: Bool = true

  let _topic: String
  let _partition_id: KafkaPartitionId
  let _kc: KafkaClient tag

  new create(source_id: RoutingId, auth: AmbientAuth, name: String,
    listen: KafkaSourceListener[In], notify: KafkaSourceNotify[In] iso,
    event_log: EventLog, router': Router,
    outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder] val,
    layout_initializer: LayoutInitializer,
    metrics_reporter': MetricsReporter iso,
    topic: String, partition_id: KafkaPartitionId,
    kafka_client: KafkaClient tag, router_registry: RouterRegistry,
    recovering: Bool)
  =>
    _source_id = source_id
    _auth = auth
    _topic = topic
    _partition_id = partition_id
    _kc = kafka_client

    _metrics_reporter = consume metrics_reporter'
    _listen = listen
    _notify = consume notify
    _event_log = event_log

    _recovering = recovering

    _name = name

    // register resilient with event log
    _event_log.register_resilient_source(_source_id, this)

    _layout_initializer = layout_initializer
    _router_registry = router_registry

    for (target_worker_name, builder) in outgoing_boundary_builders.pairs() do
      let new_boundary =
        builder.build_and_initialize(_routing_id_gen(), target_worker_name,
          _layout_initializer)
      router_registry.register_disposable(new_boundary)
      _outgoing_boundaries(target_worker_name) = new_boundary
    end

    _router = router'
    _update_router(router')

    _notify.update_boundaries(_outgoing_boundaries)

    _mute()
    ifdef "resilience" then
      _mute_local()
    end

  be first_checkpoint_complete() =>
    _unmute_local()
    _is_pending = false
    for (id, c) in _outputs.pairs() do
      Route.register_producer(_source_id, id, this, c)
    end

  fun ref metrics_reporter(): MetricsReporter =>
    _metrics_reporter

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

    _notify.update_router(_router)

  be register_downstreams(promise: Promise[Source]) =>
    promise(this)

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
    don't yet have a boundary to. Each KafkaSource has its own
    OutgoingBoundary to each worker to allow for higher throughput.
    """
    for (target_worker_name, builder) in boundary_builders.pairs() do
      if not _outgoing_boundaries.contains(target_worker_name) then
        let boundary = builder.build_and_initialize(_routing_id_gen(),
          target_worker_name, _layout_initializer)
        _outgoing_boundaries(target_worker_name) = boundary
        _router_registry.register_disposable(boundary)
        _routes.set(boundary)
      end
    end
    _notify.update_boundaries(_outgoing_boundaries)

  be add_boundaries(bs: Map[String, OutgoingBoundary] val) =>
    None

  be remove_boundary(worker: String) =>
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
        @printf[I32]("KafkaSource couldn't find boundary to %s to disconnect\n"
          .cstring(), worker.cstring())
      end
    end

  be update_worker_data_service(worker: WorkerName,
    host: String, service: String)
  =>
    @printf[I32]("SLF: TCPSource: update_worker_data_service: %s -> %s %s\n".cstring(), worker.cstring(), host.cstring(), service.cstring())
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
    None

  //////////////
  // CHECKPOINTS
  //////////////
  fun ref checkpoint_state(checkpoint_id: CheckpointId) =>
    ifdef "trace" then
      @printf[I32]("checkpoint_state in %s\n".cstring(), _name.cstring())
    end
    _next_checkpoint_id = checkpoint_id + 1
    _wb.i64_le(_last_flushed_offset)
    let payload = _wb.done()
    _event_log.checkpoint_state(_source_id, checkpoint_id, consume payload)

  be prepare_for_rollback() =>
    _prepare_for_rollback()

  fun ref _prepare_for_rollback() =>
    None

  be rollback(payload: ByteSeq val, event_log: EventLog,
    checkpoint_id: CheckpointId)
  =>
    _next_checkpoint_id = checkpoint_id + 1
    event_log.ack_rollback(_source_id)

  ///////////////
  // WATERMARKS
  ///////////////
  fun ref check_effective_input_watermark(current_ts: U64): U64 =>
    current_ts

  fun ref update_output_watermark(w: U64): (U64, U64) =>
    (w, w)



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
      @printf[I32]("KafkaSource %s has %s boundaries.\n".cstring(),
        _source_id.string().cstring(), b_count.string().cstring())
    end

  fun ref _mute() =>
    ifdef debug then
      @printf[I32]("Muting %s\n".cstring(), _name.cstring())
    end
    _kc.consumer_pause(_topic, _partition_id)

    _muted = true

  fun ref _unmute() =>
    if _recovering then
      ifdef debug then
        @printf[I32]("NOT Unmuting %s because it is currently recovering\n"
          .cstring(), _name.cstring())
      end
      return
    end
    if _last_processed_offset != -1 then
      ifdef debug then
        @printf[I32](("Unmuting %s with custom offset: " +
          (_last_processed_offset + 1).string() + "\n").cstring(),
          _name.cstring())
      end
      _kc.consumer_resume(_topic, _partition_id, _last_processed_offset + 1)
    else
      ifdef debug then
        @printf[I32]("Unmuting %s\n".cstring(), _name.cstring())
      end
      _kc.consumer_resume(_topic, _partition_id)
    end

    _muted = false

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

  be receive_kafka_message(client: KafkaClient, value: Array[U8] iso,
    key: (Array[U8] val | None), msg_metadata: KafkaMessageMetadata val,
    network_received_timestamp: U64)
  =>
    if (msg_metadata.get_topic() != _topic)
      or (msg_metadata.get_partition_id() != _partition_id) then
      @printf[I32](("Msg topic: " + msg_metadata.get_topic() + " != _topic: " +
        _topic + " or Msg partition: " + msg_metadata.get_partition_id().string()
        + " != " + " _partition_id: " + _partition_id.string() + "!").cstring())
      Fail()
    end
    _notify.received(this, consume value, key, msg_metadata,
      network_received_timestamp)

    ifdef "trace" then
      @printf[I32](("seq_id: " + current_sequence_id().string() + " => offset: "
      + msg_metadata.get_offset().string() + " in %s\n").cstring(),
      _name.cstring())
    end
    _map_seq_id_offset(current_sequence_id()) = msg_metadata.get_offset()

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
    @printf[I32]("Shutting down %s\n".cstring(), _name.cstring())

    if not _disposed then
      _unregister_all_outputs()
      _router_registry.unregister_source(this, _source_id)
      _event_log.unregister_resilient(_source_id, this)
      for b in _outgoing_boundaries.values() do
        b.dispose()
      end

      _kc.dispose()
      _disposed = true
    end
