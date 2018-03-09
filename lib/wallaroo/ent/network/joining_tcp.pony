/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "net"

class iso JoiningListenNotifier is TCPListenNotify
  """
  The sole purpose of this listener is to keep a joining worker process alive
  while waiting to get cluster info and initialize.
  TODO: Eliminate the need for this.
  """
  fun ref listening(listen: TCPListener ref) =>
    try
      (let host, let service) = listen.local_address().name()?
      @printf[I32](("Joining Worker Listener listening on " + host + ":" +
        service + "\n").cstring())
    else
      @printf[I32]("Joining Worker Listener: couldn't get local address\n"
        .cstring())
      listen.close()
    end

  fun ref not_listening(listen: TCPListener ref) =>
    @printf[I32]("Joining Worker Listener: couldn't listen\n".cstring())
    listen.close()

  fun ref connected(listen: TCPListener ref): TCPConnectionNotify iso^ =>
    //SLF: TODO
    JoiningConnectNotifier

  fun ref closed(listen: TCPListener ref) =>
    @printf[I32]("Joining Worker Listener: listener closed\n".cstring())

class JoiningConnectNotifier is TCPConnectionNotify
  fun ref connected(conn: TCPConnection ref) =>
    //SLF: TODO
    None

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso,
    n: USize): Bool
  =>
    true

  fun ref connect_failed(conn: TCPConnection ref) =>
    @printf[I32](("JoiningConnectNotifier: connection failed!\n").cstring())

  fun ref closed(conn: TCPConnection ref) =>
    @printf[I32]("JoiningConnectNotifier: server closed\n".cstring())

  fun ref throttled(conn: TCPConnection ref) =>
    @printf[I32]("JoiningConnectNotifier: throttled.\n".cstring())
    //SLF: TODO

  fun ref unthrottled(conn: TCPConnection ref) =>
    @printf[I32]("JoiningConnectNotifier: unthrottled.\n".cstring())
    //SLF: TODO