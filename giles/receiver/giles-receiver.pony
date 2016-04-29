"""
Giles receiver
"""
use "collections"
use "files"
use "net"
use "options"
use "signals"
use "time"
use "buffy/messages"
use "sendence/tcp"

// clean up @printf's
// tests
// documentation

actor Main
  new create(env: Env) =>
    var required_args_are_present = true
    var run_tests = env.args.size() == 1

    if run_tests then
      TestMain(env)
    else
      var d_arg: (Array[String] | None) = None
      var l_arg: (Array[String] | None) = None
      var n_arg: (String | None) = None

      try
        var options = Options(env)

        options
          .add("dagon", "d", StringArgument)
          .add("name", "n", StringArgument)
          .add("listen", "l", StringArgument)

        for option in options do
          match option
          | ("name", let arg: String) => n_arg = arg
          | ("dagon", let arg: String) => d_arg = arg.split(":")
          | ("listen", let arg: String) => l_arg = arg.split(":")
          end
        end

        if l_arg is None then
          env.err.print("Must supply required '--listen' argument")
          required_args_are_present = false
        else
          if (l_arg as Array[String]).size() != 2 then
            env.err.print(
              "'--listen' argument should be in format: '127.0.0.1:8080")
            required_args_are_present = false
          end
        end

        if d_arg isnt None then
          if (d_arg as Array[String]).size() != 2 then
            env.err.print(
              "'--dagon' argument should be in format: '127.0.0.1:8080")
            required_args_are_present = false
          end
        end

        if (d_arg isnt None) or (n_arg isnt None) then
          if (d_arg is None) or (n_arg is None) then
            env.err.print(
              "'--dagon' must be used in conjunction with '--name'")
            required_args_are_present = false
          end
        end

        if required_args_are_present then
          let listener_addr = l_arg as Array[String]

          let store = Store(env.root as AmbientAuth)
          let coordinator = CoordinatorFactory(env, store, n_arg, d_arg)

          SignalHandler(TermHandler(coordinator), Sig.term())

          let tcp_auth = TCPListenAuth(env.root as AmbientAuth)
          let from_buffy_listener = TCPListener(tcp_auth,
            FromBuffyListenerNotify(coordinator, store),
            listener_addr(0),
            listener_addr(1))

        end
      else
        env.err.print("FUBAR! FUBAR!")
      end
    end

class FromBuffyListenerNotify is TCPListenNotify
  let _coordinator: Coordinator
  let _store: Store

  new iso create(coordinator: Coordinator, store: Store) =>
    _coordinator = coordinator
    _store = store

  fun ref not_listening(listen: TCPListener ref) =>
    _coordinator.from_buffy_listener(listen, Failed)

  fun ref listening(listen: TCPListener ref) =>
    _coordinator.from_buffy_listener(listen, Ready)

  fun ref connected(listen: TCPListener ref): TCPConnectionNotify iso^ =>
    FromBuffyNotify(_store)

class FromBuffyNotify is TCPConnectionNotify
  let _store: Store
  let _framer: Framer = Framer

  new iso create(store: Store) =>
    _store = store

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso) =>
    for chunked in _framer.chunk(consume data).values() do
      try
        let decoded = WireMsgDecoder(consume chunked)
        match decoded
        | let d: ExternalMsg val =>
          @printf[I32]("%s\n".cstring(), d.data.cstring())
          _store.received(d.data, Time.micros())
        else
          @printf[I32]("UNEXPECTED DATA\n".cstring())
        end
      else
        @printf[I32]("UNABLE TO DECODE MESSAGE\n".cstring())
      end
    end

