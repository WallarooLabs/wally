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

use "buffered"
use "collections"
use "net"
use "wallaroo/core/boundary"
use "wallaroo/core/common"
use "wallaroo/core/data_receiver"
use "wallaroo/core/network"
use "wallaroo_labs/mort"


trait TestableDataChannelNotify[T: TCPActor ref] is TCPHandlerNotify[T]
  fun ref identify_data_receiver(dr: DataReceiver, sender_boundary_id: U128,
    highest_seq_id: SeqId, conn: DataChannel ref)
    """
    Each abstract data channel (a connection from an OutgoingBoundary)
    corresponds to a single DataReceiver. On reconnect, we want a new
    DataChannel for that boundary to use the same DataReceiver. This is
    called once we have found (or initially created) the DataReceiver for
    the DataChannel corresponding to this notify.
    """

type DataChannelAuth is (AmbientAuth | NetAuth | TCPAuth | TCPConnectAuth)

actor DataChannel is TCPActor
  var _listen: (DataChannelListener | None) = None
  var _notify: TestableDataChannelNotify[DataChannel ref]
  let _muted_downstream: SetIs[Any tag] = _muted_downstream.create()
  var _tcp_handler: TestableTCPHandler[DataChannel ref] =
    EmptyTCPHandler[DataChannel ref]

  new _accept(listen: DataChannelListener,
    notify: TestableDataChannelNotify[DataChannel ref] iso,
    fd: U32, init_size: USize = 64, max_size: USize = 16384)
  =>
    """
    A new connection accepted on a server.
    """
    let n: TestableDataChannelNotify[DataChannel ref] ref = consume notify
    _notify = n
    _listen = listen
    _tcp_handler = DataChannelTCPHandler(this, _notify, fd, init_size,
      max_size)
    _tcp_handler.accept()

  be identify_data_receiver(dr: DataReceiver, sender_step_id: RoutingId,
    highest_seq_id: SeqId)
  =>
    """
    Each abstract data channel (a connection from an OutgoingBoundary)
    corresponds to a single DataReceiver. On reconnect, we want a new
    DataChannel for that boundary to use the same DataReceiver. This is
    called once we have found (or initially created) the DataReceiver for
    this DataChannel.
    """
    _notify.identify_data_receiver(dr, sender_step_id, highest_seq_id, this)

  be mute(d: Any tag) =>
    """
    Temporarily suspend reading off this DataChannel until such time as
    `unmute` is called.
    """
    _mute(d)

  fun ref _mute(d: Any tag) =>
    _muted_downstream.set(d)
    _tcp_handler.mute()

  be unmute(d: Any tag) =>
    """
    Start reading off this DataChannel again after having been muted.
    """
    _unmute(d)

  fun ref _unmute(d: Any tag) =>
    _muted_downstream.unset(d)

    if _muted_downstream.size() == 0 then
      _tcp_handler.unmute()
    end

  fun ref closed() =>
    """
    Called by notify when the connection was closed
    """
    try (_listen as DataChannelListener)._conn_closed() end

  be dispose() =>
    """
    Close the connection gracefully once all writes are sent.
    """
    @printf[I32]("Shutting down DataChannel\n".cstring())
    close()

  /////////
  // TCP
  /////////
  be _event_notify(event: AsioEventID, flags: U32, arg: U32) =>
    _tcp_handler.event_notify(event, flags, arg)

  be write_again() =>
    _tcp_handler.write_again()

  be read_again() =>
    _tcp_handler.read_again()

  fun ref expect(qty: USize = 0) =>
    _tcp_handler.expect(qty)

  fun ref set_nodelay(state: Bool) =>
    _tcp_handler.set_nodelay(state)

  fun ref close() =>
    _tcp_handler.close()

  be write(data: ByteSeq) =>
    _tcp_handler.write(data)

  be writev(data: ByteSeqIter) =>
    _tcp_handler.writev(data)

