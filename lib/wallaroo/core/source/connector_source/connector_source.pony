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

use "assert"
use "buffered"
use "collections"
use "net"
use "promises"
use "time"
use "wallaroo/core/barrier"
use "wallaroo/core/boundary"
use "wallaroo/core/checkpoint"
use "wallaroo/core/common"
use "wallaroo/core/data_receiver"
use "wallaroo/core/initialization"
use "wallaroo/core/invariant"
use "wallaroo/core/metrics"
use "wallaroo/core/partitioning"
use "wallaroo/core/recovery"
use "wallaroo/core/registries"
use "wallaroo/core/routing"
use "wallaroo/core/source"
use "wallaroo/core/tcp_actor"
use "wallaroo/core/topology"
use cwm = "wallaroo_labs/connector_wire_messages"
use "wallaroo_labs/logging"
use "wallaroo_labs/mort"

use @l[I32](severity: LogSeverity, category: LogCategory, fmt: Pointer[U8] tag, ...)
use @ll[I32](sev_cat: U16, fmt: Pointer[U8] tag, ...)

actor ConnectorSource[In: Any val] is (Source & TCPActor)
  """
  # ConnectorSource

  ## Future work
  * Switch to requesting credits via promise
  """
  let _source_id: RoutingId
  let _auth: AmbientAuth
  let _routing_id_gen: RoutingIdGenerator = RoutingIdGenerator
  let _string_id_gen: DeterministicSourceIdGenerator =
    DeterministicSourceIdGenerator
  var _router: Router
  let _routes: SetIs[Consumer] = _routes.create()
  var _consumer_sender: TestableConsumerSender
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

  // Connector
  let _listen: ConnectorSourceCoordinator[In]
  let _notify: ConnectorSourceNotify[In]
  var _tcp_handler: TestableTCPHandler = EmptyTCPHandler
  let _tcp_handler_builder: TestableTCPHandlerBuilder

  // Start muted. Wait for unmute to begin processing
  var _muted: Bool = true
  var _disposed: Bool = false
  let _muted_by: SetIs[Any tag] = _muted_by.create()

  let _source_registry: SourceRegistry
  let _disposable_registry: DisposableRegistry

  let _event_log: EventLog

  // Producer (Resilience)
  var _seq_id: SeqId = 1 // 0 is reserved for "not seen yet"

  // Checkpoint
  var _next_checkpoint_id: CheckpointId = 1

  //Session Id
  var _session_id: RoutingId = 0

  new create(source_id: RoutingId, auth: AmbientAuth,
    listen: ConnectorSourceCoordinator[In],
    notify: ConnectorSourceNotify[In] iso,
    event_log: EventLog, router: Router,
    tcp_handler_builder: TestableTCPHandlerBuilder,
    outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder] val,
    layout_initializer: LayoutInitializer,
    metrics_reporter': MetricsReporter iso,
    source_registry: SourceRegistry,
    disposable_registry: DisposableRegistry)
  =>
    """
    A new connection accepted on a server.
    """
    _source_id = source_id
    _auth = auth
    _event_log = event_log
    _tcp_handler_builder = tcp_handler_builder
    _metrics_reporter = consume metrics_reporter'
    _listen = listen
    _notify = consume notify
    _layout_initializer = layout_initializer
    _source_registry = source_registry
    _disposable_registry = disposable_registry
    _router = router
    // We must set this up first so we can pass a ref to ConsumerSender
    _consumer_sender = FailingConsumerSender(_source_id)
    _consumer_sender = ConsumerSender(_source_id, this,
      _metrics_reporter.clone())

    for (target_worker_name, builder) in outgoing_boundary_builders.pairs() do
      if not _outgoing_boundaries.contains(target_worker_name) then
        try
          let boundary_id_string = target_worker_name + _source_id.string() +
            "boundary"
          let new_boundary =
            builder.build_and_initialize(_string_id_gen(boundary_id_string)?,
              target_worker_name, _layout_initializer)
          disposable_registry.register_disposable(new_boundary)
          _outgoing_boundaries(target_worker_name) = new_boundary
        else
          Fail()
        end
      end
    end

    _update_router(router)

    _notify.update_boundaries(_outgoing_boundaries)

    // register resilient with event log
    _event_log.register_resilient(_source_id, this)

    _mute()
    ifdef "resilience" then
      _mute_local()
    end

    ifdef "identify_routing_ids" then
      @l(Log.info(), Log.conn_source(), "===ConnectorSource %s created===\n".cstring(),
        _source_id.string().cstring())
    end

  be accept(fd: U32, init_size: USize = 64, max_size: USize = 16384) =>
    """
    A new connection accepted on a server.
    """
    if not _disposed then
      // Purge pending requests on old session id
      _listen.purge_pending_requests(_session_id)
      // Get new session id for new connection
      _session_id = _routing_id_gen()
      _tcp_handler = _tcp_handler_builder.for_connection(fd, init_size,
        max_size, this, _muted)
      _tcp_handler.accept()
    end

  //!@ Do we need sources to mute local anymore?  Can we remove this?
  be first_checkpoint_complete() =>
    """
    In case we pop into existence midway through a checkpoint, we need to
    wait until this is called to start processing.
    """
    _unmute_local()

  fun ref metrics_reporter(): MetricsReporter =>
    _metrics_reporter

  be update_router(router: Router) =>
    _update_router(router)

  fun ref _update_router(router: Router) =>
    let new_router =
      match router
      | let pr: StatePartitionRouter =>
        pr.update_boundaries(_auth, _outgoing_boundaries)
      | let spr: StatelessPartitionRouter =>
        spr.update_boundaries(_outgoing_boundaries)
      else
        router
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
      _consumer_sender.register_producer(id, c)
    end

  be register_downstream() =>
    _reregister_as_producer()

  fun ref _reregister_as_producer() =>
    if not _disposed then
      for (id, c) in _outputs.pairs() do
        match c
        | let ob: OutgoingBoundary =>
          ob.forward_register_producer(_source_id, id, this)
        else
          c.register_producer(_source_id, this)
        end
      end
    end

  be register_downstreams(promise: Promise[Source]) =>
    promise(this)

  fun ref _unregister_output(id: RoutingId, c: Consumer) =>
    try
      _consumer_sender.unregister_producer(id, c)
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
    don't yet have a boundary to. Each ConnectorSource has its own
    OutgoingBoundary to each worker to allow for higher throughput.
    """
    for (target_worker_name, builder) in boundary_builders.pairs() do
      if not _outgoing_boundaries.contains(target_worker_name) then
        try
          let boundary_id_string = target_worker_name + _source_id.string() +
            "boundary"
          let boundary =
            builder.build_and_initialize(_string_id_gen(boundary_id_string)?,
              target_worker_name, _layout_initializer)
          _disposable_registry.register_disposable(boundary)
          _outgoing_boundaries(target_worker_name) = boundary
          _routes.set(boundary)
        else
          Fail()
        end
      end
    end
    _notify.update_boundaries(_outgoing_boundaries)

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
        @l(Log.debug(), Log.conn_source(), "ConnectorSource couldn't find boundary to %s to disconnect\n"
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
      _source_registry.unregister_source(this, _source_id)
      _event_log.unregister_resilient(_source_id, this)
      _unregister_all_outputs()
      @l(Log.info(), Log.conn_source(), "Shutting down ConnectorSource\n".cstring())
      for b in _outgoing_boundaries.values() do
        b.dispose()
      end
      close()
      _muted = true
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
      @l(Log.info(), Log.conn_source(), "ConnectorSource %s has %s boundaries.\n".cstring(),
        _source_id.string().cstring(), b_count.string().cstring())
    end

  be update_worker_data_service(worker: WorkerName,
    host: String, service: String)
  =>
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
    if not _disposed then
      @l(Log.debug(), Log.conn_source(), "ConnectorSource received initiate_barrier %s\n".cstring(), token.string().cstring())
      _initiate_barrier(token)
    end

  fun ref _initiate_barrier(token: BarrierToken) =>
    match token
    | let srt: CheckpointRollbackBarrierToken =>
      _prepare_for_rollback()
    end

    match token
    | let sbt: CheckpointBarrierToken =>
      _notify.initiate_checkpoint(sbt.id)
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

  be checkpoint_complete(checkpoint_id: CheckpointId) =>
    @l(Log.debug(), Log.conn_source(), "Checkpoint %s complete at ConnectorSource %s\n".cstring(), checkpoint_id.string().cstring(), _source_id.string().cstring())
    _notify.checkpoint_complete(this, checkpoint_id)

  //////////////
  // CHECKPOINTS
  //////////////
  fun ref checkpoint_state(checkpoint_id: CheckpointId) =>
    _next_checkpoint_id = checkpoint_id + 1
    let state = _notify.create_checkpoint_state()
    _event_log.checkpoint_state(_source_id, checkpoint_id, state)

  be prepare_for_rollback() =>
    _prepare_for_rollback()

  fun ref _prepare_for_rollback() =>
    _notify.prepare_for_rollback()

  be rollback(payload: ByteSeq val, event_log: EventLog,
    checkpoint_id: CheckpointId)
  =>
    let p: String ref = p.create()
    match payload
    | let s: String =>
      p.append(s)
    | let ia: Array[U8] val =>
      for c in ia.values() do
        p.push(c)
      end
    end
    ifdef "trace" then
      @l(Log.debug(), Log.conn_source(), "TRACE: %s.%s my source_id = %s, payload.size = %d\n".cstring(),
        __loc.type_name().cstring(), __loc.method_name().cstring(),
        _source_id.string().cstring(), p.size())
    end

    _notify.rollback(this, checkpoint_id, payload)
    _next_checkpoint_id = checkpoint_id + 1
    event_log.ack_rollback(_source_id)

  ///////////////
  // WATERMARKS
  ///////////////
  fun ref check_effective_input_watermark(current_ts: U64): U64 =>
    current_ts

  fun ref update_output_watermark(w: U64): (U64, U64) =>
    (w, w)

  /////////
  // TCP
  /////////
  fun ref tcp_handler(): TestableTCPHandler =>
    _tcp_handler

  //!@ In what sense is this final?
  fun ref writev_final(data: ByteSeqIter) =>
    _tcp_handler.writev(data)

  ///////////////////////////////////////
  // pass through behaviour to the notify
  ///////////////////////////////////////
  be stream_notify_result(session_id': RoutingId, success: Bool,
    stream: StreamTuple)
  =>
    _notify.stream_notify_result(this, session_id', success, stream)

  be begin_shrink() =>
    @l(Log.info(), Log.conn_source(), "ConnectorSource %s beginning shrink migration.\n"
      .cstring(), _source_id.string().cstring())
    _notify.shrink(this)

  be complete_shrink(host: String, service: String) =>
    """
    Send a RESTART message with the (host,service) data that the connector
    should reconnect to.
    """
    @l(Log.info(), Log.conn_source(), ("ConnectorSource %s completed shrink migration with " +
      "new address: (%s, %s).\n").cstring(),
      _source_id.string().cstring(),
      host.cstring(),
      service.cstring())

    _notify.host = host
    _notify.service = service
    _notify.send_restart(this)
    // send_restart calls connector_source.close() at the end

  ///////////////
  // MUTE/UNMUTE
  ///////////////
  fun ref _mute() =>
    ifdef debug then
      @l(Log.debug(), Log.conn_source(), "Muting ConnectorSource\n".cstring())
    end
    _muted = true
    _tcp_handler.mute()

  fun ref _unmute() =>
    ifdef debug then
      @l(Log.debug(), Log.conn_source(), "Unmuting ConnectorSource\n".cstring())
    end
    _muted = false
    _tcp_handler.unmute()

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

  //////////////////////
  // NOTIFY CODE
  //////////////////////
  fun ref accepted() =>
    _notify.accepted(this, _session_id)

  fun ref closed(locally_initiated_close: Bool) =>
    _notify.closed(this)
    _listen._conn_closed(_source_id, this)

  fun ref received(data: Array[U8] iso, times: USize): Bool =>
    _notify.received(this, consume data, _consumer_sender)

  fun ref throttled() =>
    _notify.throttled(this)

  fun ref unthrottled() =>
    _notify.unthrottled(this)
