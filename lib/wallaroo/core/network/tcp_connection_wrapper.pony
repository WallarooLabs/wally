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
use "wallaroo/core/common"
use "wallaroo/core/messages"
use "wallaroo_labs/mort"


actor ControlConnection
  let _auth: AmbientAuth
  let _worker_name: WorkerName
  let _target_name: WorkerName
  let _c_service: String
  let _connections: Connections
  var _identified: Bool = false
  var _control_sender: _TCPConnectionControlSender =
    _PreTCPConnectionControlSender

  new create(auth: AmbientAuth, worker_name: WorkerName,
    target_name: WorkerName, c_service: String, connections: Connections)
  =>
    _auth = auth
    _worker_name = worker_name
    _target_name = target_name
    _c_service = c_service
    _connections = connections

  be connected(conn: TCPConnection) =>
    _connections.register_disposable(conn)
    _control_sender.flush(conn)
    _control_sender = _PostTCPConnectionControlSender(conn)
    if not _identified then _identify_control_port() end

  be closed(conn: TCPConnection) =>
    _control_sender = _PreTCPConnectionControlSender

  be write(data: ByteSeq) =>
    _control_sender.write(data)

  be writev(data: ByteSeqIter) =>
    _control_sender.writev(data)

  be dispose() =>
    @printf[I32]("Shutting down ControlConnection\n".cstring())
    _control_sender.dispose()

  fun ref _identify_control_port() =>
    try
      let message = ChannelMsgEncoder.identify_control_port(_worker_name,
        _c_service, _auth)?
      _connections.send_control(_target_name, message)
    else
      Fail()
    end
    _identified = true

trait _TCPConnectionControlSender
  fun ref write(data: ByteSeq)
  fun ref writev(data: ByteSeqIter)
  fun ref flush(conn: TCPConnection)
  fun dispose()

class _PreTCPConnectionControlSender is _TCPConnectionControlSender
  let _pending: Array[ByteSeq] = _pending.create()

  fun ref write(data: ByteSeq) =>
    _pending.push(data)
    recover Array[U8] end

  fun ref writev(data: ByteSeqIter) =>
    for bytes in data.values() do
      _pending.push(bytes)
    end
    recover Array[ByteSeq] end

  fun ref flush(conn: TCPConnection) =>
    for bytes in _pending.values() do
      conn.write(bytes)
    end

  fun dispose() =>
    None

class _PostTCPConnectionControlSender is _TCPConnectionControlSender
  let _conn: TCPConnection

  new create(conn: TCPConnection) =>
    _conn = conn

  fun ref write(data: ByteSeq) =>
    _conn.write(data)

  fun ref writev(data: ByteSeqIter) =>
    _conn.writev(data)

  fun ref flush(conn: TCPConnection) =>
    @printf[I32]("_PostTCPConnectionControlSender should not be flushed\n"
      .cstring())

  fun dispose() =>
    _conn.dispose()
