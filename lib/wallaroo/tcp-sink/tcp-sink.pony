use "assert"
use "buffered"
use "collections"
use "net"
use "wallaroo/backpressure"
use "wallaroo/boundary" 
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/topology"

use @pony_asio_event_create[AsioEventID](owner: AsioEventNotify, fd: U32,
  flags: U32, nsec: U64, noisy: Bool)
use @pony_asio_event_fd[U32](event: AsioEventID)
use @pony_asio_event_unsubscribe[None](event: AsioEventID)
use @pony_asio_event_destroy[None](event: AsioEventID)

// TODO: Fix this placeholder
class val TrackingInfo

actor EmptySink is CreditFlowConsumerStep
  be run[D: Any val](metric_name: String, source_ts: U64, data: D,
    origin: Origin tag, msg_uid: U128,
    frac_ids: None, seq_id: U64, route_id: U64)
  =>
    None

  be replay_run[D: Any val](metric_name: String, source_ts: U64, data: D,
    origin: Origin tag, msg_uid: U128,
    frac_ids: None, incoming_seq_id: U64, route_id: U64)
  =>
    None

  be initialize(outgoing_boundaries: Map[String, OutgoingBoundary] val) => None

  be register_producer(producer: CreditFlowProducer) =>
    None

  be unregister_producer(producer: CreditFlowProducer,
    credits_returned: ISize)
  =>
    None

  be credit_request(from: CreditFlowProducer) =>
    None

