/*

Copyright 2019 The Wallaroo Authors.

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
use "net"
use "promises"
use "time"
use "wallaroo/core/barrier"
use "wallaroo/core/checkpoint"
use "wallaroo/core/common"
use "wallaroo/core/initialization"
use "wallaroo/core/invariant"
use "wallaroo/core/messages"
use "wallaroo/core/metrics"
use "wallaroo/core/network"
use "wallaroo/core/recovery"
use "wallaroo/core/routing"
use "wallaroo/core/spike"
use "wallaroo/core/topology"
use "wallaroo_labs/bytes"
use "wallaroo_labs/mort"
use "wallaroo_labs/time"


class val OutgoingBoundaryBuilder
  let auth: AmbientAuth
  let worker_name: String
  let reporter: MetricsReporter val
  let host: String
  let service: String
  let spike_config_none: (SpikeConfig | None)

  new val create(auth': AmbientAuth, name: String, r: MetricsReporter iso,
    h: String, s: String, spike_config: (SpikeConfig | None) = None)
  =>
    auth = auth'
    worker_name = name
    reporter = consume r
    host = h
    service = s
    spike_config_none = spike_config

  fun apply(routing_id: RoutingId, target_worker: String): OutgoingBoundary =>
    let boundary = OutgoingBoundary(auth, worker_name, target_worker,
      reporter.clone(), host, service where spike_config = spike_config_none)
    boundary.register_routing_id(routing_id)
    boundary

  fun build_and_initialize(routing_id: RoutingId, target_worker: String,
    layout_initializer: LayoutInitializer): OutgoingBoundary
  =>
    """
    Called when creating a boundary post cluster initialization
    """
    let boundary = OutgoingBoundary(auth, worker_name, target_worker,
      reporter.clone(), host, service where spike_config = spike_config_none)
    boundary.register_routing_id(routing_id)
    boundary.quick_initialize(layout_initializer)
    boundary

  fun val clone_with_new_service(host': String, service': String):
    OutgoingBoundaryBuilder val
  =>
    let r = reporter.clone()
    OutgoingBoundaryBuilder(auth, worker_name, consume r, host', service',
      spike_config_none)

actor OutgoingBoundary is (Consumer & TCPActor)
  // Steplike
  let _wb: Writer = Writer
  let _metrics_reporter: MetricsReporter

  // Lifecycle
  var _initializer: (LayoutInitializer | None) = None
  var _reported_initialized: Bool = false
  var _reported_ready_to_work: Bool = false

  // Consumer
  var _registered_producers: RegisteredProducers =
    _registered_producers.create()
  var _upstreams: SetIs[Producer] = _upstreams.create()

  var _mute_outstanding: Bool = false

  // Connection, Acking and Replay
  var _connection_initialized: Bool = false
  var _replaying: Bool = false
  let _auth: AmbientAuth
  let _worker_name: WorkerName
  let _target_worker: WorkerName
  var _routing_id: RoutingId = 0
  var _host: String
  var _service: String
  let _from: String
  // Queuing all messages in case we need to resend them
  let _queue: Array[Array[ByteSeq] val] = _queue.create()
  // Queuing messages we haven't sent yet (these will also be queued in _queue,
  // so _unsent is a subset of _queue).
  let _unsent: Array[Array[ByteSeq] val] = _unsent.create()
  var _lowest_queue_id: SeqId = 0
  // TODO: this should go away and TerminusRoute entirely takes
  // over seq_id generation whether there is resilience or not.
  var seq_id: SeqId = 0

  // Reconnect
  var _initial_reconnect_pause: U64 = 500_000_000
  var _reconnect_pause: U64 = _initial_reconnect_pause
  let _timers: Timers = Timers

  var _pending_immediate_ack_promise:
    (Promise[OutgoingBoundary] | None) = None

  // TCP
  var _tcp_handler: TestableTCPHandler[OutgoingBoundary ref] =
    EmptyTCPHandler[OutgoingBoundary ref]
  let _notify: TestableBoundaryNotify[OutgoingBoundary ref]

  new create(auth: AmbientAuth, worker_name: String, target_worker: String,
    metrics_reporter: MetricsReporter iso, host: String, service: String,
    from: String = "", init_size: USize = 64, max_size: USize = 65_536,
    spike_config:(SpikeConfig | None) = None)
  =>
    """
    Connect via IPv4 or IPv6. If `from` is a non-empty string, the connection
    will be made from the specified interface.
    """
    _auth = auth
    ifdef "spike" then
      match spike_config
      | let sc: SpikeConfig =>
        var notify = recover iso BoundaryNotify(_auth, _routing_id,
          worker_name, target_worker, host, service) end
        _notify = SpikeBoundaryNotifyWrapper(consume notify, sc)
      else
        _notify = BoundaryNotify(_auth, _routing_id, worker_name,
          target_worker, host, service)
      end
    else
      _notify = BoundaryNotify(_auth, _routing_id, worker_name,
        target_worker, host, service)
    end

    _worker_name = worker_name
    _target_worker = target_worker
    _host = host
    _service = service
    _from = from
    _metrics_reporter = consume metrics_reporter
    _tcp_handler = TCPHandler[OutgoingBoundary ref](this, _notify,
      init_size, max_size)

  //
  // Application startup lifecycle event
  //

  be application_begin_reporting(initializer: LocalTopologyInitializer) =>
    _initializer = initializer
    initializer.report_created(this)

  be application_created(initializer: LocalTopologyInitializer) =>
    _tcp_handler.connect(_host, _service, _from)
    @printf[I32](("Connecting OutgoingBoundary to " + _host + ":" + _service +
      "\n").cstring())

  be application_initialized(initializer: LocalTopologyInitializer) =>
    try
      if _routing_id == 0 then
        Fail()
      end

      let connect_msg = ChannelMsgEncoder.data_connect(_worker_name,
        _routing_id, seq_id, _auth)?
      _tcp_handler.writev(connect_msg)
    else
      Fail()
    end

  be application_ready_to_work(initializer: LocalTopologyInitializer) =>
    None

  be cluster_ready_to_work(initializer: LocalTopologyInitializer) =>
    None

  be quick_initialize(initializer: LayoutInitializer) =>
    """
    Called when initializing as part of a new worker joining a running cluster.
    """
    if not _reported_initialized then
      try
        _initializer = initializer
        _reported_initialized = true
        _reported_ready_to_work = true
        _tcp_handler.connect(_host, _service, _from)

        @printf[I32](("Connecting OutgoingBoundary to " + _host + ":" +
          _service + "\n").cstring())

        if _routing_id == 0 then
          Fail()
        end

        let connect_msg = ChannelMsgEncoder.data_connect(_worker_name,
          _routing_id, seq_id, _auth)?
        _tcp_handler.writev(connect_msg)
      else
        Fail()
      end
    end

  be ack_immediately(p: Promise[OutgoingBoundary]) =>
    _pending_immediate_ack_promise = p
    try
      let msg = ChannelMsgEncoder.data_receiver_ack_immediately(_auth)?

      _tcp_handler.writev(msg)
    else
      Fail()
    end

  fun ref receive_immediate_ack() =>
    match _pending_immediate_ack_promise
    | let p: Promise[OutgoingBoundary] => p(this)
    else
      @printf[I32](("OutgoingBoundary: Received immediate ack but " +
        "had no corresponding pending promise.\n").cstring())
    end

  be reconnect() =>
    _reconnect()

  fun ref _reconnect() =>
    if not _tcp_handler.is_connected() then
      @printf[I32](("RE-Connecting OutgoingBoundary to " + _host + ":" +
        _service + "\n").cstring())

      // set replaying to true since we might need to replay to
      // downstream before resuming
      _replaying = true
      _tcp_handler.connect(_host, _service, _from)
    end

  be migrate_key(routing_id: RoutingId, step_group: RoutingId, key: Key,
    checkpoint_id: CheckpointId, state: ByteSeq val)
  =>
    try
      let outgoing_msg = ChannelMsgEncoder.migrate_key(step_group, key,
        checkpoint_id, state, _worker_name, _auth)?
      _tcp_handler.writev(outgoing_msg)
    else
      Fail()
    end

  be send_migration_batch_complete() =>
    try
      let migration_batch_complete_msg =
        ChannelMsgEncoder.migration_batch_complete(_worker_name, _auth)?
      _tcp_handler.writev(migration_batch_complete_msg)
    else
      Fail()
    end

  be register_routing_id(routing_id: RoutingId) =>
    _routing_id = routing_id
    _notify.register_routing_id(routing_id)

    ifdef "identify_routing_ids" then
      @printf[I32]("===OutgoingBoundary %s routing_id registered===\n"
        .cstring(), _routing_id.string().cstring())
    end

  be run[D: Any val](metric_name: String, pipeline_time_spent: U64, data: D,
    key: Key, event_ts: U64, watermark_ts: U64, i_producer_id: RoutingId,
    i_producer: Producer, msg_uid: MsgId, frac_ids: FractionalMessageId,
    i_seq_id: SeqId, latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    // run() should never be called on an OutgoingBoundary
    Fail()

  fun ref process_message[D: Any val](metric_name: String,
    pipeline_time_spent: U64, data: D, key: Key, event_ts: U64,
    watermark_ts: U64, i_producer_id: RoutingId, i_producer: Producer,
    msg_uid: MsgId, frac_ids: FractionalMessageId, i_seq_id: SeqId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    // process_message() should never be called on an OutgoingBoundary
    Fail()

  // TODO: open question: how do we reconnect if our external system goes away?
  be forward(delivery_msg: DeliveryMsg, pipeline_time_spent: U64,
    i_producer_id: RoutingId, i_producer: Producer, i_seq_id: SeqId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    let metric_name = delivery_msg.metric_name()
    // TODO: delete
    let msg_uid = delivery_msg.msg_uid()

    ifdef "trace" then
      @printf[I32]("Rcvd pipeline message at OutgoingBoundary\n".cstring())
    end

    let my_latest_ts = ifdef "detailed-metrics" then
        WallClock.nanoseconds()
      else
        latest_ts
      end

    let new_metrics_id = ifdef "detailed-metrics" then
        _metrics_reporter.step_metric(metric_name,
          "Before receive at boundary", metrics_id, latest_ts, my_latest_ts)
        metrics_id + 2
      else
        metrics_id
      end

    try
      seq_id = seq_id + 1

      let outgoing_msg = ChannelMsgEncoder.data_channel(delivery_msg,
        i_producer_id,
        pipeline_time_spent + (WallClock.nanoseconds() - worker_ingress_ts),
        seq_id, _wb, _auth, WallClock.nanoseconds(),
        new_metrics_id, metric_name)?
      _add_to_upstream_backup(outgoing_msg)

      if _connection_initialized then
        _tcp_handler.writev(outgoing_msg)
      else
        _unsent.push(outgoing_msg)
      end

      let end_ts = WallClock.nanoseconds()

      ifdef "detailed-metrics" then
        _metrics_reporter.step_metric(metric_name,
          "Before sending to next worker", metrics_id + 1,
          my_latest_ts, end_ts)
      end

      _metrics_reporter.worker_metric(metric_name, end_ts - worker_ingress_ts)
    else
      Fail()
    end

    _maybe_mute_or_unmute_upstreams()

  fun ref receive_ack(acked_seq_id: SeqId) =>
    ifdef debug then
      Invariant(acked_seq_id > _lowest_queue_id)
    end

    ifdef "trace" then
      @printf[I32](
        "OutgoingBoundary: got ack from downstream worker\n".cstring())
    end

    let flush_count: USize = (acked_seq_id - _lowest_queue_id).usize()
    _queue.remove(0, flush_count)
    _maybe_mute_or_unmute_upstreams()
    _lowest_queue_id = _lowest_queue_id + flush_count.u64()

  fun ref receive_connect_ack(last_id_seen: SeqId) =>
    _replay_from(last_id_seen)

  fun ref start_normal_sending() =>
    if not _reported_ready_to_work then
      match _initializer
      | let li: LayoutInitializer =>
        li.report_ready_to_work(this)
        _reported_ready_to_work = true
      else
        Fail()
      end
    end
    _connection_initialized = true
    _replaying = false
    for msg in _unsent.values() do
      _tcp_handler.writev(msg)
    end
    _unsent.clear()
    _maybe_mute_or_unmute_upstreams()

  fun ref _replay_from(idx: SeqId) =>
    // In case the downstream has failed and recovered, resend producer
    // registrations.
    resend_producer_registrations()

    var cur_id = _lowest_queue_id
    for msg in _queue.values() do
      if cur_id >= idx then
        _tcp_handler.writev(msg)
      end
      cur_id = cur_id + 1
    end
    _unsent.clear()

  be update_router(router: Router) =>
    """
    No-op: OutgoingBoundary has no router
    """
    None

  be dispose() =>
    """
    Gracefully shuts down the outgoing boundary. Allows all pending writes
    to be sent but any writes that arrive after this will be
    silently discarded and not acknowleged.
    """
    @printf[I32]("Shutting down OutgoingBoundary\n".cstring())
    _unmute_upstreams()
    _timers.dispose()
    _tcp_handler.close()
    _notify.dispose()

  be request_ack() =>
    // TODO: How do we propagate this down?
    None

  be register_producer(id: RoutingId, producer: Producer) =>
    ifdef debug then
      Invariant(not _upstreams.contains(producer))
    end

    _upstreams.set(producer)

  be unregister_producer(id: RoutingId, producer: Producer) =>
    // TODO: Determine if we need this Invariant.
    // ifdef debug then
    //   Invariant(_upstreams.contains(producer))
    // end

    _upstreams.unset(producer)

  be forward_register_producer(source_id: RoutingId, target_id: RoutingId,
    producer: Producer)
  =>
    _forward_register_producer(source_id, target_id, producer)

  fun ref _forward_register_producer(source_id: RoutingId,
    target_id: RoutingId, producer: Producer)
  =>
    _registered_producers.register_producer(source_id, producer, target_id)
    try
      let msg = ChannelMsgEncoder.register_producer(_worker_name,
        source_id, target_id, _auth)?
      _tcp_handler.writev(msg)
    else
      Fail()
    end
    _upstreams.set(producer)

  be forward_unregister_producer(source_id: RoutingId, target_id: RoutingId,
    producer: Producer)
  =>
    _registered_producers.unregister_producer(source_id, producer, target_id)
    try
      let msg = ChannelMsgEncoder.unregister_producer(_worker_name,
        source_id, target_id, _auth)?
      _tcp_handler.writev(msg)
    else
      Fail()
    end
    _upstreams.unset(producer)

  fun ref resend_producer_registrations() =>
    for (producer_id, producer, target_id) in
      _registered_producers.registrations().values()
    do
      _forward_register_producer(producer_id, target_id, producer)
    end

  be report_status(code: ReportStatusCode) =>
    try
      _tcp_handler.writev(ChannelMsgEncoder.report_status(code, _auth)?)
    else
      Fail()
    end

  //////////////
  // BARRIER
  //////////////
  be forward_barrier(target_routing_id: RoutingId,
    origin_routing_id: RoutingId, barrier_token: BarrierToken)
  =>
    match barrier_token
    | let srt: CheckpointRollbackBarrierToken =>
      _queue.clear()
      _unsent.clear()
    end

    try
      // If our downstream DataReceiver requests we replay messages, we need
      // to ensure we replay the barrier as well and in the correct place.
      seq_id = seq_id + 1

      let msg = ChannelMsgEncoder.forward_barrier(target_routing_id,
        origin_routing_id, barrier_token, seq_id, _auth)?
      if _connection_initialized then
        _tcp_handler.writev(msg)
      else
        _unsent.push(msg)
      end
      _add_to_upstream_backup(msg)
    else
      Fail()
    end

  be receive_barrier(routing_id: RoutingId, producer: Producer,
    barrier_token: BarrierToken)
  =>
    // We only forward barriers at the boundary. The OutgoingBoundary
    // does not participate directly in the barrier protocol.
    Fail()

  fun ref barrier_complete(barrier_token: BarrierToken) =>
    // We only forward barriers at the boundary. The OutgoingBoundary
    // does not participate directly in the barrier protocol.
    Fail()

  ///////////////
  // CHECKPOINTS
  ///////////////
  fun ref checkpoint_state(checkpoint_id: CheckpointId) =>
    """
    Boundaries don't currently write out any data as part of the checkpoint.
    """
    None

  be prepare_for_rollback() =>
    _lowest_queue_id = _lowest_queue_id + _queue.size().u64()
    _queue.clear()
    _unsent.clear()
    _pending_immediate_ack_promise = None

  be rollback(payload: ByteSeq val, event_log: EventLog,
    checkpoint_id: CheckpointId)
  =>
    """
    There is nothing for a Boundary to rollback to.
    """
    None

  be update_worker_data_service(worker: WorkerName,
    host: String, service: String)
  =>
    @printf[I32]("OutgoingBoundary: update worker data service: %s -> %s %s\n"
      .cstring(), worker.cstring(), host.cstring(), service.cstring())
    if worker != _target_worker then
      Fail()
    end
    _host = host
    _service = service
    _notify.update_address(_host, _service)
    _reconnect()

  ///////////
  // QUEUES
  ///////////
  fun ref _add_to_upstream_backup(msg: Array[ByteSeq] val) =>
    _queue.push(msg)
    _maybe_mute_or_unmute_upstreams()

  fun _backup_queue_is_overflowing(): Bool =>
    _queue.size() >= 16_384

  /////////////////
  // MUTE/UNMUTE
  /////////////////
  fun ref _maybe_mute_or_unmute_upstreams() =>
    if _mute_outstanding then
      if _can_send() then
        _unmute_upstreams()
      end
    else
      if not _can_send() then
        _mute_upstreams()
      end
    end

  fun ref _mute_upstreams() =>
    for u in _upstreams.values() do
      u.mute(this)
    end
    _mute_outstanding = true

  fun ref _unmute_upstreams() =>
    for u in _upstreams.values() do
      u.unmute(this)
    end
    _mute_outstanding = false

  fun _can_send(): Bool =>
    _tcp_handler.can_send() and
      not _replaying and
      not _backup_queue_is_overflowing()

  ///////////
  // TCP
  ///////////
  be _event_notify(event: AsioEventID, flags: U32, arg: U32) =>
    _tcp_handler.event_notify(event, flags, arg)

  be write_again() =>
    _tcp_handler.write_again()

  be read_again() =>
    _tcp_handler.read_again()

  fun ref expect(qty: USize = 0) =>
    _tcp_handler.expect(qty)

  fun ref set_nodelay(state: Bool) =>
    _tcp_handler.set_nodelay(state)

  fun ref close() =>
    _tcp_handler.close()

  fun ref _writev(data: ByteSeqIter) =>
    _tcp_handler.writev(data)

  fun ref set_connection_not_initialized() =>
    _connection_initialized = false

  fun ref maybe_report_initialized() =>
    if not _reported_initialized then
      // If connecting failed, we should handle here
      match _initializer
      | let lti: LocalTopologyInitializer =>
        lti.report_initialized(this)
        _reported_initialized = true
      else
        Fail()
      end
    end

  fun ref _schedule_reconnect() =>
    // Gradually back off
    if _reconnect_pause < 8_000_000_000 then
      _reconnect_pause = _reconnect_pause * 2
    end

    if (_host != "") and (_service != "") then
      @printf[I32]("OutgoingBoundary: Scheduling reconnect to %s at %s:%s\n"
        .cstring(), _target_worker.cstring(), _host.cstring(),
        _service.cstring())
      let timer = Timer(_PauseBeforeReconnect(this), _reconnect_pause)
      _timers(consume timer)
    end

  fun ref reset_reconnect_pause() =>
    _reconnect_pause = _initial_reconnect_pause

trait TestableBoundaryNotify[T: TCPActor ref] is TCPHandlerNotify[T]
  fun ref update_address(host: String, service: String)
  fun ref register_routing_id(r_id: RoutingId)

class BoundaryNotify is TestableBoundaryNotify[OutgoingBoundary ref]
  let _auth: AmbientAuth
  var _routing_id: RoutingId
  let _worker_name: WorkerName
  let _target_worker: WorkerName
  var _host: String
  var _service: String
  var _header: Bool = true
  let _reconnect_closed_delay: U64
  let _reconnect_failed_delay: U64
  var _initial_connection_was_established: Bool = false

  new create(auth: AmbientAuth, routing_id: RoutingId, worker_name: WorkerName,
    target_worker: WorkerName, host: String, service: String,
    reconnect_closed_delay: U64 = 100_000_000,
    reconnect_failed_delay: U64 = 10_000_000_000)
    =>
    _auth = auth
    _routing_id = routing_id
    _worker_name = worker_name
    _target_worker = target_worker
    _host = host
    _service = service
    _reconnect_closed_delay = reconnect_closed_delay
    _reconnect_failed_delay = reconnect_failed_delay

  fun ref update_address(host: String, service: String) =>
    _host = host
    _service = service

  fun ref register_routing_id(r_id: RoutingId) =>
    _routing_id = r_id

  fun ref received(conn: OutgoingBoundary ref, data: Array[U8] iso,
    times: USize): Bool
  =>
    if _header then
      try
        let e = Bytes.to_u32(data(0)?, data(1)?, data(2)?, data(3)?).usize()

        conn.expect(e)
        _header = false
      end
      true
    else
      ifdef "trace" then
        @printf[I32]("Rcvd msg at OutgoingBoundary\n".cstring())
      end
      match ChannelMsgDecoder(consume data, _auth)
      | let ac: AckDataConnectMsg =>
        ifdef "trace" then
          @printf[I32]("Received AckDataConnectMsg at Boundary\n".cstring())
        end
        conn.receive_connect_ack(ac.last_id_seen)
      | let dd: DataDisconnectMsg =>
        conn.dispose()
      | let sn: StartNormalDataSendingMsg =>
        ifdef "trace" then
          @printf[I32]("Received StartNormalDataSendingMsg at Boundary\n"
            .cstring())
        end
        conn.receive_connect_ack(sn.last_id_seen)
        conn.start_normal_sending()
      | let aw: AckDataReceivedMsg =>
        ifdef "trace" then
          @printf[I32]("Received AckDataReceivedMsg at Boundary\n".cstring())
        end
        conn.receive_ack(aw.seq_id)
      | let ia: ImmediateAckMsg =>
        conn.receive_immediate_ack()
      else
        @printf[I32](("Unknown Wallaroo data message type received at " +
          "OutgoingBoundary.\n").cstring())
      end

      conn.expect(4)
      _header = true

      ifdef linux then
        true
      else
        false
      end
    end

  fun ref connecting(conn: OutgoingBoundary ref, count: U32) =>
    @printf[I32]("BoundaryNotify: attempting to connect to %s at %s:%s...\n\n"
      .cstring(), _target_worker.cstring(), _host.cstring(),
      _service.cstring())

  fun ref connected(conn: OutgoingBoundary ref) =>
    @printf[I32]("BoundaryNotify: connected to %s at %s:%s...\n\n"
      .cstring(), _target_worker.cstring(), _host.cstring(),
      _service.cstring())
    conn.resend_producer_registrations()
    conn.reset_reconnect_pause()
    if _initial_connection_was_established then
      // This is not the initial time we connected, so we're reconnecting.
      try
        let connect_msg = ChannelMsgEncoder.data_connect(_worker_name,
          _routing_id, conn.seq_id, _auth)?
        conn._writev(connect_msg)
      else
        @printf[I32]("error creating data connect message on reconnect\n"
          .cstring())
      end
    else
      _initial_connection_was_established = true
    end
    conn.set_nodelay(true)
    conn.expect(4)
    conn.maybe_report_initialized()
    conn._maybe_mute_or_unmute_upstreams()

  fun ref closed(conn: OutgoingBoundary ref, locally_initiated_close: Bool) =>
    @printf[I32]("BoundaryNotify: closed connection to %s at %s:%s...\n\n"
      .cstring(), _target_worker.cstring(), _host.cstring(),
      _service.cstring())
    if not locally_initiated_close then
      conn._schedule_reconnect()
    end
    conn.set_connection_not_initialized()

  fun ref connect_failed(conn: OutgoingBoundary ref) =>
    @printf[I32]("BoundaryNotify: connect_failed to %s at %s:%s...\n\n"
      .cstring(), _target_worker.cstring(), _host.cstring(),
      _service.cstring())
    conn._schedule_reconnect()

  fun ref sentv(conn: OutgoingBoundary ref,
    data: ByteSeqIter): ByteSeqIter
  =>
    data

  fun ref expect(conn: OutgoingBoundary ref, qty: USize): USize =>
    qty

  fun ref throttled(conn: OutgoingBoundary ref) =>
    @printf[I32]("BoundaryNotify: throttled connection to %s at %s:%s...\n\n"
      .cstring(), _target_worker.cstring(), _host.cstring(),
      _service.cstring())
    conn._maybe_mute_or_unmute_upstreams()

  fun ref unthrottled(conn: OutgoingBoundary ref) =>
    @printf[I32]("BoundaryNotify: unthrottled connection to %s at %s:%s...\n\n"
      .cstring(), _target_worker.cstring(), _host.cstring(),
      _service.cstring())
    conn._maybe_mute_or_unmute_upstreams()

class _PauseBeforeReconnect is TimerNotify
  let _ob: OutgoingBoundary

  new iso create(ob: OutgoingBoundary) =>
    _ob = ob

  fun ref apply(timer: Timer, count: U64): Bool =>
    _ob.reconnect()
    false
