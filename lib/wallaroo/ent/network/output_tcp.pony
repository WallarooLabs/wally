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

class OutNotify is TCPConnectionNotify
  let _name: String

  new iso create(name: String) =>
    _name = name

  fun ref connected(sock: TCPConnection ref) =>
    @printf[I32]("%s outgoing connected\n".cstring(), _name.cstring())

  fun ref throttled(sock: TCPConnection ref) =>
    @printf[I32]("%s outgoing throttled\n".cstring(), _name.cstring())

  fun ref unthrottled(sock: TCPConnection ref) =>
    @printf[I32]("%s outgoing no longer throttled\n".cstring(),
      _name.cstring())

  fun ref connect_failed(conn: TCPConnection ref) =>
    @printf[I32](("%s: connection failed!\n").cstring(), _name.cstring())

  fun ref closed(conn: TCPConnection ref) =>
    @printf[I32](("%s: connection closed!\n").cstring(), _name.cstring())