class TCPSinkBuilder
  let _encoder_wrapper: EncoderWrapper val

  new val create(encoder_wrapper: EncoderWrapper val) =>
    _encoder_wrapper = encoder_wrapper

  fun apply(reporter: MetricsReporter iso, host: String, service: String):
    TCPSink
  =>
    TCPSink(_encoder_wrapper, consume reporter, host, service)

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
  var _upstreams: Array[CreditFlowProducer] = _upstreams.create()
  let _max_distributable_credits: ISize = 500_000
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
  embed _pending: List[(ByteSeq, USize, TrackingInfo val)] = _pending.create()
  var _shutdown_peer: Bool = false
  var _readable: Bool = false
  var _read_len: USize = 0
  var _shutdown: Bool = false

  new create(encoder_wrapper: EncoderWrapper val,
    metrics_reporter: MetricsReporter iso, host: String, service: String,
    from: String = "", init_size: USize = 64, max_size: USize = 16384)
  =>
    """
    Connect via IPv4 or IPv6. If `from` is a non-empty string, the connection
    will be made from the specified interface.
    """
    _encoder = encoder_wrapper
    _metrics_reporter = consume metrics_reporter
    _read_buf = recover Array[U8].undefined(init_size) end
    _next_size = init_size
    _max_size = max_size
    _notify = EmptyNotify
    _connect_count = @pony_os_connect_tcp[U32](this,
      host.cstring(), service.cstring(),
      from.cstring())
    _notify_connecting()

  be initialize(outgoing_boundaries: Map[String, OutgoingBoundary] val) => None

  // open question: how do we reconnect if our external system goes away?
  be run[D: Any val](metric_name: String, source_ts: U64, data: D,
    origin: Origin tag, msg_uid: U128,
    frac_ids: None, seq_id: U64, route_id: U64)
  =>
    try
      let encoded = _encoder.encode[D](data, _wb)
      _writev(encoded)
      
      // We are finished with the message and can update watermarks
      // Note: We are ACKing messages as fast as they come in.
      // TODO: Queue the ACKs and use a timer to send watermarks upstream
      //       periodically.
      ifdef "resilience" then
        ifdef "resilience-debug" then
          @printf[I32]((
            "sink uid: " + msg_uid.string() +
            "\troute_id: " + route_id.string() + "\tseq_id: " +
            seq_id.string() + "\n").cstring())
        end
        origin.update_watermark(route_id, seq_id)
      end
      
      // TODO: Should happen when tracking info comes back from writev as
      // being done.
      _metrics_reporter.pipeline_metric(metric_name, source_ts)
    else
      ifdef debug then
        try
          Assert(false, "Encoder sink received unrecognized input type.")
        else
          _hard_close()
          return
        end
      end
      return
    end

  be replay_run[D: Any val](metric_name: String, source_ts: U64, data: D,
    origin: Origin tag, msg_uid: U128,
    frac_ids: None, incoming_seq_id: U64, route_id: U64)
  =>
    //TODO: What do we do here?
    run[D](metric_name, source_ts, data, origin, msg_uid, frac_ids, 
      incoming_seq_id, route_id)

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

  fun ref _unit_finished(number_finished: ISize, last_sent:
    TrackingInfo val)
  =>
    """
    Handles book keeping related to resilience and backpressure. Called when
    a collection of sends is completed. When backpressure hasn't been applied,
    this would be called for each send. When backpressure has been applied and
    there is pending work to send, this would be called once after we finish
    attempting to catch up on sending pending data.
    """
    _recoup_credits(number_finished)

  //
  // CREDIT FLOW
  be register_producer(producer: CreditFlowProducer) =>
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

  be unregister_producer(producer: CreditFlowProducer,
    credits_returned: ISize)
  =>
    ifdef debug then
      try
        Assert(_upstreams.contains(producer),
          "Producer attempted to unregistered with sink " +
          "it isn't registered with")
      else
        _hard_close()
        return
      end
    end

    try
      let i = _upstreams.find(producer)
      _upstreams.delete(i)
      _recoup_credits(credits_returned)
    end

  be credit_request(from: CreditFlowProducer) =>
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

    let give_out =  if _can_send() then
      (_distributable_credits / _upstreams.size().isize())
    else
      0
    end

    from.receive_credits(give_out, this)
    _distributable_credits = _distributable_credits - give_out

  fun ref _recoup_credits(recoup: ISize) =>
    _distributable_credits = _distributable_credits + recoup

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

            _pending_writes()
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
        _pending_writes()
      end

      if AsioEvent.readable(flags) then
        _readable = true

        if _pending_reads() then
          _read_again()
        end
      end

      if AsioEvent.disposable(flags) then
        @pony_asio_event_destroy(event)
        _event = AsioEvent.none()
      end

      _try_shutdown()
    end

  // TODO: Fix this when we get a real message envelope
  fun ref _writev(data: ByteSeqIter, tracking_info: TrackingInfo val =
    TrackingInfo) =>
    """
    Write a sequence of sequences of bytes.
    """
    if _connected and not _closed then
      _in_sent = true

      for bytes in _notify.sentv(this, data).values() do
        _write_final(bytes, tracking_info)
      end

      _in_sent = false
    end

  fun ref _write_final(data: ByteSeq, tracking_info: TrackingInfo val) =>
    """
    Write as much as possible to the socket. Set _writeable to false if not
    everything was written. On an error, close the connection. This is for
    data that has already been transformed by the notifier.
    """
      if _writeable then
        try
          // Send as much data as possible.
          var len =
            @pony_os_send[USize](_event, data.cpointer(), data.size()) ?

          if len < data.size() then
            // Send any remaining data later. Apply back pressure.
            _pending.push((data, len, tracking_info))
            _apply_backpressure()
          else
            _unit_finished(1, tracking_info)
          end
        else
          // Non-graceful shutdown on error.
          _hard_close()
        end
      else
        // Send later, when the socket is available for writing.
        _pending.push((data, 0, tracking_info))
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
      (_pending.size() == 0)
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
    _pending.clear()
    _readable = false
    _writeable = false

    @pony_os_socket_close[None](_fd)
    _fd = -1

    _notify.closed(this)

  fun ref _pending_reads(): Bool =>
    """
    Read while data is available, guessing the next packet length as we go. If
    we read 4 kb of data, send ourself a resume message and stop reading, to
    avoid starving other actors.
    """
      try
        var sum: USize = 0

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
            return false
          | _next_size =>
            // Increase the read buffer size.
            _next_size = _max_size.min(_next_size * 2)
          end

          _read_len = _read_len + len

          if _read_len >= _expect then
            let data = _read_buf = recover Array[U8] end
            data.truncate(_read_len)
            _read_len = 0

            if not _notify.received(this, consume data) then
              _read_buf_size()
              return true
            else
              _read_buf_size()
            end
          end

          sum = sum + len

          if sum >= _max_size then
            // If we've read _max_size, yield and read again later.
            return true
          end
        end
      else
        // The socket has been closed from the other side.
        _shutdown_peer = true
        close()
      end

      false

  be _read_again() =>
    """
    Resume reading.
    """
    _pending_reads()

  fun _can_send(): Bool =>
    _connected and not _closed and _writeable

  fun ref _pending_writes() =>
    """
    Send pending data. If any data can't be sent, keep it and mark as not
    writeable. On an error, dispose of the connection.
    """
    var final_pending_sent: (TrackingInfo val | None) = None
    var num_sent: ISize = 0

    while _writeable and (_pending.size() > 0) do
      try
        let node = _pending.head()
        (let data, let offset, let tracking_info) = node()

        // Write as much data as possible.
        let len = @pony_os_send[USize](_event,
          data.cpointer().usize() + offset, data.size() - offset) ?

        if (len + offset) < data.size() then
          // Send remaining data later.
          node() = (data, offset + len, tracking_info)
          _writeable = false
        else
          // This chunk has been fully sent.
          _pending.shift()
          final_pending_sent = tracking_info
          num_sent = num_sent + 1
          if _pending.size() == 0 then
            // Remove back pressure.
            _release_backpressure()
          end
        end
      else
        // Non-graceful shutdown on error.
        _hard_close()
      end
    end

    match final_pending_sent
    | let sent: TrackingInfo val =>
      _unit_finished(num_sent, sent)
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
