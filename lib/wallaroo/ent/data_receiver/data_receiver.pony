/*

Copyright 2018 The Wallaroo Authors.

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

use "collections"
use "net"
use "promises"
use "time"
use "wallaroo/core/common"
use "wallaroo/core/data_channel"
use "wallaroo/core/invariant"
use "wallaroo/core/messages"
use "wallaroo/core/metrics"
use "wallaroo/core/routing"
use "wallaroo/core/topology"
use "wallaroo/ent/barrier"
use "wallaroo/ent/network"
use "wallaroo/ent/recovery"
use "wallaroo/ent/checkpoint"
use "wallaroo_labs/mort"


actor DataReceiver is Producer
  let _id: RoutingId
  let _auth: AmbientAuth
  let _worker_name: String
  var _sender_name: String
  var _sender_step_id: RoutingId = 0
  var _router: DataRouter
  var _last_id_seen: SeqId = 0
  var _last_id_acked: SeqId = 0
  var _connected: Bool = false
  var _reconnecting: Bool = false
  var _ack_counter: USize = 0

  var _last_request: USize = 0

  let _metrics_reporter: MetricsReporter

  // TODO: Test replacing this with state machine class
  // to avoid matching on every ack
  var _latest_conn: (DataChannel | None) = None

  // Keep track of point to point connections over the boundary
  let _boundary_edges: Set[BoundaryEdge] = _boundary_edges.create()

  // Keep track of register_producer calls that we weren't ready to forward
  let _queued_register_producers: Array[(RoutingId, RoutingId)] =
    _queued_register_producers.create()
  let _queued_unregister_producers: Array[(RoutingId, RoutingId)] =
    _queued_register_producers.create()

  // Keeps track of all upstreams that produce messages for state steps.
  // The map is from state routing id to a set of upstream ids.
  let _step_group_producers: Map[RoutingId, SetIs[RoutingId]] =
    _step_group_producers.create()

  // Checkpoint
  var _next_checkpoint_id: CheckpointId = 1

  var _phase: _DataReceiverPhase = _DataReceiverNotProcessingPhase

  new create(auth: AmbientAuth, id: RoutingId, worker_name: String,
    sender_name: String, data_router: DataRouter,
    metrics_reporter': MetricsReporter iso,
    initialized: Bool = false, is_recovering: Bool = false)
  =>
    _id = id
    _auth = auth
    _worker_name = worker_name
    _sender_name = sender_name
    _router = data_router
    _metrics_reporter = consume metrics_reporter'
    if is_recovering then
      _phase = _RecoveringDataReceiverPhase(this)
    else
      _phase = _NormalDataReceiverPhase(this)
    end

  fun ref metrics_reporter(): MetricsReporter =>
    _metrics_reporter

  be update_router(router': DataRouter) =>
    _router = router'

    // If we have pending register_producer calls, then try to process them now
    var retries = Array[(RoutingId, RoutingId)]
    for r in _queued_register_producers.values() do
      retries.push(r)
    end
    _queued_register_producers.clear()
    for (input, output) in retries.values() do
      _router.register_producer(input, output, this)
    end
    // If we have pending unregister_producer calls, then try to process them
    // now
    retries = Array[(RoutingId, RoutingId)]
    for r in _queued_unregister_producers.values() do
      retries.push(r)
    end
    _queued_unregister_producers.clear()
    for (input, output) in retries.values() do
      _router.unregister_producer(input, output, this)
    end

    // Reregister all step group producers in case there were more
    // keys added to this worker.
    for (r_id, producer_ids) in _step_group_producers.pairs() do
      for producer_id in producer_ids.values() do
        _router.register_producer(producer_id, r_id, this)
      end
    end

    _phase = _NormalDataReceiverPhase(this)

  be remove_route_to_consumer(id: RoutingId, c: Consumer) =>
    // DataReceiver doesn't have its own routes
    None

  be register_downstream() =>
    // DataReceiver doesn't register directly with its downstreams
    None

  be report_status(code: ReportStatusCode) =>
    _router.report_status(code)

  be dispose() =>
    @printf[I32]("Shutting down DataReceiver\n".cstring())

    for edge in _boundary_edges.values() do
      _router.unregister_producer(edge.input_id, edge.output_id, this)
    end
    match _latest_conn
    | let conn: DataChannel =>
      try
        let msg = ChannelMsgEncoder.data_disconnect(_auth)?
        conn.writev(msg)
      else
        Fail()
      end
      conn.dispose()
    end

  /////////////////////////////////////////////////////////////////////////////
  // MESSAGES
  /////////////////////////////////////////////////////////////////////////////
  be received(d: DeliveryMsg, producer_id: RoutingId, pipeline_time_spent: U64,
    seq_id: SeqId, latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    process_message(d, producer_id, pipeline_time_spent, seq_id, latest_ts,
      metrics_id, worker_ingress_ts)

  fun ref process_message(d: DeliveryMsg, producer_id: RoutingId,
    pipeline_time_spent: U64, seq_id: SeqId, latest_ts: U64, metrics_id: U16,
    worker_ingress_ts: U64)
  =>
    _phase.deliver(d, producer_id, pipeline_time_spent, seq_id, latest_ts,
      metrics_id, worker_ingress_ts)

  fun ref deliver(d: DeliveryMsg, producer_id: RoutingId,
    pipeline_time_spent: U64, seq_id: SeqId, latest_ts: U64, metrics_id: U16,
    worker_ingress_ts: U64)
  =>
    ifdef "trace" then
      @printf[I32]("Rcvd pipeline msg at DataReceiver\n".cstring())
    end
    if seq_id > _last_id_seen then
      ifdef "resilience" and debug then
        Invariant((seq_id - _last_id_seen) == 1)
      end
      _ack_counter = _ack_counter + 1
      _last_id_seen = seq_id
      _router.route(d, pipeline_time_spent, producer_id, this, seq_id,
        latest_ts, metrics_id, worker_ingress_ts)
      _maybe_ack()
    end

  fun ref _maybe_ack() =>
    if (_ack_counter % 512) == 0 then
      _ack_latest()
    end

  fun ref _ack_latest() =>
    try
      if _last_id_seen > _last_id_acked then
        ifdef "trace" then
          @printf[I32]("DataReceiver acking seq_id %lu\n".cstring(),
            _last_id_seen)
        end
        _last_id_acked = _last_id_seen
        let ack_msg = ChannelMsgEncoder.ack_data_received(_worker_name,
          _sender_step_id, _last_id_seen, _auth)?
        _write_on_conn(ack_msg)
      end
    else
      @printf[I32]("Error creating ack data received message\n".cstring())
    end

  /////////////////////////////////////////////////////////////////////////////
  // CONNECTION
  /////////////////////////////////////////////////////////////////////////////
  be start_normal_message_processing() =>
    _phase = _NormalDataReceiverPhase(this)
    _inform_boundary_to_send_normal_messages()

  be data_connect(sender_step_id: RoutingId, highest_seq_id: SeqId,
    conn: DataChannel)
  =>
    _sender_step_id = sender_step_id
    _latest_conn = conn

    // TODO: In a recovery scenario, an upstream boundary clears its queue and
    // starts from an earlier checkpoint. If the upstream is on a recovering
    // worker, then it will start its seq ids again from 0. These seq ids only
    // serve the purpose of coordinating point to point communication over
    // the boundary connection, so this works, though it could stand to be
    // improved.
    if highest_seq_id < _last_id_seen then
      _last_id_seen = highest_seq_id
    end

    _phase.data_connect(highest_seq_id)

  fun ref _update_last_id_seen(seq_id: SeqId, on_increase: Bool = false) =>
    if on_increase then
      if seq_id > _last_id_seen then
        _last_id_seen = seq_id
      end
    else
      _last_id_seen = seq_id
    end

  fun _inform_boundary_to_send_normal_messages() =>
    try
      let start_msg = ChannelMsgEncoder.start_normal_data_sending(
        _last_id_seen, _auth)?
      _write_on_conn(start_msg)
    else
      Fail()
    end

  fun _write_on_conn(data: Array[ByteSeq] val) =>
    match _latest_conn
    | let conn: DataChannel =>
      conn.writev(data)
    else
      Fail()
    end

  be mute(c: Consumer) =>
    match _latest_conn
    | let conn: DataChannel =>
      conn.mute(c)
    end

  be unmute(c: Consumer) =>
    match _latest_conn
    | let conn: DataChannel =>
      conn.unmute(c)
    end

  /////////////////////////////////////////////////////////////////////////////
  // REGISTER PRODUCERS
  /////////////////////////////////////////////////////////////////////////////
  be register_producer(input_id: RoutingId, output_id: RoutingId) =>
    if _step_group_producers.contains(output_id) then
      try
        _step_group_producers.insert_if_absent(output_id,
          SetIs[RoutingId])?.set(input_id)
      else
        Fail()
      end
    end
    _router.register_producer(input_id, output_id, this)
    _boundary_edges.set(BoundaryEdge(input_id, output_id))

  fun ref queue_register_producer(input_id: RoutingId, output_id: RoutingId) =>
    _queued_register_producers.push((input_id, output_id))

  fun ref queue_unregister_producer(input_id: RoutingId, output_id: RoutingId)
  =>
    _queued_unregister_producers.push((input_id, output_id))

  be unregister_producer(input_id: RoutingId, output_id: RoutingId) =>
    if _step_group_producers.contains(output_id) then
      try
        let set = _step_group_producers(output_id)?
        set.unset(input_id)
      else
        Unreachable()
      end
    end
    _router.unregister_producer(input_id, output_id, this)
    _boundary_edges.unset(BoundaryEdge(input_id, output_id))

  /////////////////////////////////////////////////////////////////////////////
  // BARRIER
  /////////////////////////////////////////////////////////////////////////////
  be forward_barrier(target_step_id: RoutingId, origin_step_id: RoutingId,
    barrier_token: BarrierToken, seq_id: SeqId)
  =>
    ifdef "checkpoint_trace" then
      @printf[I32]("DataReceiver: forward_barrier to %s -> seq id %s, last_seen: %s\n".cstring(),
        target_step_id.string().cstring(), seq_id.string().cstring(),
        _last_id_seen.string().cstring())
    end
    if seq_id > _last_id_seen then
      match barrier_token
      // !TODO!: This isn't good enough. We need to ensure that we've been
      // overriden to make this change back from recovery phase. As it stands,
      // this introduces a race condition if we receive an old resume token in
      // flight before we recovered.
      | let srt: CheckpointRollbackResumeBarrierToken =>
        _phase = _NormalDataReceiverPhase(this)
      end

      _forward_barrier(target_step_id, origin_step_id, barrier_token, seq_id)
    end

  fun ref _forward_barrier(target_step_id: RoutingId,
    origin_step_id: RoutingId, barrier_token: BarrierToken, seq_id: SeqId)
  =>
    _phase.forward_barrier(target_step_id, origin_step_id, barrier_token, seq_id)

  fun ref send_barrier(target_step_id: RoutingId, origin_step_id: RoutingId,
    barrier_token: BarrierToken, seq_id: SeqId)
  =>
    if seq_id > _last_id_seen then
      _ack_counter = _ack_counter + 1
      _last_id_seen = seq_id
      match barrier_token
      | let sbt: CheckpointBarrierToken =>
        checkpoint_state(sbt.id)
      end
      _router.forward_barrier(target_step_id, origin_step_id, this,
        barrier_token)
    end

  fun ref barrier_complete() =>
    // The DataReceiver only forwards the barrier at this point, so this
    // should never be called.
    Fail()

  be recovery_complete() =>
    _phase = _NormalDataReceiverPhase(this)

  /////////////////////////////////////////////////////////////////////////////
  // CHECKPOINTS
  /////////////////////////////////////////////////////////////////////////////
  fun ref checkpoint_state(checkpoint_id: CheckpointId) =>
    """
    DataReceivers don't currently write out any data as part of the checkpoint.
    """
    _next_checkpoint_id = checkpoint_id + 1

  be prepare_for_rollback() =>
    """
    There is nothing for a DataReceiver to rollback to.
    """
    None

  be rollback(payload: ByteSeq val, event_log: EventLog,
    checkpoint_id: CheckpointId)
  =>
    """
    There is nothing for a DataReceiver to rollback to.
    """
    _next_checkpoint_id = checkpoint_id + 1
    event_log.ack_rollback(_id)

  /////////////////////////////////////////////////////////////////////////////
  // PRODUCER
  /////////////////////////////////////////////////////////////////////////////
  fun ref has_route_to(c: Consumer): Bool =>
    false

  fun ref next_sequence_id(): SeqId =>
    0

  fun ref current_sequence_id(): SeqId =>
    0

  be dispose_with_promise(promise: Promise[None]) =>
    None
