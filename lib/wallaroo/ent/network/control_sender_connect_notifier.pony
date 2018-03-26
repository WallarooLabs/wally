/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "net"
use "wallaroo_labs/testing"

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
    //SLF: TODO
    /**** Uncomment when TCPConnection.set_so_recvbuf() is available.
    ifdef "wtest" then
      try
        conn.set_so_rcvbuf(EnvironmentVar.get3(
          "W_BUFSIZ", "CONTROL_SENDER", "RCV").u32()?)
      end
      try
        conn.set_so_sndbuf(EnvironmentVar.get3(
          "W_BUFSIZ", "CONTROL_SENDER", "SND").u32()?)
      end
    end
    ****/
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

  fun ref throttled(conn: TCPConnection ref) =>
    @printf[I32]("ControlSenderConnectNotifier: throttled.\n".cstring())
    //SLF: TODO

  fun ref unthrottled(conn: TCPConnection ref) =>
    @printf[I32]("ControlSenderConnectNotifier: unthrottled.\n".cstring())
    //SLF: TODO
