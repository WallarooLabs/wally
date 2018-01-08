/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "net"

actor ControlConnection
  var _control_sender: _TCPConnectionControlSender =
    _PreTCPConnectionControlSender

  be connected(conn: TCPConnection) =>
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
