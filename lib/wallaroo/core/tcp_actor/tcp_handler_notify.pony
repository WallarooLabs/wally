

trait TCPHandlerNotify[T: TCPActor ref]
  fun ref accepted(conn: T) =>
    None

  fun ref connecting(conn: T, count: U32) =>
    """
    Called if name resolution succeeded for a T
    and we are now waiting for a connection to the server to succeed. The
    count is the number of connections we're trying. The notifier will be
    informed each time the count changes, until a connection is made or
    connect_failed() is called.
    """
    None

  fun ref connected(conn: T) =>
    """
    Called when we have successfully connected to the server.
    """
    None

  fun ref connect_failed(conn: T) =>
    """
    Called when we have failed to connect to all possible addresses for the
    server. At this point, the connection will never be established.
    """
    None

  fun ref closed(conn: T, locally_initiated_close: Bool) =>
    """
    Called when the connection is closed.
    """
    None

  fun ref sent(conn: T, data: ByteSeq): ByteSeq =>
    """
    Called when data is sent on the connection. This gives the notifier an
    opportunity to modify sent data before it is written. To swallow data,
    return an empty string.
    """
    data

  fun ref sentv(conn: T, data: ByteSeqIter): ByteSeqIter =>
    """
    Called when multiple chunks of data are sent to the connection in a single
    call. This gives the notifier an opportunity to modify the sent data chunks
    before they are written. To swallow the send, return an empty
    Array[String].
    """
    data

  fun ref received(conn: T, data: Array[U8] iso, times: USize): Bool =>
    """
    Called when new data is received on the connection. Return true if you
    want to continue receiving messages without yielding until you read
    max_size on the TNotify.  Return false to
    cause the TNotify to yield now.

    `times` parameter is the number of times this method has been called during
    this behavior. Starts at 1.
    """
    true

  fun ref expect(conn: T, qty: USize): USize =>
    """
    Called when the connection has been told to expect a certain quantity of
    bytes. This allows nested notifiers to change the expected quantity, which
    allows a lower level protocol to handle any framing (e.g. SSL).
    """
    qty

  fun ref throttled(conn: T) =>
    """
    Called when the connection starts experiencing TCP backpressure. You should
    respond to this by pausing additional calls to `write` and `writev` until
    you are informed that pressure has been released. Failure to respond to
    the `throttled` notification will result in outgoing data queuing in the
    connection and increasing memory usage.
    """
    None

  fun ref unthrottled(conn: T) =>
    """
    Called when the connection stops experiencing TCP backpressure. Upon
    receiving this notification, you should feel free to start making calls to
    `write` and `writev` again.
    """
    None

  fun ref auth_failed(conn: T) =>
    """
    This can be used to report an authentication failure either at this level
    or in a lower level protocol (e.g. SSL).
    """
    None

  fun ref dispose() =>
    """
    Called when the parent actor's dispose is called.
    """
    None
