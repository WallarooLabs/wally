/*

Copyright 2018 The Wallaroo Authors.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
 implied. See the License for the specific language governing
 permissions and limitations under the License.

*/

trait WallarooOutgoingNetworkActorNotify
  fun ref connecting(conn: WallarooOutgoingNetworkActor ref, count: U32)
    """
    Called if name resolution succeeded for a WallarooOutgoingNetworkActor
    and we are now waiting for a connection to the server to succeed. The
    count is the number of connections we're trying. The notifier will be
    informed each time the count changes, until a connection is made or
    connect_failed() is called.
    """

  fun ref connected(conn: WallarooOutgoingNetworkActor ref)
    """
    Called when we have successfully connected to the server.
    """

  fun ref connect_failed(conn: WallarooOutgoingNetworkActor ref)
    """
    Called when we have failed to connect to all possible addresses for the
    server. At this point, the connection will never be established.
    """

  fun ref closed(conn: WallarooOutgoingNetworkActor ref)
    """
    Called when the connection is closed.
    """

  fun ref sentv(conn: WallarooOutgoingNetworkActor ref,
    data: ByteSeqIter): ByteSeqIter
    """
    Called when multiple chunks of data are sent to the connection in a single
    call. This gives the notifier an opportunity to modify the sent data chunks
    before they are written. To swallow the send, return an empty
    Array[String].
    """

  fun ref received(conn: WallarooOutgoingNetworkActor ref, data: Array[U8] iso,
    times: USize): Bool
    """
    Called when new data is received on the connection. Return true if you
    want to continue receiving messages without yielding until you read
    max_size on the WallarooOutgoingNetworkActorNotify.  Return false to
    cause the WallarooOutgoingNetworkActorNotify to yield now.

    `times` parameter is the number of times this method has been called during
    this behavior. Starts at 1.
    """

  fun ref expect(conn: WallarooOutgoingNetworkActor ref, qty: USize): USize
    """
    Called when the connection has been told to expect a certain quantity of
    bytes. This allows nested notifiers to change the expected quantity, which
    allows a lower level protocol to handle any framing (e.g. SSL).
    """

  fun ref throttled(conn: WallarooOutgoingNetworkActor ref)
    """
    Called when the connection starts experiencing TCP backpressure. You should
    respond to this by pausing additional calls to `write` and `writev` until
    you are informed that pressure has been released. Failure to respond to
    the `throttled` notification will result in outgoing data queuing in the
    connection and increasing memory usage.
    """

  fun ref unthrottled(conn: WallarooOutgoingNetworkActor ref)
    """
    Called when the connection stops experiencing TCP backpressure. Upon
    receiving this notification, you should feel free to start making calls to
    `write` and `writev` again.
    """

  fun ref dispose() =>
    """
    Called when the parent actor's dispose is called.
    """
    None
