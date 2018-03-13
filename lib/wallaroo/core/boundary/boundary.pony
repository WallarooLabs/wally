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
use "wallaroo_labs/bytes"
use "wallaroo_labs/time"
use "wallaroo/core/common"
use "wallaroo/ent/network"
use "wallaroo/ent/spike"
use "wallaroo/ent/watermarking"
use "wallaroo_labs/mort"
use "wallaroo_labs/testing"
use "wallaroo/core/initialization"
use "wallaroo/core/invariant"
use "wallaroo/core/messages"
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


class val OutgoingBoundaryBuilder
  let _auth: AmbientAuth
  let _worker_name: String
  let _reporter: MetricsReporter val
  let _host: String
  let _service: String
  let _spike_config: (SpikeConfig | None)

  new val create(auth: AmbientAuth, name: String, r: MetricsReporter iso,
    h: String, s: String, spike_config: (SpikeConfig | None) = None)
  =>
    _auth = auth
    _worker_name = name
    _reporter = consume r
    _host = h
    _service = s
    _spike_config = spike_config

  fun apply(step_id: StepId): OutgoingBoundary =>
    let boundary = OutgoingBoundary(_auth, _worker_name, _reporter.clone(),
      _host, _service where spike_config = _spike_config)
    boundary.register_step_id(step_id)
    boundary

  fun build_and_initialize(step_id: StepId,
    layout_initializer: LayoutInitializer): OutgoingBoundary
  =>
    """
    Called when creating a boundary post cluster initialization
    """
    let boundary = OutgoingBoundary(_auth, _worker_name, _reporter.clone(),
      _host, _service where spike_config = _spike_config)
    boundary.register_step_id(step_id)
    boundary.quick_initialize(layout_initializer)
    boundary

