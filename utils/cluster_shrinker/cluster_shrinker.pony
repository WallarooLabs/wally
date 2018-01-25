/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

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
      var workers = Array[String]

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
            env.out.print(
              """
              PARAMETERS:
              -----------------------------------------------------------------------------------
              --external/-e [Specifies address to send message to]
              --query/-q [Queries for workers eligible for removal]
              --count/-c [Specifies count of workers to remove from cluster]
              --workers/-w [Specifies workers to remove from cluster (provided as a comma-separated list of names)]
              -----------------------------------------------------------------------------------
              """)
            return
          end
        end

      let auth = env.root as AmbientAuth
      let msg = ExternalMsgEncoder.shrink(query, workers, count)
      let tcp_auth = TCPConnectAuth(auth)
      _conn = TCPConnection(tcp_auth, ClusterShrinkerConnectNotifier(env, auth,
        msg, query), x_host, x_service)
    else
      env.exitcode(1)
    end

class ClusterShrinkerConnectNotifier is TCPConnectionNotify
  let _env: Env
  let _auth: AmbientAuth
  let _msg: Array[ByteSeq] val
  let _wait_for_response: Bool
  var _header: Bool = true

  new iso create(env: Env, auth: AmbientAuth, msg: Array[ByteSeq] val,
    wait_for_response: Bool)
  =>
    _env = env
    _auth = auth
    _msg = msg
    _wait_for_response = wait_for_response

  fun ref connected(conn: TCPConnection ref) =>
    conn.writev(_msg)
    if _wait_for_response then
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
        _env.err.print("Error reading header")
      end
    else
      try
        match ExternalMsgDecoder(consume data)?
        | let m: ExternalShrinkMsg =>
          _env.out.print("Received ExternalShrinkMsg: " + m.string())
          conn.dispose()
        else
          _env.err.print("Received non-shrink msg")
        end
      else
        _env.err.print("Received invalid msg")
      end
      conn.expect(4)
      _header = true
    end
    true

  fun ref connect_failed(conn: TCPConnection ref) =>
    None
