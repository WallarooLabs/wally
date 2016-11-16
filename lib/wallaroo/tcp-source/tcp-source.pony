use "assert"
use "collections"
use "net"
use "wallaroo/backpressure"
use "wallaroo/boundary"
use "wallaroo/topology"
use "wallaroo/messages"
use "wallaroo/tcp-sink"

use @pony_asio_event_create[AsioEventID](owner: AsioEventNotify, fd: U32,
  flags: U32, nsec: U64, noisy: Bool)
use @pony_asio_event_fd[U32](event: AsioEventID)
use @pony_asio_event_unsubscribe[None](event: AsioEventID)
use @pony_asio_event_destroy[None](event: AsioEventID)

actor TCPSource is (CreditFlowProducer & Initializable & Origin)
  """
  # TCPSource

  ## Future work
  * Switch to requesting credits via promise
  """
  // Credit Flow
  let _routes: MapIs[CreditFlowConsumer, Route] = _routes.create()
  let _route_builder: RouteBuilder val
  let _outgoing_boundaries: Map[String, OutgoingBoundary] val

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
  var _shutdown_peer: Bool = false
  var _readable: Bool = false
  var _read_len: USize = 0
  var _shutdown: Bool = false
  var _muted: Bool = false

  // Resilience
  let _hwm: HighWatermarkTable = HighWatermarkTable(10)
  let _lwm: LowWatermarkTable = LowWatermarkTable(10)
  let _seq_translate: SeqTranslationTable = SeqTranslationTable(10)
  let _route_translate: RouteTranslationTable = RouteTranslationTable(10)
  let _origins: OriginSet = OriginSet(10)

  // BUG TRACKING
  var _read_agains: USize = 0

  // TODO: remove consumers
  new _accept(listen: TCPSourceListener, notify: TCPSourceNotify iso,
    routes: Array[CreditFlowConsumerStep] val, route_builder: RouteBuilder val,
    outgoing_boundaries: Map[String, OutgoingBoundary] val,
    fd: U32, default_target: (CreditFlowConsumerStep | None) = None,
    init_size: USize = 64, max_size: USize = 16384)
  =>
    """
    A new connection accepted on a server.
    """
    _listen = listen
    _notify = consume notify
    _notify.set_origin(this)
    _connect_count = 0
    _fd = fd
    _event = @pony_asio_event_create(this, fd, AsioEvent.read_write(), 0, true)
    _connected = true
    _read_buf = recover Array[U8].undefined(init_size) end
    _next_size = init_size
    _max_size = max_size

    _route_builder = route_builder
    _outgoing_boundaries = outgoing_boundaries

    _notify.accepted(this)

    for consumer in routes.values() do
      _routes(consumer) =
        _route_builder(this, consumer, TCPSourceRouteCallbackHandler)
    end

    for (worker, boundary) in _outgoing_boundaries.pairs() do
      _routes(boundary) =
        _route_builder(this, boundary, StepRouteCallbackHandler)
    end

    match default_target
    | let r: CreditFlowConsumerStep =>
      _routes(r) = _route_builder(this, r, StepRouteCallbackHandler)
    end

    for r in _routes.values() do
      r.initialize()
    end

  //////////////
  // ORIGIN (resilience)
  fun ref hwm_get(): HighWatermarkTable =>
    _hwm

  fun ref lwm_get(): LowWatermarkTable =>
    _lwm

  fun ref seq_translate_get(): SeqTranslationTable =>
    _seq_translate

  fun ref route_translate_get(): RouteTranslationTable =>
    _route_translate

  fun ref origins_get(): OriginSet =>
    _origins

  fun ref _flush(low_watermark: U64, origin: Origin tag,
    upstream_route_id: U64 , upstream_seq_id: U64) =>
    None

  be initialize(outgoing_boundaries: Map[String, OutgoingBoundary] val,
    tcp_sinks: Array[TCPSink] val)
  =>
    None

  be dispose() =>
     """
    - Close the connection gracefully.
    - Dispose of our routes
    """
    close()
    for r in _routes.values() do
      r.dispose()
    end

  //
  // CREDIT FLOW
  be receive_credits(credits: ISize, from: CreditFlowConsumer) =>
    ifdef debug then
      try
        Assert(_routes.contains(from),
        "Source received credits from consumer it isn't registered with.")
      else
        _hard_close()
        return
      end
    end

    try
      let route = _routes(from)
      route.receive_credits(credits)
    end

  fun ref route_to(c: CreditFlowConsumerStep): (Route | None) =>
    try
      _routes(c)
    else
      None
    end

  fun ref update_route_id(route_id: U64) =>
    None // only used in Route to update the outgoing route_id for a message

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

            _notify.connected(this)
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
      if AsioEvent.readable(flags) then
        if not _readable  then
          @printf[None]("Got readable while readable\n".cstring())
          _mute()
        end
        if _read_agains > 0 then
          @printf[None]("got readable and _read_agains is more than 0. Doubling up\n".cstring())
          _mute()
        end
        _readable = true
        _pending_reads()
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
    Attempt to perform a graceful shutdown. Don't accept new writes. If the
    connection isn't muted then we won't finish closing until we get a zero
    length read.  If the connection is muted, perform a hard close and
    shut down immediately.
    """
    if _muted then
      _hard_close()
    else
      _close()
    end

  fun ref _close() =>
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

    @pony_os_socket_close[None](_fd)
    _fd = -1

    _notify.closed(this)

    _listen._conn_closed()

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
          @printf[None]("Attempt to read while muted\n".cstring())
          //_read_again()
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

          let carry_on = _notify.received(this, consume data)
          _read_buf_size()
          if not carry_on then
            _read_agains = _read_agains + 1
            _read_again()
            return
          end
        end

        sum = sum + len

        if sum >= _max_size then
          // If we've read _max_size, yield and read again later.
          _read_agains = _read_agains + 1
          _read_again()
          return
        end
      end
    else
      // The socket has been closed from the other side.
      _shutdown_peer = true
      close()
    end

  be _read_again() =>
    """
    Resume reading.
    """
    if _read_agains > 1 then
      @printf[None]("Too many read again calls. BUG!!!!!".cstring())
      _mute()
    end

    _read_agains = _read_agains - 1

    _pending_reads()

  fun ref _read_buf_size() =>
    """
    Resize the read buffer.
    """
    if _expect != 0 then
      _read_buf.undefined(_expect)
    else
      _read_buf.undefined(_next_size)
    end

  fun ref _mute() =>
    @printf[None]("Muting\n".cstring())
    _muted = true

  fun ref _unmute() =>
    @printf[None]("Unmuting\n".cstring())
    _muted = false

  fun ref expect(qty: USize = 0) =>
    """
    A `received` call on the notifier must contain exactly `qty` bytes. If
    `qty` is zero, the call can contain any amount of data.
    """
    // TODO: verify that removal of "in_sent" check is harmless
    _expect = _notify.expect(this, qty)
    _read_buf_size()

class TCPSourceRouteCallbackHandler is RouteCallbackHandler
  var _muted: ISize = 0

  fun shutdown(producer: CreditFlowProducer ref) =>
    match producer
    | let p: TCPSource ref =>
      p._hard_close()
    end

  fun ref credits_replenished(producer: CreditFlowProducer ref) =>
    ifdef debug then
      try
        Assert(_muted > 0,
          "credits_replenished() should only be called when the calling " +
          "Route was already muted.")
      else
        shutdown(producer)
        return
      end
    end
    match producer
    | let p: TCPSource ref =>
      _muted = _muted - 1
      if (_muted == 0) then
        p._unmute()
      end
    end

  fun ref credits_exhausted(producer: CreditFlowProducer ref) =>
    match producer
    | let p: TCPSource ref =>
      _muted = _muted + 1
      p._mute()
    end