actor OutgoingBoundary is Consumer
  // Steplike
  let _wb: Writer = Writer
  let _metrics_reporter: MetricsReporter

  // Lifecycle
  var _initializer: (LayoutInitializer | None) = None
  var _reported_initialized: Bool = false
  var _reported_ready_to_work: Bool = false

  // Consumer
  var _upstreams: SetIs[Producer] = _upstreams.create()
  var _mute_outstanding: Bool = false

  // TCP
  var _notify: WallarooOutgoingNetworkActorNotify
  var _read_buf: Array[U8] iso
  var _next_size: USize
  let _max_size: USize
  var _connect_count: U32 = 0
  var _fd: U32 = -1
  var _in_sent: Bool = false
  var _expect: USize = 0
  var _connected: Bool = false
  var _closed: Bool = false
  var _writeable: Bool = false
  var _throttled: Bool = false
  var _event: AsioEventID = AsioEvent.none()
  embed _pending: List[(ByteSeq, USize)] = _pending.create()
  embed _pending_writev: Array[USize] = _pending_writev.create()
  var _pending_writev_total: USize = 0
  var _shutdown_peer: Bool = false
  var _readable: Bool = false
  var _read_len: USize = 0
  var _shutdown: Bool = false
  var _muted: Bool = false
  var _no_more_reconnect: Bool = false
  var _expect_read_buf: Reader = Reader

  // Connection, Acking and Replay
  var _connection_initialized: Bool = false
  var _replaying: Bool = false
  let _auth: AmbientAuth
  let _worker_name: String
  var _step_id: StepId = 0
  let _host: String
  let _service: String
  let _from: String
  let _queue: Array[Array[ByteSeq] val] = _queue.create()
  var _lowest_queue_id: SeqId = 0
  // TODO: this should go away and TerminusRoute entirely takes
  // over seq_id generation whether there is resilience or not.
  var _seq_id: SeqId = 1

  // Producer (Resilience)
  let _terminus_route: TerminusRoute = TerminusRoute

  var _reconnect_pause: U64 = 10_000_000_000
  let _timers: Timers = Timers

  new create(auth: AmbientAuth, worker_name: String,
    metrics_reporter: MetricsReporter iso, host: String, service: String,
    from: String = "", init_size: USize = 64, max_size: USize = 16384,
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
        var notify = recover iso BoundaryNotify(_auth, this) end
        _notify = SpikeWrapper(consume notify, sc)
      else
        _notify = BoundaryNotify(_auth, this)
      end
    else
      _notify = BoundaryNotify(_auth, this)
    end

    _worker_name = worker_name
    _host = host
    _service = service
    _from = from
    _metrics_reporter = consume metrics_reporter
    _read_buf = recover Array[U8].>undefined(init_size) end
    _next_size = init_size
    _max_size = 65_536

  //
  // Application startup lifecycle event
  //

  be application_begin_reporting(initializer: LocalTopologyInitializer) =>
    _initializer = initializer
    initializer.report_created(this)

  be application_created(initializer: LocalTopologyInitializer,
    omni_router: OmniRouter)
  =>
    _connect_count = @pony_os_connect_tcp[U32](this,
      _host.cstring(), _service.cstring(),
      _from.cstring())
    _notify_connecting()

    @printf[I32](("Connecting OutgoingBoundary to " + _host + ":" + _service +
      "\n").cstring())

  be application_initialized(initializer: LocalTopologyInitializer) =>
    try
      if _step_id == 0 then
        Fail()
      end

      let connect_msg = ChannelMsgEncoder.data_connect(_worker_name, _step_id,
        _auth)?
      _writev(connect_msg)
    else
      Fail()
    end

  be application_ready_to_work(initializer: LocalTopologyInitializer) =>
    None

  be quick_initialize(initializer: LayoutInitializer) =>
    """
    Called when initializing as part of a new worker joining a running cluster.
    """
    try
      _initializer = initializer
      _reported_initialized = true
      _reported_ready_to_work = true
      _connect_count = @pony_os_connect_tcp[U32](this,
        _host.cstring(), _service.cstring(),
        _from.cstring())
      _notify_connecting()

      @printf[I32](("Connecting OutgoingBoundary to " + _host + ":" +
        _service + "\n").cstring())

      if _step_id == 0 then
        Fail()
      end

      let connect_msg = ChannelMsgEncoder.data_connect(_worker_name, _step_id,
        _auth)?
      _writev(connect_msg)
    else
      Fail()
    end

  be reconnect() =>
    if not _connected and not _no_more_reconnect then
      _connect_count = @pony_os_connect_tcp[U32](this,
        _host.cstring(), _service.cstring(),
        _from.cstring())
      _notify_connecting()
    end

    @printf[I32](("RE-Connecting OutgoingBoundary to " + _host + ":" + _service
      + "\n").cstring())

  be migrate_step[K: (Hashable val & Equatable[K] val)](step_id: StepId,
    state_name: String, key: K, state: ByteSeq val)
  =>
    try
      let outgoing_msg = ChannelMsgEncoder.migrate_step[K](step_id,
        state_name, key, state, _worker_name, _auth)?
      _writev(outgoing_msg)
    else
      Fail()
    end

  be send_migration_batch_complete() =>
    try
      let migration_batch_complete_msg =
        ChannelMsgEncoder.migration_batch_complete(_worker_name, _auth)?
      _writev(migration_batch_complete_msg)
    else
      Fail()
    end

  be register_step_id(step_id: StepId) =>
    _step_id = step_id

  be run[D: Any val](metric_name: String, pipeline_time_spent: U64, data: D,
    producer: Producer, msg_uid: MsgId, frac_ids: FractionalMessageId,
    seq_id: SeqId, route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    // Run should never be called on an OutgoingBoundary
    Fail()

  be replay_run[D: Any val](metric_name: String, pipeline_time_spent: U64,
    data: D, producer: Producer, msg_uid: MsgId, frac_ids: FractionalMessageId,
    incoming_seq_id: SeqId, route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    // Should never be called on an OutgoingBoundary
    Fail()

  // TODO: open question: how do we reconnect if our external system goes away?
  be forward(delivery_msg: ReplayableDeliveryMsg, pipeline_time_spent: U64,
    i_producer: Producer, i_seq_id: SeqId, i_route_id: RouteId, latest_ts: U64,
    metrics_id: U16, worker_ingress_ts: U64)
  =>
    let metric_name = delivery_msg.metric_name()
    // TODO: delete
    let msg_uid = delivery_msg.msg_uid()

    ifdef "trace" then
      @printf[I32]("Rcvd pipeline message at OutgoingBoundary\n".cstring())
    end

    let my_latest_ts = ifdef "detailed-metrics" then
        Time.nanos()
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
      let seq_id = ifdef "resilience" then
        _terminus_route.terminate(i_producer, i_route_id, i_seq_id)
      else
        _seq_id = _seq_id + 1
      end

      let outgoing_msg = ChannelMsgEncoder.data_channel(delivery_msg,
        pipeline_time_spent + (Time.nanos() - worker_ingress_ts),
        seq_id, _wb, _auth, WallClock.nanoseconds(),
        new_metrics_id, metric_name)?
      _add_to_upstream_backup(outgoing_msg)

      if _connection_initialized then
        _writev(outgoing_msg)
      end

      let end_ts = Time.nanos()

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

  be writev(data: Array[ByteSeq] val) =>
    _writev(data)

  be receive_state(state: ByteSeq val) => Fail()

  fun ref receive_ack(seq_id: SeqId) =>
    ifdef debug then
      Invariant(seq_id > _lowest_queue_id)
    end

    ifdef "trace" then
      @printf[I32](
        "OutgoingBoundary: got ack from downstream worker\n".cstring())
    end

    let flush_count: USize = (seq_id - _lowest_queue_id).usize()
    _queue.remove(0, flush_count)
    _maybe_mute_or_unmute_upstreams()
    _lowest_queue_id = _lowest_queue_id + flush_count.u64()

    ifdef "resilience" then
      _terminus_route.receive_ack(seq_id)
    end

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
    _maybe_mute_or_unmute_upstreams()

  fun ref _replay_from(idx: SeqId) =>
    try
      var cur_id = _lowest_queue_id
      for msg in _queue.values() do
        if cur_id >= idx then
          _writev(ChannelMsgEncoder.replay(msg, _auth)?)
        end
        cur_id = cur_id + 1
      end
      _writev(ChannelMsgEncoder.replay_complete(_worker_name, _step_id, _auth)?)
    else
      Fail()
    end

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
    _no_more_reconnect = true
    _timers.dispose()
    close()
    _notify.dispose()

  be request_ack() =>
    // TODO: How do we propagate this down?
    None

  be register_producer(producer: Producer) =>
    ifdef debug then
      Invariant(not _upstreams.contains(producer))
    end

    _upstreams.set(producer)

  be unregister_producer(producer: Producer) =>
    // TODO: Determine if we need this Invariant.
    // ifdef debug then
    //   Invariant(_upstreams.contains(producer))
    // end

    _upstreams.unset(producer)

  //
  // TCP
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
            _on_connected()
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
        elseif not _connected and _closed then
          @printf[I32]("Reconnection asio event\n".cstring())
          if @pony_os_connected[Bool](fd) then
            // The connection was successful, make it ours.
            _fd = fd
            _event = event

            // clear anything pending to be sent because on recovery we're
            // going to have to replay from our queue when requested
            _pending_writev.clear()
            _pending.clear()
            _pending_writev_total = 0

            _connected = true
            _writeable = true
            _readable = true

            // set replaying to true since we might need to replay to
            // downstream before resuming
            _replaying = true

            _closed = false
            _shutdown = false
            _shutdown_peer = false

            _notify.connected(this)
            _pending_reads()

            try
              let connect_msg = ChannelMsgEncoder.data_connect(_worker_name,
                _step_id, _auth)?
              _writev(connect_msg)
            else
              @printf[I32]("error creating data connect message on reconnect\n"
                .cstring())
            end

            ifdef not windows then
              if _pending_writes() then
                //sent all data; release backpressure
                _release_backpressure()
              end
            end
            _maybe_mute_or_unmute_upstreams()
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

  fun ref _on_connected() =>
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
    if (_host != "") and (_service != "") and not _no_more_reconnect then
      @printf[I32]("RE-Connecting OutgoingBoundary to %s:%s\n".cstring(),
        _host.cstring(), _service.cstring())
      let timer = Timer(_PauseBeforeReconnect(this), _reconnect_pause)
      _timers(consume timer)
    end

  fun ref _writev(data: ByteSeqIter) =>
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

    _pending_writes()

    _in_sent = false

  fun ref _write_final(data: ByteSeq) =>
    """
    Write as much as possible to the socket. Set _writeable to false if not
    everything was written. On an error, close the connection. This is for
    data that has already been transformed by the notifier.
    """
    _pending_writev.>push(data.cpointer().usize()).>push(data.size())
    _pending_writev_total = _pending_writev_total + data.size()

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
    _pending_writev.clear()
    _pending.clear()
    _pending_writev_total = 0
    _readable = false
    _writeable = false
    @pony_asio_event_set_readable[None](_event, false)
    @pony_asio_event_set_writeable[None](_event, false)

    @pony_os_socket_close[None](_fd)
    _fd = -1

    _notify.closed(this)
    _connection_initialized = false

  fun ref _pending_reads() =>
    """
    Unless this connection is currently muted, read while data is available,
    guessing the next packet length as we go. If we read 4 kb of data, send
    ourself a resume message and stop reading, to avoid starving other actors.
    """
    try
      var sum: USize = 0
      var received_called: USize = 0

      while _readable and not _shutdown_peer do
        if _muted then
          return
        end

        // Read as much data as possible.
        let len = @pony_os_recv[USize](
          _event,
          _read_buf.cpointer().usize() + _read_len,
          _read_buf.size() - _read_len) ?

        match len
        | 0 =>
          // Would block, try again later.
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

  be _read_again() =>
    """
    Resume reading.
    """
    _pending_reads()

  fun ref _pending_writes(): Bool =>
    """
    Send pending data. If any data can't be sent, keep it and mark as not
    writeable. On an error, dispose of the connection. Returns whether
    it sent all pending data or not.
    """
    // TODO: Make writev_batch_size user configurable
    let writev_batch_size: USize = @pony_os_writev_max[I32]().usize()
    var num_to_send: USize = 0
    var bytes_to_send: USize = 0
    var bytes_sent: USize = 0
    while _writeable and not _shutdown_peer and (_pending_writev_total > 0) do
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

    false

  fun ref _read_buf_size() =>
    """
    Resize the read buffer.
    """
    if _expect != 0 then
      _read_buf.undefined(_expect)
    else
      _read_buf.undefined(_next_size)
    end

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

  fun local_address(): NetAddress =>
    """
    Return the local IP address.
    """
    let ip = recover NetAddress end
    @pony_os_sockname[Bool](_fd, ip)
    ip

  fun ref set_nodelay(state: Bool) =>
    """
    Turn Nagle on/off. Defaults to on. This can only be set on a connected
    socket.
    """
    if _connected then
      @pony_os_nodelay[None](_fd, state)
    end

  fun ref _add_to_upstream_backup(msg: Array[ByteSeq] val) =>
    _queue.push(msg)
    _maybe_mute_or_unmute_upstreams()

  fun ref _apply_backpressure() =>
    if not _throttled then
      _throttled = true
      _writeable = false
      // this is safe because asio thread isn't currently subscribed
      // for a write event so will not be writing to the readable flag
      @pony_asio_event_set_writeable[None](_event, false)
      @pony_asio_event_resubscribe_write(_event)
      _notify.throttled(this)
      _maybe_mute_or_unmute_upstreams()
    end

  fun ref _release_backpressure() =>
    if _throttled then
      _throttled = false
      _notify.unthrottled(this)
      _maybe_mute_or_unmute_upstreams()
    end

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
    _connected and
      _writeable and
      not _closed and
      not _replaying and
      not _backup_queue_is_overflowing()

  fun _backup_queue_is_overflowing(): Bool =>
    _queue.size() >= 16_384

  fun ref set_so_sndbuf(bufsiz: U32): U32 =>
    @printf[I32]("OutgoingBoundary set_so_sndbuf arg = %d\n".cstring(), bufsiz)
    (let x1: U32, let x2: U32) = OSSocket.get_so_sndbuf(_fd)
    @printf[I32]("OutgoingBoundary get SO_SNDBUF = %d %d\n".cstring(), x1, x2)
    let y: U32 = OSSocket.set_so_sndbuf(_fd, bufsiz)
    @printf[I32]("OutgoingBoundary set SO_SNDBUF = %d\n".cstring(), y)
    (let z1: U32, let z2: U32) = OSSocket.get_so_sndbuf(_fd)
    @printf[I32]("OutgoingBoundary get SO_SNDBUF = %d %d\n".cstring(), z1, z2)
    y

class BoundaryNotify is WallarooOutgoingNetworkActorNotify
  let _auth: AmbientAuth
  var _header: Bool = true
  let _outgoing_boundary: OutgoingBoundary tag
  let _reconnect_closed_delay: U64
  let _reconnect_failed_delay: U64

  new create(auth: AmbientAuth, outgoing_boundary: OutgoingBoundary tag,
    reconnect_closed_delay: U64 = 100_000_000,
    reconnect_failed_delay: U64 = 10_000_000_000)
    =>
    _auth = auth
    _outgoing_boundary = outgoing_boundary
    _reconnect_closed_delay = reconnect_closed_delay
    _reconnect_failed_delay = reconnect_failed_delay

  fun ref received(conn: WallarooOutgoingNetworkActor ref, data: Array[U8] iso,
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
        _outgoing_boundary.dispose()
      | let sn: StartNormalDataSendingMsg =>
        ifdef "trace" then
          @printf[I32]("Received StartNormalDataSendingMsg at Boundary\n"
            .cstring())
        end
        conn.receive_connect_ack(sn.last_id_seen)
        conn.start_normal_sending()
      | let aw: AckWatermarkMsg =>
        ifdef "trace" then
          @printf[I32]("Received AckWatermarkMsg at Boundary\n".cstring())
        end
        conn.receive_ack(aw.seq_id)
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

  fun ref connecting(conn: WallarooOutgoingNetworkActor ref, count: U32) =>
    @printf[I32]("BoundaryNotify: attempting to connect...\n\n".cstring())

  fun ref connected(conn: WallarooOutgoingNetworkActor ref) =>
    @printf[I32]("BoundaryNotify: connected\n\n".cstring())
    conn.set_nodelay(true)
    //SLF: TODO
    ifdef "wtest" then
      try
        conn.set_so_sndbuf(EnvironmentVar.get3(
          "WT_BUFSIZ", "BOUNDARY", "SND").u32()?)
      end
    end
    conn.expect(4)

  fun ref accepted(conn: WallarooOutgoingNetworkActor ref) =>
    Unreachable()

  fun ref closed(conn: WallarooOutgoingNetworkActor ref) =>
    @printf[I32]("BoundaryNotify: closed\n\n".cstring())

  fun ref connect_failed(conn: WallarooOutgoingNetworkActor ref) =>
    @printf[I32]("BoundaryNotify: connect_failed\n\n".cstring())

  fun ref sentv(conn: WallarooOutgoingNetworkActor ref,
    data: ByteSeqIter): ByteSeqIter
  =>
    data

  fun ref expect(conn: WallarooOutgoingNetworkActor ref, qty: USize): USize =>
    qty

  fun ref throttled(conn: WallarooOutgoingNetworkActor ref) =>
    @printf[I32]("BoundaryNotify: throttled\n\n".cstring())
    //SLF: TODO

  fun ref unthrottled(conn: WallarooOutgoingNetworkActor ref) =>
    @printf[I32]("BoundaryNotify: unthrottled\n\n".cstring())
    //SLF: TODO


class _PauseBeforeReconnect is TimerNotify
  let _ob: OutgoingBoundary

  new iso create(ob: OutgoingBoundary) =>
    _ob = ob

  fun ref apply(timer: Timer, count: U64): Bool =>
    _ob.reconnect()
    false
