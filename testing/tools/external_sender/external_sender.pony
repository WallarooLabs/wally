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
A tool for test sending external messages.
"""
use "buffered"
use "net"
use "files"
use "wallaroo_labs/bytes"
use "wallaroo_labs/messages"
use "wallaroo_labs/mort"
use "wallaroo_labs/options"
use "wallaroo_labs/query"

actor Main
  var _conn: (TCPConnection | None) = None

  new create(env: Env) =>
    try
      var x_host: String = ""
      var x_service: String = "0"
      var message: String = ""
      var message_type: String = "Print"
      let options = Options(env.args)
      var await_response = false
      var json = false

      options
        .add("external", "e", StringArgument)
        .add("type", "t", StringArgument)
        .add("message", "m", StringArgument)
        .add("help", "h", None)
        .add("json", "j", None)

        for option in options do
          match option
          | ("external", let arg: String) =>
            let x_addr = arg.split(":")
            x_host = x_addr(0)?
            x_service = x_addr(1)?
          | ("message", let arg: String) => message = arg
          | ("type", let arg: String) => message_type = arg
          | ("json", None) => json = true
          | ("help", None) =>
            @printf[I32](
              """
              PARAMETERS:
              -----------------------------------------------------------------
              --json/-j                 [Output JSON format when avaiable]

              --external/-e <HOST:PORT> [Specifies address to send message to]

              --type/-t                 [Specifies message type]
                  clean-shutdown | rotate-log | partition-query |
                  partition-count-query | cluster-status-query |
                  source-ids-query | boundary-count-status |
                  state-entity-query | state-entity-count-query |
                  cluster-state-entity-count-query |
                  stateless-partition-query | stateless-partition-count-query |
                  print

              --message/-m              [Specifies message contents to send]
                  rotate-log
                      Node name to rotate log files
                  clean-shutdown | print
                      Text to embed in the message
              -----------------------------------------------------------------
              """.cstring())
            return
          end
        end

      let auth = env.root as AmbientAuth
      let msg =
        match message_type.lower()
        | "clean-shutdown" =>
          ExternalMsgEncoder.clean_shutdown(message)
        | "rotate-log" =>
          ExternalMsgEncoder.rotate_log(message)
        | "partition-query" =>
          await_response = true
          ExternalMsgEncoder.partition_query()
        | "partition-count-query" =>
          await_response = true
          ExternalMsgEncoder.partition_count_query()
        | "cluster-status-query" =>
          await_response = true
          ExternalMsgEncoder.cluster_status_query()
        | "source-ids-query" =>
          await_response = true
          ExternalMsgEncoder.source_ids_query()
        | "boundary-count-status" =>
          ExternalMsgEncoder.report_status("boundary-count-status")
        | "state-entity-query" =>
          await_response = true
          ExternalMsgEncoder.state_entity_query()
        | "stateless-partition-query" =>
          await_response = true
          ExternalMsgEncoder.stateless_partition_query()
        | "state-entity-count-query" =>
          await_response = true
          ExternalMsgEncoder.state_entity_count_query()
        | "cluster-state-entity-count-query" =>
          await_response = true
          ExternalMsgEncoder.cluster_state_entity_count_query()
        | "stateless-partition-count-query" =>
          await_response = true
          ExternalMsgEncoder.stateless_partition_count_query()
        else // default to print
          ExternalMsgEncoder.print_message(message)
        end
      let tcp_auth = TCPConnectAuth(auth)
      _conn = TCPConnection(tcp_auth, ExternalSenderConnectNotifier(env, auth,
        msg, await_response, json), x_host, x_service)
    else
      env.err.print("Error sending.")
    end

class ExternalSenderConnectNotifier is TCPConnectionNotify
  let _env: Env
  let _auth: AmbientAuth
  let _msg: Array[ByteSeq] val
  let _await_response: Bool
  var _header: Bool = true
  let _json: Bool

  new iso create(env: Env, auth: AmbientAuth, msg: Array[ByteSeq] val,
    await_response: Bool, json: Bool)
  =>
    _env = env
    _auth = auth
    _msg = msg
    _await_response = await_response
    _json = json

  fun ref connected(conn: TCPConnection ref) =>
    if not _json then
      _env.out.print("Connected...")
    end
    conn.writev(_msg)
    if not _await_response then
      conn.dispose()
    end
    try
      conn.expect(4)?
    else
      Fail()
    end

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso,
    n: USize): Bool
  =>
    if _header then
      try
        let expect = Bytes.to_u32(data(0)?, data(1)?, data(2)?, data(3)?)
          .usize()
        conn.expect(expect)?
        _header = false
      else
        _env.err.print("Error reading header")
        _env.exitcode(1)
        conn.dispose()
      end
    else
      try
        match ExternalMsgDecoder(consume data)?
        | let m: ExternalPartitionQueryResponseMsg =>
          if not _json then
            _env.out.print("Partition Distribution:")
          end
          _env.out.print(m.msg)
          conn.dispose()
        | let m: ExternalClusterStatusQueryResponseNotInitializedMsg =>
          if _json then
            _env.out.print(m.json)
          else
            _env.out.print("Cluster Status:")
            _env.out.print("Cluster not yet initialized")
            _env.out.print(m.string())
          end
          conn.dispose()
        | let m: ExternalClusterStatusQueryResponseMsg =>
          if  _json then
            _env.out.print(m.json)
          else
            _env.out.print("Cluster Status:")
            _env.out.print(m.string())
          end
          conn.dispose()
        | let m: ExternalPartitionCountQueryResponseMsg =>
          if not _json then
            _env.out.print("Partition Distribution (counts):")
          end
          _env.out.print(m.msg)
          conn.dispose()
          | let m: ExternalSourceIdsQueryResponseMsg =>
          if not _json then
            _env.out.print("Source Ids:" + "".join(m.source_ids.values()))
          else
            _env.out.print(m.json)
          end
          conn.dispose()
        | let m: ExternalStateEntityQueryResponseMsg =>
          if not _json then
            _env.out.print("State Entity Distribution:")
          end
          _env.out.print(m.msg)
          conn.dispose()
        | let m: ExternalStatelessPartitionQueryResponseMsg =>
          if not _json then
            _env.out.print("Stateless Partition Distribution:")
          end
          _env.out.print(m.msg)
          conn.dispose()
        | let m: ExternalStateEntityCountQueryResponseMsg =>
          if not _json then
            _env.out.print("State Entity Count:")
          end
          _env.out.print(m.msg)
          conn.dispose()
        | let m: ExternalClusterStateEntityCountQueryResponseMsg =>
          if not _json then
            _env.out.print("Cluster State Entity Count:")
          end
          _env.out.print(m.msg)
          conn.dispose()
        | let m: ExternalStatelessPartitionCountQueryResponseMsg =>
          if not _json then
            _env.out.print("Stateless Partition Count:")
          end
          _env.out.print(m.msg)
          conn.dispose()
        else
          _env.err.print("Received unhandled external message type")
          _env.exitcode(1)
          conn.dispose()
        end
      else
        _env.err.print("Received invalid message")
        _env.exitcode(1)
        conn.dispose()
      end
      try
        conn.expect(4)?
      else
        Fail()
      end
      _header = true
    end
    true

  fun ref connect_failed(conn: TCPConnection ref) =>
    _env.err.print("Failed to connect")
    _env.exitcode(1)
    conn.dispose()
