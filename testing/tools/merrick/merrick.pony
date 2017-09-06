/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

"""
Merrick: Metrics Receiver
"""
use "collections"
use "files"
use "net"
use "wallaroo_labs/options"
use "signals"
use "time"
use "wallaroo_labs/messages"
use "wallaroo_labs/bytes"
use "debug"

actor Main
  new create(env: Env) =>
    var required_args_are_present = true
    var forward: Bool = false

    var p_arg: (Array[String] | None) = None
    var l_arg: (Array[String] | None) = None
    var n_arg: (String | None) = None
    var e_arg: (USize | None) = None
    var o_arg = "recevied-metrics.txt"
    var f_addr_arg: (Array[String] | None) = None

    try
      var options = Options(env.args)

      options
        .add("phone-home", "d", StringArgument)
        .add("name", "n", StringArgument)
        .add("listen", "l", StringArgument)
        .add("output-file", "o", StringArgument)
        .add("forward", "f", None)
        .add("forward-addr", "m", StringArgument)

      for option in options do
        match option
        | ("name", let arg: String) => n_arg = arg
        | ("phone-home", let arg: String) => p_arg = arg.split(":")
        | ("listen", let arg: String) => l_arg = arg.split(":")
        | ("output-file", let arg: String) => o_arg = arg
        | ("forward", None) => forward = true
        | ("forward-addr", let arg: String) => f_addr_arg = arg.split(":")
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
            "'--listen' argument should be in format: '127.0.0.1:8080'\n"
            .cstring())
          required_args_are_present = false
        end
      end

      if p_arg isnt None then
        if (p_arg as Array[String]).size() != 2 then
          @printf[I32](
            "'--phone-home' argument should be in format: '127.0.0.1:8080'\n"
            .cstring())
            required_args_are_present = false
        end
      end

      if (p_arg isnt None) or (n_arg isnt None) then
        if (p_arg is None) or (n_arg is None) then
          @printf[I32](
            "'--phone-home' must be used in conjuction with '--name'\n"
            .cstring())
          required_args_are_present = false
        end
      end

      if forward isnt false then
        if f_addr_arg is None then
          @printf[I32](
            "'--forward-addr' must be used in conjucion with '--forward'\n"
            .cstring())
        else
          if (f_addr_arg as Array[String]).size() != 2 then
            @printf[I32](
              "'--forward-addr' arg should be in format: '127.0.0.1:8080\n"
              .cstring())
          end
        end
      end

      if required_args_are_present then
        let listener_addr = l_arg as Array[String]

        let store = Store(env.root as AmbientAuth, o_arg)
        let coordinator = CoordinatorFactory(env, store, n_arg, p_arg)

        SignalHandler(TermHandler(coordinator), Sig.term())
        SignalHandler(TermHandler(coordinator), Sig.int())

        let tcp_listen_auth = TCPListenAuth(env.root as AmbientAuth)
        let tcp_connect_auth = TCPConnectAuth(env.root as AmbientAuth)
        var forwarding_actor: (MsgForwarder | None) = None
        if forward then
          let forward_addr = f_addr_arg as Array[String]
          let forward_conn = TCPConnection(tcp_connect_auth,
            ForwarderNotify(),
            forward_addr(0),
            forward_addr(1))
          forwarding_actor = MsgForwarder(forward_conn)
        end
        let from_wallaroo_listener = TCPListener(tcp_listen_auth,
          FromWallarooListenerNotify(coordinator, store, env.err,
            forward, forwarding_actor),
          listener_addr(0),
          listener_addr(1))
      end
    else
      @printf[I32](
        """
        --phone-home/-p <address> [Sets the address for phone home]
        --name/-n <name> [Name of metrics-receiver node]
        --listen/-l <address> [Address metrics-receiver node is listening on]
        """
        )
    end

