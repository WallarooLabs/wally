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
use "wallaroo/ent/barrier"
use "wallaroo/ent/recovery"
use "wallaroo/ent/router_registry"
use "wallaroo/ent/snapshot"
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
  let _routes: MapIs[Consumer, Route] = _routes.create()
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
  let _muted_downstream: SetIs[Any tag] = _muted_downstream.create()

  let _router_registry: RouterRegistry

  // Producer (Resilience)
  var _seq_id: SeqId = 1 // 0 is reserved for "not seen yet"

  let _state_step_creator: StateStepCreator

  let _pending_message_store: PendingMessageStore =
    _pending_message_store.create()

  let _pending_barriers: Array[BarrierToken] = _pending_barriers.create()

  let _topic: String
  let _partition_id: KafkaPartitionId
  let _kc: KafkaClient tag

  new create(source_id: RoutingId, auth: AmbientAuth, name: String,
    listen: KafkaSourceListener[In], notify: KafkaSourceNotify[In] iso,
    event_log: EventLog, router': Router,
    outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder] val,
    layout_initializer: LayoutInitializer,
    metrics_reporter: MetricsReporter iso,
    topic: String, partition_id: KafkaPartitionId,
    kafka_client: KafkaClient tag, router_registry: RouterRegistry,
    state_step_creator: StateStepCreator,
    recovering: Bool)
  =>
    _source_id = source_id
    _auth = auth
    _topic = topic
    _partition_id = partition_id
    _kc = kafka_client

    _metrics_reporter = consume metrics_reporter
    _listen = listen
    _notify = consume notify
    _event_log = event_log

    _state_step_creator = state_step_creator

    _recovering = recovering

    _name = name

    // register resilient with event log
    _event_log.register_resilient(_source_id, this)

    _layout_initializer = layout_initializer
    _router_registry = router_registry

    for (target_worker_name, builder) in outgoing_boundary_builders.pairs() do
      let new_boundary =
        builder.build_and_initialize(_routing_id_gen(), target_worker_name,
          _layout_initializer)
      router_registry.register_disposable(new_boundary)
      _outgoing_boundaries(target_worker_name) = new_boundary
    end

    let new_router =
      match router'
      | let pr: PartitionRouter =>
        pr.update_boundaries(_auth, _outgoing_boundaries)
      | let spr: StatelessPartitionRouter =>
        spr.update_boundaries(_outgoing_boundaries)
      else
        router'
      end
    _router = new_router

    for (c_id, consumer) in _router.routes().pairs() do
      _register_output(c_id, consumer)
    end

    _notify.update_boundaries(_outgoing_boundaries)

    for r in _routes.values() do
      // TODO: this is a hack, we shouldn't be calling application events
      // directly. route lifecycle needs to be broken out better from
      // application lifecycle
      r.application_created()
     end

    for r in _routes.values() do
      r.application_initialized("KafkaSource-" + topic + "-"
        + partition_id.string())
    end

    _mute()

  be update_router(router': Router) =>
    let new_router =
      match router'
      | let pr: PartitionRouter =>
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
    _pending_message_store.process_known_keys(this, _router)
    if not _pending_message_store.has_pending() then
      let bs = Array[BarrierToken]
      for b in _pending_barriers.values() do
        bs.push(b)
      end
      _pending_barriers.clear()
      for b in bs.values() do
        _initiate_barrier(b)
      end
      _unmute_local()
    end

  be register_downstreams(action: Promise[Source]) =>
    action(this)

  fun ref unknown_key(state_name: String, key: Key,
    routing_args: RoutingArguments)
  =>
    _pending_message_store.add(state_name, key, routing_args)
    _state_step_creator.report_unknown_key(this, state_name, key)

  be remove_route_to_consumer(id: RoutingId, c: Consumer) =>
    if _outputs.contains(id) then
      ifdef debug then
        Invariant(_routes.contains(c))
      end
      _unregister_output(id, c)
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
      let new_route = RouteBuilder(_source_id, this, c, _metrics_reporter)
      _routes(c) = new_route
      new_route.register_producer(id)
    else
      try
        _routes(c)?.register_producer(id)
      else
        Unreachable()
      end
    end

  fun router(): Router =>
    _router

  fun ref _unregister_output(id: RoutingId, c: Consumer) =>
    try
      _routes(c)?.unregister_producer(id)
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
    try
      _routes.remove(c)?._2
    else
      Fail()
    end

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
        let new_route = RouteBuilder(_source_id, this, boundary,
          _metrics_reporter)
        _routes(boundary) = new_route
      end
    end
    _notify.update_boundaries(_outgoing_boundaries)

  be add_boundaries(bs: Map[String, OutgoingBoundary] val) =>
    //!@ Should we fail here?
    None

  be remove_boundary(worker: String) =>
    None

  be reconnect_boundary(target_worker_name: String) =>
    try
      _outgoing_boundaries(target_worker_name)?.reconnect()
    else
      Fail()
    end

  be remove_route_for(step: Consumer) =>
    try
      _routes.remove(step)?
    else
      Fail()
    end

  be initialize_seq_id_on_recovery(seq_id: SeqId) =>
    ifdef "trace" then
      @printf[I32](("initializing sequence id on recovery: " + seq_id.string() +
        " in %s\n").cstring(), _name.cstring())
    end
    // update to use correct seq_id for recovery
    _seq_id = seq_id

  //////////////
  // BARRIER
  //////////////
  be initiate_barrier(token: BarrierToken) =>
    _initiate_barrier(token)

  fun ref _initiate_barrier(token: BarrierToken) =>
    if not _disposed then
      match token
      | let srt: SnapshotRollbackBarrierToken =>
        _pending_message_store.clear()
      end

      if not _pending_message_store.has_pending() then
        for (o_id, o) in _outputs.pairs() do
          match o
          | let ob: OutgoingBoundary =>
            ob.forward_barrier(o_id, _source_id, token)
          else
            o.receive_barrier(_source_id, this, token)
          end
        end
      else
        _mute_local()
        _pending_barriers.push(token)
      end
    end

  be barrier_complete(token: BarrierToken) =>
    // !@ Here's where we could ack finished messages up to snapshot point.
    // We should also match for rollback token.
    None

  //////////////
  // SNAPSHOTS
  //////////////
  fun ref snapshot_state(snapshot_id: SnapshotId) =>
    //!@ We probably need to snapshot info about last seq id for snapshot.
    ifdef "trace" then
      @printf[I32]("snapshot_state in %s\n".cstring(), _name.cstring())
    end
    _wb.i64_le(_last_flushed_offset)
    let payload = _wb.done()
    _event_log.snapshot_state(_source_id, snapshot_id, consume payload)

  be rollback(payload: ByteSeq val, event_log: EventLog) =>
    //!@ Rollback!
    event_log.ack_rollback(_source_id)




  fun ref route_to(c: Consumer): (Route | None) =>
    try
      _routes(c)?
    else
      None
    end

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
        | let br: BoundaryRoute => b_count = b_count + 1
        end
      end
      @printf[I32]("KafkaSource %s has %s boundaries.\n".cstring(),
        _source_id.string().cstring(), b_count.string().cstring())
    end
    for route in _routes.values() do
      route.report_status(code)
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
    _muted_downstream.set(this)
    _mute()

  fun ref _unmute_local() =>
    _muted_downstream.unset(this)

    if _muted_downstream.size() == 0 then
      _unmute()
    end

  be mute(c: Consumer) =>
    _muted_downstream.set(c)
    _mute()

  be unmute(c: Consumer) =>
    _muted_downstream.unset(c)

    if _muted_downstream.size() == 0 then
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
    for (id, consumer) in _outputs.pairs() do
      _unregister_output(id, consumer)
    end

  be dispose() =>
    @printf[I32]("Shutting down %s\n".cstring(), _name.cstring())

    if not _disposed then
      _unregister_all_outputs()
      _router_registry.unregister_source(this, _source_id)
      for b in _outgoing_boundaries.values() do
        b.dispose()
      end

      _kc.dispose()
      _disposed = true
    end
