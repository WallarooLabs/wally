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

use "backpressure"
use "buffered"
use "collections"
use "net"
use "time"
use "wallaroo/core/barrier"
use "wallaroo/core/boundary"
use "wallaroo/core/checkpoint"
use "wallaroo/core/common"
use "wallaroo/core/data_receiver"
use "wallaroo/core/initialization"
use "wallaroo/core/invariant"
use "wallaroo/core/messages"
use "wallaroo/core/metrics"
use "wallaroo/core/network"
use "wallaroo/core/recovery"
use "wallaroo/core/routing"
use "wallaroo/core/sink"
use "wallaroo/core/topology"
use "wallaroo_labs/bytes"
use cp = "wallaroo_labs/connector_protocol"
use "wallaroo_labs/logging"
use "wallaroo_labs/mort"
use "wallaroo_labs/time"

use @pony_asio_event_create[AsioEventID](owner: AsioEventNotify, fd: U32,
  flags: U32, nsec: U64, noisy: Bool)
use @pony_asio_event_fd[U32](event: AsioEventID)
use @pony_asio_event_unsubscribe[None](event: AsioEventID)
use @pony_asio_event_resubscribe_read[None](event: AsioEventID)
use @pony_asio_event_resubscribe_write[None](event: AsioEventID)
use @pony_asio_event_destroy[None](event: AsioEventID)

use @ll[I32](sev_cat: U16, fmt: Pointer[U8] tag, ...)

primitive _ConnectTimeout
  fun apply(): U64 =>
    ifdef debug then
      100_000_000
    else
      1_000_000_000
    end

