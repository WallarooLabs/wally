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
