/*

Copyright 2019 The Wallaroo Authors.

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


trait TCPActor
  fun ref tcp_handler(): TestableTCPHandler

  // This behavior is called by the Pony runtime.
  be _event_notify(event: AsioEventID, flags: U32, arg: U32) =>
    tcp_handler().event_notify(event, flags, arg)

  be write_again() =>
    tcp_handler().write_again()

  be read_again() =>
    tcp_handler().read_again()

  fun ref expect(qty: USize = 0) =>
    tcp_handler().expect(qty)

  fun ref set_nodelay(state: Bool) =>
    tcp_handler().set_nodelay(state)

  fun ref close() =>
    tcp_handler().close()

  // !TODO! Can we eliminate this?
  fun ref accepted() =>
    None

  fun ref connecting(count: U32) =>
    """
    Called if name resolution succeeded for a TCPActor
    and we are now waiting for a connection to the server to succeed. The
    count is the number of connections we're trying. The notifier will be
    informed each time the count changes, until a connection is made or
    connect_failed() is called.
    """
    None

  fun ref connected() =>
    """
    Called when we have successfully connected to the server.
    """
    None

  fun ref connect_failed() =>
    """
    Called when we have failed to connect to all possible addresses for the
    server. At this point, the connection will never be established.
    """
    None

  fun ref closed(locally_initiated_close: Bool) =>
    """
    Called when the connection is closed.
    """
    None

  fun ref sent(data: ByteSeq): ByteSeq =>
    """
    Called when data is sent on the connection. This gives the notifier an
    opportunity to modify sent data before it is written. To swallow data,
    return an empty string.
    """
    data

  fun ref sentv(data: ByteSeqIter): ByteSeqIter =>
    """
    Called when multiple chunks of data are sent to the connection in a single
    call. This gives the notifier an opportunity to modify the sent data chunks
    before they are written. To swallow the send, return an empty
    Array[String].
    """
    data

  fun ref received(data: Array[U8] iso, times: USize): Bool =>
    """
    Called when new data is received on the connection. Return true if you
    want to continue receiving messages without yielding until you read
    max_size on the TNotify.  Return false to
    cause the TNotify to yield now.

    `times` parameter is the number of times this method has been called during
    this behavior. Starts at 1.
    """
    true

  fun ref throttled() =>
    """
    Called when the connection starts experiencing TCP backpressure. You should
    respond to this by pausing additional calls to `write` and `writev` until
    you are informed that pressure has been released. Failure to respond to
    the `throttled` notification will result in outgoing data queuing in the
    connection and increasing memory usage.
    """
    None

  fun ref unthrottled() =>
    """
    Called when the connection stops experiencing TCP backpressure. Upon
    receiving this notification, you should feel free to start making calls to
    `write` and `writev` again.
    """
    None
