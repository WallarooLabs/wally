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
use "wallaroo_labs/guid"
use "wallaroo/core/boundary"
use "wallaroo/core/common"
use "wallaroo/core/invariant"
use "wallaroo/ent/recovery"
use "wallaroo/ent/router_registry"
use "wallaroo/ent/snapshot"
use "wallaroo/ent/watermarking"
use "wallaroo_labs/mort"
use "wallaroo/core/initialization"
use "wallaroo/core/metrics"
use "wallaroo/core/routing"
use "wallaroo/core/topology"

actor KafkaSource[In: Any val] is (Producer & InFlightAckResponder &
  StatusReporter & KafkaConsumer)
  let _source_id: StepId
  let _auth: AmbientAuth
  let _step_id_gen: StepIdGenerator = StepIdGenerator
  var _router: Router
  let _routes: MapIs[Consumer, Route] = _routes.create()
  // _outputs keeps track of all output targets by step id. There might be
  // duplicate consumers in this map (unlike _routes) since there might be
  // multiple target step ids over a boundary
  let _outputs: Map[StepId, Consumer] = _outputs.create()
  let _route_builder: RouteBuilder
  let _outgoing_boundaries: Map[String, OutgoingBoundary] =
    _outgoing_boundaries.create()
  let _layout_initializer: LayoutInitializer
  var _unregistered: Bool = false

  let _event_log: EventLog
  let _acker_x: Acker
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
  let _muted_downstream: SetIs[Any tag] = _muted_downstream.create()

  let _router_registry: RouterRegistry

  // Producer (Resilience)
  var _seq_id: SeqId = 1 // 0 is reserved for "not seen yet"
  var _in_flight_ack_waiter: InFlightAckWaiter

  let _state_step_creator: StateStepCreator

  let _pending_message_store: PendingMessageStore =
    _pending_message_store.create()

  let _topic: String
  let _partition_id: KafkaPartitionId
  let _kc: KafkaClient tag

  new create(source_id: StepId, auth: AmbientAuth, name: String,
    listen: KafkaSourceListener[In], notify: KafkaSourceNotify[In] iso,
    event_log: EventLog, router: Router, route_builder: RouteBuilder,
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
    _acker_x = Acker

    _state_step_creator = state_step_creator

    _recovering = recovering

    _name = name

    // register resilient with event log
    _event_log.register_resilient(this, _source_id)

    _layout_initializer = layout_initializer
    _router_registry = router_registry

    _route_builder = route_builder

    _in_flight_ack_waiter = InFlightAckWaiter(_source_id)

    for (target_worker_name, builder) in outgoing_boundary_builders.pairs() do
      let new_boundary =
        builder.build_and_initialize(_step_id_gen(), target_worker_name,
          _layout_initializer)
      router_registry.register_disposable(new_boundary)
      _outgoing_boundaries(target_worker_name) = new_boundary
    end

    let new_router =
      match router
      | let pr: PartitionRouter =>
        pr.update_boundaries(_outgoing_boundaries)
      | let spr: StatelessPartitionRouter =>
        spr.update_boundaries(_outgoing_boundaries)
      else
        router
      end
    _router = new_router

    for (c_id, consumer) in _router.routes().pairs() do
      _outputs(c_id) = consumer
      _routes(consumer) =
        _route_builder(_source_id, this, consumer, _metrics_reporter)
    end

    //!@
    // for (worker, boundary) in _outgoing_boundaries.pairs() do
    //   _routes(boundary) =
    //     _route_builder(_source_id, this, boundary, _metrics_reporter)
    // end

    _notify.update_boundaries(_outgoing_boundaries)

    for r in _routes.values() do
      // TODO: this is a hack, we shouldn't be calling application events
      // directly. route lifecycle needs to be broken out better from
      // application lifecycle
      r.application_created()
      ifdef "resilience" then
        _acker_x.add_route(r)
      end
    end

    for r in _routes.values() do
      r.application_initialized("KafkaSource-" + topic + "-"
        + partition_id.string())
    end

    _mute()

  be update_router(router: Router) =>
    let new_router =
      match router
      | let pr: PartitionRouter =>
        pr.update_boundaries(_auth, _outgoing_boundaries)
      | let spr: StatelessPartitionRouter =>
        spr.update_boundaries(_outgoing_boundaries)
      else
        router
      end

    let old_router = _router
    _router = router
    for (old_id, outdated_consumer) in
      old_router.routes_not_in(_router).pairs()
    do
      if _outputs.contains(old_id) then
        try
          _outputs.remove(old_id)?
          _remove_route_if_no_output(outdated_consumer)
        else
          Fail()
        end
      end
    end
    for (c_id, consumer) in _router.routes().pairs() do
      _outputs(c_id) = consumer
      if not _routes.contains(consumer) then
        let new_route = _route_builder(_source_id, this, consumer,
          _metrics_reporter)
        ifdef "resilience" then
          _acker_x.add_route(new_route)
        end
        _routes(consumer) = new_route
      end
    end

    _notify.update_router(new_router)
    _pending_message_store.process_known_keys(this, _notify, new_router)

  fun ref unknown_key(state_name: String, key: Key,
    routing_args: RoutingArguments)
  =>
    _pending_message_store.add(state_name, key, routing_args)
    _state_step_creator.report_unknown_key(this, state_name, key)

  be remove_route_to_consumer(id: StepId, c: Consumer) =>
    if _outputs.contains(id) then
      ifdef debug then
        Invariant(_routes.contains(c))
      end
      try
        _outputs.remove(id)?
        _remove_route_if_no_output(c)
      end
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
      let outdated_route = _routes.remove(c)?._2
      ifdef "resilience" then
        _acker_x.remove_route(outdated_route)
      end
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
        let boundary = builder.build_and_initialize(_step_id_gen(),
          target_worker_name, _layout_initializer)
        _outgoing_boundaries(target_worker_name) = boundary
        _router_registry.register_disposable(boundary)
        let new_route = _route_builder(_source_id, this, boundary,
          _metrics_reporter)
        _acker_x.add_route(new_route)
        _routes(boundary) = new_route
      end
    end
    _notify.update_boundaries(_outgoing_boundaries)

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
    end
    _notify.update_boundaries(_outgoing_boundaries)

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

  //////////////
  // ORIGIN (resilience)
  be request_ack() =>
    ifdef "trace" then
      @printf[I32]("request_ack in %s\n".cstring(), _name.cstring())
    end
    for route in _routes.values() do
      route.request_ack()
    end

  be log_replay_finished()
  =>
    // now that log replay is finished, we are no longer "recovering"
    _recovering = false

    // try and unmute if downstreams are already unmuted
    if _muted_downstream.size() == 0 then
      _unmute()
    end

  be replay_log_entry(uid: U128, frac_ids: FractionalMessageId,
    statechange_id: U64, payload: ByteSeq)
  =>
    _rb.append(payload)
    _last_processed_offset = try _rb.i64_le()?
                             else Fail(); _last_processed_offset end

    ifdef "trace" then
      @printf[I32](("replaying log entry on recovery with last processed" +
        " offset: %lld in %s\n").cstring(), _last_processed_offset,
        _name.cstring())
    end

  be initialize_seq_id_on_recovery(seq_id: SeqId) =>
    ifdef "trace" then
      @printf[I32](("initializing sequence id on recovery: " + seq_id.string() +
        " in %s\n").cstring(), _name.cstring())
    end
    // update to use correct seq_id for recovery
    _seq_id = seq_id

  fun ref _acker(): Acker =>
    _acker_x

  fun ref flush(low_watermark: U64) =>
    ifdef "trace" then
      @printf[I32]("flushing at and below: %llu in %s\n".cstring(),
        low_watermark, _name.cstring())
    end

    (_, let offset) = try _map_seq_id_offset.remove(low_watermark)?
                      else Fail(); (0, -1) end

    // remove all other lower seq_ids that we're tracking offsets for
    for s in Range[U64](_last_flushed_seq_id, low_watermark) do
      if _map_seq_id_offset.contains(s) then
        try _map_seq_id_offset.remove(s)? else Fail() end
      end
    end

    _wb.i64_le(offset)
    let payload = _wb.done()

    // store offset
    _event_log.queue_log_entry(_source_id, 0, None, 0, low_watermark,
      consume payload)

    // store low watermark so it is properly replayed
    _event_log.flush_buffer(_source_id, low_watermark)

    _last_flushed_seq_id = low_watermark
    _last_flushed_offset = offset


  //////////////
  // SNAPSHOTS
  //////////////
  be initiate_snapshot_barrier(snapshot_id: SnapshotId) =>
    // TODO: Eventually we might need to snapshot information about the
    // source here before sending down the barrier.
    for (o_id, o) in _outputs.pairs() do
      match o
      | let ob: OutgoingBoundary =>
        ob.forward_snapshot_barrier(o_id, _source_id, snapshot_id)
      else
        o.receive_snapshot_barrier(_source_id, this, snapshot_id)
      end
    end

  be receive_snapshot_barrier(step_id: StepId, sr: SnapshotRequester,
    snapshot_id: SnapshotId)
  =>
    // Sources have no inputs on which to receive barriers
    Fail()

  be remote_snapshot_state() =>
    ifdef "trace" then
      @printf[I32]("snapshot_state in %s\n".cstring(), _name.cstring())
    end
    _wb.i64_le(_last_flushed_offset)
    let payload = _wb.done()
    _event_log.snapshot_state(_source_id, 0, 0, _last_flushed_seq_id,
      consume payload)

  fun ref snapshot_state(snapshot_id: SnapshotId) =>
    // !@
    None

  fun ref snapshot_complete() =>
    // !@
    None

  be log_flushed(low_watermark: SeqId) =>
    ifdef "trace" then
      @printf[I32]("log_flushed for: %llu in %s\n".cstring(), low_watermark,
        _name.cstring())
    end
    _acker().flushed(low_watermark)

  fun ref bookkeeping(o_route_id: RouteId, o_seq_id: SeqId) =>
    ifdef "trace" then
      @printf[I32]("Bookkeeping called for route %llu in %s\n".cstring(),
        o_route_id, _name.cstring())
    end
    ifdef "resilience" then
      _acker().sent(o_route_id, o_seq_id)
    end

  be update_watermark(route_id: RouteId, seq_id: SeqId) =>
    ifdef debug then
      @printf[I32]("%s received update_watermark\n".cstring(), _name.cstring())
    end
    _update_watermark(route_id, seq_id)

  fun ref _update_watermark(route_id: RouteId, seq_id: SeqId) =>
    ifdef "trace" then
      @printf[I32]((
      "Update watermark called with " +
      "route_id: " + route_id.string() +
      "\tseq_id: " + seq_id.string() + " in %s\n\n").cstring(), _name.cstring())
    end

    _acker().ack_received(this, route_id, seq_id)

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

  be request_in_flight_ack(upstream_request_id: RequestId, requester_id: StepId,
    requester: InFlightAckRequester)
  =>
    _in_flight_ack_waiter.add_new_request(requester_id, upstream_request_id,
      requester)

    if _routes.size() > 0 then
      for route in _routes.values() do
        let request_id = _in_flight_ack_waiter.add_consumer_request(
          requester_id)
        route.request_in_flight_ack(request_id, _source_id, this)
      end
    else
      requester.try_finish_in_flight_request_early(requester_id)
    end

  be request_in_flight_resume_ack(in_flight_resume_ack_id: InFlightResumeAckId,
    request_id: RequestId, requester_id: StepId,
    requester: InFlightAckRequester, leaving_workers: Array[String] val)
  =>
    if _in_flight_ack_waiter.request_in_flight_resume_ack(
      in_flight_resume_ack_id, request_id, requester_id, requester)
    then
      for route in _routes.values() do
        let new_request_id =
          _in_flight_ack_waiter.add_consumer_resume_request()
        route.request_in_flight_resume_ack(in_flight_resume_ack_id,
          new_request_id, _source_id, this, leaving_workers)
      end
    end


  be try_finish_in_flight_request_early(requester_id: StepId) =>
    _in_flight_ack_waiter.try_finish_in_flight_request_early(requester_id)

  be receive_in_flight_ack(request_id: RequestId) =>
    _in_flight_ack_waiter.unmark_consumer_request(request_id)

  be receive_in_flight_resume_ack(request_id: RequestId) =>
    _in_flight_ack_waiter.unmark_consumer_resume_request(request_id)

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

  be dispose() =>
    @printf[I32]("Shutting down %s\n".cstring(), _name.cstring())

    for b in _outgoing_boundaries.values() do
      b.dispose()
    end

    _kc.dispose()
