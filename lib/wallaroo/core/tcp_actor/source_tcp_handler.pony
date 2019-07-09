use "buffered"
use "collections"
use "net"
use "wallaroo_labs/mort"

class val SourceTCPHandlerBuilder
  fun apply(tcp_actor: TCPActor ref): SourceTCPHandler =>
    @printf[I32](("Currently you must build a SourceTCPHandler using " +
      ".for_connection()\n").cstring())
    Fail()
    SourceTCPHandler(tcp_actor)

  fun for_connection(fd: U32, init_size: USize = 64, max_size: USize = 16384,
    tcp_actor: TCPActor ref, muted: Bool): TestableTCPHandler
  =>
    SourceTCPHandler(tcp_actor, fd, init_size, max_size, muted)

class SourceTCPHandler is TestableTCPHandler
  let _tcp_actor: TCPActor ref
  var _init_size: USize = 0
  var _max_size: USize = 0
  var _connect_count: U32 = 0
  var _fd: U32 = -1
  var _expect: USize = 0
  var _connected: Bool = false
  var _closed: Bool = false
  var _event: AsioEventID = AsioEvent.none()
  var _read_buf: Array[U8] iso = recover Array[U8] end
  var _read_buf_offset: USize = 0
  var _shutdown_peer: Bool = false
  var _readable: Bool = false
  var _writeable: Bool = false
  var _reading: Bool = false
  var _shutdown: Bool = false
  var _expect_read_buf: Reader = Reader
  var _max_received_count: USize = 50
  var _muted: Bool = false
  // _pending is used to avoid GC prematurely reaping memory.
  // See GitHub bug 2526 for more.  It looks like a write-only
  // data structure, but its use is vital to avoid GC races:
  // _pending_writev's C pointers are invisible to ORCA.
  embed _pending: Array[ByteSeq] = _pending.create()
  embed _pending_writev: Array[USize] = _pending_writev.create()
  var _pending_sent: USize = 0
  var _pending_writev_total: USize = 0
  var _throttled: Bool = false

  new create(tcp_actor: TCPActor ref, fd: U32 = -1, init_size: USize = 64,
    max_size: USize = 16384, muted: Bool = false)
  =>
    """
    A new connection accepted on a server.
    """
    _tcp_actor = tcp_actor
    _connect_count = 0
    _fd = fd
    _event = @pony_asio_event_create(_tcp_actor, fd,
      AsioEvent.read_write_oneshot(), 0, true)
    _connected = true
    ifdef not windows then
      @pony_asio_event_set_writeable(_event, true)
    end
    _writeable = true
    _throttled = false
    _read_buf = recover Array[U8].>undefined(init_size) end
    _read_buf_offset = 0
    _init_size = init_size
    _max_size = max_size

    _readable = true
    _closed = false
    _muted = muted
    _shutdown = false
    _shutdown_peer = false

    _pending.clear()
    _pending_writev.clear()
    _pending_sent = 0
    _pending_writev_total = 0

  fun is_connected(): Bool =>
    _connected

  fun ref accept() =>
    _tcp_actor.accepted()
    _pending_reads()

  fun ref connect(host: String, service: String) =>
    if not _connected then
      let asio_flags =
        ifdef not windows then
          AsioEvent.read_write_oneshot()
        else
          AsioEvent.read_write()
        end
      _connect_count = @pony_os_connect_tcp[U32](_tcp_actor,
        host.cstring(), service.cstring(), "".cstring(), asio_flags)
      _notify_connecting()
    end

  fun ref event_notify(event: AsioEventID, flags: U32, arg: U32) =>
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

            _tcp_actor.connected()

            _pending_reads()
          else
            // The connection failed, unsubscribe the event and close.
            @pony_asio_event_unsubscribe(event)
            @pony_os_socket_close[None](fd)
            _notify_connecting()
          end
        else
          // We're already connected, unsubscribe the event and close.
          if not AsioEvent.disposable(flags) then
            @pony_asio_event_unsubscribe(event)
          end
          if _connected then
            @pony_os_socket_close[None](fd)
          end
          _try_shutdown()
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

  fun ref write(data: ByteSeq) =>
    // Not currently supported here
    Fail()

  // !TODO! This is being used in place of _writev_final for ConnectorSource
  fun ref writev(data: ByteSeqIter) =>
    if _connected and not _closed then
      ifdef windows then
        Fail()
      else
        for bs in data.values() do
          _pending_writev .> push(bs.cpointer().usize()) .> push(bs.size())
          _pending_writev_total = _pending_writev_total + bs.size()
          _pending.push(bs)
        end
      end
      _pending_writes()
    end

  fun ref close() =>
    """
    Shut our connection down immediately. Stop reading data from the incoming
    source.
    """
    _hard_close(where locally_initiated_close = true)

  fun can_send(): Bool =>
    _connected and _writeable and not _closed

  fun ref read_again() =>
    """
    Resume reading.
    """
    _pending_reads()

  fun ref write_again() =>
    """
    Resume writing.
    """
    _pending_writes()

  fun ref expect(qty: USize) =>
    """
    A `received` call on the notifier must contain exactly `qty` bytes. If
    `qty` is zero, the call can contain any amount of data.
    """
    if qty <= _max_size then
      _expect = qty
    else
      Fail()
    end

  fun ref set_nodelay(state: Bool) =>
    """
    Turn Nagle on/off. Defaults to on. This can only be set on a connected
    socket.
    """
    if _connected then
      @pony_os_nodelay[None](_fd, state)
    end

  fun local_address(): NetAddress =>
    """
    Return the local IP address.
    """
    let ip = recover NetAddress end
    @pony_os_sockname[Bool](_fd, ip)
    ip

  fun remote_address(): NetAddress =>
    """
    Return the remote IP address.
    """
    let ip = recover NetAddress end
    @pony_os_peername[Bool](_fd, ip)
    ip

  fun ref _notify_connecting() =>
    """
    Inform the notifier that we're connecting.
    """
    if _connect_count > 0 then
      _tcp_actor.connecting(_connect_count)
    else
      _tcp_actor.connect_failed()
      _hard_close()
    end

  fun ref _try_shutdown(locally_initiated_close: Bool = false) =>
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
      _hard_close(locally_initiated_close)
    end

  fun ref _hard_close(locally_initiated_close: Bool = false) =>
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

    _tcp_actor.closed(locally_initiated_close)

  fun ref _apply_backpressure() =>
    if not _throttled then
      _throttled = true
      _tcp_actor.throttled()
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
      _tcp_actor.unthrottled()
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
      var received_count: USize = 0
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
          if (not _tcp_actor.received(consume data, received_count))
            or (received_count >= _max_received_count)
          then
            _read_buf_size()
            _tcp_actor.read_again()
            _reading = false
            return
          end
        end

        if sum >= _max_size then
          // If we've read _max_size, yield and read again later.
          _read_buf_size()
          _tcp_actor.read_again()
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
          _init_size = _max_size.min(_init_size * 2)
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

  fun ref _read_buf_size() =>
    """
    Resize the read buffer.
    """
    if _expect != 0 then
      _read_buf.undefined(_expect.next_pow2().max(_init_size))
    else
      _read_buf.undefined(_init_size)
    end

  /////////////
  // TODO: these mute/unmute methods should be removed
  fun ref mute() =>
    _muted = true

  fun ref unmute() =>
    _muted = false
    if not _reading then
      _pending_reads()
    end
