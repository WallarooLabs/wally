use "wallaroo/routing"

interface WallarooOutgoingNetworkActor
  fun ref set_nodelay(state: Bool)
    """
    Turn Nagle on/off. Defaults to on. This can only be set on a connected
    socket.
    """

  fun ref expect(qty: USize = 0)
    """
    A `received` call on the notifier must contain exactly `qty` bytes. If
    `qty` is zero, the call can contain any amount of data. This has no effect
    if called in the `sent` notifier callback.
    """

  fun ref receive_ack(seq_id: SeqId)
    """
    Called when processing an acknowledgment of a message sent over the
    connection
    """

  fun ref close()
    """
    Called to close the connection in a graceful fashion
    """
