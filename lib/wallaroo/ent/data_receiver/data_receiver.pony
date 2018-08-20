/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "collections"
use "net"
use "time"
use "wallaroo/core/common"
use "wallaroo/core/data_channel"
use "wallaroo/core/invariant"
use "wallaroo/core/messages"
use "wallaroo/core/routing"
use "wallaroo/core/topology"
use "wallaroo/ent/barrier"
use "wallaroo/ent/network"
use "wallaroo/ent/recovery"
use "wallaroo/ent/snapshot"
use "wallaroo_labs/mort"


actor DataReceiver is (Producer & Rerouter)
  let _id: RoutingId
  let _auth: AmbientAuth
  let _worker_name: String
  var _sender_name: String
  let _state_step_creator: StateStepCreator
  var _sender_step_id: RoutingId = 0
  var _router: DataRouter
  var _last_id_seen: SeqId = 0
  var _last_id_acked: SeqId = 0
  var _connected: Bool = false
  var _reconnecting: Bool = false
  var _ack_counter: USize = 0

  var _last_request: USize = 0

  let _pending_message_store: PendingMessageStore =
    _pending_message_store.create()

  // (input_id, output_id, barrier)
  let _pending_barriers: Array[(RoutingId, RoutingId, BarrierToken)] = _pending_barriers.create()

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

  // A special RoutingId that indicates that a barrier or register_producer
  // request needs to be forwarded to all known state steps on this worker.
  let _state_routing_id: RoutingId
  // Keeps track of all upstreams that produce messages for state steps.
  let _state_partition_producers: SetIs[RoutingId] =
    _state_partition_producers.create()

  var _phase: _DataReceiverPhase = _DataReceiverNotProcessingPhase

  new create(auth: AmbientAuth, id: RoutingId, worker_name: String,
    sender_name: String, data_router: DataRouter,
    state_step_creator: StateStepCreator, initialized: Bool = false)
  =>
    _id = id
    _auth = auth
    _worker_name = worker_name
    _sender_name = sender_name
    _state_step_creator = state_step_creator
    _state_routing_id = WorkerStateRoutingId(_worker_name)
    _router = data_router
    //!@
    // if initialized then
      _phase = _NormalDataReceiverPhase(this)
    // end

  fun router(): DataRouter =>
    _router

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

    // Reregister all state partition producers in case there were more
    // keys added to this worker.
    for input_id in _state_partition_producers.values() do
      _router.register_producer(input_id, _state_routing_id, this)
    end

    _pending_message_store.process_known_keys(this, _router)
    if not _pending_message_store.has_pending() then
      let resend = _phase.flush()
      _phase = _NormalDataReceiverPhase(this)
      for m in resend.values() do
        match m
        | let qdm: _QueuedDeliveryMessage =>
          qdm.process_message(this)
        | let qrdm: _QueuedReplayableDeliveryMessage =>
          qrdm.replay_process_message(this)
        | let pb: _QueuedBarrier =>
          _forward_barrier(pb._1, pb._2, pb._3)
        end
      end
    end

  be remove_route_to_consumer(id: RoutingId, c: Consumer) =>
    // DataReceiver doesn't have its own routes
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
  be received(d: DeliveryMsg, pipeline_time_spent: U64, seq_id: SeqId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    process_message(d, pipeline_time_spent, seq_id, latest_ts,
      metrics_id, worker_ingress_ts)

  fun ref process_message(d: DeliveryMsg, pipeline_time_spent: U64,
    seq_id: SeqId, latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    _phase.deliver(d, pipeline_time_spent, seq_id, latest_ts, metrics_id,
      worker_ingress_ts)

  fun ref deliver(d: DeliveryMsg, pipeline_time_spent: U64, seq_id: SeqId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    ifdef "trace" then
      @printf[I32]("Rcvd pipeline msg at DataReceiver\n".cstring())
    end
    if seq_id > _last_id_seen then
      _ack_counter = _ack_counter + 1
      _last_id_seen = seq_id
      _router.route(d, pipeline_time_spent, _id, this, seq_id, latest_ts,
        metrics_id, worker_ingress_ts)
      _maybe_ack()
    end

  be replay_received(r: ReplayableDeliveryMsg, pipeline_time_spent: U64,
    seq_id: SeqId, latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    replay_process_message(r, pipeline_time_spent, seq_id, latest_ts,
      metrics_id, worker_ingress_ts)

  fun ref replay_process_message(r: ReplayableDeliveryMsg,
    pipeline_time_spent: U64, seq_id: SeqId, latest_ts: U64, metrics_id: U16,
    worker_ingress_ts: U64)
  =>
    _phase.replay_deliver(r, pipeline_time_spent, seq_id, latest_ts,
      metrics_id, worker_ingress_ts)

  fun ref replay_deliver(r: ReplayableDeliveryMsg, pipeline_time_spent: U64,
    seq_id: SeqId, latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    if seq_id > _last_id_seen then
      _last_id_seen = seq_id
      _router.replay_route(r, pipeline_time_spent, _id, this, seq_id,
        latest_ts, metrics_id, worker_ingress_ts)
    end

  fun ref unknown_key(state_name: String, key: Key,
    routing_args: RoutingArguments)
  =>
    _pending_message_store.add(state_name, key, routing_args)
    _state_step_creator.report_unknown_key(this, state_name, key)

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

    //!@ Don't think we need this anymore
  // be start_replay_processing() =>
    //!@
    // _processing_phase = _DataReceiverAcceptingReplaysPhase(this)
    // If we've already received a DataConnect, then send ack
    // match _latest_conn
    // | let conn: DataChannel =>
    //   _ack_data_connect()
    // end

  be start_normal_message_processing() =>
    _phase = _NormalDataReceiverPhase(this)
    _inform_boundary_to_send_normal_messages()

  be data_connect(sender_step_id: RoutingId, conn: DataChannel) =>
    _sender_step_id = sender_step_id
    _latest_conn = conn
    _phase.data_connect()

    //!@
  // fun _ack_data_connect() =>
  //   try
  //     let ack_msg = ChannelMsgEncoder.ack_data_connect(_last_id_seen, _auth)?
  //     _write_on_conn(ack_msg)
  //   else
  //     Fail()
  //   end

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
    if output_id == _state_routing_id then
      _state_partition_producers.set(input_id)
    end
    _router.register_producer(input_id, output_id, this)
    _boundary_edges.set(BoundaryEdge(input_id, output_id))

  fun ref queue_register_producer(input_id: RoutingId, output_id: RoutingId) =>
    _queued_register_producers.push((input_id, output_id))

  fun ref queue_unregister_producer(input_id: RoutingId, output_id: RoutingId)
  =>
    _queued_unregister_producers.push((input_id, output_id))

  be unregister_producer(input_id: RoutingId, output_id: RoutingId) =>
    if output_id == _state_routing_id then
      _state_partition_producers.unset(input_id)
    end
    _router.unregister_producer(input_id, output_id, this)
    _boundary_edges.unset(BoundaryEdge(input_id, output_id))

  /////////////////////////////////////////////////////////////////////////////
  // BARRIER
  /////////////////////////////////////////////////////////////////////////////
  be forward_barrier(target_step_id: RoutingId, origin_step_id: RoutingId,
    barrier_token: BarrierToken)
  =>
    match barrier_token
    | let srt: SnapshotRollbackBarrierToken =>
      _pending_message_store.clear()
      _pending_barriers.clear()
    end

    _forward_barrier(target_step_id, origin_step_id, barrier_token)

  fun ref _forward_barrier(target_step_id: RoutingId,
    origin_step_id: RoutingId, barrier_token: BarrierToken)
  =>
    _phase.forward_barrier(target_step_id, origin_step_id, barrier_token)

  fun ref send_barrier(target_step_id: RoutingId, origin_step_id: RoutingId,
    barrier_token: BarrierToken)
  =>
    if not _pending_message_store.has_pending() then
      _router.forward_barrier(target_step_id, origin_step_id, this,
        barrier_token)
    else
      _pending_barriers.push((target_step_id, origin_step_id, barrier_token))
      match _phase
      | let qdr: _QueuingDataReceiverPhase => None
      else
        _phase = _QueuingDataReceiverPhase(this)
      end
    end

  fun ref barrier_complete() =>
    // The DataReceiver only forwards the barrier at this point, so this
    // should never be called.
    Fail()

  /////////////////////////////////////////////////////////////////////////////
  // SNAPSHOTS
  /////////////////////////////////////////////////////////////////////////////
  fun ref snapshot_state(snapshot_id: SnapshotId) =>
    """
    DataReceivers don't currently write out any data as part of the snapshot.
    """
    None

  be rollback(payload: ByteSeq val, event_log: EventLog) =>
    """
    There is nothing for a DataReceiver to rollback to.
    """
    None

  /////////////////////////////////////////////////////////////////////////////
  // PRODUCER
  /////////////////////////////////////////////////////////////////////////////
  fun ref route_to(c: Consumer): (Route | None) =>
    None

  fun ref next_sequence_id(): SeqId =>
    0

  fun ref current_sequence_id(): SeqId =>
    0
