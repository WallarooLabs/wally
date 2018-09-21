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

    var l_arg: (Array[String] | None) = None
    var e_arg: (USize | None) = None
    var o_arg = "recevied-metrics.txt"
    var f_addr_arg: (Array[String] | None) = None

    try
      var options = Options(env.args)

      options
        .add("listen", "l", StringArgument)
        .add("output-file", "o", StringArgument)
        .add("forward", "f", None)
        .add("forward-addr", "m", StringArgument)

      for option in options do
        match option
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
        let coordinator = Coordinator(env, store)?

        SignalHandler(TermHandler(coordinator), Sig.term())
        SignalHandler(TermHandler(coordinator), Sig.int())

        let tcp_listen_auth = TCPListenAuth(env.root as AmbientAuth)
        let tcp_connect_auth = TCPConnectAuth(env.root as AmbientAuth)
        var forwarding_actor: (MsgForwarder | None) = None
        if forward then
          let forward_addr = f_addr_arg as Array[String]
          let forward_conn = TCPConnection(tcp_connect_auth,
            ForwarderNotify(),
            forward_addr(0)?,
            forward_addr(1)?)
          forwarding_actor = MsgForwarder(forward_conn)
        end
        let from_wallaroo_listener = TCPListener(tcp_listen_auth,
          FromWallarooListenerNotify(coordinator, store, env.err,
            forward, forwarding_actor),
          listener_addr(0)?,
          listener_addr(1)?)
      end
    else
      @printf[I32](
        """
        --listen/-l <address> [Address metrics-receiver node is listening on]
        """
        )
    end

class FromWallarooListenerNotify is TCPListenNotify
  let _coordinator: Coordinator
  let _store: Store
  let _stderr: OutStream
  let _forward: Bool
  let _forwarding_actor: (MsgForwarder | None)


  new iso create(coordinator: Coordinator,
    store: Store, stderr: OutStream,
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

  fun ref connect_failed(conn: TCPConnection ref) =>
    None

class FromWallarooNotify is TCPConnectionNotify
  let _coordinator: Coordinator
  let _store: Store
  let _stderr: OutStream
  let _forward: Bool
  let _forwarding_actor: (MsgForwarder | None)
  var _header: Bool = true
  var _closed: Bool = false

  new iso create(coordinator: Coordinator,
    store: Store, stderr: OutStream,
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

        let expect = Bytes.to_u32(data(0)?, data(1)?, data(2)?, data(3)?).usize()
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

  fun ref connect_failed(conn: TCPConnection ref) =>
    None

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

///
/// RECEIVED MESSAGE STORE
///

actor Store
  let _received_file: (File | None)

  new create(auth: AmbientAuth, output_file_path: String) =>
    _received_file =
      try
        let f = File(FilePath(auth, output_file_path)?)
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
    @printf[I32]("%s outgoing connected\n".cstring(),
      _name.cstring())

  fun ref throttled(sock: TCPConnection ref) =>
    @printf[I32]("%s outgoing throttled\n".cstring(),
      _name.cstring())

  fun ref unthrottled(sock: TCPConnection ref) =>
    @printf[I32]("%s outgoing no longer throttled\n".cstring(),
      _name.cstring())

  fun ref connect_failed(conn: TCPConnection ref) =>
    None
