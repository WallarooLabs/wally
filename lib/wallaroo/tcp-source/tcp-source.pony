use "assert"
use "collections"
use "net"
use "../backpressure"

use @pony_asio_event_create[AsioEventID](owner: AsioEventNotify, fd: U32,
  flags: U32, nsec: U64, noisy: Bool)
use @pony_asio_event_fd[U32](event: AsioEventID)
use @pony_asio_event_unsubscribe[None](event: AsioEventID)
use @pony_asio_event_destroy[None](event: AsioEventID)

actor TCPSource is CreditFlowProducer
  """
  # TCPSource

  ## Future work
  * Switch to requesting credits via promise
  """
  // Credit Flow
  // TODO: CREDITFLOW- Bug. Credits should be ISize.
  let _consumers: MapIs[CreditFlowConsumer, USize] = _consumers.create()
  var _request_more_credits_at: USize = 0

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

  var _muted: Bool

  new _accept(listen: TCPSourceListener, notify: TCPSourceNotify iso,
    consumers: Array[CreditFlowConsumer] val, fd: U32, init_size: USize = 64,
    max_size: USize = 16384)
  =>
    """
    A new connection accepted on a server.
    """
    _listen = listen
    _notify = consume notify
    _connect_count = 0
    _fd = fd
    _event = @pony_asio_event_create(this, fd, AsioEvent.read_write(), 0, true)
    _connected = true
    _read_buf = recover Array[U8].undefined(init_size) end
    _next_size = init_size
    _max_size = max_size

    _muted =
      ifdef "use_backpressure" then
        true
      else
        false
      end

    _notify.accepted(this)

    ifdef "use_backpressure" then
      for c in consumers.values() do
        _consumers(c) = 0
      end
      _register_with_consumers()

      // TODO: this should be in a post create initialize
      for c in consumers.values() do
        _request_credits(c)
      end
    end

  be dispose() =>
     """
    - Close the connection gracefully.
    - Unregister with our consumers
    """
    close()


  //
  // CREDIT FLOW
  be receive_credits(credits: USize, from: CreditFlowConsumer) =>
    //@printf[None]("received credits: %d\n".cstring(), credits)

    ifdef debug then
      try
        Assert(_consumers.contains(from),
        "Source received credits from consumer it isn't registered with.")
      else
        _hard_close()
        return
      end
    end

    try
      if credits > 0 then
        let credits_available = _consumers.upsert(from, credits,
          lambda(x1: USize, x2: USize): USize => x1 + x2 end)
        if (credits_available - credits) == 0 then
          _unmute()
        end
        // TODO: CREDITFLOW. This is a bug.
        // If we have more than 1 consumer, they will step on each
        // other. We need a class to hold info about each
        // relationship we have with a given consumer.
        // The old `Producer` class from `backpressure-jr` branch
        // would serve that general role with updates
        // The logic here could also result, in low credit situations with
        // more than 1 credit request outstanding at a time.
        // Example. go from 0 to 8. request at 6, request again at 0.
        _request_more_credits_at = credits_available - (credits_available >> 2)
      else
        _request_credits(from)
      end
    end


  fun ref credits_used(c: CreditFlowConsumer, num: USize = 1) =>
    //@printf[None]("credits used: %d\n".cstring(), num)

    ifdef debug then
      try
        Assert(_consumers.contains(c),
        "Source used credits going to consumer it isn't registered with.")
        Assert(num <= _consumers(c),
        "Source got usage notification for more than the available credits")
      else
        _hard_close()
        return
      end
    end

    try
      let credits_available = _consumers.upsert(c, num,
        lambda(x1: USize, x2: USize): USize => x1 - x2 end)
      if credits_available == 0 then
        _mute()
        _request_credits(c)
      else
        // TODO: this breaks if num != (0 | 1)
        if credits_available == _request_more_credits_at then
          _request_credits(c)
        end
      end
    end

  fun ref _register_with_consumers() =>
    for consumer in _consumers.keys() do
      consumer.register_producer(this)
    end

  fun ref _unregister_with_consumers() =>
    @printf[None]("unregistering\n".cstring())
    for (consumer, credits) in _consumers.pairs() do
      consumer.unregister_producer(this, credits)
    end

  fun ref _request_credits(from: CreditFlowConsumer) =>
    //@printf[None]("Requesting credits\n".cstring())
    from.credit_request(this)

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
    _unregister_with_consumers()

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
          _read_again()
          return
        end

        // Read as much data as possible.
        let len = @pony_os_recv[USize](
          _event,
          _read_buf.cstring().usize() + _read_len,
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
            _read_again()
            return
          end
        end

        sum = sum + len

        if sum >= _max_size then
          // If we've read _max_size, yield and read again later.
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
