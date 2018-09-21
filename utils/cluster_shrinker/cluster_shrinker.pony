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

"""
A tool for sending autoscale shrink messages.
"""
use "buffered"
use "net"
use "files"
use "wallaroo_labs/bytes"
use "wallaroo_labs/messages"
use "wallaroo_labs/options"

actor Main
  var _conn: (TCPConnection | None) = None

  new create(env: Env) =>
    try
      let options = Options(env.args)
      var x_host: String = ""
      var x_service: String = "0"
      var query = false
      var count = U64(0)
      var workers = recover iso Array[String] end

      options
        .add("external", "e", StringArgument)
        .add("query", "q", None)
        .add("count", "c", I64Argument)
        .add("workers", "w", StringArgument)
        .add("help", "h", None)

        for option in options do
          match option
          | ("external", let arg: String) =>
            let x_addr = arg.split(":")
            x_host = x_addr(0)?
            x_service = x_addr(1)?
          | ("query", None) =>
            query = true
          | ("count", let arg: I64) =>
            count = arg.u64()
          | ("workers", let arg: String) =>
            workers = arg.split(",")
          | ("help", None) =>
            _print_help(env)
            return
          end
        end

      // Check that exactly one of query, count, or workers was specified.
      if (query and ((count > 0) or (workers.size() > 0))) or
        (not query and (count == 0) and (workers.size() == 0)) or
        ((count > 0) and (workers.size() > 0))
      then
        env.err.print(("You must specify exactly one of --query, --count, " +  "or --workers"))
        env.exitcode(1)
        return
      end

      let auth = env.root as AmbientAuth
      let msg = ExternalMsgEncoder.shrink_request(query, consume workers,
        count)
      let tcp_auth = TCPConnectAuth(auth)
      _conn = TCPConnection(tcp_auth, ClusterShrinkerConnectNotifier(env, auth,
        msg, query, x_host, x_service), x_host, x_service)
    else
      _print_help(env)
      env.exitcode(1)
    end

  fun _print_help(env: Env) =>
    env.out.print(
      """
      PARAMETERS:
      -----------------------------------------------------------------------------------
      --external/-e [Specifies address to send message to]
      Specify exactly one of the following:
      --query/-q [Queries for workers eligible for removal]
      --count/-c [Specifies count of workers to remove from cluster]
      --workers/-w [Specifies workers to remove from cluster (provided as a comma-separated list of names)]
      -----------------------------------------------------------------------------------
      """)

class ClusterShrinkerConnectNotifier is TCPConnectionNotify
  let _env: Env
  let _auth: AmbientAuth
  let _msg: Array[ByteSeq] val
  var _header: Bool = true
  let _host: String
  let _service: String

  new iso create(env: Env, auth: AmbientAuth, msg: Array[ByteSeq] val,
    wait_for_response: Bool, host: String, service: String)
  =>
    _env = env
    _auth = auth
    _msg = msg
    _host = host
    _service = service

  fun ref connected(conn: TCPConnection ref) =>
    conn.writev(_msg)
    conn.expect(4)

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso,
    n: USize): Bool
  =>
    if _header then
      try
        let expect = Bytes.to_u32(data(0)?, data(1)?, data(2)?, data(3)?)
          .usize()
        conn.expect(expect)
        _header = false
      else
        _env.err.print("Error reading header")
        _env.exitcode(1)
        conn.dispose()
      end
    else
      try
        match ExternalMsgDecoder(consume data)?
        | let m: ExternalShrinkQueryResponseMsg =>
          _env.out.print("Eligible for shrink: " + m.string())
          conn.dispose()
        | let m: ExternalShrinkErrorResponseMsg =>
          _env.out.print("Cluster shrink response: " + m.msg.string())
          conn.dispose()
        else
          _env.err.print("Received incorrect external message type")
          _env.exitcode(1)
          conn.dispose()
        end
      else
        _env.err.print("Received invalid message")
        _env.exitcode(1)
        conn.dispose()
      end
      conn.expect(4)
      _header = true
    end
    true

  fun ref connect_failed(conn: TCPConnection ref) =>
    _env.err.print("Failed to connect to " + _host + ":" + _service)
    _env.exitcode(1)
