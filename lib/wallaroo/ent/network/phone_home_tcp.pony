/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "net"
use "sendence/messages"
use "sendence/bytes"

class HomeConnectNotify is TCPConnectionNotify
  let _name: String
  let _connections: Connections
  var _header: Bool = true
  var _has_connected: Bool = false

  new iso create(name: String, connections: Connections) =>
    _name = name
    _connections = connections

  fun ref connected(conn: TCPConnection ref) =>
    if not _has_connected then
      conn.expect(4)
      _has_connected = true
    end

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso,
    n: USize): Bool
  =>
    if _header then
      try
        let expect = Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()
        conn.expect(expect)
        _header = false
      else
        @printf[I32]("Error reading header on phone home channel\n".cstring())
      end
    else
      try
        let external_msg = ExternalMsgDecoder(consume data)
        match external_msg
        | let m: ExternalShutdownMsg =>
          @printf[I32]("Received ExternalShutdownMsg\n".cstring())
          _connections.shutdown()
        | let m: ExternalRotateLogFilesMsg =>
          @printf[I32]("Received ExternalRotateLogFilesMsg\n".cstring())
          _connections.rotate_log_files(m.node_name)
        end
      else
        @printf[I32](("Phone home connection: error decoding phone home " +
          "message\n").cstring())
      end

      conn.expect(4)
      _header = true
    end
    true

  fun ref closed(conn: TCPConnection ref) =>
    @printf[I32](("HomeConnectNotify: " + _name + ": server closed\n")
      .cstring())
