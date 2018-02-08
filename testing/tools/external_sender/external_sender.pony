/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

"""
A tool for test sending external messages.
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
      var x_host: String = ""
      var x_service: String = "0"
      var message: String = ""
      var message_type: String = "Print"
      let options = Options(env.args)
      var await_response = false

      options
        .add("external", "e", StringArgument)
        .add("type", "t", StringArgument)
        .add("message", "m", StringArgument)
        .add("help", "h", None)

        for option in options do
          match option
          | ("external", let arg: String) =>
            let x_addr = arg.split(":")
            x_host = x_addr(0)?
            x_service = x_addr(1)?
          | ("message", let arg: String) => message = arg
          | ("type", let arg: String) => message_type = arg
          | ("help", None) =>
            @printf[I32](
              """
              PARAMETERS:
              -----------------------------------------------------------------------------------
              --external/-e [Specifies address to send message to]
              --type/-t [Specifies message type]
                  clean-shutdown | rotate-log | partition-query |
                  cluster-status-query | print
              --message/-m [Specifies message contents to send]
                  rotate-log
                      Node name to rotate log files
                  clean-shutdown | print
                      Text to embed in the message
              -----------------------------------------------------------------------------------
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
        | "cluster-status-query" =>
          await_response = true
          ExternalMsgEncoder.cluster_status_query()
        else // default to print
          ExternalMsgEncoder.print_message(message)
        end
      let tcp_auth = TCPConnectAuth(auth)
      _conn = TCPConnection(tcp_auth, ExternalSenderConnectNotifier(env, auth,
        msg, await_response), x_host, x_service)
    else
      env.err.print("Error sending.")
    end

class ExternalSenderConnectNotifier is TCPConnectionNotify
  let _env: Env
  let _auth: AmbientAuth
  let _msg: Array[ByteSeq] val
  let _await_response: Bool
  var _header: Bool = true

  new iso create(env: Env, auth: AmbientAuth, msg: Array[ByteSeq] val,
    await_response: Bool)
  =>
    _env = env
    _auth = auth
    _msg = msg
    _await_response = await_response

  fun ref connected(conn: TCPConnection ref) =>
    _env.out.print("Connected...")
    conn.writev(_msg)
    if not _await_response then
      conn.dispose()
    end
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
        | let m: ExternalPartitionQueryResponseMsg =>
          _env.out.print("Partition Distribution:")
          _env.out.print(m.msg)
          conn.dispose()
        | let m: ExternalClusterStatusQueryResponseMsg =>
          _env.out.print("Cluster Status:")
          _env.out.print(m.string())
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
      conn.expect(4)
      _header = true
    end
    true

  fun ref connect_failed(conn: TCPConnection ref) =>
    _env.err.print("Failed to connect")
    conn.dispose()
