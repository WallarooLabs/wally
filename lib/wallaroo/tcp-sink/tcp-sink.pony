use "assert"
use "buffered"
use "collections"
use "net"
use "wallaroo/backpressure"
use "wallaroo/boundary"
use "wallaroo/fail"
use "wallaroo/invariant"
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/topology"

use @pony_asio_event_create[AsioEventID](owner: AsioEventNotify, fd: U32,
  flags: U32, nsec: U64, noisy: Bool)
use @pony_asio_event_fd[U32](event: AsioEventID)
use @pony_asio_event_unsubscribe[None](event: AsioEventID)
use @pony_asio_event_resubscribe[None](event: AsioEventID, flags: U32)
use @pony_asio_event_destroy[None](event: AsioEventID)

actor EmptySink is CreditFlowConsumerStep
  be run[D: Any val](metric_name: String, source_ts: U64, data: D,
    origin: Producer, msg_uid: U128,
    frac_ids: None, seq_id: SeqId, route_id: RouteId)
  =>
    ifdef "trace" then
      @printf[I32]("Rcvd msg at EmptySink\n".cstring())
    end
    None

  be replay_run[D: Any val](metric_name: String, source_ts: U64, data: D,
    origin: Producer, msg_uid: U128,
    frac_ids: None, incoming_seq_id: SeqId, route_id: RouteId)
  =>
    None

  be initialize(outgoing_boundaries: Map[String, OutgoingBoundary] val,
    tcp_sinks: Array[TCPSink] val, omni_router: OmniRouter val)
  =>
    None

  be register_producer(producer: Producer) =>
    None

  be unregister_producer(producer: Producer, credits_returned: ISize) =>
    None

  be credit_request(from: Producer, credits_requested: ISize) =>
    None

  be return_credits(credits: ISize) =>
    None

class TCPSinkBuilder
  let _encoder_wrapper: EncoderWrapper val
  let _initial_msgs: Array[Array[ByteSeq] val] val

  new val create(encoder_wrapper: EncoderWrapper val,
    initial_msgs: Array[Array[ByteSeq] val] val)
  =>
    _encoder_wrapper = encoder_wrapper
    _initial_msgs = initial_msgs

  fun apply(reporter: MetricsReporter iso, host: String, service: String):
    TCPSink
  =>
    TCPSink(_encoder_wrapper, consume reporter, host, service,
      _initial_msgs)

