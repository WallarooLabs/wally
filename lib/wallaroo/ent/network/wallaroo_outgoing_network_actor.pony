/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "wallaroo/core/common"
use "wallaroo/core/routing"

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

  fun ref receive_connect_ack(seq_id: SeqId)
    """
    Called when processing an acknowledgment of successful connection to a
    DataReceiver
    """

  fun ref start_normal_sending()
    """
    Called when we are ready to begin sending messages normally (after
    replay is complete)
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

  fun ref set_so_sndbuf(bufsiz: U32): U32 =>
    """
    Temp hack
    """
    8823783 // not implemented
