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
use "time"
use "wallaroo/core/common"
use "wallaroo_labs/mort"

class ControlSenderConnectNotifier is TCPConnectionNotify
  let _auth: AmbientAuth
  let _target_worker: WorkerName
  let _host: String
  let _service: String
  var _header: Bool = true
  let _tcp_conn_wrapper: ControlConnection
  let _connections: Connections
  let _timers: Timers = Timers

  new iso create(auth: AmbientAuth, target_worker: WorkerName, host: String,
    service: String, tcp_conn_wrapper: ControlConnection,
    connections: Connections)
  =>
    _auth = auth
    _target_worker = target_worker
    _host = host
    _service = service
    _tcp_conn_wrapper = tcp_conn_wrapper
    _connections = connections

  fun ref connected(conn: TCPConnection ref) =>
    _tcp_conn_wrapper.connected(conn)
    try
      conn.expect(4)?
    else
      Fail()
    end
    _header = true
    @printf[I32]("ControlSenderConnectNotifier: connected to %s at %s:%s.\n"
      .cstring(), _target_worker.cstring(), _host.cstring(),
      _service.cstring())

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso,
    n: USize): Bool
  =>
    true

  fun ref connect_failed(conn: TCPConnection ref) =>
    @printf[I32](("ControlSenderConnectNotifier: connection to %s at %s:%s " +
      " failed!\n").cstring(), _target_worker.cstring(), _host.cstring(),
      _service.cstring())
    let t = Timer(_Reconnect(_target_worker, _host, _service, _connections),
      1_000_000_000)
    _timers(consume t)
    _tcp_conn_wrapper.closed(conn)

  fun ref closed(conn: TCPConnection ref) =>
    @printf[I32](("ControlSenderConnectNotifier: connection to %s at %s:%s " +
      " closed\n").cstring(), _target_worker.cstring(), _host.cstring(),
      _service.cstring())
    _tcp_conn_wrapper.closed(conn)

class _Reconnect is TimerNotify
  let _target_worker: WorkerName
  let _host: String
  let _service: String
  let _connections: Connections

  new iso create(target_worker: WorkerName, host: String, service: String,
    connections: Connections)
  =>
    _target_worker = target_worker
    _host = host
    _service = service
    _connections = connections

  fun ref apply(timer: Timer, count: U64): Bool =>
    _connections.create_control_connection(_target_worker, _host, _service)
    false
