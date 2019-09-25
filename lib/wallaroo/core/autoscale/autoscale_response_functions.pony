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
use "wallaroo/core/common"
use "wallaroo/core/messages"
use "wallaroo/core/network"
use "wallaroo_labs/mort"

type TryShrinkResponseFn is {(Array[ByteSeq] val)} val

trait tag TryJoinResponseFn
  be apply(response: Array[ByteSeq] val)
  be dispose()

actor TryJoinConnResponseFn is TryJoinResponseFn
  let _conn: TCPConnection

  new create(conn: TCPConnection) =>
    _conn = conn

  be apply(response: Array[ByteSeq] val) =>
    _conn.writev(response)

  be dispose() =>
    _conn.dispose()

actor TryJoinProxyResponseFn is TryJoinResponseFn
  let _connections: Connections
  let _proxy_worker_name: WorkerName
  let _conn_id: U128
  let _auth: AmbientAuth

  new create(connections: Connections, proxy_worker_name: WorkerName,
    conn_id: U128, auth: AmbientAuth)
  =>
    _connections = connections
    _proxy_worker_name = proxy_worker_name
    _conn_id = conn_id
    _auth = auth

  be apply(response: Array[ByteSeq] val) =>
    try
      let msg = ChannelMsgEncoder.try_join_response(
        response, _conn_id, _auth)?
      _connections.send_control(_proxy_worker_name, msg)
    else
      Fail()
    end

  be dispose() =>
    None

