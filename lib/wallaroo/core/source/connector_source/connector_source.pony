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
use "wallaroo/core/boundary"
use "wallaroo/core/common"
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
use cwm = "wallaroo_labs/connector_wire_messages"
use "wallaroo_labs/mort"

use @pony_asio_event_create[AsioEventID](owner: AsioEventNotify, fd: U32,
  flags: U32, nsec: U64, noisy: Bool)
use @pony_asio_event_fd[U32](event: AsioEventID)
use @pony_asio_event_unsubscribe[None](event: AsioEventID)
use @pony_asio_event_resubscribe_read[None](event: AsioEventID)
use @pony_asio_event_resubscribe_write[None](event: AsioEventID)
use @pony_asio_event_destroy[None](event: AsioEventID)
use @pony_asio_event_set_writeable[None](event: AsioEventID, writeable: Bool)


actor ConnectorSource[In: Any val] is Source
  """
  # ConnectorSource

  ## Future work
  * Switch to requesting credits via promise
  """
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

  // Connector
  let _listen: ConnectorSourceListener[In]
  let _notify: ConnectorSourceNotify[In]
  var _next_size: USize = 0
  var _max_size: USize = 0
  var _connect_count: U32 = 0
  var _fd: U32 = -1
  var _expect: USize = 0
  var _connected: Bool = false
  var _closed: Bool = false
  var _event: AsioEventID = AsioEvent.none()
  // _pending is used to avoid GC prematurely reaping memory.
  // See GitHub bug 2526 for more.  It looks like a write-only
  // data structure, but its use is vital to avoid GC races:
  // _pending_writev's C pointers are invisible to ORCA.
  embed _pending: Array[ByteSeq] = _pending.create()
  embed _pending_writev: Array[USize] = _pending_writev.create()
  var _pending_sent: USize = 0
  var _pending_writev_total: USize = 0
  var _read_buf: Array[U8] iso = recover Array[U8] end
  var _read_buf_offset: USize = 0
  var _shutdown_peer: Bool = false
  var _readable: Bool = false
  var _writeable: Bool = false
  var _throttled: Bool = false
  var _reading: Bool = false
  var _shutdown: Bool = false
  // Start muted. Wait for unmute to begin processing
  var _muted: Bool = true
  var _disposed: Bool = false
  var _expect_read_buf: Reader = Reader
  var _max_received_count: U8 = 50
  let _muted_by: SetIs[Any tag] = _muted_by.create()

  var _is_pending: Bool = true

  let _router_registry: RouterRegistry

  let _event_log: EventLog

  // Producer (Resilience)
  var _seq_id: SeqId = 1 // 0 is reserved for "not seen yet"

  // Checkpoint
  var _next_checkpoint_id: CheckpointId = 1

  //Session Id
  var _session_id: RoutingId = 0

  new create(source_id: RoutingId, auth: AmbientAuth,
    listen: ConnectorSourceListener[In],
    notify_parameters: ConnectorSourceNotifyParameters[In],
    event_log: EventLog, router': Router,
    outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder] val,
    layout_initializer: LayoutInitializer,
    metrics_reporter': MetricsReporter iso, router_registry: RouterRegistry)
  =>
    """
    A new connection accepted on a server.
    """
    _source_id = source_id
    _auth = auth
    _event_log = event_log
    _metrics_reporter = consume metrics_reporter'
    _listen = listen
    _notify = ConnectorSourceNotify[In](source_id, notify_parameters,
      _listen)
    _layout_initializer = layout_initializer
    _router_registry = router_registry

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

    _notify.update_boundaries(_outgoing_boundaries)

    // register resilient with event log
    _event_log.register_resilient_source(_source_id, this)

    _mute()
    ifdef "resilience" then
      _mute_local()
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
      // update notify's session value
      _notify.accepted(this, _session_id)

      _connect_count = 0
      _fd = fd
      _event = @pony_asio_event_create(this, fd,
        AsioEvent.read_write_oneshot(), 0, true)
      _connected = true
      ifdef not windows then
        @pony_asio_event_set_writeable(_event, true)
      end
      _writeable = true
      _throttled = false
      _read_buf = recover Array[U8].>undefined(init_size) end
      _read_buf_offset = 0
      _next_size = init_size
      _max_size = max_size

      _readable = true
      _closed = false
      _shutdown = false
      _shutdown_peer = false

      _pending.clear()
      _pending_writev.clear()
      _pending_sent = 0
      _pending_writev_total = 0

      _pending_reads()
    end

  fun ref writev_final(datav: ByteSeqIter) =>
    if _connected and not _closed then
      ifdef windows then
        Fail()
      else
        for data in datav.values() do
          _pending_writev .> push(data.cpointer().usize()) .> push(data.size())
          _pending_writev_total = _pending_writev_total + data.size()
          _pending.push(data)
        end
      end
      _pending_writes()
    end

  fun ref _complete_writes(len: U32) =>
    """
    The OS has informed us that `len` bytes of pending writes have completed.
    This occurs only with IOCP on Windows.
    """
    ifdef windows then
      Fail()
    end

  fun ref _pending_writes(): Bool =>
    """
    Send pending data. If any data can't be sent, keep it and mark as not
    writeable. On an error, dispose of the connection. Returns whether
    it sent all pending data or not.
    """
    ifdef not windows then
      // TODO: Make writev_batch_size user configurable
      let writev_batch_size: USize = @pony_os_writev_max[I32]().usize()
      var num_to_send: USize = 0
      var bytes_to_send: USize = 0
      while _writeable and (_pending_writev_total > 0) do
        try
          // Determine number of bytes and buffers to send.
          if (_pending_writev.size() / 2) < writev_batch_size then
            num_to_send = _pending_writev.size() / 2
            bytes_to_send = _pending_writev_total
          else
            // Have more buffers than a single writev can handle.
            // Iterate over buffers being sent to add up total.
            num_to_send = writev_batch_size
            bytes_to_send = 0
            for d in Range[USize](1, num_to_send * 2, 2) do
              bytes_to_send = bytes_to_send + _pending_writev(d)?
            end
          end

          // Write as much data as possible.
          var len = @pony_os_writev[USize](_event,
            _pending_writev.cpointer(), num_to_send.i32()) ?

          if _manage_pending_buffer(len, bytes_to_send, num_to_send)? then
            return true
          end
        else
          // Non-graceful shutdown on error.
          _hard_close()
        end
      end
    end

    false

  fun ref _manage_pending_buffer(
    bytes_sent: USize,
    bytes_to_send: USize,
    num_to_send: USize)
    : Bool ?
  =>
    """
    Manage pending buffer for data sent. Returns a boolean of whether
    the pending buffer is empty or not.
    """
    var len = bytes_sent
    if len < bytes_to_send then
      while len > 0 do
        let iov_p =
          ifdef windows then
            _pending_writev(1)?
          else
            _pending_writev(0)?
          end
        let iov_s =
          ifdef windows then
            _pending_writev(0)?
          else
            _pending_writev(1)?
          end
        if iov_s <= len then
          len = len - iov_s
          _pending_writev.shift()?
          _pending_writev.shift()?
          _pending.shift()?
          ifdef windows then
            _pending_sent = _pending_sent - 1
          end
          _pending_writev_total = _pending_writev_total - iov_s
        else
          ifdef windows then
            _pending_writev.update(1, iov_p+len)?
            _pending_writev.update(0, iov_s-len)?
          else
            _pending_writev.update(0, iov_p+len)?
            _pending_writev.update(1, iov_s-len)?
          end
          _pending_writev_total = _pending_writev_total - len
          len = 0
        end
      end
      ifdef not windows then
        _apply_backpressure()
      end
    else
      // sent all data we requested in this batch
      _pending_writev_total = _pending_writev_total - bytes_to_send
      if _pending_writev_total == 0 then
        _pending_writev.clear()
        _pending.clear()
        ifdef windows then
          _pending_sent = 0
        end
        return true
      else
        for d in Range[USize](0, num_to_send, 1) do
          _pending_writev.shift()?
          _pending_writev.shift()?
          _pending.shift()?
          ifdef windows then
            _pending_sent = _pending_sent - 1
          end
        end
      end
    end

    false

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
    don't yet have a boundary to. Each ConnectorSource has its own
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
        @printf[I32]("ConnectorSource couldn't find boundary to %s to disconnect\n"
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
      @printf[I32]("Shutting down ConnectorSource\n".cstring())
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
      @printf[I32]("ConnectorSource %s has %s boundaries.\n".cstring(),
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
    if not _is_pending and not _disposed then
      ifdef "checkpoint_trace" then
        @printf[I32]("ConnectorSource received initiate_barrier %s\n"
          .cstring(), token.string().cstring())
      end
      _initiate_barrier(token)
    else
      @printf[I32]("ConnectorSource received initiate_barrier %s NOT IS_PENDING AND NOT DISPOSED\n"
          .cstring(), token.string().cstring())
    end

  fun ref _initiate_barrier(token: BarrierToken) =>
    match token
    | let srt: CheckpointRollbackBarrierToken =>
      _prepare_for_rollback()
    end

    match token
    | let sbt: CheckpointBarrierToken =>
      _notify.initiate_barrier(sbt.id)
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

  be barrier_fully_acked(token: BarrierToken) =>
    ifdef "checkpoint_trace" then
      @printf[I32]("barrier_complete at ConnectorSource %s\n".cstring(),
        _source_id.string().cstring())
    end
    match token
    | let sbt: CheckpointBarrierToken =>
      _notify.barrier_complete(this, sbt.id)
    else
      @printf[I32]("DEBUG %s.%s when %s\n".cstring(),
        __loc.type_name().cstring(), __loc.method_name().cstring(),
        token.string().cstring())
      // TODO [post-source-migration]: this shouldn't actually fail, there are
      // many barrier token types for which it's safe to do nothing.
      // Bug john for documentation on this.
      // TODO [post-source-migration]: Check with John on whether this is okay
      None
    end

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
      @printf[I32]("TRACE: %s.%s my source_id = %s, payload.size = %d\n".cstring(),
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
  // Connector
  /////////
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
      if AsioEvent.writeable(flags) then
        _writeable = true
        _complete_writes(arg)
        ifdef not windows then
          if _pending_writes() then
            // Sent all data. Release backpressure.
            _release_backpressure()
          end
        end
      end

      if _connected and not _shutdown_peer then
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

  fun ref _notify_connecting() =>
    """
    Inform the notifier that we're connecting.
    """
    if _connect_count > 0 then
      _notify.connecting(this, _connect_count)
    else
      _notify.connect_failed(this)
      _hard_close()
    end

  fun ref close() =>
    """
    Shut our connection down immediately. Stop reading data from the incoming
    source.
    """
    _hard_close()

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
      (_connect_count == 0)
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
    _readable = false
    _writeable = false
    @pony_asio_event_set_readable[None](_event, false)

    @pony_os_socket_close[None](_fd)
    _fd = -1

    _event = AsioEvent.none()
    _expect_read_buf.clear()
    _expect = 0

    _notify.closed(this)

    _listen._conn_closed(_source_id, this)

  fun ref _apply_backpressure() =>
    if not _throttled then
      _throttled = true
      _notify.throttled(this)
    end
    ifdef not windows then
      _writeable = false

      // this is safe because asio thread isn't currently subscribed
      // for a write event so will not be writing to the readable flag
      @pony_asio_event_set_writeable(_event, false)
      @pony_asio_event_resubscribe_write(_event)
    end

  fun ref _release_backpressure() =>
    if _throttled then
      _throttled = false
      _notify.unthrottled(this)
    end

  fun ref _pending_reads() =>
    """
    Unless this connection is currently muted, read while data is available,
    guessing the next packet length as we go. If we read 5 kb of data, send
    ourself a resume message and stop reading, to avoid starving other actors.
    Currently we can handle a varying value of _expect (greater than 0) and
    constant _expect of 0 but we cannot handle switching between these two
    cases.
    """
    try
      var sum: USize = 0
      var received_count: U8 = 0
      _reading = true

      while _readable and not _shutdown_peer do
        // exit if muted
        if _muted then
          _reading = false
          return
        end

        // distribute and data we've already read that is in the `read_buf`
        // and able to be distributed
        while (_read_buf_offset >= _expect) and (_read_buf_offset > 0) do
          // get data to be distributed and update `_read_buf_offset`
          let data =
            if _expect == 0 then
              let data' = _read_buf = recover Array[U8] end
              data'.truncate(_read_buf_offset)
              _read_buf_offset = 0
              consume data'
            else
              let x = _read_buf = recover Array[U8] end
              (let data', _read_buf) = (consume x).chop(_expect)
              _read_buf_offset = _read_buf_offset - _expect
              consume data'
            end

          // increment max reads
          received_count = received_count + 1

          // check if we should yield to let another actor run
          if (not _notify.received(this, consume data))
            or (received_count >= _max_received_count)
          then
            _read_buf_size()
            _read_again()
            _reading = false
            return
          end
        end

        if sum >= _max_size then
          // If we've read _max_size, yield and read again later.
          _read_buf_size()
          _read_again()
          _reading = false
          return
        end

        // make sure we have enough space to read enough data for _expect
        if _read_buf.size() <= _read_buf_offset then
          _read_buf_size()
        end

        // Read as much data as possible.
        let len = @pony_os_recv[USize](
          _event,
          _read_buf.cpointer(_read_buf_offset),
          _read_buf.size() - _read_buf_offset) ?

        match len
        | 0 =>
          // Would block, try again later.
          // this is safe because asio thread isn't currently subscribed
          // for a read event so will not be writing to the readable flag
          @pony_asio_event_set_readable[None](_event, false)
          _readable = false
          _reading = false
          @pony_asio_event_resubscribe_read(_event)
          return
        | (_read_buf.size() - _read_buf_offset) =>
          // Increase the read buffer size.
          _next_size = _max_size.min(_next_size * 2)
        end

        _read_buf_offset = _read_buf_offset + len
        sum = sum + len
      end
    else
      // The socket has been closed from the other side.
      _shutdown_peer = true
      _hard_close()
    end

    _reading = false

  be _read_again() =>
    """
    Resume reading.
    """
    _pending_reads()

  fun ref _read_buf_size() =>
    """
    Resize the read buffer.
    """
    if _expect != 0 then
      _read_buf.undefined(_expect.next_pow2().max(_next_size))
    else
      _read_buf.undefined(_next_size)
    end

  fun ref _mute() =>
    ifdef debug then
      @printf[I32]("Muting ConnectorSource\n".cstring())
    end
    _muted = true

  fun ref _unmute() =>
    ifdef debug then
      @printf[I32]("Unmuting ConnectorSource\n".cstring())
    end
    _muted = false
    if not _reading then
      _pending_reads()
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

  fun ref expect(qty: USize = 0) =>
    """
    A `received` call on the notifier must contain exactly `qty` bytes. If
    `qty` is zero, the call can contain any amount of data.
    """
    // TODO: verify that removal of "in_sent" check is harmless
    _expect = _notify.expect(this, qty)

  ///////////////////////////////////////
  // pass through behaviour to the notify
  ///////////////////////////////////////
  be stream_notify_result(session_id': RoutingId, success: Bool,
    stream: StreamTuple)
  =>
    _notify.stream_notify_result(this, session_id', success, stream)

  be begin_shrink() =>
    @printf[I32]("ConnectorSource %s beginning shrink migration.\n"
      .cstring(), _source_id.string().cstring())
    _notify.shrink(this)

  be complete_shrink(host: String, service: String) =>
    """
    Send a RESTART message with the (host,service) data that the connector
    should reconnect to.
    """
    @printf[I32](("ConnectorSource %s completed shrink migration with " +
      "new address: (%s, %s).\n").cstring(),
      _source_id.string().cstring(),
      host.cstring(),
      service.cstring())

    _notify.host = host
    _notify.service = service
    _notify.send_restart(this)
    // send_restart calls connector_source.close() at the end
