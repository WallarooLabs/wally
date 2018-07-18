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

use "buffered"
use "collections"
use "net"
use "time"
use "wallaroo/core/boundary"
use "wallaroo/core/common"
use "wallaroo/ent/barrier"
use "wallaroo/ent/data_receiver"
use "wallaroo/ent/recovery"
use "wallaroo/ent/router_registry"
use "wallaroo/ent/snapshot"
use "wallaroo/ent/watermarking"
use "wallaroo_labs/mort"
use "wallaroo/core/initialization"
use "wallaroo/core/invariant"
use "wallaroo/core/metrics"
use "wallaroo/core/routing"
use "wallaroo/core/topology"

use @pony_asio_event_create[AsioEventID](owner: AsioEventNotify, fd: U32,
  flags: U32, nsec: U64, noisy: Bool)
use @pony_asio_event_fd[U32](event: AsioEventID)
use @pony_asio_event_unsubscribe[None](event: AsioEventID)
use @pony_asio_event_resubscribe_read[None](event: AsioEventID)
use @pony_asio_event_resubscribe_write[None](event: AsioEventID)
use @pony_asio_event_destroy[None](event: AsioEventID)

actor TCPSource is (Producer & StatusReporter)
  """
  # TCPSource

  ## Future work
  * Switch to requesting credits via promise
  """
  let _source_id: StepId
  let _auth: AmbientAuth
  let _step_id_gen: StepIdGenerator = StepIdGenerator
  var _router: Router
  let _routes: MapIs[Consumer, Route] = _routes.create()
  // _outputs keeps track of all output targets by step id. There might be
  // duplicate consumers in this map (unlike _routes) since there might be
  // multiple target step ids over a boundary
  let _outputs: Map[StepId, Consumer] = _outputs.create()
  let _outgoing_boundaries: Map[String, OutgoingBoundary] =
    _outgoing_boundaries.create()
  let _layout_initializer: LayoutInitializer
  var _unregistered: Bool = false

  let _metrics_reporter: MetricsReporter

  let _pending_message_store: PendingMessageStore =
    _pending_message_store.create()

  // TCP
  let _listen: TCPSourceListener
  let _notify: TCPSourceNotify
  var _next_size: USize
  let _max_size: USize
  var _connect_count: U32
  var _fd: U32 = -1
  var _expect: USize = 0
  var _connected: Bool = false
  var _closed: Bool = false
  var _event: AsioEventID = AsioEvent.none()
  var _read_buf: Array[U8] iso
  var _read_buf_offset: USize = 0
  var _shutdown_peer: Bool = false
  var _readable: Bool = false
  var _read_len: USize = 0
  var _reading: Bool = false
  var _shutdown: Bool = false
  // Start muted. Wait for unmute to begin processing
  var _muted: Bool = true
  var _disposed: Bool = false
  var _expect_read_buf: Reader = Reader
  let _muted_downstream: SetIs[Any tag] = _muted_downstream.create()
  let _max_received_count: U8 = 50

  let _router_registry: RouterRegistry
  let _state_step_creator: StateStepCreator

  let _event_log: EventLog
  let _acker_x: Acker

  // Producer (Resilience)
  var _seq_id: SeqId = 1 // 0 is reserved for "not seen yet"

  new _accept(source_id: StepId, auth: AmbientAuth, listen: TCPSourceListener,
    notify: TCPSourceNotify iso, event_log: EventLog,
    router: Router,
    outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder] val,
    layout_initializer: LayoutInitializer,
    fd: U32, init_size: USize = 64, max_size: USize = 16384,
    metrics_reporter: MetricsReporter iso, router_registry: RouterRegistry,
    state_step_creator: StateStepCreator)
  =>
    """
    A new connection accepted on a server.
    """
    _source_id = source_id
    _auth = auth
    _event_log = event_log
    _metrics_reporter = consume metrics_reporter
    _listen = listen
    _notify = consume notify
    _connect_count = 0
    _fd = fd
    _event = @pony_asio_event_create(this, fd,
      AsioEvent.read_write_oneshot(), 0, true)
    _connected = true
    _read_buf = recover Array[U8].>undefined(init_size) end
    _next_size = init_size
    _max_size = max_size

    _layout_initializer = layout_initializer
    _router_registry = router_registry
    _state_step_creator = state_step_creator

    for (target_worker_name, builder) in outgoing_boundary_builders.pairs() do
      if not _outgoing_boundaries.contains(target_worker_name) then
        let new_boundary =
          builder.build_and_initialize(_step_id_gen(), target_worker_name,
            _layout_initializer)
        router_registry.register_disposable(new_boundary)
        _outgoing_boundaries(target_worker_name) = new_boundary
      end
    end

    // register resilient with event log
    _event_log.register_resilient(this, _source_id)
    _acker_x = Acker

    _readable = true

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
      _register_output(c_id, consumer)
    end

    _pending_reads()
    //TODO: either only accept when we are done recovering or don't start
    //listening until we are done recovering
    _notify.accepted(this)

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
      r.application_initialized("TCPSource")
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

    _notify.update_router(new_router)
    _pending_message_store.process_known_keys(this, _notify, new_router)

  be remove_route_to_consumer(id: StepId, c: Consumer) =>
    if _outputs.contains(id) then
      ifdef debug then
        Invariant(_routes.contains(c))
      end
      _unregister_output(id, c)
    end

  fun ref _register_output(id: StepId, c: Consumer) =>
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
      ifdef "resilience" then
        _acker_x.add_route(new_route)
      end
      new_route.register_producer(id)
    else
      try
        _routes(c)?.register_producer(id)
      else
        Unreachable()
      end
    end

  fun ref _unregister_output(id: StepId, c: Consumer) =>
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
    don't yet have a boundary to. Each TCPSource has its own
    OutgoingBoundary to each worker to allow for higher throughput.
    """
    for (target_worker_name, builder) in boundary_builders.pairs() do
      if not _outgoing_boundaries.contains(target_worker_name) then
        let boundary = builder.build_and_initialize(_step_id_gen(),
          target_worker_name, _layout_initializer)
        _router_registry.register_disposable(boundary)
        _outgoing_boundaries(target_worker_name) = boundary
        let new_route = RouteBuilder(_source_id, this, boundary,
          _metrics_reporter)
        _acker_x.add_route(new_route)
        _routes(boundary) = new_route
      end
    end
    _notify.update_boundaries(_outgoing_boundaries)

  be remove_boundary(worker: String) =>
    _remove_boundary(worker)

  fun ref _remove_boundary(worker: String) =>
    None
    //!@
    // try
    //   let old_ob = _outgoing_boundaries.remove(worker)?._2
    //   _routes(old_ob)?.dispose()
    //   for (id, c) in _outputs.pairs() do
    //     match c
    //     | let ob: OutgoingBoundary =>
    //       if ob is old_ob then
    //         @printf[I32]("!@ YO UNREGISTER OB\n".cstring())
    //         _unregister_output(id, old_ob)
    //       end
    //     end
    //   end
    // else
    //   Fail()
    // end
    // _notify.update_boundaries(_outgoing_boundaries)

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
      @printf[I32]("request_ack in TCPSource\n".cstring())
    end
    for route in _routes.values() do
      route.request_ack()
    end

  be log_replay_finished() => None

  be replay_log_entry(uid: U128, frac_ids: FractionalMessageId,
    statechange_id: U64, payload: ByteSeq)
  =>
    ifdef "trace" then
      @printf[I32]("replaying log entry on recovery: in TCPSource\n".cstring())
    end
    None

  be initialize_seq_id_on_recovery(seq_id: SeqId) =>
    ifdef "trace" then
      @printf[I32](("initializing sequence id on recovery: " + seq_id.string() +
        " in TCPSource\n").cstring())
    end
    // update to use correct seq_id for recovery
    _seq_id = seq_id

  fun ref _acker(): Acker =>
    _acker_x

  // Override these for TCPSource as we are currently
  // not resilient.
  fun ref flush(low_watermark: U64) =>
    ifdef "trace" then
      @printf[I32]("flushing at and below: %llu in TCPSource\n".cstring(),
        low_watermark)
    end
    _event_log.flush_buffer(_source_id, low_watermark)

  // Log-rotation
  be remote_snapshot_state() =>
    ifdef "trace" then
      @printf[I32]("snapshot_state in TCPSource\n".cstring())
    end
    None

  be log_flushed(low_watermark: SeqId) =>
    ifdef "trace" then
      @printf[I32]("log_flushed for: %llu in TCPSource\n".cstring(),
        low_watermark)
    end
    _acker().flushed(low_watermark)

  fun ref bookkeeping(o_route_id: RouteId, o_seq_id: SeqId) =>
    ifdef "trace" then
      @printf[I32](
        "Bookkeeping called for route %llu, o_seq_id: %llu in TCPSource\n"
        .cstring(), o_route_id, o_seq_id)
    end
    ifdef "resilience" then
      _acker().sent(o_route_id, o_seq_id)
    end

  be update_watermark(route_id: RouteId, seq_id: SeqId) =>
    ifdef "trace" then
      @printf[I32]("TCPSource received update_watermark\n".cstring())
    end
    _update_watermark(route_id, seq_id)

  fun ref _update_watermark(route_id: RouteId, seq_id: SeqId) =>
    ifdef "trace" then
      @printf[I32]((
      "Update watermark called with " +
      "route_id: " + route_id.string() +
      "\tseq_id: " + seq_id.string() + " in TCPSource\n\n").cstring())
    end

    _acker().ack_received(this, route_id, seq_id)

  fun ref _unregister_all_outputs() =>
    """
    This method should only be called if we are removing this source from the
    active graph (or on dispose())
    """
    for (id, consumer) in _outputs.pairs() do
      // @printf[I32]("!@ -- _unregister_all_outputs\n".cstring())
      _unregister_output(id, consumer)
    end

  be dispose() =>
    """
    - Close the connection gracefully.
    """
    if not _disposed then
      _unregister_all_outputs()
      _router_registry.unregister_source(this, _source_id)
      @printf[I32]("Shutting down TCPSource\n".cstring())
      for b in _outgoing_boundaries.values() do
        b.dispose()
      end
      close()
      _disposed = true
    end

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

  fun ref unknown_key(state_name: String, key: Key,
    routing_args: RoutingArguments)
  =>
    _pending_message_store.add(state_name, key, routing_args)
    _state_step_creator.report_unknown_key(this, state_name, key)

  be report_status(code: ReportStatusCode) =>
    match code
    | BoundaryCountStatus =>
      var b_count: USize = 0
      for r in _routes.values() do
        match r
        | let br: BoundaryRoute => b_count = b_count + 1
        end
      end
      @printf[I32]("TCPSource %s has %s boundaries.\n".cstring(),
        _source_id.string().cstring(), b_count.string().cstring())
    end
    for route in _routes.values() do
      route.report_status(code)
    end

  //////////////
  // BARRIER
  //////////////
  be initiate_barrier(token: BarrierToken) =>
    @printf[I32]("!@ Source initiate_barrier\n".cstring())
    for (o_id, o) in _outputs.pairs() do
      match o
      | let ob: OutgoingBoundary =>
        ob.forward_barrier(o_id, _source_id, token)
      else
        o.receive_barrier(_source_id, this, token)
      end
    end

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

  fun ref snapshot_state(snapshot_id: SnapshotId) =>
    // !@
    None

  fun ref snapshot_complete() =>
    // !@
    None

  /////////
  // TCP
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
    else
      if not _unregistered then
        _dispose_routes()
      end
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
    @pony_asio_event_set_readable[None](_event, false)


    @pony_os_socket_close[None](_fd)
    _fd = -1

    _notify.closed(this)

    _listen._conn_closed()
    if not _unregistered then
      _dispose_routes()
    end

  fun ref _dispose_routes() =>
    if not _unregistered then
      for r in _routes.values() do
        r.dispose()
      end
      _unregistered = true
    end
    _muted = true

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
        if _muted then
          _reading = false
          return
        end

        if (_read_buf_offset >= _expect) and (_read_buf_offset != 0) then
          if (_expect == 0) and (_read_buf_offset > 0) then
            let data = _read_buf = recover Array[U8] end
            data.truncate(_read_buf_offset)
            _read_buf_offset = 0

            received_count = received_count + 1
            if not _notify.received(this, consume data) then
              _read_buf_size()
              _read_again()
              _reading = false
              return
            else
              _read_buf_size()
            end
            if received_count >= _max_received_count then
              _read_again()
              _reading = false
              return
            end
          else
            while _read_buf_offset >= _expect do
              let x = _read_buf = recover Array[U8] end
              (let data, _read_buf) = (consume x).chop(_expect)
              _read_buf_offset = _read_buf_offset - _expect

              // increment max reads
              received_count = received_count + 1
              if not _notify.received(this, consume data) then
                _read_buf_size()
                _read_again()
                _reading = false
                return
              end

              if received_count >= _max_received_count then
                _read_buf_size()
                _read_again()
                _reading = false
                return
              end
            end

            _read_buf_size()
          end

          if sum >= _max_size then
            // If we've read _max_size, yield and read again later.
            // _read_buf_size()
            _read_again()
            _reading = false
            return
          end
        else
          if _read_buf.size() > _read_buf_offset then
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
              @pony_asio_event_resubscribe_read(_event)
              _reading = false
              return
            | (_read_buf.size() - _read_buf_offset) =>
              // Increase the read buffer size.
              _next_size = _max_size.min(_next_size * 2)
            end

            _read_buf_offset = _read_buf_offset + len
            sum = sum + len
          else
            _read_buf_size()
            _read_again()
          end
        end
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
      @printf[I32]("Muting TCPSource\n".cstring())
    end
    _muted = true

  fun ref _unmute() =>
    ifdef debug then
      @printf[I32]("Unmuting TCPSource\n".cstring())
    end
    _muted = false
    if not _reading then
      _pending_reads()
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

  fun ref expect(qty: USize = 0) =>
    """
    A `received` call on the notifier must contain exactly `qty` bytes. If
    `qty` is zero, the call can contain any amount of data.
    """
    // TODO: verify that removal of "in_sent" check is harmless
    _expect = _notify.expect(this, qty)
