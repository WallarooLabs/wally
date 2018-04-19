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

"""
Giles receiver
"""
use "collections"
use "files"
use "net"
use "wallaroo_labs/options"
use "signals"
use "time"
use "wallaroo_labs/messages"
use "wallaroo_labs/bytes"
use "wallaroo_labs/time"
use "debug"

// tests
// documentation

actor Main
  new create(env: Env) =>
    var required_args_are_present = true
    var run_tests = env.args.size() == 1
    var use_metrics = false
    var no_write = false

    if run_tests then
      TestMain(env)
    else
      var l_arg: (Array[String] | None) = None
      var e_arg: (USize | None) = None

      try
        var options = Options(env.args)

        options
          .add("listen", "l", StringArgument)
          .add("expect", "e", I64Argument)
          .add("metrics", "m", None)
          .add("no-write", "w", None)

        for option in options do
          match option
          | ("listen", let arg: String) => l_arg = arg.split(":")
          | ("expect", let arg: I64) => e_arg = arg.usize()
          | ("metrics", None) => use_metrics = true
          | ("no-write", None) => no_write = true
          | let err: ParseError =>
            err.report(env.err)
            required_args_are_present = false
          end
        end

        if l_arg is None then
          @printf[I32]("Must supply required '--listen' argument\n".cstring())
          required_args_are_present = false
        else
          if (l_arg as Array[String]).size() != 2 then
            @printf[I32](
              "'--listen' argument should be in format: '127.0.0.1:8080\n"
              .cstring())
            required_args_are_present = false
          end
        end

        if (e_arg isnt None) then
          try
            let e' = (e_arg as USize)
            if e' < 1 then error end
          else
            @printf[I32](
              "'--expect' must be an integer greater than 0\n"
              .cstring())
            required_args_are_present = false
          end
        end

        if required_args_are_present then
          let listener_addr = l_arg as Array[String]

          let store = Store(env.root as AmbientAuth, e_arg)
          let coordinator = Coordinator(env, store, e_arg, use_metrics)

          SignalHandler(TermHandler(coordinator), Sig.term())
          SignalHandler(TermHandler(coordinator), Sig.int())

          let tcp_auth = TCPListenAuth(env.root as AmbientAuth)
          TCPListener(tcp_auth,
            ListenerNotify(coordinator, store, env.err, no_write),
            listener_addr(0)?,
            listener_addr(1)?)

        else
          error
        end
      else
        @printf[I32](
          """
          --listen/-l <address> [Address giles-receiver node is listening on]
          --expect/-e <number> [Number of messages to process before terminating]
          --metrics/-m [Add metrics reporting]
          """)
      end
    end

class ListenerNotify is TCPListenNotify
  let _coordinator: Coordinator
  let _store: Store
  let _stderr: OutStream
  let _no_write: Bool

  new iso create(coordinator: Coordinator,
    store: Store, stderr: OutStream, no_write: Bool)
  =>
    _coordinator = coordinator
    _store = store
    _stderr = stderr
    _no_write = no_write

  fun ref not_listening(listen: TCPListener ref) =>
    _coordinator.register_listener(listen, Failed)

  fun ref listening(listen: TCPListener ref) =>
    _coordinator.register_listener(listen, Ready)

  fun ref connected(listen: TCPListener ref): TCPConnectionNotify iso^ =>
    Notify(_coordinator, _store, _stderr, _no_write)

class Notify is TCPConnectionNotify
  let _coordinator: Coordinator
  let _store: Store
  let _stderr: OutStream
  var _header: Bool = true
  let _no_write: Bool
  var _closed: Bool = false

  new iso create(coordinator: Coordinator,
    store: Store, stderr: OutStream, no_write: Bool)
  =>
    _coordinator = coordinator
    _store = store
    _stderr = stderr
    _no_write = no_write

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso,
    n: USize): Bool
  =>
    if _header then
      try
        let expect = Bytes.to_u32(data(0)?, data(1)?, data(2)?, data(3)?).usize()

        conn.expect(expect)
        _header = false
      else
        @printf[I32]("Blew up reading header from Buffy\n".cstring())
      end
    else
      if not _no_write then
        _store.received(consume data, WallClock.nanoseconds())
      end
      _coordinator.received_message()
      conn.expect(4)
      _header = true
    end
    true

  fun ref accepted(conn: TCPConnection ref) =>
    conn.expect(4)

  fun ref connect_failed(conn: TCPConnection ref) =>
    @printf[I32]("Notify: connection failed.\n".cstring())

