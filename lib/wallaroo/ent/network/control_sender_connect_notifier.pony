/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

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
    @printf[I32]("ControlSenderConnectNotifier: connection failed!\n"
      .cstring())

  fun ref closed(conn: TCPConnection ref) =>
    @printf[I32]("ControlSenderConnectNotifier: server closed\n".cstring())