actor ConnectorSink is Sink
  """
  # ConnectorSink

  `ConnectorSink` replaces the Pony standard library class
  `TCPConnection` within Wallaroo for outgoing connections to external
  systems. While `TCPConnection` offers a number of excellent features
  it doesn't account for our needs around resilience.

  `ConnectorSink` incorporates basic send/recv functionality from
  `TCPConnection` as well working with our upstream backup/message
  acknowledgement system.

  ## Resilience and message tracking

  ...

  ## Possible future work

  - At the moment we treat sending over Connector as done. In the future we
    can and should support ack of the data being handled from the other side.
  - Optional in sink deduplication (this woud involve storing what we sent and
    was acknowleged.)
  """
  let _env: Env
  var _phase: SinkPhase = InitialSinkPhase
  let _barrier_coordinator: BarrierCoordinator
  let _checkpoint_initiator: CheckpointInitiator
  // Steplike
  let _sink_id: RoutingId
  let _event_log: EventLog
  let _recovering: Bool
  let _name: String
  let _encoder: ConnectorEncoderWrapper
  let _wb: Writer = Writer
  let _metrics_reporter: MetricsReporter
  var _initializer: (LocalTopologyInitializer | None) = None
  let _conn_debug: U16 = Log.make_sev_cat(Log.debug(), Log.conn_sink())
  let _conn_info: U16 = Log.info()
  let _conn_err: U16 = Log.make_sev_cat(Log.err(), Log.conn_sink())
  let _twopc_debug: U16 = Log.make_sev_cat(Log.debug(), Log.twopc())
  let _twopc_info: U16 = Log.make_sev_cat(Log.info(), Log.twopc())
  let _twopc_err: U16 = Log.make_sev_cat(Log.err(), Log.twopc())

  // Consumer
  var _upstreams: SetIs[Producer] = _upstreams.create()
  // _inputs keeps track of all inputs by step id. There might be
  // duplicate producers in this map (unlike _upstreams) since there might be
  // multiple upstream step ids over a boundary
  let _inputs: Map[RoutingId, Producer] = _inputs.create()

  // Connector
  var _notify: ConnectorSinkNotify
  var _read_buf: Array[U8] iso
  var _next_size: USize
  let _max_size: USize
  var _connect_count: U32
  var _fd: U32 = -1
  var _in_sent: Bool = false
  var _expect: USize = 0
  var _connected: Bool = false
  var _closed: Bool = false
  var _writeable: Bool = false
  var _event: AsioEventID = AsioEvent.none()
  embed _pending: List[(ByteSeq, USize)] = _pending.create()
  embed _pending_tracking: List[(USize, SeqId)] = _pending_tracking.create()
  embed _pending_writev: Array[USize] = _pending_writev.create()
  var _pending_writev_total: USize = 0
  var _expect_read_buf: Reader = Reader

  var _shutdown_peer: Bool = false
  var _readable: Bool = false
  var _read_len: USize = 0
  var _shutdown: Bool = false
  var _no_more_reconnect: Bool = false
  let _initial_msgs: Array[Array[ByteSeq] val] val

  var _reconnect_pause: U64
  var _host: String
  var _service: String
  let _worker_name: WorkerName
  let _protocol_version: String
  let _cookie: String
  let _auth: ApplyReleaseBackpressureAuth
  var _from: String

  let _asio_flags: U32 =
    ifdef not windows then
      AsioEvent.read_write_oneshot()
    else
      AsioEvent.read_write()
    end

  // Producer (Resilience)
  let _timers: Timers = Timers

  var _seq_id: SeqId = 0

  // 2PC
  let _twopc: ConnectorSink2PC

  new create(sink_id: RoutingId, sink_name: String, event_log: EventLog,
    recovering: Bool, env: Env, encoder_wrapper: ConnectorEncoderWrapper,
    metrics_reporter: MetricsReporter iso,
    barrier_coordinator: BarrierCoordinator,
    checkpoint_initiator: CheckpointInitiator,
    host: String, service: String, worker_name: WorkerName,
    protocol_version: String, cookie: String,
    auth: ApplyReleaseBackpressureAuth,
    initial_msgs: Array[Array[ByteSeq] val] val,
    from: String = "", init_size: USize = 64, max_size: USize = 16384,
    reconnect_pause: U64 = _ConnectTimeout())
  =>
    """
    Connect via IPv4 or IPv6. If `from` is a non-empty string, the connection
    will be made from the specified interface.
    """
    _env = env
    _sink_id = sink_id
    _name = sink_name
    _event_log = event_log
    _recovering = recovering
    _encoder = encoder_wrapper
    _metrics_reporter = consume metrics_reporter
    _barrier_coordinator = barrier_coordinator
    _checkpoint_initiator = checkpoint_initiator
    _read_buf = recover Array[U8].>undefined(init_size) end
    _next_size = init_size
    _max_size = max_size
    _notify = ConnectorSinkNotify(
      _sink_id, worker_name, protocol_version, cookie, auth)
    _initial_msgs = initial_msgs
    _reconnect_pause = reconnect_pause
    _host = host
    _service = service
    _worker_name = worker_name
    _protocol_version = protocol_version
    _cookie = cookie
    _auth = auth
    _from = from
    _connect_count = 0
    _twopc = ConnectorSink2PC(_notify.stream_name)
    _phase = NormalSinkPhase(this)

    ifdef "identify_routing_ids" then
      @ll(_conn_info, "===ConnectorSink %s created===\n".cstring(),
        _sink_id.string().cstring())
    end

  //
  // Application Lifecycle events
  //

  be application_begin_reporting(initializer: LocalTopologyInitializer) =>
    _initializer = initializer
    initializer.report_created(this)

  be application_created(initializer: LocalTopologyInitializer) =>
    initializer.report_initialized(this)

  be application_initialized(initializer: LocalTopologyInitializer) =>
    _initial_connect()

  be application_ready_to_work(initializer: LocalTopologyInitializer) =>
    _notify.application_ready_to_work(this)

  be cluster_ready_to_work(initializer: LocalTopologyInitializer) =>
    None

  fun ref _initial_connect() =>
    @ll(_conn_info, "ConnectorSink initializing connection to %s:%s\n".cstring(),
      _host.cstring(), _service.cstring())
    _connect_count = @pony_os_connect_tcp[U32](this,
      _host.cstring(), _service.cstring(),
      _from.cstring(), _asio_flags)
    _notify_connecting()

  // open question: how do we reconnect if our external system goes away?
  be run[D: Any val](metric_name: String, pipeline_time_spent: U64, data: D,
    key: Key, event_ts: U64, watermark_ts: U64, i_producer_id: RoutingId,
    i_producer: Producer, msg_uid: MsgId, frac_ids: FractionalMessageId,
    i_seq_id: SeqId, latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    _phase.process_message[D](metric_name, pipeline_time_spent,
      data, key, event_ts, watermark_ts, i_producer_id, i_producer, msg_uid,
      frac_ids, i_seq_id, latest_ts, metrics_id, worker_ingress_ts)

  fun ref process_message[D: Any val](metric_name: String,
    pipeline_time_spent: U64, data: D, key: Key, event_ts: U64,
    watermark_ts: U64, i_producer_id: RoutingId, i_producer: Producer,
    msg_uid: MsgId, frac_ids: FractionalMessageId, i_seq_id: SeqId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    ifdef "trace" then
      @ll(_conn_debug, "Rcvd msg at ConnectorSink\n".cstring())
    end

    var receive_ts: U64 = 0
    ifdef "detailed-metrics" then
      receive_ts = WallClock.nanoseconds()
      _metrics_reporter.step_metric(metric_name, "Before receive at sink",
        9998, latest_ts, receive_ts)
    end

    try
      if _notify.credits == 0 then
        // TODO: add token management back to connector sink protocol?
        // Ideas?
        // 1. We can't simply use _apply_backpressure because the socket
        //    probably is writeable, which would mean ASIO would immediately
        //    trigger a writeable event, and we'd have to check credits
        //    and defer again, causing an ASIO busy wait loop??
        //    Maybe that's OK?  But if the remote were to crash without
        //    sending an Ack with credit replenishing, then we could
        //    busy wait for a long time.
        // 2. If we have zero credits, then we set
        //    pony_asio_event_set_writeable(false), then we also apply
        //    backpressure *without* also resubscribing
        //    pony_asio_event_set_writeable(true)!  We want to mute
        //    upstreams, and the rest of _apply_backpressure() will do
        //    that for us.
        //    * For events that arrive here while pony**writeable(false),
        //      can we simply call _writev() and then know exactly how
        //      many credits correspond to stuff in _pending??
        //      * Do we change the 2-tuple in _pending to a 3-tuple, where
        //        the 3rd element is the # of credits that correspond?
        //        * Tricksy, because a single credit of message may be more
        //          than one writev array item!
        None
      else
        _notify.credits = _notify.credits - 1
      end
      let encoded1 = _encoder.encode[D](data, _wb)?
      var encoded1_len: USize = 0
      for x in encoded1.values() do
        encoded1_len = encoded1_len + x.size()
      end
      // We do not include MessageMsg size overhead in our offset accounting
      _twopc.update_offset(encoded1_len)

      let encoded2 =
        try
          let w1: Writer = w1.create()
          let msg = _notify.make_message(encoded1)?
          let bs = cp.Frame.encode(msg, w1)
          Bytes.length_encode(bs)
        else
          Fail()
          encoded1
        end

      let next_seq_id = (_seq_id = _seq_id + 1)
      _writev(encoded2, next_seq_id)

      let end_ts = WallClock.nanoseconds()
      let time_spent = end_ts - worker_ingress_ts

      ifdef "detailed-metrics" then
        _metrics_reporter.step_metric(metric_name, "Before end at sink", 9999,
          receive_ts, end_ts)
      end

      _metrics_reporter.pipeline_metric(metric_name,
        time_spent + pipeline_time_spent)
      _metrics_reporter.worker_metric(metric_name, time_spent)
    else
      Fail()
    end

  be update_router(router: Router) =>
    """
    No-op: ConnectorSink has no router
    """
    None

  be dispose() =>
    """
    Gracefully shuts down the sink. Allows all pending writes
    to be sent but any writes that arrive after this will be
    silently discarded and not acknowleged.
    """
    @ll(_conn_info, "Shutting down ConnectorSink\n".cstring())
    _no_more_reconnect = true
    _timers.dispose()
    close()
    _notify.dispose()

  fun inputs(): Map[RoutingId, Producer] box =>
    _inputs

  be register_producer(id: RoutingId, producer: Producer) =>
    // If we have at least one input, then we are involved in checkpointing.
    if _inputs.size() == 0 then
      _barrier_coordinator.register_sink(this)
      _checkpoint_initiator.register_sink(this)
      _event_log.register_resilient(_sink_id, this)
    end

    _inputs(id) = producer
    _upstreams.set(producer)

  be unregister_producer(id: RoutingId, producer: Producer) =>
    if _inputs.contains(id) then
      try
        _inputs.remove(id)?
      else
        Fail()
      end

      var have_input = false
      for i in _inputs.values() do
        if i is producer then have_input = true end
      end
      if not have_input then
        _upstreams.unset(producer)
      end

      // If we have no inputs, then we are not involved in checkpointing.
      if _inputs.size() == 0 then
        _barrier_coordinator.unregister_sink(this)
        _checkpoint_initiator.unregister_sink(this)
        _event_log.unregister_resilient(_sink_id, this)
      end
    end

  be report_status(code: ReportStatusCode) =>
    None

  ///////////////
  // 2PC glue funcs between this, ConnectorSinkNotify, and ConnectorSink2PC
  ///////////////

  fun ref twopc_phase1_reply(txn_id: String, commit: Bool) =>
    """
    This is a callback used by the ConnectorSinkNotify class to Inform
    us that it received a 2PC phase 1 reply.
    """
    if _twopc.twopc_phase1_reply(txn_id, commit) then
      _barrier_coordinator.ack_barrier(this, _twopc.barrier_token)
    else
      abort_decision("phase 1 ABORT", _twopc.txn_id, _twopc.barrier_token)
    end

  fun ref abort_decision(reason: String, txn_id: String,
    barrier_token: CheckpointBarrierToken)
  =>
    @ll(_twopc_debug, "2PC: abort_decision: txn_id %s %s\n".cstring(), txn_id.cstring(), reason.cstring())

    _twopc.set_state_abort()
    _barrier_coordinator.abort_barrier(barrier_token)

  fun send_msg(sink: ConnectorSink ref, msg: cp.Message) =>
    _notify.send_msg(sink, msg)

  fun ref twopc_intro_done() =>
    """
    This callback is used by ConnectorSinkNotify when the 2PC intro
    part of the connector sink protocol has finished.
    """
    _twopc.twopc_intro_done(this)

  ///////////////
  // BARRIER
  ///////////////
  be receive_barrier(input_id: RoutingId, producer: Producer,
    barrier_token: BarrierToken)
  =>
    """
    Process a barrier token of some type: autoscale, checkpoint,
    rollback, etc.  For a particular barrier, we should receive
    exactly one per input (blocking each input over which we
    receive one), at which point we can unblock all inputs and
    continue.
    """
    @ll(_conn_debug, "Receive barrier %s at ConnectorSink %s\n".cstring(), barrier_token.string().cstring(), _sink_id.string().cstring())
    process_barrier(input_id, producer, barrier_token)

  fun ref receive_new_barrier(input_id: RoutingId, producer: Producer,
    barrier_token: BarrierToken)
  =>
    _phase = BarrierSinkPhase(_sink_id, this,
      barrier_token)
    _phase.receive_barrier(input_id, producer,
      barrier_token)

  fun ref process_barrier(input_id: RoutingId, producer: Producer,
    barrier_token: BarrierToken)
  =>
    match barrier_token
    | let srt: CheckpointRollbackBarrierToken =>
      _phase.prepare_for_rollback(barrier_token)
    end
    _phase.receive_barrier(input_id, producer,
      barrier_token)

  fun ref barrier_complete(barrier_token: BarrierToken) =>
    """
    Our local barrier token processing has determined that we have
    received all of the barriers for this autoscale/checkpoint/rollback/
    whatever event.  This tells us nothing about the state of barrier
    propagation or processing by other actors in this worker or in
    any other worker.
    """
    @ll(_conn_debug, "Barrier %s complete at ConnectorSink %s\n".cstring(), barrier_token.string().cstring(), _sink_id.string().cstring())
    var ack_now = true
    match barrier_token
    | let sbt: CheckpointBarrierToken =>
      ack_now = false
      if not _notify.twopc_intro_done then
        // This sink applies Pony runtime backpressure when disconnected,
        // so it's quite unlikely that we will get here: sending
        // messages to us will block the senders.  However, the nature
        // of backpressure may change over time as the runtime's
        // backpressure system changes.
        @ll(_twopc_debug, "2PC: preemptive abort: connector sink not fully connected\n".cstring())
        abort_decision("connector sink not fully connected",
          _twopc.txn_id, _twopc.barrier_token)
        _twopc.preemptive_txn_abort(sbt)
        return
      end

      checkpoint_state(sbt.id)
      _notify.twopc_txn_id_current = _twopc.txn_id
      match _twopc.barrier_complete(sbt)
      | None =>
        // If no data has been processed by the sink since the last
        // checkpoint, then don't bother with 2PC, return early.
        _barrier_coordinator.ack_barrier(this, sbt)
        @ll(_twopc_debug, "2PC: no data written during this checkpoint interval, skipping 2PC round\n".cstring())
        return

      | let msg: cp.MessageMsg =>
        _notify.send_msg(this, msg)
        @ll(_twopc_debug, "2PC: sent phase 1 for txn_id %s\n".cstring(), _twopc.txn_id.cstring())
      end

      // As a 2PC participant as a Wallaroo *sink*, we cannot
      // allow messages to be processed by this sink during 2PC,
      // unless we make additional assumptions about the ability of
      // the connector sink to be able to manage the storage of and
      // possible rollback of data sent during a round of 2PC.
      // We choose to assume that the client can only manage
      // commit/abort decisions only on the range of output
      // governed by a single round of 2PC.

      _phase = QueuingSinkPhase(_sink_id,
        this)

    | let srt: CheckpointRollbackBarrierToken =>
      _use_normal_processor()
    | let rbrt: CheckpointRollbackResumeBarrierToken =>
      _resume_processing_messages()
      _twopc.reset_state()
    end
    if ack_now then
      _barrier_coordinator.ack_barrier(this, barrier_token)
    end

  be checkpoint_complete(checkpoint_id: CheckpointId) =>
    @ll(_twopc_debug, "2PC: Checkpoint complete %d at ConnectorSink %s\n".cstring(), checkpoint_id, _sink_id.string().cstring())

    let cpoint_id = ifdef "test_disconnect_at_5" then "5" else "" end
    let drop_phase2_msg = try if _twopc.txn_id.split("=")(1)? == cpoint_id then true else false end else false end

    _twopc.checkpoint_complete(this, drop_phase2_msg)

    try @ll(_twopc_debug, "2PC: DBGDBG: checkpoint_complete: commit, _twopc.last_offset %d _notify.twopc_txn_id_last_committed %s\n".cstring(), _twopc.last_offset, (_notify.twopc_txn_id_last_committed as String).cstring()) else Fail() end

    if _twopc.txn_id == "" then
      @ll(_twopc_err, "Error: checkpoint_complete() with empty _twopc.txn_id = %s.\n".cstring(), _twopc.txn_id.cstring())
      Fail()
    else
      _notify.twopc_txn_id_last_committed = _twopc.txn_id
      try @ll(_twopc_debug, "2PC: DBGDBG: twopc_txn_id_last_committed = %s.\n".cstring(), (_notify.twopc_txn_id_last_committed as String).cstring()) else Fail() end
    end
    _twopc.reset_state()

    _resume_processing_messages()

    if drop_phase2_msg then
      // Because we're using TCP, we get message loss only when
      // the TCP connection is closed.  It doesn't matter why the
      // connection is closed.  We have direct control over the
      // timing here, so close it now.
      _hard_close()
      _schedule_reconnect()
    end

  fun ref _resume_processing_messages() =>
    """
    2nd-half logic for barrier_fully_acked().
    """
    let queued = _phase.queued()
    _use_normal_processor()
    for q in queued.values() do
      match q
      | let qm: QueuedMessage =>
        qm.process_message(this)
      | let qb: QueuedBarrier =>
        qb.inject_barrier(this)
      end
    end

  fun ref _use_normal_processor() =>
    _phase = NormalSinkPhase(this)

  ///////////////
  // CHECKPOINTS
  ///////////////

  fun ref checkpoint_state(checkpoint_id: CheckpointId) =>
    """
    Serialize hard state (i.e., can't afford to lose it) and send
    it to the local event log and reset 2PC state.
    """
    if not (_twopc.state_is_1precommit() or _twopc.state_is_start()) then
      @ll(_twopc_err, "2PC: ERROR: _twopc.state = %d\n".cstring(), _twopc.state())
      Fail()
    end

    @ll(_twopc_debug, "2PC: Checkpoint state %s at ConnectorSink %s, txn-id %s\n".cstring(), checkpoint_id.string().cstring(), _sink_id.string().cstring(), _twopc.txn_id.cstring())

    let wb: Writer = wb.create()
    wb.u64_be(_twopc.current_offset.u64())
    wb.u64_be(_notify.acked_point_of_ref)
    let bs = wb.done()

    _event_log.checkpoint_state(_sink_id, checkpoint_id,
      consume bs)

  be prepare_for_rollback() =>
    @ll(_conn_debug, "Prepare for checkpoint rollback at ConnectorSink %s\n".cstring(), _sink_id.string().cstring())
    // Don't call _use_normal_processor() here

  fun ref finish_preparing_for_rollback() =>
    _use_normal_processor()

  be rollback(payload: ByteSeq val, event_log: EventLog,
    checkpoint_id: CheckpointId)
  =>
    """
    If we're here, it's implicit that Wallaroo has determinted
    the global status of this checkpoint_id: it was committed.
    We may need to re-send phase2=commit for this checkpoint_id.
    (But that's async from our point of view, beware tricksy bugs....)
    """
    @ll(_conn_debug, "Rollback to %s at ConnectorSink %s\n".cstring(), checkpoint_id.string().cstring(), _sink_id.string().cstring())
    @ll(_twopc_debug, "2PC: Rollback: twopc_state %d txn_id %s.\n".cstring(), _twopc.state(), _twopc.txn_id.cstring())

    if _twopc.txn_id != "" then
      // Phase 1 decision was abort + we haven't been disconnected.
      // If we were disconnected + perform a local abort, then we
      // arrive here with _twopc.txn_id="".  The last transaction,
      // named by _twopc.txn_id_at_close, has already been aborted
      // during the twopc_intro portion of the connector sink protocol.
      _twopc.send_phase2(this, false)
    end
    _twopc.reset_state()

    let r = Reader
    r.append(payload)
    let current_offset = try r.u64_be()?.usize() else Fail(); 0 end
    _twopc.rollback(current_offset)
    _notify.acked_point_of_ref = try r.u64_be()? else Fail(); 0 end
    _notify.message_id = _twopc.last_offset.u64()

    // The EventLog's payload's data doesn't include the last
    // committed txn_id because at the time that payload was created,
    // we didn't know if the txn-in-progress had committed globally.
    // When rollback() is called here, we now know the global txn
    // commit status: commit for checkpoint_id, all greater are invalid.
    _notify.twopc_txn_id_last_committed =
      _twopc.make_txn_id_string(checkpoint_id)
    try @ll(_twopc_debug, "DBGDBG: 2PC: twopc_txn_id_last_committed = %s.\n".cstring(), (_notify.twopc_txn_id_last_committed as String).cstring()) else Fail() end
    _notify.twopc_current_txn_aborted = _notify.process_uncommitted_list(this)

    @ll(_twopc_debug, "DBGDBG: 2PC: twopc_current_txn_aborted = %s.\n".cstring(), _notify.twopc_current_txn_aborted.string().cstring())
    @ll(_twopc_debug, "2PC: Rollback: _twopc.last_offset %lu _twopc.current_offset %lu acked_point_of_ref %lu last committed txn %s at ConnectorSink %s\n".cstring(), _twopc.last_offset, _twopc.current_offset, _notify.acked_point_of_ref, try (_notify.twopc_txn_id_last_committed as String).cstring() else "<<<None>>>".string() end, _sink_id.string().cstring())

    event_log.ack_rollback(_sink_id)

  ///////////////
  // Connector
  ///////////////
  be _event_notify(event: AsioEventID, flags: U32, arg: U32) =>
    """
    Handle socket events.
    """
    if event isnt _event then
      if AsioEvent.writeable(flags) then
        // A connection has completed.
        var fd = @pony_asio_event_fd(event)
        _connect_count = _connect_count - 1

        if not _connected and not _closed then
          // We don't have a connection yet.
          if @pony_os_connected[Bool](fd) then
            // The connection was successful, make it ours.
            _fd = fd
            _event = event
            _connected = true
            _writeable = true
            _readable = true

            _notify.connected(this)
            _pending_reads()

            for msg in _initial_msgs.values() do
              _writev(msg, None)
            end
            ifdef not windows then
              if _pending_writes() then
                //sent all data; release backpressure
                _release_backpressure()
              end
            end
          else
            // The connection failed, unsubscribe the event and close.
            @pony_asio_event_unsubscribe(event)
            @pony_os_socket_close[None](fd)
            _notify_connecting()
          end
        elseif not _connected and _closed then
          @ll(_conn_info, "Reconnection asio event\n".cstring())
          if @pony_os_connected[Bool](fd) then
            // The connection was successful, make it ours.
            _fd = fd
            _event = event

            _pending_writev.clear()
            _pending.clear()
            _pending_writev_total = 0

            _connected = true
            _writeable = true
            _readable = true

            _closed = false
            _shutdown = false
            _shutdown_peer = false

            _notify.connected(this)
            _pending_reads()

            ifdef not windows then
              if _pending_writes() then
                //sent all data; release backpressure
                _release_backpressure()
              end
            end
          else
            // The connection failed, unsubscribe the event and close.
            @pony_asio_event_unsubscribe(event)
            @pony_os_socket_close[None](fd)
            _notify_connecting()
          end
        else
          // We're already connected, unsubscribe the event and close.
          @pony_asio_event_unsubscribe(event)
          @pony_os_socket_close[None](fd)
        end
      else
        // It's not our event.
        if AsioEvent.disposable(flags) then
          // It's disposable, so dispose of it.
          @pony_asio_event_destroy(event)
        end
      end
    else
      // At this point, it's our event.
      if _connected and not _shutdown_peer then
        if AsioEvent.writeable(flags) then
          _writeable = true
          ifdef not windows then
            if _pending_writes() then
              //sent all data; release backpressure
              _release_backpressure()
            end
          end
        end

        if AsioEvent.readable(flags) then
          _readable = true
          _pending_reads()
        end
      end

      if AsioEvent.disposable(flags) then
        @pony_asio_event_destroy(event)
        _event = AsioEvent.none()
      end

      _try_shutdown()
    end

  fun ref report_ready_to_work() =>
    match _initializer
    | let initializer: LocalTopologyInitializer =>
      initializer.report_ready_to_work(this)
      _initializer = None
    end

  fun ref _writev(data: ByteSeqIter, tracking_id: (SeqId | None))
  =>
    """
    Write a sequence of sequences of bytes.
    """
    _in_sent = true

    var data_size: USize = 0
    for bytes in _notify.sentv(this, data).values() do
      _pending_writev.>push(bytes.cpointer().usize()).>push(bytes.size())
      _pending_writev_total = _pending_writev_total + bytes.size()
      _pending.push((bytes, 0))
      data_size = data_size + bytes.size()
    end

    ifdef "resilience" then
      match tracking_id
      | let id: SeqId =>
        _pending_tracking.push((data_size, id))
      end
    end

    _pending_writes()

    _in_sent = false

  fun ref _write_final(data: ByteSeq, tracking_id: (SeqId | None)) =>
    """
    Write as much as possible to the socket. Set _writeable to false if not
    everything was written. On an error, close the connection. This is for
    data that has already been transformed by the notifier.
    """
    _pending_writev.>push(data.cpointer().usize()).>push(data.size())
    _pending_writev_total = _pending_writev_total + data.size()
    ifdef "resilience" then
      match tracking_id
        | let id: SeqId =>
          _pending_tracking.push((data.size(), id))
        end
    end
    _pending.push((data, 0))
    _pending_writes()

  fun ref _notify_connecting() =>
    """
    Inform the notifier that we're connecting.
    """
    if _connect_count > 0 then
      _notify.connecting(this, _connect_count)
    else
      _notify.connect_failed(this)
      _hard_close()
      _schedule_reconnect()
    end

  fun ref close() =>
    """
    Perform a graceful shutdown. Don't accept new writes, but don't finish
    closing until we get a zero length read.
    """
    _closed = true
    _try_shutdown()

  fun ref _try_shutdown() =>
    """
    If we have closed and we have no remaining writes or pending connections,
    then shutdown.
    """
    if not _closed then
      return
    end

    if
      not _shutdown and
      (_connect_count == 0) and
      (_pending_writev_total == 0)
    then
      _shutdown = true

      if _connected then
        @pony_os_socket_shutdown[None](_fd)
      else
        _shutdown_peer = true
      end
    end

    if _connected and _shutdown and _shutdown_peer then
      _hard_close()
    end

  fun ref _hard_close() =>
    """
    When an error happens, do a non-graceful close.
    """
    if not _connected then
      return
    end

    _connected = false
    _closed = true
    _shutdown = true
    _shutdown_peer = true

    // Unsubscribe immediately and drop all pending writes.
    @pony_asio_event_unsubscribe(_event)
    _pending_tracking.clear()
    _pending_writev.clear()
    _pending.clear()
    _pending_writev_total = 0
    _readable = false
    _writeable = false
    @pony_asio_event_set_readable[None](_event, false)
    @pony_asio_event_set_writeable[None](_event, false)

    @pony_os_socket_close[None](_fd)
    _fd = -1

    _twopc.hard_close()
    _notify.closed(this)

  fun ref _pending_reads() =>
    """
    Read while data is available,
    guessing the next packet length as we go. If we read 4 kb of data, send
    ourself a resume message and stop reading, to avoid starving other actors.
    """
    try
      var sum: USize = 0
      var received_called: USize = 0

      while _readable and not _shutdown_peer do
        // Read as much data as possible.
        let len = @pony_os_recv[USize](
          _event,
          _read_buf.cpointer().usize() + _read_len,
          _read_buf.size() - _read_len) ?

        match len
        | 0 =>
          // Would block, try again later.
          _readable = false
          // this is safe because asio thread isn't currently subscribed
          // for a read event so will not be writing to the readable flag
          @pony_asio_event_set_readable[None](_event, false)
          _readable = false
          @pony_asio_event_resubscribe_read(_event)
          return
        | _next_size =>
          // Increase the read buffer size.
          _next_size = _max_size.min(_next_size * 2)
        end

        _read_len = _read_len + len

        if _read_len >= _expect then
          let data = _read_buf = recover Array[U8] end
          data.truncate(_read_len)
          _read_len = 0

          received_called = received_called + 1
          if not _notify.received(this, consume data,
            received_called)
          then
            _read_buf_size()
            _read_again()
            return
          else
            _read_buf_size()
          end

          sum = sum + len

          if sum >= _max_size then
            // If we've read _max_size, yield and read again later.
            _read_again()
            return
          end
        end
      end
    else
      // The socket has been closed from the other side.
      _shutdown_peer = true
      _hard_close()
      _schedule_reconnect()
    end

  be _write_again() =>
    """
    Resume writing.
    """
    _pending_writes()

  fun ref _pending_writes(): Bool =>
    """
    Send pending data. If any data can't be sent, keep it and mark as not
    writeable. On an error, dispose of the connection. Returns whether
    it sent all pending data or not.
    """
    let writev_batch_size: USize = @pony_os_writev_max[I32]().usize()
    var num_to_send: USize = 0
    var bytes_to_send: USize = 0
    var bytes_sent: USize = 0

    // nothing to send
    if _pending_writev_total == 0 then
      return true
    end

    while _writeable and not _shutdown_peer and (_pending_writev_total > 0) do
      // yield if we sent max bytes
      if bytes_sent > _max_size then
        // do tracking finished stuff
        _tracking_finished(bytes_sent)

        _write_again()
        return false
      end
      try
        //determine number of bytes and buffers to send
        if (_pending_writev.size()/2) < writev_batch_size then
          num_to_send = _pending_writev.size()/2
          bytes_to_send = _pending_writev_total
        else
          //have more buffers than a single writev can handle
          //iterate over buffers being sent to add up total
          num_to_send = writev_batch_size
          bytes_to_send = 0
          for d in Range[USize](1, num_to_send*2, 2) do
            bytes_to_send = bytes_to_send + _pending_writev(d)?
          end
        end

        // Write as much data as possible.
        var len = @pony_os_writev[USize](_event,
          _pending_writev.cpointer(), num_to_send) ?

        // keep track of how many bytes we sent
        bytes_sent = bytes_sent + len

        if len < bytes_to_send then
          while len > 0 do
            let iov_p = _pending_writev(0)?
            let iov_s = _pending_writev(1)?
            if iov_s <= len then
              len = len - iov_s
              _pending_writev.shift()?
              _pending_writev.shift()?
              _pending.shift()?
              _pending_writev_total = _pending_writev_total - iov_s
            else
              _pending_writev.update(0, iov_p+len)?
              _pending_writev.update(1, iov_s-len)?
              _pending_writev_total = _pending_writev_total - len
              len = 0
            end
          end
          _apply_backpressure()
        else
          // sent all data we requested in this batch
          _pending_writev_total = _pending_writev_total - bytes_to_send
          if _pending_writev_total == 0 then
            _pending_writev.clear()
            _pending.clear()

            // do tracking finished stuff
            _tracking_finished(bytes_sent)
            return true
          else
           for d in Range[USize](0, num_to_send, 1) do
             _pending_writev.shift()?
             _pending_writev.shift()?
             _pending.shift()?
           end

          end
        end
      else
        // Non-graceful shutdown on error.
        _hard_close()
        _schedule_reconnect()
      end
    end

    // do tracking finished stuff
    _tracking_finished(bytes_sent)

    false

  fun ref _tracking_finished(num_bytes_sent: USize) =>
    ifdef "resilience" then
      var num_sent: ISize = 0
      var tracked_sent: ISize = 0
      var final_pending_sent: (SeqId | None) = None
      var bytes_sent = num_bytes_sent

      try
        while bytes_sent > 0 do
          let node = _pending_tracking.head()?
          (let bytes, let tracking_id) = node()?
          if bytes <= bytes_sent then
            num_sent = num_sent + 1
            bytes_sent = bytes_sent - bytes
            _pending_tracking.shift()?
            match tracking_id
            | let id: SeqId =>
              tracked_sent = tracked_sent + 1
              final_pending_sent = tracking_id
            end
          else
            let bytes_remaining = bytes - bytes_sent
            bytes_sent = 0
            // update remaining for this message
            node()? = (bytes_remaining, tracking_id)
          end
        end
      end
    end

  fun ref _read_buf_size() =>
    """
    Resize the read buffer.
    """
    if _expect != 0 then
      _read_buf.undefined(_expect)
    else
      _read_buf.undefined(_next_size)
    end

  fun local_address(): NetAddress =>
    """
    Return the local IP address.
    """
    let ip = recover NetAddress end
    @pony_os_sockname[Bool](_fd, ip)
    ip

  fun ref expect(qty: USize = 0) =>
    """
    A `received` call on the notifier must contain exactly `qty` bytes. If
    `qty` is zero, the call can contain any amount of data. This has no effect
    if called in the `sent` notifier callback.
    """
    if not _in_sent then
      _expect = _notify.expect(this, qty)
      _read_buf_size()
    end

  be _read_again() =>
    """
    Resume reading.
    """

    _pending_reads()

  fun ref _schedule_reconnect() =>
    if (_host != "") and (_service != "") and not _no_more_reconnect then
      @ll(_conn_info, "RE-Connecting ConnectorSink to %s:%s\n".cstring(),
                   _host.cstring(), _service.cstring())
      let timer = Timer(PauseBeforeReconnectConnectorSink(this), _reconnect_pause)
      _timers(consume timer)
    end

  be reconnect() =>
    if not _connected and not _no_more_reconnect then
      _connect_count = @pony_os_connect_tcp[U32](this,
        _host.cstring(), _service.cstring(),
        _from.cstring(), _asio_flags)
      _notify_connecting()
    end

  fun ref _apply_backpressure() =>
    _notify.throttled(this)
    _writeable = false
    // this is safe because asio thread isn't currently subscribed
    // for a write event so will not be writing to the readable flag
    @pony_asio_event_set_writeable[None](_event, false)
    @pony_asio_event_resubscribe_write(_event)

  fun ref _release_backpressure() =>
    _notify.unthrottled(this)

  fun _can_send(): Bool =>
    _connected and not _closed and _writeable

  fun ref set_nodelay(state: Bool) =>
    """
    Turn Nagle on/off. Defaults to on. This can only be set on a connected
    socket.
    """
    if _connected then
      @pony_os_nodelay[None](_fd, state)
    end

  fun ref receive_connect_ack(seq_id: SeqId) =>
    """
    For WallarooOutgoingNetworkActor only.
    This would be needed if we used a handshake to connect downstream.
    """
    None

  fun ref start_normal_sending() =>
    None

  fun ref receive_ack(seq_id: SeqId) =>
    """
    For WallarooOutgoingNetworkActor only.
    This would be needed if we start only acking once we receive some kind
    of confirmation from the downstream.
    """
    None

  fun _print_array[A: Stringable #read](array: ReadSeq[A]): String =>
    """
    Generate a printable string of the contents of the given readseq to use in
    error messages.
    """
    "[len=" + array.size().string() + ": " + ", ".join(array.values()) + "]"

  fun get_twopc_state(): U8 =>
    _twopc.state()

class PauseBeforeReconnectConnectorSink is TimerNotify
  let _tcp_sink: ConnectorSink

  new iso create(tcp_sink: ConnectorSink) =>
    _tcp_sink = tcp_sink

  fun ref apply(timer: Timer, count: U64): Bool =>
    _tcp_sink.reconnect()
    false

