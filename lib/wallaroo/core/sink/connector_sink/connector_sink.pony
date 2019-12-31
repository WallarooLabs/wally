/*

Copyright (C) 2016-2019, Wallaroo Labs
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
use "wallaroo_labs/connector_protocol"
use cwm = "wallaroo_labs/connector_wire_messages"
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
  let _conn_info: U16 = Log.make_sev_cat(Log.info(), Log.conn_sink())
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
  var connected_count: USize = 0
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
  let _app_name: String
  let _worker_name: WorkerName
  let _protocol_version: String
  let _cookie: String
  let _auth: ApplyReleaseBackpressureAuth
  var _from: String

  let _asio_flags: U32 = AsioEvent.read_write_oneshot()

  // Producer (Resilience)
  let _timers: Timers = Timers

  // Lifecycle
  var _ready_to_work: Bool = false
  var _report_ready_to_work_requested: Bool = false
  var _report_ready_to_work_done: Bool = false

  // Connector Protocol
  var _ec: _ExtConnOps = _ExtConnInit
  var _cprb: _CpRbOps
  var _rtag: U64 = 77777
  var _seq_id: SeqId = 0
  var _ext_conn_state: ExtConnStateState = ExtConnStateDisconnected
  var _credits: U32 = 0
  var _acked_point_of_ref: cwm.MessageId = 0
  var _message_id: cwm.MessageId = _acked_point_of_ref
  let _stream_id: cwm.StreamId = 1
  let _stream_name: String

  // 2PC
  let _twopc: ConnectorSink2PC

  new create(sink_id: RoutingId, sink_name: String, event_log: EventLog,
    recovering: Bool, env: Env, encoder_wrapper: ConnectorEncoderWrapper,
    metrics_reporter: MetricsReporter iso,
    barrier_coordinator: BarrierCoordinator,
    checkpoint_initiator: CheckpointInitiator,
    host: String, service: String,
    app_name: String, worker_name: WorkerName,
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
    _notify = ConnectorSinkNotify(auth)
    _initial_msgs = initial_msgs
    _reconnect_pause = reconnect_pause
    _host = host
    _service = service
    _app_name = app_name
    _worker_name = worker_name
    _protocol_version = protocol_version
    _cookie = cookie
    _auth = auth
    _from = from
    _connect_count = 0
    _stream_name = _app_name + "-w-" + _worker_name + "-id-" + _sink_id.string()
    _twopc = ConnectorSink2PC(_stream_name)
    // Do not change sink phase yet: if we have crashed and have just
    // restarted, Our point-of-reference/message_id is 0, *until* we get
    // the rollback payload.
    //
    // Meanwhile, it's possible to get an app message via run() before
    // we've we receive rollback() + the rollback payload that tells use
    // what our point-of-reference/message_id is supposed to be.  If we
    // are using the normal processing phase, then we would process that
    // message and send it downstream with a bogus p-o-r/msg_id of 0.

    ifdef "identify_routing_ids" then
      @ll(_conn_info, "===ConnectorSink %s created===".cstring(),
        _sink_id.string().cstring())
    end
    _cprb = _CpRbInit
    // _CpRbInit is the starting state, so we must call enter() ourselves.
    try (_cprb as _CpRbInit).enter(this) else Fail() end
    _phase = EarlySinkPhase(this)

  //
  // Application Lifecycle events
  //

  be application_begin_reporting(initializer: LocalTopologyInitializer) =>
    @ll(_conn_info, "Lifecycle: %s.%s at %s".cstring(),
      __loc.type_name().cstring(), __loc.method_name().cstring(),
      _sink_id.string().cstring())
    _initializer = initializer
    initializer.report_created(this)

  be application_created(initializer: LocalTopologyInitializer) =>
    @ll(_conn_info, "Lifecycle: %s.%s at %s".cstring(),
      __loc.type_name().cstring(), __loc.method_name().cstring(),
      _sink_id.string().cstring())
    initializer.report_initialized(this)

  be application_initialized(initializer: LocalTopologyInitializer) =>
    @ll(_conn_info, "Lifecycle: %s.%s at %s".cstring(),
      __loc.type_name().cstring(), __loc.method_name().cstring(),
      _sink_id.string().cstring())
    _initial_connect()
    ready_to_work_requested(this)

  be application_ready_to_work(initializer: LocalTopologyInitializer) =>
    @ll(_conn_info, "Lifecycle: %s.%s at %s".cstring(),
      __loc.type_name().cstring(), __loc.method_name().cstring(),
      _sink_id.string().cstring())
    report_ready_to_work()
    _use_normal_processor()

  be cluster_ready_to_work(initializer: LocalTopologyInitializer) =>
    @ll(_conn_info, "Lifecycle: %s.%s at %s".cstring(),
      __loc.type_name().cstring(), __loc.method_name().cstring(),
      _sink_id.string().cstring())
    ifdef "TODO-delete-me" then
      @ll(_conn_err, "TODOTODOTODOTODO: switching to normal processor here (e.g., restart after crash) is bad if we're in the middle of rollback and and phase=QueuingSinkPhase!".cstring())
      _use_normal_processor()
    end

  fun ref _initial_connect() =>
    @ll(_conn_info, "ConnectorSink initializing connection to %s:%s".cstring(),
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
    ifdef "trace" then
    try
      let dq = data as Array[U8] val
      @ll(_conn_debug, "Rcvd msg at ConnectorSink.run: phase %s data %s".cstring(), _phase.name().cstring(), _print_array[U8](dq).cstring())
    else
      Fail()
    end
    end
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
      @ll(_conn_debug, "Rcvd msg at ConnectorSink".cstring())
    end

    var receive_ts: U64 = 0
    ifdef "detailed-metrics" then
      receive_ts = WallClock.nanoseconds()
      _metrics_reporter.step_metric(metric_name, "Before receive at sink",
        9998, latest_ts, receive_ts)
    end

    try
      if _credits == 0 then
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
        _credits = _credits - 1
      end
      let encoded1 = _encoder.encode[D](data, _wb)?
      var encoded1_len: USize = 0
      for x in encoded1.values() do
        encoded1_len = encoded1_len + x.size()
      end
      let encoded1_offset = _twopc.current_offset
      // We do not include MessageMsg size overhead in our offset accounting
      _twopc.update_offset(encoded1_len)
      ifdef "trace" then
        try
        @ll(_conn_debug, "process_msg: offset %lu msg %s".cstring(), encoded1_offset, _print_array[U8](
          match encoded1(0)?
          | let s: String =>
            s.array()
          | let a: Array[U8] val =>
            a
          end).cstring())
        end
      end

      let w1: Writer = w1.create()
      let msg = make_message(encoded1)
      let bs = cwm.Frame.encode(msg, w1)
      let encoded2 = Bytes.length_encode(bs)

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
    @ll(_conn_info, "Shutting down ConnectorSink".cstring())
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

  fun ref twopc_phase1_reply(txn_id: String, commit: Bool) =>
    """
    TODO
    """
    None//TODO

  fun ref abort_decision(reason: String, txn_id: String,
    barrier_token: CheckpointBarrierToken)
  =>
    @ll(_twopc_debug, "2PC: abort_decision: txn_id %s %s".cstring(), txn_id.cstring(), reason.cstring())

    None//TODO
    _barrier_coordinator.abort_barrier(barrier_token)


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
    @ll(_conn_debug, "Receive barrier %s at ConnectorSink %s".cstring(), barrier_token.string().cstring(), _sink_id.string().cstring())
    process_barrier(input_id, producer, barrier_token)

  fun ref receive_new_barrier(input_id: RoutingId, producer: Producer,
    barrier_token: BarrierToken)
  =>
    @ll(_conn_debug, "Receive new barrier %s at ConnectorSink %s".cstring(), barrier_token.string().cstring(), _sink_id.string().cstring())
    _phase = BarrierSinkPhase(_sink_id, this,
      barrier_token)
    _phase.receive_barrier(input_id, producer,
      barrier_token)

  fun ref process_barrier(input_id: RoutingId, producer: Producer,
    barrier_token: BarrierToken)
  =>
    ifdef "checkpoint_trace" then
      @ll(_conn_debug, "Process Barrier %s at ConnectorSink %s from %s with phase %s\n".cstring(),
        barrier_token.string().cstring(), _sink_id.string().cstring(),
        input_id.string().cstring(), _phase.name().cstring())
    end

    _phase.maybe_use_normal_processor()

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
    @ll(_conn_debug, "Barrier %s complete at ConnectorSink %s".cstring(), barrier_token.string().cstring(), _sink_id.string().cstring())
    var ack_now = true
    match barrier_token
    | let sbt: CheckpointBarrierToken =>
      checkpoint_state(sbt.id)
      let queued = _phase.queued()
      _cprb.cp_barrier_complete(this, sbt, queued)
      ack_now = false
    | let srt: CheckpointRollbackBarrierToken =>
      // No action required here.  When we ack this token at the end of
      // this function, Wallaroo will send use the prepare_to_rollback
      // and rollback messages that we're expecting.
      None
    | let rbrt: CheckpointRollbackResumeBarrierToken =>
      _cprb.rollbackresume_barrier_complete(this)
    | let sat: AutoscaleBarrierToken =>
      //TODO//_twopc_last_autoscale_barrier_token = sat
      //TODO//resume_processing_messages_queued()
      None//TODO
    | let sart: AutoscaleResumeBarrierToken =>
      // if sart.id() == _twopc_last_autoscale_barrier_token.id() then
      //   let lws = _twopc_last_autoscale_barrier_token.leaving_workers()
      //   @ll(_conn_debug, "autoscale: leaving_workers size = %lu".cstring(),
      //     lws.size())
      //   if (lws.size() > 0) and _connected then
      //     _twopc.send_workers_left(this, 7 /*unused by sink*/, lws)
      //   end
      // end
      None//TODO resume_processing_messages_queued()
    else
      // Any other remaining barrier token
      None//TODO resume_processing_messages_queued()
    end
    if ack_now then
      @ll(_conn_debug, "Barrier %s acked at ConnectorSink %s".cstring(), barrier_token.string().cstring(), _sink_id.string().cstring())
      _barrier_coordinator.ack_barrier(this, barrier_token)
    end

  be checkpoint_complete(checkpoint_id: CheckpointId) =>
    @ll(_twopc_debug, "2PC: Checkpoint complete %d _twopc.txn_id is %s".cstring(), checkpoint_id, _twopc.txn_id.cstring())
    _cprb.checkpoint_complete(this, checkpoint_id)
    @ll(_twopc_debug, "2PC: Checkpoint complete %d _twopc.txn_id is %s _cprb.name = %s".cstring(), checkpoint_id, _twopc.txn_id.cstring(), _cprb.name().cstring())

  fun ref resume_processing_messages_queued(discard_app_msgs: Bool = false) =>
    let queued = _phase.queued()
    _use_normal_processor()
    @ll(_conn_debug, "resume_processing_messages_queued: size = %lu".cstring(), queued.size())
    for q in queued.values() do
      match q
      | let qm: QueuedMessage =>
        if not discard_app_msgs then
          qm.process_message(this)
        end
      | let qb: QueuedBarrier =>
        qb.inject_barrier(this)
      end
    end

  fun ref use_normal_processor() =>
    _use_normal_processor()

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
    @ll(_twopc_debug, "2PC: Checkpoint state %s at ConnectorSink %s, txn-id %s current_offset %lu _acked_point_of_ref %lu _pending_writev_total %lu".cstring(), checkpoint_id.string().cstring(), _sink_id.string().cstring(), _twopc.txn_id.cstring(), _twopc.current_offset.u64(), _acked_point_of_ref, _pending_writev_total)

    let wb: Writer = wb.create()
    wb.u64_be(_twopc.current_offset.u64())
    wb.u64_be(_acked_point_of_ref)
    let bs = wb.done()

    _event_log.checkpoint_state(_sink_id, checkpoint_id,
      consume bs)

  be prepare_for_rollback() =>
    @ll(_conn_debug, "Prepare for checkpoint rollback at ConnectorSink %s".cstring(), _sink_id.string().cstring())
    _cprb.prepare_for_rollback(this)

  fun ref finish_preparing_for_rollback() =>
    @ll(_conn_debug, "Finish preparing for checkpoint rollback at ConnectorSink %s".cstring(), _sink_id.string().cstring())
    None//TODO

  be rollback(payload: ByteSeq val, event_log: EventLog,
    checkpoint_id: CheckpointId)
  =>
    """
    If we're here, it's implicit that Wallaroo has determinted
    the global status of this checkpoint_id: it was committed.
    We may need to re-send phase2=commit for this checkpoint_id.
    (But that's async from our point of view, beware tricksy bugs....)
    """
    @ll(_conn_info, "Rollback to %s at ConnectorSink %s".cstring(), checkpoint_id.string().cstring(), _sink_id.string().cstring())

    let rollback_to_c_id = _twopc.make_txn_id_string(checkpoint_id)

    let r = Reader
    r.append(payload)
    let current_offset = try r.u64_be()?.usize() else Fail(); 0 end
    _twopc.rollback(current_offset)
    None//TODO
    _acked_point_of_ref = try r.u64_be()? else Fail(); 0 end
    _message_id = _twopc.last_offset.u64()
    @ll(_conn_debug, "rollback payload: current_offset %lu _acked_point_of_ref %lu".cstring(), current_offset, _acked_point_of_ref)

    // The EventLog's payload's data doesn't include the last
    // committed txn_id because at the time that payload was created,
    // we didn't know if the txn-in-progress had committed globally.
    // When rollback() is called here, we now know the global txn
    // commit status: commit for checkpoint_id, all greater are invalid.

    let cbt = CheckpointBarrierToken(checkpoint_id)
    _cprb.rollback(this, cbt)

    None//TODO _twopc.reset_ext_conn_state()
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

            _notify.connected(this, _twopc)
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
          @ll(_conn_info, "Reconnection asio event".cstring())
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

            _notify.connected(this, _twopc)
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
      ifdef "trace-writev" then
        @ll(_conn_debug, "TRACE: ConnectorSink._writev: %s\n".cstring(), _print_array[U8](
          match bytes
          | let s: String val =>
            s.array()
          | let a: Array[U8] val =>
            a
          end).cstring())
      end
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
    _notify.closed(this, _twopc)

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
          if not _notify.received(this, consume data, received_called)
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
      @ll(_conn_info, "RE-Connecting ConnectorSink to %s:%s".cstring(),
                   _host.cstring(), _service.cstring())
      let timer = Timer(PauseBeforeReconnectConnectorSink(this, _auth), _reconnect_pause)
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

  fun prefix_skip(): String =>
    "skip--.--"

  fun prefix_rollback(): String =>
    "rollback--.--"

  /////////////////////////////////////////////////////////
  // EXTERNAL CONNECTION AND CHECKPOINT/ROLLBACK COMPONENTS
  /////////////////////////////////////////////////////////

  fun _make_hello_msg(): cwm.HelloMsg =>
    cwm.HelloMsg(_protocol_version, _cookie, _app_name, _worker_name)

  fun _make_notify1_msg(): cwm.NotifyMsg =>
    cwm.NotifyMsg(_stream_id, _stream_name, _message_id)

  fun ref _make_list_uncommitted_msg_encoded(): Array[U8] val =>
    _rtag = _rtag + 1
    TwoPCEncode.list_uncommitted(_rtag)

  fun ref swap_barrier_to_queued(queue: Array[SinkPhaseQueued] = [],
    forward_tokens: Bool = true, shear_risk: Bool = false) =>
    match _phase
    | let x: QueuingSinkPhase =>
      @ll(_conn_debug, "QQQ: swap_barrier_to_queued: already queuing".cstring())
      None
    | let bsp: BarrierSinkPhase =>
      @ll(_conn_debug, "QQQ: swap_barrier_to_queued: use exising BarrierSinkPhase ?= %s".cstring(), shear_risk.string().cstring())
      if shear_risk then
        bsp.disable_completion_notifies_sink()
        _phase = QueuingSinkPhase(_sink_id, this, queue, forward_tokens
          where forward_token_phase = bsp)
      else
        _phase = QueuingSinkPhase(_sink_id, this, queue, forward_tokens)
      end
    else
      @ll(_conn_debug, "QQQ: swap_barrier_to_queued: forward_tokens = %s queue.size = %lu".cstring(), forward_tokens.string().cstring(), queue.size())
      let forward_token_phase =
        if shear_risk then
          match _phase
          | let bsp: BarrierSinkPhase =>
            @ll(_conn_debug, "QQQ: swap_barrier_to_queued: shear detected!".cstring())
            bsp.disable_completion_notifies_sink()
            bsp
          else
            None
          end
        else
          None
        end
      _phase = QueuingSinkPhase(_sink_id, this, queue, forward_tokens
        where forward_token_phase = forward_token_phase)
    end

  fun ref _get_cprb_member(): _CpRbOps =>
    _cprb

  fun ref _get_ec_member(): _ExtConnOps =>
    _ec

  fun ref _update_cprb_member(next: _CpRbOps) =>
    _cprb = next

  fun ref _update_ec_member(next: _ExtConnOps) =>
    _ec = next

  fun ref cprb_queuing_barrier_drop_app_msgs() =>
    match _phase
    | let qp: QueuingSinkPhase =>
      qp.drop_app_msg_queue()
    else
      Fail()
    end

  fun ref cprb_send_conn_ready() =>
    @ll(_conn_debug, "Send conn_ready to CpRb".cstring())
    _cprb.conn_ready(this)

  fun ref cprb_send_abort_next_checkpoint() =>
    @ll(_conn_debug, "Send abort_next_checkpoint to CpRb".cstring())
    _cprb.abort_next_checkpoint(this)

  fun ref cprb_send_2pc_phase1(barrier_token: CheckpointBarrierToken) =>
    @ll(_twopc_debug, "Send Phase 1 for %s".cstring(),
      barrier_token.string().cstring())
    _twopc.send_phase1(this, barrier_token.id)

  fun ref cprb_send_2pc_phase2(txn_id: String, commit: Bool) =>
    @ll(_twopc_debug, "Send Phase 2 commit=%s for %s".cstring(),
      commit.string().cstring(), txn_id.cstring())
    _twopc.send_phase2(this, txn_id, commit)

  fun ref cprb_send_phase1_result(txn_id: String, commit: Bool) =>
    @ll(_twopc_debug, "Got Phase 1 result: commit=%s for %s".cstring(),
      commit.string().cstring(), txn_id.cstring())
    if commit then
      _cprb.phase1_commit(this, txn_id)
    else
      _cprb.phase1_abort(this, txn_id)
    end

  fun ref cprb_send_commit_to_barrier_coordinator(
    barrier_token: CheckpointBarrierToken)
  =>
    @ll(_conn_debug, "Send commit to barrier coordinator for %s".cstring(), barrier_token.string().cstring())
    _barrier_coordinator.ack_barrier(this, barrier_token)

  fun ref cprb_send_abort_to_barrier_coordinator(
    barrier_token: CheckpointBarrierToken, txn_id: String)
  =>
    @ll(_conn_debug, "Send abort to barrier coordinator for %s".cstring(), barrier_token.string().cstring())
    abort_decision("Phase 2 abort", txn_id, barrier_token)

  fun ref cprb_twopc_clear_txn_id() =>
    _twopc.clear_txn_id()

  fun ref cprb_make_txn_id_string(checkpoint_id: CheckpointId): String =>
    _twopc.make_txn_id_string(checkpoint_id)

  fun ref cprb_get_phase_queued(): Array[SinkPhaseQueued] =>
    _phase.queued()

  fun ref cprb_check_sink_phase_partial_barrier(): (None | BarrierToken) =>
    match _phase
    | let x: BarrierSinkPhase =>
      x.get_barrier_token()
    else
      None
    end

  fun ref cprb_send_rollback_info(barrier_token: CheckpointBarrierToken) =>
    @ll(_conn_debug, "Send rollback_info for %s".cstring(), barrier_token.string().cstring())
    _ec.rollback_info(this, barrier_token)

  fun ref cprb_send_advertise_status(advertise_status: Bool = true) =>
    // FSM state transitions can be lost in cross-CpRb-ExtConn calling.
    // TODO: I've been assuming that all this message stuff is sync.
    //       A behavior makes things async. What does this break, and when?
    @ll(_conn_debug, "Send advertise_status %s".cstring(), advertise_status.string().cstring())
    _ec.set_advertise_status(this, advertise_status)

  fun ref cprb_inject_hard_close() =>
    // FSM state transitions can be lost in cross-CpRb-ExtConn calling.
    // In _hard_close's case, the circular cross-FSM call happens via
    // the ConnectorSinkNotify.closed() -> cb_closed() -> ...
    @ll(_conn_info, "CpRb component is forcing closed the connection via _hard_close()".cstring())
    _hard_close()
    _schedule_reconnect()

  ///////////////////
  // NOTIFY CALLBACKS
  ///////////////////

  fun ref cb_connected() =>
    connected_count = connected_count + 1
    _ec.tcp_connected(this)
    if true then //TODO//
      @ll(_conn_err, "unthrottle early".cstring())
      _notify.unthrottled(this)
    end

  fun ref cb_closed() =>
    _ec.tcp_closed(this)

  fun ref cb_received(data: Array[U8] val): None ?
  =>
    @ll(_conn_debug, "cb_received: top".cstring())
    match cwm.Frame.decode(data)?
    | let m: cwm.HelloMsg =>
      _error_and_close("Protocol error: Sink sent us HelloMsg")
    | let m: cwm.OkMsg =>
      _credits = m.initial_credits
      if _credits < 2 then
        _error_and_close("HEY, too few credits: " + _credits.string())
      else
        @ll(_conn_debug, "cb_received: OkMsg".cstring())
        _ec.handle_message(this, m)
      end
    | let m: cwm.ErrorMsg =>
      _error_and_close("Protocol error: Sink sent us ErrorMsg: %s" + m.message)
    | let m: cwm.NotifyMsg =>
      _error_and_close("Protocol error: Sink sent us NotifyMsg")
    | let m: cwm.NotifyAckMsg =>
      @ll(_conn_debug, "cb_received: NotifyAckMsg".cstring())
      _ec.handle_message(this, m)
    | let m: cwm.MessageMsg =>
      // 2PC messages are sent via MessageMsg on stream_id 0.
      if (m.stream_id != 0) or (m.message is None) then
        _error_and_close("Bad External Connection State: Ea" +
          _ext_conn_state().string())
        return
      end
      @ll(_conn_debug, "cb_received: MessageMsg".cstring())
      _ec.handle_message(this, m)
    | let m: cwm.AckMsg =>
      if _ext_conn_state is ExtConnStateStreaming then
        // NOTE: we aren't actually using credits
        _credits = _credits + m.credits
        for (s_id, p_o_r) in m.credit_list.values() do
          if s_id == _stream_id then
            if p_o_r > _message_id then
              // This is possible with 2PC, but it's harmless if
              // we recognize it and ignore it.
              // 0. The connector sink's p_o_r is 4000.
              // 1. The connector sink sends phase1=abort.
              // 2. We send phase2=abort.
              // 3. The connector sink decides to send an ACK with p_o_r=4000.
              //    This message is delayed just a little bit to make a race.
              // 4. We process prepare_to_rollback & rollback.  Our
              //    _message_id is reset to _message_id=0.  Wallaroo
              //    has fully rolled back state and is ready to resume
              //    all of its work from offset=0.
              // 5. The ACK from step #3 arrives.
              //    4000 > 0, which looks like a terrible state:
              //    we haven't sent anything, but the sink is ACKing
              //    4000 bytes.
              //
              // I am going to disable unsolicited ACK'ing by the
              // connector sink.  Disabling unsolicited ACKs would
              // definitely prevent late-arriving ACKs.  (Will still
              // send ACK in response to Eos.)
              // TODO: Otherwise I believe we'd have to
              // add a checkpoint #/rollback #/state-something to
              // the ACK message to be able to identify late-arriving
              // ACKs.
              None
            elseif p_o_r < _acked_point_of_ref then
              @ll(_conn_err, "Error: Ack: stream-id %lu p_o_r %lu _acked_point_of_ref %lu".cstring(), _stream_id, p_o_r, _acked_point_of_ref)
              Fail()
            else
              _acked_point_of_ref = p_o_r
            end
          else
            @ll(_conn_err, "Ack: unknown stream_id %d".cstring(), s_id)
            Fail()
          end
        end
      else
        _error_and_close("Bad External Connection State: F" +_ext_conn_state().string())
      end
    | let m: cwm.RestartMsg =>
      @ll(_conn_debug, "TRACE: got restart message, closing connection".cstring())
      close()
    end

  fun ref process_uncommitted_list(conn: ConnectorSink ref) =>
    """
    TODO
    """
    None

  fun ref _error_and_close(msg: String) =>
    send_msg(cwm.ErrorMsg(msg))
    close()

  fun ref make_message(encoded1: Array[(String val | Array[U8 val] val)] val):
    cwm.MessageMsg
  =>
    let event_time: cwm.EventTimeType = 0
    let key = None

    let base_message_id = _message_id
    for e in encoded1.values() do
      _message_id = _message_id + e.size().u64()
    end
    cwm.MessageMsg(_stream_id, base_message_id, event_time, key, encoded1)

  fun ref send_msg(msg: cwm.Message) =>
    let w1: Writer = w1.create()

    let bs = cwm.Frame.encode(msg, w1)
    for item in Bytes.length_encode(bs).values() do
      _write_final(item, None)
    end

  fun ref ready_to_work_requested(conn: ConnectorSink ref) =>
    _report_ready_to_work_requested = true
    if _ready_to_work then
      report_ready_to_work()
      _report_ready_to_work_done = true
    end

  fun _print_array[A: U8](array: Array[A] val): String =>
    """
    Generate a printable string of the contents of the given readseq to use in
    error messages.
    """
    ifdef "verbose_debug" then
      if (array.size() == 76) or (array.size() == 77) or (array.size() == 49) or (array.size() == 50) then
        let hack = recover trn Array[U8] end
        let skip = array.size() - match array.size()
          | 76 => 49
          | 77 => 50
          | 49 => 49
          | 50 => 50
          else
            49
          end
        var count: USize = 0
        for b in array.values() do
          if count >= skip then
            hack.push(b)
          end
          count = count + 1
        end
        let hack2 = consume hack
        String.from_array(consume hack2)
      else
        "[len=" + array.size().string() + ": " + ",".join(array.values()) + "]"
      end
    else
      "[len=" + array.size().string() + ": " + "...]"
    end

class PauseBeforeReconnectConnectorSink is TimerNotify
  let _tcp_sink: ConnectorSink
  let _auth: ApplyReleaseBackpressureAuth

  new iso create(tcp_sink: ConnectorSink, auth: ApplyReleaseBackpressureAuth)
  =>
    _tcp_sink = tcp_sink
    _auth = auth

  fun ref apply(timer: Timer, count: U64): Bool =>
    // NOTE: This function is executed in the context of the Timers actor.
    //       If the "owner" of this Timers actor, a ConnectorSink actor,
    //       is under pressure, then the Timers actor can become muted after
    //       sending this reconnect message to the sink.  We avoid muting
    //       the Timers actor by applying backpressure, sending the critical
    //       reconnect message, then releasing backpressure.
    //
    //       We know that no other actor shares a tag to this Timers actor,
    //       so we do not risk muting some other actor by this apply+release
    //       trick.
    Backpressure.apply(_auth)
    _tcp_sink.reconnect()
    Backpressure.release(_auth)
    false