actor TCPSink is (CreditFlowConsumer & RunnableStep & Initializable)
  """
  # TCPSink

  `TCPSink` replaces the Pony standard library class `TCPConnection`
  within Wallaroo for outgoing connections to external systems. While
  `TCPConnection` offers a number of excellent features it doesn't
  account for our needs around resilience and backpressure.

  `TCPSink` incorporates basic send/recv functionality from `TCPConnection` as
  well as supporting our CreditFlow backpressure system and working with
  our upstream backup/message acknowledgement system.

  ## Backpressure

  ...

  ## Resilience and message tracking

  ...

  ## Possible future work

  - Much better algo for determining how many credits to hand out per producer
  - At the moment we treat sending over TCP as done. In the future we can and should support ack of the data being handled from the other side.
  - Handle reconnecting after being disconnected from the downstream
  - Optional in sink deduplication (this woud involve storing what we sent and
    was acknowleged.)
  """
  // Steplike
  let _encoder: EncoderWrapper val
  let _wb: Writer = Writer
  let _metrics_reporter: MetricsReporter

  // CreditFlow
  var _upstreams: Array[Producer] = _upstreams.create()
  var _max_distributable_credits: ISize = 350_000
  var _distributable_credits: ISize = _max_distributable_credits

  // TCP
  var _notify: _TCPSinkNotify
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
  var _muted: Bool = false
  var _expect_read_buf: Reader = Reader

  var _shutdown_peer: Bool = false
  var _readable: Bool = false
  var _read_len: USize = 0
  var _shutdown: Bool = false
  let _initial_msgs: Array[Array[ByteSeq] val] val

  // Origin (Resilience)
  let _terminus_route: TerminusRoute ref = recover ref TerminusRoute end

  new create(encoder_wrapper: EncoderWrapper val,
    metrics_reporter: MetricsReporter iso, host: String, service: String,
    initial_msgs: Array[Array[ByteSeq] val] val,
    from: String = "", init_size: USize = 64, max_size: USize = 16384)
  =>
    """
    Connect via IPv4 or IPv6. If `from` is a non-empty string, the connection
    will be made from the specified interface.
    """
    _max_distributable_credits =
      _max_distributable_credits.usize().next_pow2().isize()
    _encoder = encoder_wrapper
    _metrics_reporter = consume metrics_reporter
    _read_buf = recover Array[U8].undefined(init_size) end
    _next_size = init_size
    _max_size = max_size
    _notify = EmptyNotify
    _initial_msgs = initial_msgs
    _connect_count = @pony_os_connect_tcp[U32](this,
      host.cstring(), service.cstring(),
      from.cstring())
    _notify_connecting()

  be initialize(outgoing_boundaries: Map[String, OutgoingBoundary] val,
    tcp_sinks: Array[TCPSink] val, omni_router: OmniRouter val)
  =>
    ifdef debug then
      Invariant(_max_distributable_credits ==
        (_max_distributable_credits.usize() - 1).next_pow2().isize())
    end

  // open question: how do we reconnect if our external system goes away?
  be run[D: Any val](metric_name: String, source_ts: U64, data: D,
    i_origin: Producer, msg_uid: U128,
    i_frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId)
  =>
    ifdef "trace" then
      @printf[I32]("Rcvd msg at TCPSink\n".cstring())
    end
    try
      let encoded = _encoder.encode[D](data, _wb)

      let tracking_id = ifdef "resilience" then
        _terminus_route.terminate(i_origin, i_route_id, i_seq_id)
      else
        None
      end

      _writev(encoded, tracking_id)

      // TODO: Should happen when tracking info comes back from writev as
      // being done.
      _metrics_reporter.pipeline_metric(metric_name, source_ts)
    else
      Fail()
    end
    // DO NOT REMOVE. THIS IS AN INTENTIONAL GC
    @pony_triggergc[None](this)

  be replay_run[D: Any val](metric_name: String, source_ts: U64, data: D,
    i_origin: Producer, msg_uid: U128,
    i_frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId)
  =>
    //TODO: deduplication like in the Step <- this is pointless if the Sink
    //doesn't have state, because on recovery we won't have a list of "seen
    //messages", which we would normally get from the eventlog.
    run[D](metric_name, source_ts, data, i_origin, msg_uid, i_frac_ids,
      i_seq_id, i_route_id)

  be update_router(router: Router val) =>
    """
    No-op: TCPSink has no router
    """
    None

  be dispose() =>
    """
    Gracefully shuts down the sink. Allows all pending writes
    to be sent but any writes that arrive after this will be
    silently discarded and not acknowleged.
    """
    close()

  fun ref _unit_finished(number_finished: ISize,
    tracking_id: (SeqId | None))
  =>
    """
    Handles book keeping related to resilience and backpressure. Called when
    a collection of sends is completed. When backpressure hasn't been applied,
    this would be called for each send. When backpressure has been applied and
    there is pending work to send, this would be called once after we finish
    attempting to catch up on sending pending data.
    """
    ifdef "backpressure" then
      _recoup_credits(number_finished)
    end

    ifdef "resilience" then
      match tracking_id
      | let sent: SeqId =>
        _terminus_route.receive_ack(sent)
      end
    end

  //
  // CREDIT FLOW
  be register_producer(producer: Producer) =>
    ifdef debug then
      try
        Assert(not _upstreams.contains(producer),
          "Producer attempted registered with sink more than once")
      else
        _hard_close()
        return
      end
    end

    _upstreams.push(producer)

  be unregister_producer(producer: Producer, credits_returned: ISize) =>
    ifdef debug then
      try
        Assert(_upstreams.contains(producer),
          "Producer attempted to unregister with sink " +
          "it isn't registered with")
      else
        _hard_close()
        return
      end
    end

    try
      let i = _upstreams.find(producer)
      _upstreams.delete(i)
      ifdef "backpressure" then
        _recoup_credits(credits_returned)
      end
    end

  be credit_request(from: Producer, credits_requested: ISize) =>
    """
    Receive a credit request from a producer. For speed purposes, we assume
    the producer is already registered with us.

    Even if we have credits available in the "distributable pool", we can't
    give them out if our outgoing socket is in a non-sendable state. The
    following are non-sendable states:

    - Not connected
    - Closed
    - Not currently writeable

    By not giving out credits when we are "not currently writable", we can
    implement backpressure without having to inform our upstream producers
    to stop sending. They only send when they have credits. If they run out
    and we are experiencing backpressure, they don't get any more.
    """
    ifdef debug then
      try
        Assert(_upstreams.contains(from),
          "Credit request from unregistered producer")
      else
        _hard_close()
        return
      end
    end

    let desired_give_out = if _can_send() then
      (_distributable_credits / _upstreams.size().isize())
    else
      0
    end

    let give_out = credits_requested.min(desired_give_out)

    ifdef debug then
      try
        Assert(give_out >= 0,
          "TCPSink calculated and is trying to send back negative credits")
      else
        _hard_close()
        return
      end
    end

    ifdef "credit_trace" then
      @printf[I32]("Sink: Credits requested. Giving %llu out of %llu\n".cstring(), give_out, _distributable_credits)
    end

    from.receive_credits(give_out, this)
    _distributable_credits = _distributable_credits - give_out

  fun ref _recoup_credits(recoup: ISize) =>
    _distributable_credits = _distributable_credits + recoup

  be return_credits(credits: ISize) =>
    _distributable_credits = _distributable_credits + credits

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

            _notify.connected(this)


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

      if AsioEvent.disposable(flags) then
        @pony_asio_event_destroy(event)
        _event = AsioEvent.none()
      end

      _try_shutdown()
    end
    _resubscribe_event()

  fun ref _writev(data: ByteSeqIter, tracking_id: (SeqId | None))
  =>
    """
    Write a sequence of sequences of bytes.
    """
    if _connected and not _closed then
      _in_sent = true

      var data_size: USize = 0
      for bytes in _notify.sentv(this, data).values() do
        _pending_writev.push(bytes.cpointer().usize()).push(bytes.size())
        _pending_writev_total = _pending_writev_total + bytes.size()
        _pending.push((bytes, 0))
        data_size = data_size + bytes.size()
      end

      ifdef "backpressure" or "resilience" then
        match tracking_id
        | let id: SeqId =>
          _pending_tracking.push((data_size, id))
        end
      end

      _pending_writes()

      _in_sent = false
    end

  fun ref _write_final(data: ByteSeq, tracking_id: (SeqId | None)) =>
    """
    Write as much as possible to the socket. Set _writeable to false if not
    everything was written. On an error, close the connection. This is for
    data that has already been transformed by the notifier.
    """
    _pending_writev.push(data.cpointer().usize()).push(data.size())
    _pending_writev_total = _pending_writev_total + data.size()
    ifdef "backpressure" or "resilience" then
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

      while _readable and not _shutdown_peer do
        if _muted then
          return
        end

        while (_expect_read_buf.size() > 0) and
          (_expect_read_buf.size() >= _expect)
        do
          let block_size = if _expect != 0 then
            _expect
          else
            _expect_read_buf.size()
          end

          let out = _expect_read_buf.block(block_size)
          let carry_on = _notify.received(this, consume out)
          ifdef osx then
            if not carry_on then
              _read_again()
              return
            end

            sum = sum + block_size

            if sum >= _max_size then
              // If we've read _max_size, yield and read again later.
              _read_again()
              return
            end
          end
        end

        // Read as much data as possible.
        _read_buf_size()
        let len = @pony_os_recv[USize](
          _event,
          _read_buf.cpointer().usize() + _read_len,
          _read_buf.size() - _read_len) ?

        match len
        | 0 =>
          // Would block, try again later.
          _readable = false
          _resubscribe_event()
          return
        | _next_size =>
          // Increase the read buffer size.
          _next_size = _max_size.min(_next_size * 2)
        end

         _read_len = _read_len + len

        if _expect != 0 then
          let data = _read_buf = recover Array[U8] end
          data.truncate(_read_len)
          _read_len = 0

          _expect_read_buf.append(consume data)

          while (_expect_read_buf.size() > 0) and
            (_expect_read_buf.size() >= _expect)
          do
            let block_size = if _expect != 0 then
              _expect
            else
              _expect_read_buf.size()
            end

            let out = _expect_read_buf.block(block_size)
            let osize = block_size
            let carry_on = _notify.received(this, consume out)
            ifdef osx then
              if not carry_on then
                _read_again()
                return
              end

              sum = sum + osize

              if sum >= _max_size then
                // If we've read _max_size, yield and read again later.
                _read_again()
                return
              end
            end
          end
        else
          let data = _read_buf = recover Array[U8] end
          data.truncate(_read_len)
          let dsize = _read_len
          _read_len = 0

          let carry_on = _notify.received(this, consume data)
          ifdef osx then
            if not carry_on then
              _read_again()
              return
            end

            sum = sum + dsize

            if sum >= _max_size then
              // If we've read _max_size, yield and read again later.
              _read_again()
              return
            end
          end
        end
      end
    else
      // The socket has been closed from the other side.
      _shutdown_peer = true
      close()
    end

  fun _can_send(): Bool =>
    _connected and not _closed and _writeable

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
    while _writeable and (_pending_writev_total > 0) do
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
            bytes_to_send = bytes_to_send + _pending_writev(d)
          end
        end

        // Write as much data as possible.
        var len = @pony_os_writev[USize](_event,
          _pending_writev.cpointer(), num_to_send) ?

        // keep track of how many bytes we sent
        bytes_sent = bytes_sent + len

        if len < bytes_to_send then
          while len > 0 do
            let iov_p = _pending_writev(0)
            let iov_s = _pending_writev(1)
            if iov_s <= len then
              len = len - iov_s
              _pending_writev.shift()
              _pending_writev.shift()
              _pending.shift()
              _pending_writev_total = _pending_writev_total - iov_s
            else
              _pending_writev.update(0, iov_p+len)
              _pending_writev.update(1, iov_s-len)
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
             _pending_writev.shift()
             _pending_writev.shift()
             _pending.shift()
           end

          end
        end
      else
        // Non-graceful shutdown on error.
        _hard_close()
      end
    end

    // do tracking finished stuff
    _tracking_finished(bytes_sent)

    false


  fun ref _tracking_finished(num_bytes_sent: USize) =>
    """
    Call _unit_finished with # of sent messages and last tracking_id
    """
    ifdef "backpressure" or "resilience" then
      var num_sent: ISize = 0
      var final_pending_sent: (SeqId | None) = None
      var bytes_sent = num_bytes_sent

      try
        while bytes_sent > 0 do
          let node = _pending_tracking.head()
          (let bytes, let tracking_id) = node()
          if bytes <= bytes_sent then
            num_sent = num_sent + 1
            bytes_sent = bytes_sent - bytes
            final_pending_sent = tracking_id
            _pending_tracking.shift()
          else
            let bytes_remaining = bytes - bytes_sent
            bytes_sent = 0
            // update remaining for this message
            node() = (bytes_remaining, tracking_id)
          end
        end

        match final_pending_sent
        | let sent: SeqId =>
          _unit_finished(num_sent, sent)
        end
      end
    end

  fun ref _apply_backpressure() =>
    _writeable = false
    _notify.throttled(this)

  fun ref _release_backpressure() =>
    _notify.unthrottled(this)

  fun ref _read_buf_size() =>
    """
    Resize the read buffer.
    """
    if _expect != 0 then
      _read_buf.undefined(_expect)
    else
      _read_buf.undefined(_next_size)
    end

  fun local_address(): IPAddress =>
    """
    Return the local IP address.
    """
    let ip = recover IPAddress end
    @pony_os_sockname[Bool](_fd, ip)
    ip

  be _read_again() =>
    """
    Resume reading.
    """

    _pending_reads()

  fun ref _resubscribe_event() =>
    ifdef linux then
      let flags = if not _readable and not _writeable then
        AsioEvent.read_write_oneshot()
      elseif not _readable then
        AsioEvent.read() or AsioEvent.oneshot()
      elseif not _writeable then
        AsioEvent.write() or AsioEvent.oneshot()
      else
        return
      end

      @pony_asio_event_resubscribe(_event, flags)
    end

