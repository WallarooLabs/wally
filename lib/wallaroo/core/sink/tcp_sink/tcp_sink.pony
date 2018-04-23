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
use "wallaroo/core/boundary"
use "wallaroo/core/common"
use "wallaroo/ent/data_receiver"
use "wallaroo/ent/network"
use "wallaroo/ent/recovery"
use "wallaroo/ent/watermarking"
use "wallaroo_labs/mort"
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

actor TCPSink is Consumer
  """
  # TCPSink

  `TCPSink` replaces the Pony standard library class `TCPConnection`
  within Wallaroo for outgoing connections to external systems. While
  `TCPConnection` offers a number of excellent features it doesn't
  account for our needs around resilience.

  `TCPSink` incorporates basic send/recv functionality from `TCPConnection` as
  well working with our upstream backup/message acknowledgement system.

  ## Resilience and message tracking

  ...

  ## Possible future work

  - Much better algo for determining how many credits to hand out per producer
  - At the moment we treat sending over TCP as done. In the future we can and
    should support ack of the data being handled from the other side.
  - Handle reconnecting after being disconnected from the downstream
  - Optional in sink deduplication (this woud involve storing what we sent and
    was acknowleged.)
  """
  let _env: Env
  // Steplike
  let _sink_id: StepId
  let _event_log: EventLog
  let _recovering: Bool
  let _name: String
  let _encoder: TCPEncoderWrapper
  let _wb: Writer = Writer
  let _metrics_reporter: MetricsReporter
  var _initializer: (LocalTopologyInitializer | None) = None

  // Consumer
  var _upstreams: SetIs[Producer] = _upstreams.create()

  // TCP
  var _notify: WallarooOutgoingNetworkActorNotify
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
  var _throttled: Bool = false
  var _event: AsioEventID = AsioEvent.none()
  // _pending is used to avoid GC prematurely reaping memory.
  // See Wallaroo commit 75f1c394e for more.  It looks like a write-only
  // data structure, but its use is important until the Pony runtime changes.
  embed _pending: List[ByteSeq] = _pending.create()
  embed _pending_tracking: List[(USize, SeqId)] = _pending_tracking.create()
  embed _pending_writev: Array[USize] = _pending_writev.create()
  var _pending_writev_total: USize = 0
  var _muted: Bool = false
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
  var _from: String

  // Producer (Resilience)
  var _timers: Timers = Timers

  let _terminus_route: TerminusRoute = TerminusRoute

  new create(sink_id: StepId, sink_name: String, event_log: EventLog,
    recovering: Bool, env: Env, encoder_wrapper: TCPEncoderWrapper,
    metrics_reporter: MetricsReporter iso, host: String, service: String,
    initial_msgs: Array[Array[ByteSeq] val] val,
    from: String = "", init_size: USize = 64, max_size: USize = 16384,
    reconnect_pause: U64 = 10_000_000_000)
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
    _read_buf = recover Array[U8].>undefined(init_size) end
    _next_size = init_size
    _max_size = max_size
    _notify = TCPSinkNotify(env.root, host, service)
    _initial_msgs = initial_msgs
    _reconnect_pause = reconnect_pause
    _host = host
    _service = service
    _from = from
    _connect_count = 0

  //
  // Application Lifecycle events
  //

  be application_begin_reporting(initializer: LocalTopologyInitializer) =>
    _initializer = initializer
    initializer.report_created(this)

  be application_created(initializer: LocalTopologyInitializer,
    omni_router: OmniRouter)
  =>
    initializer.report_initialized(this)

  be application_initialized(initializer: LocalTopologyInitializer) =>
    _initial_connect()

  be application_ready_to_work(initializer: LocalTopologyInitializer) =>
    None

  fun ref _initial_connect() =>
    @printf[I32]("TCPSink initializing connection to %s:%s\n".cstring(),
      _host.cstring(), _service.cstring())
    _connect_count = @pony_os_connect_tcp[U32](this,
      _host.cstring(), _service.cstring(),
      _from.cstring())
    _notify_connecting()

  // open question: how do we reconnect if our external system goes away?
  be run[D: Any val](metric_name: String, pipeline_time_spent: U64, data: D,
    i_producer_id: StepId, i_producer: Producer, msg_uid: MsgId,
    frac_ids: FractionalMessageId, i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    var receive_ts: U64 = 0
    ifdef "detailed-metrics" then
      receive_ts = Time.nanos()
      _metrics_reporter.step_metric(metric_name, "Before receive at sink",
        9998, latest_ts, receive_ts)
    end

    ifdef "trace" then
      @printf[I32]("Rcvd msg at TCPSink\n".cstring())
    end
    try
      let encoded = _encoder.encode[D](data, _wb)?

      let next_tracking_id = _next_tracking_id(i_producer, i_route_id, i_seq_id)
      _writev(encoded, next_tracking_id)

      // TODO: Should happen when tracking info comes back from writev as
      // being done.
      let end_ts = Time.nanos()
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

  fun ref _next_tracking_id(i_producer: Producer, i_route_id: RouteId,
    i_seq_id: SeqId): (U64 | None)
  =>
    ifdef "resilience" then
      return _terminus_route.terminate(i_producer, i_route_id, i_seq_id)
    end

    None

  be replay_run[D: Any val](metric_name: String, pipeline_time_spent: U64,
    data: D, i_producer_id: StepId, i_producer: Producer, msg_uid: MsgId,
    frac_ids: FractionalMessageId, i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    //TODO: deduplication like in the Step <- this is pointless if the Sink
    //doesn't have state, because on recovery we won't have a list of "seen
    //messages", which we would normally get from the eventlog.
    run[D](metric_name, pipeline_time_spent, data, i_producer_id, i_producer,
      msg_uid, frac_ids, i_seq_id, i_route_id, latest_ts, metrics_id,
      worker_ingress_ts)

  be update_router(router: Router) =>
    """
    No-op: TCPSink has no router
    """
    None

  be receive_state(state: ByteSeq val) => Fail()

  be dispose() =>
    """
    Gracefully shuts down the sink. Allows all pending writes
    to be sent but any writes that arrive after this will be
    silently discarded and not acknowleged.
    """
    @printf[I32]("Shutting down TCPSink\n".cstring())
    _no_more_reconnect = true
    _timers.dispose()
    close()
    _notify.dispose()

  fun ref _unit_finished(number_finished: ISize,
    number_tracked_finished: ISize,
    tracking_id: (SeqId | None))
  =>
    """
    Handles book keeping related to resilience. Called when
    a collection of sends is completed. When backpressure hasn't been applied,
    this would be called for each send. When backpressure has been applied and
    there is pending work to send, this would be called once after we finish
    attempting to catch up on sending pending data.
    """
    ifdef debug then
      Invariant(number_finished > 0)
      Invariant(number_tracked_finished <= number_finished)
    end
    ifdef "trace" then
      @printf[I32]("Sent %d msgs over sink\n".cstring(), number_finished)
    end

    ifdef "resilience" then
      match tracking_id
      | let sent: SeqId =>
        _terminus_route.receive_ack(sent)
      end
    end

  be request_ack() =>
    _terminus_route.request_ack()

  be register_producer(producer: Producer) =>
    _upstreams.set(producer)

  be unregister_producer(producer: Producer) =>
    ifdef debug then
      Invariant(_upstreams.contains(producer))
    end

    _upstreams.unset(producer)

  be report_status(code: ReportStatusCode) =>
    None

  be request_in_flight_ack(request_id: RequestId, requester_id: StepId,
    requester: InFlightAckRequester)
  =>
    requester.receive_in_flight_ack(request_id)

  be request_in_flight_resume_ack(in_flight_resume_ack_id: InFlightResumeAckId,
    request_id: RequestId, requester_id: StepId,
    requester: InFlightAckRequester, leaving_workers: Array[String] val)
  =>
    requester.receive_in_flight_resume_ack(request_id)

  be try_finish_in_flight_request_early(requester_id: StepId) =>
    None

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
        // TODO setsockopt here?
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

            match _initializer
            | let initializer: LocalTopologyInitializer =>
              initializer.report_ready_to_work(this)
              _initializer = None
            else
              Fail()
            end

            _notify.connected(this)
            _pending_reads()

            for msg in _initial_msgs.values() do
              _writev(msg, None)
            end
            ifdef not windows then
              _pending_writes()
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
              _pending_writes()
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
            _pending_writes()
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
      _pending.push(bytes)
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
    _pending.push(data)
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
    _throttled = false
    @pony_asio_event_set_readable[None](_event, false)
    @pony_asio_event_set_writeable[None](_event, false)

    @pony_os_socket_close[None](_fd)
    _fd = -1

    _notify.closed(this)

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

    // nothing to send
    if _pending_writev_total == 0 then
      return true
    end

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

            // do tracking finished stuff
            _tracking_finished(bytes_sent)
            _release_backpressure()
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
    """
    Call _unit_finished with:
      number of sent messages,
      number of tracked messages sent
      last tracking_id
    """
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

        if num_sent > 0 then
          _unit_finished(num_sent, tracked_sent, final_pending_sent)
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
      @printf[I32]("RE-Connecting TCPSink to %s:%s\n".cstring(),
                   _host.cstring(), _service.cstring())
      // Bug/feature work-around: we need to create a new timer wheel/actor
      // for each reconnect attempt.  The timer actor sends a message to
      // us; we are under pressure, so the sender (the timer actor!) will
      // be muted.  It's very difficult to create exemptions to the
      // runtime's back-pressure regime: no such exemption exists yet.
      let old_timers = _timers = Timers
      old_timers.dispose()
      let timer = Timer(PauseBeforeReconnectTCPSink(this), _reconnect_pause)
      _timers(consume timer)
    end

  be reconnect() =>
    if not _connected and not _no_more_reconnect then
      _connect_count = @pony_os_connect_tcp[U32](this,
        _host.cstring(), _service.cstring(),
        _from.cstring())
      _notify_connecting()
    end

  fun ref _apply_backpressure() =>
    if not _throttled then
      _throttled = true
      _notify.throttled(this)
    end
    _writeable = false
    // this is safe because asio thread isn't currently subscribed
    // for a write event so will not be writing to the writeable flag
    @pony_asio_event_set_writeable[None](_event, false)
    @pony_asio_event_resubscribe_write(_event)

  fun ref _release_backpressure() =>
    if _throttled then
      _throttled = false
      _notify.unthrottled(this)
    end

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

class TCPSinkNotify is WallarooOutgoingNetworkActorNotify
  let _auth: (AmbientAuth | None)
  let _host: String
  let _service: String

  new iso create(auth: (AmbientAuth | None), host: String, service: String) =>
    _auth = auth
    _host = host
    _service = service

  fun ref connecting(conn: WallarooOutgoingNetworkActor ref, count: U32) =>
    None

  fun ref connected(conn: WallarooOutgoingNetworkActor ref) =>
    @printf[I32]("TCPSink connected\n".cstring())
    _release_backpressure_in_runtime()

  fun ref closed(conn: WallarooOutgoingNetworkActor ref) =>
    @printf[I32]("TCPSink connection closed\n".cstring())
    _apply_backpressure_in_runtime()

  fun ref connect_failed(conn: WallarooOutgoingNetworkActor ref) =>
    @printf[I32]("TCPSink connection failed\n".cstring())

  fun ref sentv(conn: WallarooOutgoingNetworkActor ref,
    data: ByteSeqIter): ByteSeqIter
  =>
    data

  fun ref received(conn: WallarooOutgoingNetworkActor ref, data: Array[U8] iso,
    times: USize): Bool
  =>
    true

  fun ref expect(conn: WallarooOutgoingNetworkActor ref, qty: USize): USize =>
    qty

  fun ref throttled(conn: WallarooOutgoingNetworkActor ref) =>
    @printf[I32]("TCPSink is experiencing back pressure\n".cstring())
    _apply_backpressure_in_runtime()

  fun ref unthrottled(conn: WallarooOutgoingNetworkActor ref) =>
    @printf[I32](("TCPSink is no longer experiencing" +
      " back pressure\n").cstring())
    _release_backpressure_in_runtime()

  fun ref _apply_backpressure_in_runtime() =>
    @printf[I32]("TCPSink: back-pressure apply by %s:%s\n".cstring(),
      _host.cstring(), _service.cstring())
    try Backpressure.apply(_auth as AmbientAuth) end

  fun ref _release_backpressure_in_runtime() =>
    @printf[I32]("TCPSink: back-pressure release by %s:%s\n".cstring(),
      _host.cstring(), _service.cstring())
    try Backpressure.release(_auth as AmbientAuth) end

class PauseBeforeReconnectTCPSink is TimerNotify
  let _tcp_sink: TCPSink

  new iso create(tcp_sink: TCPSink) =>
    _tcp_sink = tcp_sink

  fun ref apply(timer: Timer, count: U64): Bool =>
    _tcp_sink.reconnect()
    false
