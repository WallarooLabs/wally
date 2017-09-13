/*

Copyright 2017 The Wallaroo Authors.

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
use "wallaroo_labs/messages"

actor Main
  new create(env: Env) =>
    try
      let split = env.args(1).split(":")
      let host = split(0)
      let service = split(1)

      let auth = env.root as AmbientAuth
      let tcp_auth = TCPConnectAuth(auth)
      TCPConnection(tcp_auth, Notifier(env, host, service), host, service)
    else
      env.err.print("Usage: cluster_shutdown HOST:PORT")
      env.exitcode(1)
    end

class Notifier is TCPConnectionNotify
  let _env: Env
  let _host: String
  let _service: String

  new iso create(env: Env, host: String, service: String) =>
    _env = env
    _host = host
    _service = service

  fun ref connected(conn: TCPConnection ref) =>
    conn.writev(ExternalMsgEncoder.clean_shutdown())
    conn.dispose()

  fun ref connect_failed(conn: TCPConnection ref) =>
    _env.err.print("Error: Unable to connect to " + _host + ":" + _service)
    _env.exitcode(1)

