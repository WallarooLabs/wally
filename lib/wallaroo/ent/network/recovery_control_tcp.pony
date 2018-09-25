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

use "net"
use "collections"
use "wallaroo"
use "wallaroo/core/common"
use "wallaroo/core/initialization"
use "wallaroo/core/messages"
use "wallaroo/ent/recovery"
use "wallaroo_labs/bytes"
use "wallaroo_labs/mort"

//!@ Remove
class RecoveryControlSenderConnectNotifier is TCPConnectionNotify
  let _auth: AmbientAuth
  let _worker_name: String
  let _startup: Startup
  var _header: Bool = true

  new iso create(auth: AmbientAuth, worker_name: String, startup: Startup) =>
    _auth = auth
    _worker_name = worker_name
    _startup = startup

  fun ref connected(conn: TCPConnection ref) =>
    try
      let msg = ChannelMsgEncoder.request_recovery_info(_worker_name, _auth)?
      conn.writev(msg)
    else
      Fail()
    end
    conn.expect(4)
    _header = true

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso,
    n: USize): Bool
  =>
    if _header then
      try
        let expect = Bytes.to_u32(data(0)?, data(1)?, data(2)?, data(3)?).usize()
        conn.expect(expect)
        _header = false
      else
        @printf[I32]("Error reading header on control channel\n".cstring())
      end
    else
      let msg = ChannelMsgDecoder(consume data, _auth)
      match msg
      | let m: InformRecoveringWorkerMsg =>
        @printf[I32]("***Received cluster information!***\n".cstring())
        _startup.recover_and_initialize(m.checkpoint_id)
      | let m: CleanShutdownMsg =>
        @printf[I32]("Shutting down early: %s\n".cstring(), m.msg.cstring())
        _startup.dispose()
      else
        @printf[I32](("Incoming Channel Message type not handled by " +
          "recovery control channel.\n").cstring())
      end
      conn.expect(4)
      _header = true
    end
    true

  fun ref connect_failed(conn: TCPConnection ref) =>
    @printf[I32]("RecoveryControlSenderConnectNotifier: connection failed!\n"
      .cstring())

  fun ref closed(conn: TCPConnection ref) =>
    @printf[I32]("RecoveryControlSenderConnectNotifier: server closed\n"
      .cstring())

class iso RecoveryListenNotifier is TCPListenNotify
  """
  The sole purpose of this listener is to keep a recovery worker process alive
  while waiting to get cluster info and initialize.
  TODO: Eliminate the need for this.
  """
  fun ref listening(listen: TCPListener ref) =>
    try
      (let host, let service) = listen.local_address().name()?
      @printf[I32](("Recovery Worker Listener listening on " + host + ":" +
        service + "\n").cstring())
    else
      @printf[I32]("Recovery Worker Listener: couldn't get local address\n"
        .cstring())
      listen.close()
    end

  fun ref not_listening(listen: TCPListener ref) =>
    @printf[I32]("Recovery Worker Listener: couldn't listen\n".cstring())
    listen.close()

  fun ref connected(listen: TCPListener ref): TCPConnectionNotify iso^ =>
    RecoveryConnectNotifier

  fun ref closed(listen: TCPListener ref) =>
    @printf[I32]("Recovery Worker Listener: listener closed\n".cstring())

class RecoveryConnectNotifier is TCPConnectionNotify
  fun ref connected(conn: TCPConnection ref) =>
    None

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso,
    n: USize): Bool
  =>
    true

  fun ref connect_failed(conn: TCPConnection ref) =>
    @printf[I32](("RecoveryConnectNotifier: connection failed!\n").cstring())

  fun ref closed(conn: TCPConnection ref) =>
    @printf[I32]("RecoveryConnectNotifier: server closed\n".cstring())
