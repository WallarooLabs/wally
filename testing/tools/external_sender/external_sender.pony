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
      var stay_alive: Bool = false
      let options = Options(env.args)

      options
        .add("external", "e", StringArgument)
        .add("type", "t", StringArgument)
        .add("message", "m", StringArgument)
        .add("stay-alive", "s", None)
        .add("help", "h", None)

        for option in options do
          match option
          | ("external", let arg: String) =>
            let x_addr = arg.split(":")
            x_host = x_addr(0)?
            x_service = x_addr(1)?
          | ("message", let arg: String) => message = arg
          | ("type", let arg: String) => message_type = arg
          | ("stay-alive", None) => stay_alive = true
          | ("help", None) =>
            @printf[I32](
              """
              PARAMETERS:
              -----------------------------------------------------------------------------------
              --external/-e [Specifies address to send message to]
              --type/-t [Specifies message type]
                  clean-shutdown | rotate-log | shrink | print
              --message/-m [Specifies message contents to send]
                  rotate-log
                      Node name to rotate log files
                  clean-shutdown | print
                      Text to embed in the message
                  shrink
                      Specify names of nodes or number of nodes.
                      If 1st char is a digit, specify number of of nodes;
                      else specify comma-separated list of node names.
              --stay-alive/-s [Keep connection alive]
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
        | "shrink" =>
          (let query: Bool,
            let node_names: Array[String], let num_nodes: USize) =
            parse_shrink_cmd_line(message)?
          ExternalMsgEncoder.shrink(query, node_names, num_nodes)
        else // default to print
          ExternalMsgEncoder.print_message(message)
        end
      let tcp_auth = TCPConnectAuth(auth)
      _conn = TCPConnection(tcp_auth, ExternalSenderConnectNotifier(auth,
        msg, stay_alive), x_host, x_service)
    else
      @printf[I32]("Error sending.\n".cstring())
    end

    fun parse_shrink_cmd_line(s: String): (Bool, Array[String], USize) ? =>
      let first: U8 = s(0)?

      if (first == '?') then
        return (true, [], 0)
      elseif (first >= U8('0')) and (first <= U8('9')) then
        return (false, [], s.usize()?)
      else
        return (false, s.split(","), 0)
      end

class ExternalSenderConnectNotifier is TCPConnectionNotify
  let _auth: AmbientAuth
  let _msg: Array[ByteSeq] val
  let _stay_alive: Bool
  var _header: Bool = true

  new iso create(auth: AmbientAuth, msg: Array[ByteSeq] val,
    stay_alive: Bool)
  =>
    _auth = auth
    _msg = msg
    _stay_alive = stay_alive

  fun ref connected(conn: TCPConnection ref) =>
    @printf[I32]("Connected...\n".cstring())
    conn.writev(_msg)
    @printf[I32]("Sent message!\n".cstring())
    if _stay_alive then
      conn.expect(4)
    else
      conn.dispose()
    end

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
        @printf[I32]("Error reading header\n".cstring())
      end
    else
      try
        match ExternalMsgDecoder(consume data)?
        | let m: ExternalShrinkMsg =>
          @printf[I32]("Received ExternalShrinkMsg: %s\n".cstring(),
            m.string().cstring())
        else
          @printf[I32]("Received non-shrink msg\n".cstring())
        end
      else
        @printf[I32]("Received invalid msg\n".cstring())
      end
      conn.expect(4)
      _header = true
    end
    true

  fun ref connect_failed(conn: TCPConnection ref) =>
    None
