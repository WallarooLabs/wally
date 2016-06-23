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
use "sendence/bytes"

// tests
// documentation

actor Main
  new create(env: Env) =>
    var required_args_are_present = true
    var run_tests = env.args.size() == 1

    if run_tests then
      TestMain(env)
    else
      var p_arg: (Array[String] | None) = None
      var l_arg: (Array[String] | None) = None
      var n_arg: (String | None) = None

      try
        var options = Options(env)

        options
          .add("phone_home", "d", StringArgument)
          .add("name", "n", StringArgument)
          .add("listen", "l", StringArgument)

        for option in options do
          match option
          | ("name", let arg: String) => n_arg = arg
          | ("phone_home", let arg: String) => p_arg = arg.split(":")
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

        if required_args_are_present then
          let listener_addr = l_arg as Array[String]

          let store = Store(env.root as AmbientAuth)
          let decoder = Decoder(store, env.err)
          let coordinator = CoordinatorFactory(env, store, n_arg, p_arg)

          SignalHandler(TermHandler(coordinator), Sig.term())

          let tcp_auth = TCPListenAuth(env.root as AmbientAuth)
          let from_buffy_listener = TCPListener(tcp_auth,
            FromBuffyListenerNotify(coordinator, decoder, env.err),
            listener_addr(0),
            listener_addr(1))

        end
      else
        env.err.print("FUBAR! FUBAR!")
      end
    end

class FromBuffyListenerNotify is TCPListenNotify
  let _coordinator: Coordinator
  let _decoder: Decoder
  let _stderr: StdStream

  new iso create(coordinator: Coordinator,
    decoder: Decoder, stderr: StdStream)
  =>
    _coordinator = coordinator
    _decoder = decoder
    _stderr = stderr

  fun ref not_listening(listen: TCPListener ref) =>
    _coordinator.from_buffy_listener(listen, Failed)

  fun ref listening(listen: TCPListener ref) =>
    _coordinator.from_buffy_listener(listen, Ready)

  fun ref connected(listen: TCPListener ref): TCPConnectionNotify iso^ =>
    FromBuffyNotify(_coordinator, _decoder, _stderr)

class FromBuffyNotify is TCPConnectionNotify
  let _coordinator: Coordinator
  let _decoder: Decoder
  let _stderr: StdStream
  var _header: Bool = true

  new iso create(coordinator: Coordinator,
    decoder: Decoder, stderr: StdStream)
  =>
    _coordinator = coordinator
    _decoder = decoder
    _stderr = stderr

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso) =>
    if _header then
      try
        let expect = Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()
        conn.expect(expect)
        _header = false
      else
        _stderr.print("Blew up reading header from Buffy")
      end
    else
      _decoder.received(consume data, Time.wall_to_nanos(Time.now()))

      conn.expect(4)
      _header = true
    end

  fun ref accepted(conn: TCPConnection ref) =>
    conn.expect(4)
    _coordinator.connection_added(consume conn)


class ToDagonNotify is TCPConnectionNotify
  let _coordinator: WithDagonCoordinator
  let _stderr: StdStream
  var _header: Bool = true

  new iso create(coordinator: WithDagonCoordinator, stderr: StdStream) =>
    _coordinator = coordinator
    _stderr = stderr

  fun ref connect_failed(sock: TCPConnection ref) =>
    _coordinator.to_dagon_socket(sock, Failed)

  fun ref connected(sock: TCPConnection ref) =>
    sock.expect(4)
    _coordinator.to_dagon_socket(sock, Ready)

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso) =>
    if _header then
      try
        let expect = Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()
        conn.expect(expect)
        _header = false
      else
        _stderr.print("Blew up reading header from Buffy")
      end
    else
      try
        let decoded = ExternalMsgDecoder(consume data)
        match decoded
        | let d: ExternalShutdownMsg val =>
          _coordinator.finished()
        else
          _stderr.print("Unexpected data from Dagon")
        end
      else
        _stderr.print("Unable to decode message Dagon")
      end

      conn.expect(4)
      _header = true
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
  be from_buffy_listener(listener: TCPListener, state: WorkerState)
  be connection_added(connection: TCPConnection)

primitive Waiting
primitive Ready
primitive Failed

type WorkerState is (Waiting | Ready | Failed)

actor WithoutDagonCoordinator is Coordinator
  let _env: Env
  let _store: Store
  var _from_buffy_listener: ((TCPListener | None), WorkerState) = (None, Waiting)
  let _connections: Array[TCPConnection] = Array[TCPConnection]

  new create(env: Env, store: Store) =>
    _env = env
    _store = store

  be finished() =>
    try
      let x = _from_buffy_listener._1 as TCPListener
      x.dispose()
    end
    for c in _connections.values() do c.dispose() end
    _store.dump()

  be from_buffy_listener(listener: TCPListener, state: WorkerState) =>
    _from_buffy_listener = (listener, state)
    if state is Failed then
      _env.err.print("Unable to open listener")
      listener.dispose()
    elseif state is Ready then
      _env.out.print("Listening for data")
    end

  be connection_added(c: TCPConnection) =>
    _connections.push(c)

actor WithDagonCoordinator is Coordinator
  let _env: Env
  let _store: Store
  var _from_buffy_listener: ((TCPListener | None), WorkerState) = (None, Waiting)
  var _to_dagon_socket: ((TCPConnection | None), WorkerState) = (None, Waiting)
  let _node_id: String
  let _connections: Array[TCPConnection] = Array[TCPConnection]

  new create(env: Env, store: Store, node_id: String) =>
    _env = env
    _store = store
    _node_id = node_id

  be finished() =>
    try
      let x = _from_buffy_listener._1 as TCPListener
      x.dispose()
    end
    for c in _connections.values() do c.dispose() end
    _store.dump()
    try
      let x = _to_dagon_socket._1 as TCPConnection
      x.writev(ExternalMsgEncoder.done_shutdown(_node_id))
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
        x.writev(ExternalMsgEncoder.ready(_node_id as String))
       end
    end

  be connection_added(c: TCPConnection) =>
    _connections.push(c)

///
/// RECEIVED MESSAGE DECODER
///

actor Decoder
  let _store: Store
  let _stderr: StdStream

  new create(store: Store, stderr: StdStream) =>
    _store = store
    _stderr = stderr

  be received(data: Array[U8] iso, at: U64) =>
    try
      let decoded = ExternalMsgDecoder(consume data)
      match decoded
      | let d: ExternalDataMsg val =>
        _store.received(d.data, at)
      else
        _stderr.print("Unexpected data from Buffy")
      end
    else
      _stderr.print("Unable to decode message Buffy")
    end

///
/// RECEIVED MESSAGE STORE
///

actor Store
  let _encoder: ReceivedLogEncoder = ReceivedLogEncoder
  let _received_file: (File | None)

  new create(auth: AmbientAuth) =>
    _received_file = try
      let f = File(FilePath(auth, "received.txt"))
      f.set_length(0)
      f
    else
      None
    end

  be received(msg: ByteSeq, at: U64) =>
    match _received_file
      | let file: File => file.print(_encoder((msg, at)))
    end

  be dump() =>
    match _received_file
      | let file: File => file.dispose()
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
