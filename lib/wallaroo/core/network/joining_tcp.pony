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
    JoiningConnectNotifier

  fun ref closed(listen: TCPListener ref) =>
    @printf[I32]("Joining Worker Listener: listener closed\n".cstring())

class JoiningConnectNotifier is TCPConnectionNotify
  fun ref connected(conn: TCPConnection ref) =>
    None

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso,
    n: USize): Bool
  =>
    true

  fun ref connect_failed(conn: TCPConnection ref) =>
    @printf[I32](("JoiningConnectNotifier: connection failed!\n").cstring())

  fun ref closed(conn: TCPConnection ref) =>
    @printf[I32]("JoiningConnectNotifier: server closed\n".cstring())
