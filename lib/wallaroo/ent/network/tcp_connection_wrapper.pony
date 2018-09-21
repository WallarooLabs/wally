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

actor ControlConnection
  let _connections: Connections
  var _control_sender: _TCPConnectionControlSender =
    _PreTCPConnectionControlSender

  new create(connections: Connections) =>
    _connections = connections

  be connected(conn: TCPConnection) =>
    _connections.register_disposable(conn)
    _control_sender.flush(conn)
    _control_sender = _PostTCPConnectionControlSender(conn)

  be closed(conn: TCPConnection) =>
    _control_sender = _PreTCPConnectionControlSender

  be write(data: ByteSeq) =>
    _control_sender.write(data)

  be writev(data: ByteSeqIter) =>
    _control_sender.writev(data)

  be dispose() =>
    @printf[I32]("Shutting down ControlConnection\n".cstring())
    _control_sender.dispose()

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
