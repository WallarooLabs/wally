"""
Giles Sender
"""
use "collections"
use "files"
use "net"
use "options"
use "time"
use "buffy/messages"
use "sendence/tcp"
use "debug"

// documentation
// more tests

actor Main
  new create(env: Env)=>
    var required_args_are_present = true
    var run_tests = env.args.size() == 1

    if run_tests then
      TestMain(env)
    else
      var b_arg: (Array[String] | None) = None
      var m_arg: (USize | None) = None
      var p_arg: (Array[String] | None) = None
      var n_arg: (String | None) = None
      var f_arg: (String | None) = None

      try
        var options = Options(env)

        options
          .add("buffy", "b", StringArgument)
          .add("phone_home", "p", StringArgument)
          .add("name", "n", StringArgument)
          .add("messages", "m", I64Argument)
          .add("file", "f", StringArgument)

        for option in options do
          match option
          | ("buffy", let arg: String) => b_arg = arg.split(":")
          | ("messages", let arg: I64) => m_arg = arg.usize()
          | ("name", let arg: String) => n_arg = arg
          | ("file", let arg: String) => f_arg = arg
          | ("phone_home", let arg: String) => p_arg = arg.split(":")
          end
        end

        if b_arg is None then
          env.err.print("Must supply required '--buffy' argument")
          required_args_are_present = false
        else
          if (b_arg as Array[String]).size() != 2 then
            env.err.print(
              "'--buffy' argument should be in format: '127.0.0.1:8080")
            required_args_are_present = false
          end
        end

        if m_arg is None then
          env.err.print("Must supply required '--messages' argument")
          required_args_are_present = false
        end

        if p_arg isnt None then
          if (p_arg as Array[String]).size() != 2 then
            env.err.print(
              "'--dagon' argument should be in format: '127.0.0.1:8080")
            required_args_are_present = false
          end
        end

        if (p_arg isnt None) or (n_arg isnt None) then
          if (p_arg is None) or (n_arg is None) then
            env.err.print(
              "'--dagon' must be used in conjunction with '--name'")
            required_args_are_present = false
          end
        end

        if f_arg isnt None then
          let f = f_arg as String
          try
            let path = FilePath(env.root as AmbientAuth, f)
            if not path.exists() then
              env.err.print("Error opening file '" + f + "'.")
              required_args_are_present = false
            end
          end
        end

        if required_args_are_present then
          let messages_to_send = m_arg as USize
          let to_buffy_addr = b_arg as Array[String]

          let store = Store(env.root as AmbientAuth)
          let coordinator = CoordinatorFactory(env, store, n_arg, p_arg)

          let tcp_auth = TCPConnectAuth(env.root as AmbientAuth)
          let to_buffy_socket = TCPConnection(tcp_auth,
            ToBuffyNotify(coordinator),
            to_buffy_addr(0),
            to_buffy_addr(1))

          let data_source =
            match f_arg
            | let mfn': String =>
              try
                let path = FilePath(env.root as AmbientAuth, mfn')
                FileDataSource(path)
              else
                error
              end
            else
              IntegerDataSource
            end
            
          let sa = SendingActor(
            messages_to_send,
            to_buffy_socket,
            store,
            coordinator,
            consume data_source)

          coordinator.sending_actor(sa)
        end
      else
        env.err.print("FUBAR! FUBAR!")
      end
    end

class ToBuffyNotify is TCPConnectionNotify
  let _coordinator: Coordinator

  new iso create(coordinator: Coordinator) =>
    _coordinator = coordinator

  fun ref connect_failed(sock: TCPConnection ref) =>
    _coordinator.to_buffy_socket(sock, Failed)

  fun ref connected(sock: TCPConnection ref) =>
    sock.set_nodelay(true)
    _coordinator.to_buffy_socket(sock, Ready)

class ToDagonNotify is TCPConnectionNotify
  let _coordinator: WithDagonCoordinator
  let _framer: Framer = Framer
  let _stderr: StdStream

  new iso create(coordinator: WithDagonCoordinator, stderr: StdStream) =>
    _coordinator = coordinator
    _stderr = stderr

  fun ref connect_failed(sock: TCPConnection ref) =>
    _coordinator.to_dagon_socket(sock, Failed)

  fun ref connected(sock: TCPConnection ref) =>
    _coordinator.to_dagon_socket(sock, Ready)

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso) =>
    for chunked in _framer.chunk(consume data).values() do
      try
        let decoded = ExternalMsgDecoder(consume chunked)
        match decoded
        | let m: ExternalStartMsg val =>
            _coordinator.go()
        else
          _stderr.print("Unexpected message from Dagon")
        end
      else
        _stderr.print("Unable to decode message from Dagon")
      end
    end

//
// COORDINATE OUR STARTUP
//

primitive CoordinatorFactory
  fun apply(env: Env,
    store: Store,
    node_id: (String | None),
    to_dagon_addr: (Array[String] | None)): Coordinator ?
  =>
    if (node_id isnt None) and (to_dagon_addr isnt None) then
      let n = node_id as String
      let ph = to_dagon_addr as Array[String]
      let coordinator = WithDagonCoordinator(env, store, n)

      let tcp_auth = TCPConnectAuth(env.root as AmbientAuth)
      let to_dagon_socket = TCPConnection(tcp_auth,
        ToDagonNotify(coordinator, env.err),
        ph(0),
        ph(1))

      coordinator
    else
      WithoutDagonCoordinator(env, store)
    end

