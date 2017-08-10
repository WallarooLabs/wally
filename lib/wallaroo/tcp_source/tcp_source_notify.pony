use "collections"
use "wallaroo/boundary"
use "wallaroo/core"
use "wallaroo/messages"
use "wallaroo/routing"
use "wallaroo/topology"

interface TCPSourceNotify
  // TODO: CREDITFLOW - this is weird that its here
  // It exists so that a TCPSource can get its routes
  // on startup. It probably makes more sense to make this
  // available via the source builder that Listener gets
  // and it can then make routes available
  fun ref routes(): Array[Consumer] val

  fun ref update_router(router: Router val)

  fun ref update_boundaries(obs: box->Map[String, OutgoingBoundary])

  fun ref accepted(conn: TCPSource ref) =>
    """
    Called when a TCPSource is accepted by a TCPSourceListener.
    """
    None

  fun ref connecting(conn: TCPSource ref, count: U32) =>
    """
    Called if name resolution succeeded for a TCPSource and we are now
    waiting for a connection to the server to succeed. The count is the number
    of connections we're trying. The notifier will be informed each time the
    count changes, until a connection is made or connect_failed() is called.
    """
    None

  fun ref connected(conn: TCPSource ref) =>
    """
    Called when we have successfully connected to the server.
    """
    None


  fun ref connect_failed(conn: TCPSource ref) =>
    """
    Called when we have failed to connect to all possible addresses for the
    server. At this point, the connection will never be established.
    """
    None

  fun ref received(conn: TCPSource ref, data: Array[U8] iso): Bool =>
    """
    Called when new data is received on the connection. Return true if you
    want to continue receiving messages without yielding until you read
    max_size on the TCPSource.  Return false to cause the TCPSource
    to yield now.
    """
    true

  fun ref expect(conn: TCPSource ref, qty: USize): USize =>
    """
    Called when the connection has been told to expect a certain quantity of
    bytes. This allows nested notifiers to change the expected quantity, which
    allows a lower level protocol to handle any framing (e.g. SSL).
    """
    qty


  fun ref closed(conn: TCPSource ref) =>
    """
    Called when the connection is closed.
    """
    None
