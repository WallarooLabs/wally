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

class ControlSenderConnectNotifier is TCPConnectionNotify
  let _auth: AmbientAuth
  let _worker_name: String
  var _header: Bool = true
  let _tcp_conn_wrapper: ControlConnection

  new iso create(auth: AmbientAuth, worker_name: String,
    tcp_conn_wrapper: ControlConnection)
  =>
    _auth = auth
    _worker_name = worker_name
    _tcp_conn_wrapper = tcp_conn_wrapper

  fun ref connected(conn: TCPConnection ref) =>
    _tcp_conn_wrapper.connected(conn)
    conn.expect(4)
    _header = true
    @printf[I32]("ControlSenderConnectNotifier: connected to %s.\n".cstring(),
      _worker_name.cstring())

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso,
    n: USize): Bool
  =>
    true

  fun ref connect_failed(conn: TCPConnection ref) =>
    @printf[I32]("ControlSenderConnectNotifier (to %s): connection failed!\n"
      .cstring(), _worker_name.cstring())

  fun ref closed(conn: TCPConnection ref) =>
    @printf[I32]("ControlSenderConnectNotifier (to %s): server closed\n"
      .cstring(), _worker_name.cstring())
    _tcp_conn_wrapper.closed(conn)