interface tag Coordinator
  be finished()
  be sending_actor(sa: SendingActor)
  be to_buffy_socket(sock: TCPConnection, state: WorkerState)

primitive Waiting
primitive Ready
primitive Failed

type WorkerState is (Waiting | Ready | Failed)

actor WithoutDagonCoordinator
  let _env: Env
  var _to_buffy_socket: ((TCPConnection | None), WorkerState) = (None, Waiting)
  var _sending_actor: (SendingActor | None) = None
  let _store: Store

  new create(env: Env, store: Store) =>
    _env = env
    _store = store

  be to_buffy_socket(sock: TCPConnection, state: WorkerState) =>
    _to_buffy_socket = (sock, state)
    if state is Failed then
      _env.err.print("Unable to open buffy socket")
      sock.dispose()
    elseif state is Ready then
      _go_if_ready()
    end

  be sending_actor(sa: SendingActor) =>
    _sending_actor = sa

  be finished() =>
    try
      let x = _to_buffy_socket._1 as TCPConnection
      x.dispose()
    end
    _store.dispose()

  fun _go_if_ready() =>
    if _to_buffy_socket._2 is Ready then
      try
        let y = _sending_actor as SendingActor
        y.go()
      end
    end

actor WithDagonCoordinator
  let _env: Env
  var _to_buffy_socket: ((TCPConnection | None), WorkerState) = (None, Waiting)
  var _to_dagon_socket: ((TCPConnection | None), WorkerState) = (None, Waiting)
  var _sending_actor: (SendingActor | None) = None
  let _store: Store
  let _node_id: String

  new create(env: Env, store: Store, node_id: String) =>
    _env = env
    _store = store
    _node_id = node_id

  be go() =>
    try
      let y = _sending_actor as SendingActor
      y.go()
    end

  be to_buffy_socket(sock: TCPConnection, state: WorkerState) =>
    _to_buffy_socket = (sock, state)
    if state is Failed then
      _env.err.print("Unable to open buffy socket")
      sock.dispose()
    elseif state is Ready then
      _go_if_ready()
    end

  be to_dagon_socket(sock: TCPConnection, state: WorkerState) =>
    _to_dagon_socket = (sock, state)
    if state is Failed then
      _env.err.print("Unable to open dagon socket")
      sock.dispose()
    elseif state is Ready then
      _go_if_ready()
    end

  be sending_actor(sa: SendingActor) =>
    _sending_actor = sa

  be finished() =>
    try
      let x = _to_dagon_socket._1 as TCPConnection
      x.writev(ExternalMsgEncoder.done_shutdown(_node_id as String))
      x.dispose()
    end
    try
      let x = _to_buffy_socket._1 as TCPConnection
      x.dispose()
    end
    _store.dispose()

  fun _go_if_ready() =>
    if (_to_dagon_socket._2 is Ready) and (_to_buffy_socket._2 is Ready) then
      _send_ready()
    end

  fun _send_ready() =>
    try
      let x = _to_dagon_socket._1 as TCPConnection
      x.writev(ExternalMsgEncoder.ready(_node_id as String))
    end

//
// SEND DATA INTO BUFFY
//

actor SendingActor
  let _messages_to_send: USize
  var _messages_sent: USize = USize(0)
  let _to_buffy_socket: TCPConnection
  let _store: Store
  let _coordinator: Coordinator
  let _timers: Timers
  let _data_source: Iterator[String] iso
  var _finished: Bool = false
  let _msg_encoder: BufferedExternalMsgEncoder = BufferedExternalMsgEncoder

  new create(messages_to_send: USize,
    to_buffy_socket: TCPConnection,
    store: Store,
    coordinator: Coordinator,
    data_source: Iterator[String] iso)
  =>
    _messages_to_send = messages_to_send
    _to_buffy_socket = to_buffy_socket
    _store = store
    _coordinator = coordinator
    _data_source = consume data_source
    _timers = Timers

  be go() =>
    let t = Timer(SendBatch(this), 0, 5_000_000)
    _timers(consume t)

  be send_batch() =>
    if _finished then return end

    let batch_size = USize(500)

    var current_batch_size =
      if (_messages_to_send - _messages_sent) > batch_size then
        batch_size
      else
        _messages_to_send - _messages_sent
      end

    if (current_batch_size > 0) and _data_source.has_next() then
      let d' = recover Array[ByteSeq](current_batch_size) end
      for i in Range(0, current_batch_size) do
        try
          let n = _data_source.next()
          d'.push(n)
          _msg_encoder.add_data(n)
        else
          Debug.out("SendingActor: failed reading _data_source.next()")
          break
        end
      end

      _to_buffy_socket.writev(_msg_encoder.done())
      _store.sentv(consume d', Time.wall_to_nanos(Time.now()))
      _messages_sent = _messages_sent + current_batch_size
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
      let f = File(FilePath(auth, "sent.txt"))
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
      .append(time)
      .append(", ")
      .append(payload)
    end

//
// DATA SOURCES
//

class IntegerDataSource is Iterator[String]
  var _counter: U64

  new iso create() =>
    _counter = 0

  fun ref has_next(): Bool =>
    true

  fun ref next(): String =>
    _counter = _counter + 1
    _counter.string()


class FileDataSource is Iterator[String]
  let _lines: Iterator[String]

  new iso create(path: FilePath val) =>
    _lines = File(path).lines()

  fun ref has_next(): Bool =>
    _lines.has_next()

  fun ref next(): String ? =>
    if has_next() then
      _lines.next()
    else
      error
    end