class FromWallarooListenerNotify is TCPListenNotify
  let _coordinator: Coordinator
  let _store: Store
  let _stderr: StdStream
  let _forward: Bool
  let _forwarding_actor: (MsgForwarder | None)


  new iso create(coordinator: Coordinator,
    store: Store, stderr: StdStream,
    forward: Bool, forwarding_actor: (MsgForwarder | None))
  =>
    _coordinator = coordinator
    _store = store
    _stderr = stderr
    _forward = forward
    _forwarding_actor = forwarding_actor

    fun ref not_listening(listen: TCPListener ref) =>
      _coordinator.from_wallaroo_listener(listen, Failed)

    fun ref listening(listen: TCPListener ref) =>
      _coordinator.from_wallaroo_listener(listen, Ready)

    fun ref connected(listen: TCPListener ref): TCPConnectionNotify iso^ =>
      FromWallarooNotify(_coordinator, _store, _stderr,
        _forward, _forwarding_actor)

class FromWallarooNotify is TCPConnectionNotify
  let _coordinator: Coordinator
  let _store: Store
  let _stderr: StdStream
  let _forward: Bool
  let _forwarding_actor: (MsgForwarder | None)
  var _header: Bool = true
  var _closed: Bool = false

  new iso create(coordinator: Coordinator,
    store: Store, stderr: StdStream,
    forward: Bool, forwarding_actor: (MsgForwarder | None))
  =>
    _coordinator = coordinator
    _store = store
    _stderr = stderr
    _forward = forward
    _forwarding_actor = forwarding_actor

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso,
    n: USize): Bool
  =>
    if _header then
      try

        let expect = Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()
        conn.expect(expect)
        _header = false
      else
        @printf[I32]("Blew up reading header from Wallaroo\n".cstring())
      end
    else
      var data_copy: Array[U8 val] val = consume data
      if _forward then
        try
          (_forwarding_actor as MsgForwarder).forward_msg(data_copy)
        end
      end
      _store.received(data_copy)
      conn.expect(4)
      _header = true
    end
    true

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

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso,
    n: USize): Bool
  =>
    if _header then
      try
        let expect = Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()
        conn.expect(expect)
        _header = false
      else
        @printf[I32]("Blew up reading header from Wallaroo\n".cstring())
      end
    else
      try
        let decoded = ExternalMsgDecoder(consume data)
        match decoded
        | let d: ExternalShutdownMsg =>
          _coordinator.finished()
        else
          @printf[I32]("Unexpected data from Dagon\n".cstring())
        end
      else
        @printf[I32]("Unable to decode message from Dagon\n".cstring())
      end

      conn.expect(4)
      _header = true
    end
    true

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
  be from_wallaroo_listener(listener: TCPListener, state: WorkerState)
  be connection_added(connection: TCPConnection)

primitive Waiting
primitive Ready
primitive Failed

type WorkerState is (Waiting | Ready | Failed)

actor WithoutDagonCoordinator is Coordinator
  let _env: Env
  let _store: Store
  var _from_wallaroo_listener: ((TCPListener | None), WorkerState) = (None,
    Waiting)
  let _connections: Array[TCPConnection] = Array[TCPConnection]

  new create(env: Env, store: Store) =>
    _env = env
    _store = store

  be finished() =>
    try
      let x = _from_wallaroo_listener._1 as TCPListener
      x.dispose()
    end
    for c in _connections.values() do c.dispose() end
    _store.dump()

  be from_wallaroo_listener(listener: TCPListener, state: WorkerState) =>
    _from_wallaroo_listener = (listener, state)
    if state is Failed then
      @printf[I32]("Unable to open listener\n".cstring())
      listener.dispose()
    elseif state is Ready then
      @printf[I32]("Listening for data\n".cstring())
    end

  be connection_added(c: TCPConnection) =>
    _connections.push(c)

