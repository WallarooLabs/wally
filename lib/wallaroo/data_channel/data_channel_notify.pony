use "collections"
use "wallaroo/boundary"

interface DataChannelNotify
  """
  Notifications for DataChannel connections.

  For an example of using this class please see the documentation for the
  `DataChannel` and `DataChannelListener` actors.
  """
  fun ref identify_data_receiver(dr: DataReceiver, sender_boundary_id: U128,
    conn: DataChannel ref)
    """
    Each abstract data channel (a connection from an OutgoingBoundary)
    corresponds to a single DataReceiver. On reconnect, we want a new
    DataChannel for that boundary to use the same DataReceiver. This is
    called once we have found (or initially created) the DataReceiver for
    the DataChannel corresponding to this notify.
    """

  fun ref accepted(conn: DataChannel ref) =>
    """
    Called when a DataChannel is accepted by a DataChannelListener.
    """
    None

  fun ref connecting(conn: DataChannel ref, count: U32) =>
    """
    Called if name resolution succeeded for a DataChannel and we are now
    waiting for a connection to the server to succeed. The count is the number
    of connections we're trying. The notifier will be informed each time the
    count changes, until a connection is made or connect_failed() is called.
    """
    None

  fun ref connected(conn: DataChannel ref) =>
    """
    Called when we have successfully connected to the server.
    """
    None

  fun ref connect_failed(conn: DataChannel ref) =>
    """
    Called when we have failed to connect to all possible addresses for the
    server. At this point, the connection will never be established.
    """
    None

  fun ref auth_failed(conn: DataChannel ref) =>
    """
    A raw DataChannel has no authentication mechanism. However, when
    protocols are wrapped in other protocols, this can be used to report an
    authentication failure in a lower level protocol (e.g. SSL).
    """
    None

  fun ref sent(conn: DataChannel ref, data: ByteSeq): ByteSeq =>
    """
    Called when data is sent on the connection. This gives the notifier an
    opportunity to modify sent data before it is written. To swallow data,
    return an empty string.
    """
    data

  fun ref sentv(conn: DataChannel ref, data: ByteSeqIter): ByteSeqIter =>
    """
    Called when multiple chunks of data are sent to the connection in a single
    call. This gives the notifier an opportunity to modify the sent data chunks
    before they are written. To swallow the send, return an empty
    Array[String].
    """
    data

  fun ref received(conn: DataChannel ref, data: Array[U8] iso,
    times: USize): Bool
  =>
    """
    Called when new data is received on the connection. Return true if you
    want to continue receiving messages without yielding until you read
    max_size on the DataChannel. Return false to cause the DataChannel
    to yield now.

    Includes the number of times during the current behavior, that received has
    been called. This allows the notifier to end reads on a regular basis.
    """
    true

  fun ref expect(conn: DataChannel ref, qty: USize): USize =>
    """
    Called when the connection has been told to expect a certain quantity of
    bytes. This allows nested notifiers to change the expected quantity, which
    allows a lower level protocol to handle any framing (e.g. SSL).
    """
    qty

  fun ref closed(conn: DataChannel ref) =>
    """
    Called when the connection is closed.
    """
    None

  fun ref throttled(conn: DataChannel ref) =>
    """
    Called when the connection starts experiencing TCP backpressure. You should
    respond to this by pausing additional calls to `write` and `writev` until
    you are informed that pressure has been released. Failure to respond to
    the `throttled` notification will result in outgoing data queuing in the
    connection and increasing memory usage.
    """
    None

  fun ref unthrottled(conn: DataChannel ref) =>
    """
    Called when the connection stops experiencing TCP backpressure. Upon
    receiving this notification, you should feel free to start making calls to
    `write` and `writev` again.
    """
    None