class ToDagonNotify is TCPConnectionNotify
  let _coordinator: WithDagonCoordinator
  let _framer: Framer = Framer

  new iso create(coordinator: WithDagonCoordinator) =>
    _coordinator = coordinator

  fun ref connect_failed(sock: TCPConnection ref) =>
    _coordinator.to_dagon_socket(sock, Failed)

  fun ref connected(sock: TCPConnection ref) =>
    _coordinator.to_dagon_socket(sock, Ready)

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso) =>
    for chunked in _framer.chunk(consume data).values() do
      try
        let decoded = WireMsgDecoder(consume chunked)
        match decoded
        | let d: ShutdownMsg val =>
          _coordinator.finished()
        else
          @printf[I32]("UNEXPECTED DATA\n".cstring())
        end
      else
        @printf[I32]("UNABLE TO DECODE MESSAGE\n".cstring())
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
        ToDagonNotify(coordinator),
        ph(0),
        ph(1))

      coordinator
    else
      WithoutDagonCoordinator(env, store)
    end

interface tag Coordinator
  be finished()
  be from_buffy_listener(listener: TCPListener, state: WorkerState)

primitive Waiting
primitive Ready
primitive Failed

type WorkerState is (Waiting | Ready | Failed)

actor WithoutDagonCoordinator is Coordinator
  let _env: Env
  let _store: Store
  var _from_buffy_listener: ((TCPListener | None), WorkerState) = (None, Waiting)

  new create(env: Env, store: Store) =>
    _env = env
    _store = store

  be finished() =>
    try
      let x = _from_buffy_listener._1 as TCPListener
      x.dispose()
    end
    _store.dump()

  be from_buffy_listener(listener: TCPListener, state: WorkerState) =>
    _from_buffy_listener = (listener, state)
    if state is Failed then
      _env.err.print("Unable to open listener")
      listener.dispose()
    elseif state is Ready then
      _env.out.print("Listening for data")
    end

actor WithDagonCoordinator is Coordinator
  let _env: Env
  let _store: Store
  var _from_buffy_listener: ((TCPListener | None), WorkerState) = (None, Waiting)
  var _to_dagon_socket: ((TCPConnection | None), WorkerState) = (None, Waiting)
  let _node_id: String

  new create(env: Env, store: Store, node_id: String) =>
    _env = env
    _store = store
    _node_id = node_id

  be finished() =>
    try
      let x = _from_buffy_listener._1 as TCPListener
      x.dispose()
    end
    _store.dump()
    try
      let x = _to_dagon_socket._1 as TCPConnection
      x.write(WireMsgEncoder.done_shutdown(_node_id))
      x.dispose()
    end

  be from_buffy_listener(listener: TCPListener, state: WorkerState) =>
    _from_buffy_listener = (listener, state)
    if state is Failed then
      _env.err.print("Unable to open listener")
      listener.dispose()
    elseif state is Ready then
      _env.out.print("Listening for data")
      _alert_ready_if_ready()
    end

  be to_dagon_socket(sock: TCPConnection, state: WorkerState) =>
    _to_dagon_socket = (sock, state)
    if state is Failed then
      _env.err.print("Unable to open dagon socket")
      sock.dispose()
    elseif state is Ready then
      _alert_ready_if_ready()
    end

  fun _alert_ready_if_ready() =>
    if (_to_dagon_socket._2 is Ready) and
       (_from_buffy_listener._2 is Ready)
    then
      try
        let x = _to_dagon_socket._1 as TCPConnection
        x.write(WireMsgEncoder.ready(_node_id as String))
       end
    end

///
/// RECEIVED MESSAGE STORE
///

actor Store
  let _auth: AmbientAuth
  let _received: List[(ByteSeq, U64)]
  let _encoder: ReceivedLogEncoder = ReceivedLogEncoder

  new create(auth: AmbientAuth) =>
    _auth = auth
    _received = List[(ByteSeq, U64)](1_000_000)

  be received(msg: ByteSeq, at: U64) =>
    _received.push((msg, at))

  be dump() =>
    try
      let received_handle = File(FilePath(_auth, "received.txt"))
      received_handle.set_length(0)
      for r in _received.values() do
        received_handle.print(_encoder(r))
      end
      received_handle.dispose()
    end

class ReceivedLogEncoder
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
// SHUTDOWN GRACEFULLY ON SIGTERM
//

class TermHandler is SignalNotify
  let _coordinator: Coordinator

  new iso create(coordinator: Coordinator) =>
    _coordinator = coordinator

  fun ref apply(count: U32): Bool =>
    _coordinator.finished()
    true