actor WithDagonCoordinator is Coordinator
  let _env: Env
  let _store: Store
  var _from_wallaroo_listener: ((TCPListener | None), WorkerState) = (None,
    Waiting)
  var _to_dagon_socket: ((TCPConnection | None), WorkerState) = (None, Waiting)
  let _node_id: String
  let _connections: Array[TCPConnection] = Array[TCPConnection]

  new create(env: Env, store: Store, node_id: String) =>
    _env = env
    _store = store
    _node_id = node_id

  be finished() =>
    try
      let x = _from_wallaroo_listener._1 as TCPListener
      x.dispose()
    end
    for c in _connections.values() do c.dispose() end
    _store.dump()
    try
      let x = _to_dagon_socket._1 as TCPConnection
      x.writev(ExternalMsgEncoder.done_shutdown(_node_id))
      x.dispose()
    end

  be from_wallaroo_listener(listener: TCPListener, state: WorkerState) =>
    _from_wallaroo_listener = (listener, state)
    if state is Failed then
      @printf[I32]("Unable to open listener\n".cstring())
      listener.dispose()
    elseif state is Ready then
      @printf[I32]("Listening for data\n".cstring())
      _alert_ready_if_ready()
    end

  be to_dagon_socket(sock: TCPConnection, state: WorkerState) =>
    _to_dagon_socket = (sock, state)
    if state is Failed then
      @printf[I32]("Unable to open dagon socket\n".cstring())
      sock.dispose()
    elseif state is Ready then
      _alert_ready_if_ready()
    end

  fun _alert_ready_if_ready() =>
    if (_to_dagon_socket._2 is Ready) and
      (_from_wallaroo_listener._2 is Ready)
    then
      try
        let x = _to_dagon_socket._1 as TCPConnection
        x.writev(ExternalMsgEncoder.ready(_node_id as String))
      end
    end

  be connection_added(c: TCPConnection) =>
    _connections.push(c)

///
/// RECEIVED MESSAGE STORE
///

actor Store
  let _received_file: (File | None)

  new create(auth: AmbientAuth, output_file_path: String) =>
    _received_file =
      try
        let f = File(FilePath(auth, output_file_path))
        f.set_length(0)
        f
      else
        None
      end

  be received(msg: Array[U8] val) =>
    match _received_file
    | let file: File =>
      let msg_size = Bytes.from_u32((msg.size()).u32())
      file.write(consume msg_size)
      file.write(msg)
    end

  be dump() =>
    match _received_file
    | let file: File => file.dispose()
    end

///
/// SHUTDOWN GRACEFULLY ON SIGTERM
///

class TermHandler is SignalNotify
  let _coordinator: Coordinator

  new iso create(coordinator: Coordinator) =>
    _coordinator = coordinator

  fun ref apply(count: U32): Bool =>
    _coordinator.finished()
    true

class ForwarderTermHandler is SignalNotify
  let _forwarding_actor: MsgForwarder

  new iso create(forwarding_actor: MsgForwarder) =>
    _forwarding_actor = forwarding_actor

  fun ref apply(count: U32): Bool =>
    _forwarding_actor.finished()
    true

actor MsgForwarder
  let _forwarding_conn: TCPConnection

  new create(forwarding_conn: TCPConnection) =>
    _forwarding_conn = forwarding_conn

  be forward_msg(msg: Array[U8] val) =>
    let len_encoded_msg = Bytes.length_encode(msg)
    _forwarding_conn.writev(len_encoded_msg)

  be finished() =>
    _forwarding_conn.dispose()

class ForwarderNotify is TCPConnectionNotify
  let _name: String

  new iso create(name: String = "Forwarder") =>
    _name = name

  fun ref connected(sock: TCPConnection ref) =>
    @printf[None]("%s outgoing connected\n".cstring(),
      _name.cstring())

  fun ref throttled(sock: TCPConnection ref) =>
    @printf[None]("%s outgoing throttled\n".cstring(),
      _name.cstring())

  fun ref unthrottled(sock: TCPConnection ref) =>
    @printf[None]("%s outgoing no longer throttled\n".cstring(),
      _name.cstring())