interface _TCPSinkNotify
  fun ref connecting(conn: TCPSink ref, count: U32) =>
    """
    Called if name resolution succeeded for a TCPConnection and we are now
    waiting for a connection to the server to succeed. The count is the number
    of connections we're trying. The notifier will be informed each time the
    count changes, until a connection is made or connect_failed() is called.
    """
    None

  fun ref connected(conn: TCPSink ref) =>
    """
    Called when we have successfully connected to the server.
    """
    None

  fun ref connect_failed(conn: TCPSink ref) =>
    """
    Called when we have failed to connect to all possible addresses for the
    server. At this point, the connection will never be established.
    """
    None

  fun ref sentv(conn: TCPSink ref, data: ByteSeqIter): ByteSeqIter =>
    """
    Called when multiple chunks of data are sent to the connection in a single
    call. This gives the notifier an opportunity to modify the sent data chunks
    before they are written. To swallow the send, return an empty
    Array[String].
    """
    data

  fun ref received(conn: TCPSink ref, data: Array[U8] iso): Bool =>
    """
    Called when new data is received on the connection. Return true if you
    want to continue receiving messages without yielding until you read
    max_size on the TCPConnection.  Return false to cause the TCPConnection
    to yield now.
    """
    true

  fun ref expect(conn: TCPSink ref, qty: USize): USize =>
    """
    Called when the connection has been told to expect a certain quantity of
    bytes. This allows nested notifiers to change the expected quantity, which
    allows a lower level protocol to handle any framing (e.g. SSL).
    """
    qty

  fun ref closed(conn: TCPSink ref) =>
    """
    Called when the connection is closed.
    """
    None

  fun ref throttled(conn: TCPSink ref) =>
    """
    Called when the connection starts experiencing TCP backpressure. You should
    respond to this by pausing additional calls to `write` and `writev` until
    you are informed that pressure has been released. Failure to respond to
    the `throttled` notification will result in outgoing data queuing in the
    connection and increasing memory usage.
    """
    None

  fun ref unthrottled(conn: TCPSink ref) =>
    """
    Called when the connection stops experiencing TCP backpressure. Upon
    receiving this notification, you should feel free to start making calls to
    `write` and `writev` again.
    """
    None

class EmptyNotify is _TCPSinkNotify
  fun ref connected(conn: TCPSink ref) =>
  """
  Called when we have successfully connected to the server.
  """
  None