//
// COORDINATE OUR STARTUP
//

primitive Waiting
primitive Ready
primitive Failed

type WorkerState is (Waiting | Ready | Failed)

actor Coordinator
  let _env: Env
  let _store: Store
  var _listener: ((TCPListener | None), WorkerState) = (None, Waiting)
  let _expected: USize
  var _count: USize = 0
  var _finished: Bool = false
  let _metrics: Metrics tag = Metrics
  let _use_metrics: Bool

  new create(env: Env, store: Store, expected: (USize | None),
    use_metrics: Bool)
  =>
    _env = env
    _store = store
    _expected = try (expected as USize) else USize.max_value() end
    _use_metrics = use_metrics

  be finished() =>
    _do_finished()

  fun ref _do_finished() =>
    _finished = true
    try
      let x = _listener._1 as TCPListener
      x.dispose()
    end
    _store.dump()

  be received_message() =>
    if _finished then
      return
    end
    if _use_metrics and (_count == 0)then
      _metrics.set_start(Time.nanos())
    end
    _count = _count + 1
    if _count >= _expected then
      @printf[I32]((_count.string() + " expected messages received. " +
            "Terminating...\n").cstring())
      if _use_metrics then
        _metrics.set_end(Time.nanos(), _expected)
      end
      _do_finished()
    end

  be register_listener(listener: TCPListener, state: WorkerState) =>
    _listener = (listener, state)
    if state is Failed then
      @printf[I32]("Unable to open listener\n".cstring())
      listener.dispose()
    elseif state is Ready then
      @printf[I32]("Listening for data\n".cstring())
    end

///
/// RECEIVED MESSAGE STORE
///

actor Store
  let _received_file: (File | None)
  var _count: USize = 0
  let _expected: USize

  new create(auth: AmbientAuth, expected: (USize | None)) =>
    _received_file =
      try
        let f = File(FilePath(auth, "received.txt")?)
        f.set_length(0)
        f
      else
        None
      end
    _expected = try (expected as USize) else USize.max_value() end

  be received(msg: Array[U8] iso, at: U64) =>
    if _count < _expected then
      match _received_file
        | let file: File => file.writev(
            FallorMsgEncoder.timestamp_raw(at, consume msg))
      end
      _count = _count + 1
    end

  be dump() =>
    match _received_file
      | let file: File => file.dispose()
    end

//
// SHUTDOWN GRACEFULLY ON SIGTERM
//

class TermHandler is SignalNotify
  let _coordinator: Coordinator

  new iso create(coordinator: Coordinator) =>
    _coordinator = coordinator

  fun ref apply(count: U32): Bool =>
    _coordinator.finished()
    true

actor Metrics
  var start_t: U64 = 0
  var next_start_t: U64 = 0
  var end_t: U64 = 0

  be set_start(s: U64) =>
    if start_t != 0 then
      next_start_t = s
    else
      start_t = s
    end
    @printf[I32]("Metrics Start: %zu\n".cstring(), start_t)

  be set_end(e: U64, expected: USize) =>
    end_t = e
    let overall = (end_t - start_t).f64() / 1_000_000_000
    let throughput = ((expected.f64() / overall) / 1_000).usize()
    @printf[I32]("Metrics End: %zu\n".cstring(), end_t)
    @printf[I32]("Overall Time: %fs\n".cstring(), overall)
    @printf[I32]("Messages: %zu\n".cstring(), expected)
    @printf[I32]("Throughput: %zuk\n".cstring(), throughput)
    start_t = next_start_t
    next_start_t = 0
    end_t = 0
