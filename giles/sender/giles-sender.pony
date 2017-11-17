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
Giles Sender
"""
use "buffered"
use "collections"
use "debug"
use "files"
use "net"
use "random"
use "time"
use "wallaroo_labs/bytes"
use "wallaroo_labs/messages"
use "wallaroo_labs/options"
use "wallaroo_labs/time"

// documentation
// more tests

actor Main
  new create(env: Env)=>
    var required_args_are_present = true
    var run_tests = env.args.size() == 1
    var batch_size: USize = 500
    var interval: U64 = 5_000_000
    var should_repeat = false
    var binary_fmt = false
    var variable_size = false
    var msg_size: USize = 80
    var write_to_file: Bool = true
    var binary_integer: Bool = false
    var start_from: U64 = 0
    var vary_by: U64 = 0

    if run_tests then
      TestMain(env)
    else
      var h_arg: (Array[String] | None) = None
      var m_arg: (USize | None) = None
      var f_arg: (String | None) = None
      var g_arg: (USize | None) = None
      var z_arg: (Bool | None) = None

      try
        var options = Options(env.args)

        options
          .add("host", "h", StringArgument)
          .add("messages", "m", I64Argument)
          .add("file", "f", StringArgument)
          .add("batch-size", "s", I64Argument)
          .add("interval", "i", I64Argument)
          .add("repeat", "r", None)
          .add("binary", "y", None)
          .add("u64", "u", None)
          .add("start-from", "v", I64Argument)
          .add("variable-size", "z", None)
          .add("msg-size", "g", I64Argument)
          .add("no-write", "w", None)
          .add("vary-by", "j", I64Argument)

        for option in options do
          match option
          | ("host", let arg: String) =>
            h_arg = arg.split(":")
          | ("messages", let arg: I64) =>
            m_arg = arg.usize()
          | ("file", let arg: String) =>
            f_arg = arg
          | ("batch-size", let arg: I64) =>
            batch_size = arg.usize()
          | ("interval", let arg: I64) =>
            interval = arg.u64()
          | ("repeat", None) =>
            should_repeat = true
          | ("binary", None) =>
            binary_fmt = true
          | ("u64", None) =>
            binary_integer = true
          | ("start-from", let arg: I64) =>
            start_from = arg.u64()
          | ("variable-size", None) =>
            variable_size = true
          | ("msg-size", let arg: I64) =>
            g_arg = arg.usize()
          | ("no-write", None) =>
            write_to_file = false
          | ("vary-by", let arg: I64) =>
            vary_by = arg.u64()
          end
        end

        if h_arg is None then
          @printf[I32]("Must supply required '--host' argument\n".cstring())
          required_args_are_present = false
        else
          if (h_arg as Array[String]).size() != 2 then
            @printf[I32](
              "'--host' argument should be in format: '127.0.0.1:8080\n"
              .cstring())
            required_args_are_present = false
          end
        end

        if m_arg is None then
          @printf[I32]("Must supply required '--messages' argument\n".cstring())
          required_args_are_present = false
        end

        if (g_arg isnt None) and variable_size then
          @printf[I32](
            "--msg-size and --variable-size can't be used together\n"
            .cstring())
          required_args_are_present = false
        end

        if binary_fmt then
          if (variable_size == false) and (g_arg is None) then
            @printf[I32](
              "--binary requires either --msg-size or --variable-size\n"
              .cstring())
            required_args_are_present = false
          end
        end

        if f_arg isnt None then
          let f = f_arg as String
          let fs: Array[String] = recover f.split(",") end
          try
            for str in (consume fs).values() do
              let path = FilePath(env.root as AmbientAuth, str)?
              if not path.exists() then
                @printf[I32](("Error opening file '" + str + "'.\n").cstring())
                required_args_are_present = false
              end
            end
          end
        end

        if required_args_are_present then
          let messages_to_send = m_arg as USize
          let to_host_addr = h_arg as Array[String]

          let store = Store(env.root as AmbientAuth)
          let coordinator = Coordinator(env, store)?

          let tcp_auth = TCPConnectAuth(env.root as AmbientAuth)
          let to_host_socket = TCPConnection(tcp_auth,
            ToHostNotify(coordinator),
            to_host_addr(0)?,
            to_host_addr(1)?)

          let data_source =
            match f_arg
            | let mfn': String =>
              let fs: Array[String] iso = recover mfn'.split(",") end
              let paths: Array[FilePath] iso =
                recover Array[FilePath] end
              for str in (consume fs).values() do
                paths.push(FilePath(env.root as AmbientAuth, str)?)
              end
              if binary_fmt then
                if variable_size then
                  MultiFileVariableBinaryDataSource(consume paths,
                    should_repeat)
                else
                  MultiFileBinaryDataSource(consume paths,
                    should_repeat, g_arg as USize)
                end
              else
                MultiFileDataSource(consume paths, should_repeat)
              end
            else
              if binary_integer then
                BinaryIntegerDataSource(start_from)
              else
                IntegerDataSource(start_from)
              end
            end

          let sa = SendingActor(
            messages_to_send,
            to_host_socket,
            store,
            coordinator,
            consume data_source,
            batch_size,
            interval,
            binary_fmt,
            variable_size,
            write_to_file,
            vary_by)

          coordinator.sending_actor(sa)
        end
      else
        @printf[I32]("FUBAR! FUBAR!\n".cstring())
      end
    end

class ToHostNotify is TCPConnectionNotify
  let _coordinator: Coordinator

  new iso create(coordinator: Coordinator) =>
    _coordinator = coordinator

  fun ref connect_failed(sock: TCPConnection ref) =>
    _coordinator.to_host_socket(sock, Failed)

  fun ref connected(sock: TCPConnection ref) =>
    if sock.local_address() != sock.remote_address() then
      sock.set_nodelay(true)
    end
    _coordinator.to_host_socket(sock, Ready)

  fun ref throttled(sock: TCPConnection ref) =>
    _coordinator.pause_sending(true)

  fun ref unthrottled(sock: TCPConnection ref) =>
    _coordinator.pause_sending(false)

//
// COORDINATE OUR STARTUP
//

primitive Waiting
primitive Ready
primitive Failed

type WorkerState is (Waiting | Ready | Failed)

actor Coordinator
  let _env: Env
  var _to_host_socket: ((TCPConnection | None), WorkerState) = (None, Waiting)
  var _sending_actor: (SendingActor | None) = None
  let _store: Store

  new create(env: Env, store: Store) =>
    _env = env
    _store = store

  be to_host_socket(sock: TCPConnection, state: WorkerState) =>
    _to_host_socket = (sock, state)
    if state is Failed then
      @printf[I32]("Unable to connect\n".cstring())
      sock.dispose()
    elseif state is Ready then
      @printf[I32]("Connected\n".cstring())
      _go_if_ready()
    end

  be sending_actor(sa: SendingActor) =>
    _sending_actor = sa

  be finished() =>
    try
      let x = _to_host_socket._1 as TCPConnection
      x.dispose()
    end
    _store.dispose()

  be pause_sending(v: Bool) =>
    try
      let sa = _sending_actor as SendingActor
      sa.pause(v)
    end

  fun _go_if_ready() =>
    if _to_host_socket._2 is Ready then
      try
        let y = _sending_actor as SendingActor
        y.go()
      end
    end

//
// SEND DATA INTO WALLAROO
//

actor SendingActor
  let _messages_to_send: USize
  var _messages_sent: USize = USize(0)
  let _to_host_socket: TCPConnection
  let _store: Store
  let _coordinator: Coordinator
  let _timers: Timers
  let _data_source: Iterator[ByteSeq] iso
  let _binary_fmt: Bool
  let _variable_size: Bool
  var _paused: Bool = false
  var _finished: Bool = false
  var _batch_size: USize
  let _interval: U64
  let _wb: Writer
  var _write_to_file: Bool = true
  var _vary_by: U64
  let _rng: MT
  var _drunk_walk: USize = 0
  var _walks_remaining: USize = 1000

  new create(messages_to_send: USize,
    to_host_socket: TCPConnection,
    store: Store,
    coordinator: Coordinator,
    data_source: Iterator[ByteSeq] iso,
    batch_size: USize,
    interval: U64,
    binary_fmt: Bool,
    variable_size: Bool,
    write_to_file: Bool,
    vary_by: U64)
  =>
    _messages_to_send = messages_to_send
    _to_host_socket = to_host_socket
    _store = store
    _coordinator = coordinator
    _data_source = consume data_source
    _timers = Timers
    _batch_size = batch_size
    _interval = interval
    _binary_fmt = binary_fmt
    _variable_size = variable_size
    _write_to_file = write_to_file
    _wb = Writer
    _vary_by = vary_by
    _rng = MT(Time.millis())

  be go() =>
    let t = Timer(SendBatch(this), 0, _interval)
    _timers(consume t)

  be pause(v: Bool) =>
    _paused = v

  be send_batch() =>
    if _paused or _finished then return end

    if _walks_remaining == 0 then
      _drunk_walk = (_rng.int(_vary_by)).usize()
      _walks_remaining = 1000
    else
      _walks_remaining = _walks_remaining - 1
    end

    let this_batch = _batch_size + _drunk_walk

    var current_batch_size =
      if (_messages_to_send - _messages_sent) > this_batch then
        this_batch
      else
        _messages_to_send - _messages_sent
      end

    if (current_batch_size > 0) and _data_source.has_next() then
      _wb.reserve_chunks(current_batch_size)

      let d' = recover Array[ByteSeq](current_batch_size) end
      for i in Range(0, current_batch_size) do
        try
          if _binary_fmt then
            let n = _data_source.next()?
            if n.size() > 0 then
              d'.push(n)
              if _variable_size then
                _wb.u32_be(n.size().u32())
              end
              _wb.write(n)
              _messages_sent = _messages_sent + 1
            end
          else
            let n = _data_source.next()?
            if n.size() > 0 then
              d'.push(n)
              _wb.u32_be(n.size().u32())
              _wb.write(n)
              _messages_sent = _messages_sent + 1
            end
          end
        else
          ifdef debug then
            Debug.out("SendingActor: failed reading _data_source.next()")
          end
          break
        end
      end

      for i in _wb.done().values() do
        _to_host_socket.write(i)
      end
      if _write_to_file then
        _store.sentv(consume d', WallClock.nanoseconds())
      end
    else
      _finished = true
      _timers.dispose()
      _coordinator.finished()
    end

class SendBatch is TimerNotify
  let _sending_actor: SendingActor

  new iso create(sending_actor: SendingActor) =>
    _sending_actor = sending_actor

  fun ref apply(timer: Timer, count: U64): Bool =>
    _sending_actor.send_batch()
    true

//
// SENT MESSAGE STORE
//

actor Store
  let _encoder: SentLogEncoder = SentLogEncoder
  var _sent_file: (File|None)

  new create(auth: AmbientAuth) =>
    _sent_file = try
      let f = File(FilePath(auth, "sent.txt")?)
      f.set_length(0)
      f
    else
      None
    end

  be sentv(msgs: Array[ByteSeq] val, at: U64) =>
    match _sent_file
      | let file: File =>
      for m in msgs.values() do
        file.print(_encoder((m, at)))
      end
    end

  be dispose() =>
    match _sent_file
      | let file: File => file.dispose()
    end

class SentLogEncoder
  fun apply(tuple: (ByteSeq, U64)): String =>
    let time: String = tuple._2.string()
    let payload = tuple._1

    recover
      String(time.size() + ", ".size() + payload.size())
      .>append(time)
      .>append(", ")
      .>append(payload)
    end

//
// DATA SOURCES
//

class IntegerDataSource is Iterator[String]
  var _counter: U64

  new iso create(start_from: U64 = 0) =>
    _counter = start_from

  fun ref has_next(): Bool =>
    true

  fun ref next(): String =>
    _counter = _counter + 1
    _counter.string()

class BinaryIntegerDataSource is Iterator[Array[U8] val]
  var _counter: U64

  new iso create(start_from: U64 = 0) =>
    _counter = start_from

  fun ref has_next(): Bool =>
    true

  fun ref next(): Array[U8] val =>
    _counter = _counter + 1
    Bytes.from_u64(_counter, Bytes.from_u32(U32(8)))

class FileDataSource is Iterator[String]
  let _lines: Iterator[String]
  let _file: File

  new iso create(path: FilePath val) =>
    _file = File.open(path)
    _lines = _file.lines()

  fun ref has_next(): Bool =>
    _lines.has_next()

  fun ref next(): String ? =>
    if has_next() then
      _lines.next()?
    else
      error
    end

  fun ref dispose() =>
    _file.dispose()

class MultiFileDataSource is Iterator[String]
  let _paths: Array[FilePath val] val
  var _cur_source: (FileDataSource | None)
  var _idx: USize = 0
  var _should_repeat: Bool

  new iso create(paths: Array[FilePath val] val, should_repeat: Bool = false)
  =>
    _paths = paths
    _cur_source =
      try
        FileDataSource(_paths(_idx)?)
      else
        None
      end
    _should_repeat = should_repeat

  fun ref has_next(): Bool =>
    match _cur_source
    | let f: FileDataSource =>
      if f.has_next() then
        true
      else
        f.dispose()
        _idx = _idx + 1
        try
          _cur_source = FileDataSource(_paths(_idx)?)
          has_next()
        else
          if _should_repeat then
            f.dispose()
            _idx = 0
            _cur_source =
              try
                FileDataSource(_paths(_idx)?)
              else
                None
              end
            has_next()
          else
            false
          end
        end
      end
    else
      false
    end

  fun ref next(): String ? =>
    if has_next() then
      match _cur_source
      | let f: FileDataSource =>
        f.next()?
      else
        error
      end
    else
      error
    end

class MultiFileBinaryDataSource is Iterator[Array[U8 val] val]
  let _paths: Array[FilePath val] val
  var _cur_source: (BinaryFileDataSource | None)
  var _idx: USize = 0
  var _should_repeat: Bool
  var _msg_size: USize

  new iso create(paths: Array[FilePath val] val, should_repeat: Bool = false,
    msg_size: USize) =>
    _paths = paths
    _msg_size = msg_size
    _cur_source =
      try
        BinaryFileDataSource(_paths(_idx)?, _msg_size)
      else
        None
      end
    _should_repeat = should_repeat

  fun ref has_next(): Bool =>
    match _cur_source
    | let f: BinaryFileDataSource =>
      if f.has_next() then
        true
      else
        f.dispose()
        _idx = _idx + 1
        try
          _cur_source = BinaryFileDataSource(_paths(_idx)?, _msg_size)
          has_next()
        else
          if _should_repeat then
            f.dispose()
            _idx = 0
            _cur_source =
              try
                BinaryFileDataSource(_paths(_idx)?, _msg_size)
              else
                None
              end
            has_next()
          else
            false
          end
        end
      end
    else
      false
    end

  fun ref next(): Array[U8 val] val ? =>
    if has_next() then
      match _cur_source
      | let f: BinaryFileDataSource =>
        f.next()
      else
        error
      end
    else
      error
    end

class MultiFileVariableBinaryDataSource is Iterator[Array[U8 val] val]
  let _paths: Array[FilePath val] val
  var _cur_source: (VariableLengthBinaryFileDataSource | None)
  var _idx: USize = 0
  var _should_repeat: Bool

  new iso create(paths: Array[FilePath val] val, should_repeat: Bool = false) =>
    _paths = paths
    _cur_source =
      try
        VariableLengthBinaryFileDataSource(_paths(_idx)?)
      else
        None
      end
    _should_repeat = should_repeat

  fun ref has_next(): Bool =>
    match _cur_source
    | let f: VariableLengthBinaryFileDataSource =>
      if f.has_next() then
        true
      else
        f.dispose()
        _idx = _idx + 1
        try
          _cur_source = VariableLengthBinaryFileDataSource(_paths(_idx)?)
          has_next()
        else
          if _should_repeat then
            f.dispose()
            _idx = 0
            _cur_source =
              try
                VariableLengthBinaryFileDataSource(_paths(_idx)?)
              else
                None
              end
            has_next()
          else
            false
          end
        end
      end
    else
      false
    end

  fun ref next(): Array[U8 val] val ? =>
    if has_next() then
      match _cur_source
      | let f: VariableLengthBinaryFileDataSource =>
        f.next()
      else
        error
      end
    else
      error
    end

class BinaryFileDataSource is Iterator[Array[U8] val]
  let _file: File
  let _msg_size: USize

  new iso create(path: FilePath val, msg_size: USize) =>
    _file = File.open(path)
    _msg_size = msg_size

  fun ref has_next(): Bool =>
    if _file.position() < _file.size() then
      true
    else
      false
    end

  fun ref next(): Array[U8] val =>
    _file.read(_msg_size)

  fun ref dispose() =>
    _file.dispose()

class VariableLengthBinaryFileDataSource is Iterator[Array[U8] val]
  let _file: File

  new iso create(path: FilePath val) =>
    _file = File.open(path)

  fun ref has_next(): Bool =>
    if _file.position() < _file.size() then
      true
    else
      false
    end

  fun ref next(): Array[U8] val =>
    let h = _file.read(4)
    try
      let expect: USize = Bytes.to_u32(h(0)?, h(1)?, h(2)?, h(3)?).usize()
      _file.read(expect)
    else
      ifdef debug then
        @printf[I32]("Failed to convert message header!\n".cstring())
      end
      recover val Array[U8] end
    end

  fun ref dispose() =>
    _file.dispose()
