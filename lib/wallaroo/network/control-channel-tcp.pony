use "net"
use "collections"
use "wallaroo/messages"
use "sendence/bytes"
use "time"

class ControlChannelListenNotifier is TCPListenNotify
  let _env: Env
  let _auth: AmbientAuth
  let _name: String
  var _host: String = ""
  var _service: String = ""
  let _is_initializer: Bool
  let _initializer: (Initializer | None)
  let _connections: Connections

  new iso create(name: String, env: Env, auth: AmbientAuth,
    connections: Connections, is_initializer: Bool,
    initializer: (Initializer | None) = None)
  =>
    _env = env
    _auth = auth
    _name = name
    _is_initializer = is_initializer
    _initializer = initializer
    _connections = connections

  fun ref listening(listen: TCPListener ref) =>
    try
      (_host, _service) = listen.local_address().name()
      _env.out.print(_name + " control: listening on " + _host + ":" + _service)
      if not _is_initializer then
        let message = ChannelMsgEncoder.identify_control_port(_name, 
          _service, _auth)
        _connections.send_control("initializer", message)
      end
    else
      _env.out.print(_name + "control : couldn't get local address")
      listen.close()
    end

  fun ref not_listening(listen: TCPListener ref) =>
    _env.out.print(_name + "control : couldn't listen")
    listen.close()

  fun ref connected(listen: TCPListener ref) : TCPConnectionNotify iso^ =>
    ControlChannelConnectNotifier(_name, _env, _auth, _connections, 
      _initializer)

class ControlChannelConnectNotifier is TCPConnectionNotify
  let _env: Env
  let _auth: AmbientAuth
  let _name: String
  let _connections: Connections
  let _initializer: (Initializer | None)
  var _header: Bool = true

  new iso create(name: String, env: Env, auth: AmbientAuth, 
    connections: Connections, initializer: (Initializer | None)) 
  =>
    _env = env
    _auth = auth
    _name = name
    _connections = connections
    _initializer = initializer

  fun ref accepted(conn: TCPConnection ref) =>
    conn.expect(4)

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso): Bool =>
    if _header then
      try
        let expect = Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()
        conn.expect(expect)
        _header = false
      else
        _env.err.print("Error reading header on control channel")
      end
    else
      let msg = ChannelMsgDecoder(consume data, _auth)
      match msg
      | let m: IdentifyControlPortMsg val =>
        try
          (let host, _) = conn.remote_address().name()
          match _initializer
          | let i: Initializer =>
            i.identify_control_address(m.worker_name, host, m.service)
          end
          _connections.create_control_connection(m.worker_name, host, m.service)
        end
      | let m: IdentifyDataPortMsg val =>
        _env.out.print("Got data message!")
        try
          (let host, _) = conn.remote_address().name()
          match _initializer
          | let i: Initializer =>
            i.identify_data_address(m.worker_name, host, m.service)
          end
          _connections.create_data_connection(m.worker_name, host, m.service)
        end
      | let m: AddControlMsg val =>
        None
        // do something
      | let m: AddDataMsg val =>
        None
        // do something
      | let m: CreateConnectionsMsg val =>
        _connections.create_connections(m.addresses)
      | let m: UnknownChannelMsg val =>
        _env.err.print("Unknown channel message type.")
      else
        _env.err.print("Error decoding incoming message.")
      end

      conn.expect(4)
      _header = true
    end
    true

  fun ref connected(conn: TCPConnection ref) =>
    _env.out.print(_name + " is connected.")

  fun ref connect_failed(conn: TCPConnection ref) =>
    _env.out.print(_name + ": connection failed!")

  fun ref closed(conn: TCPConnection ref) =>
    _env.out.print(_name + ": server closed")

class ControlSenderConnectNotifier is TCPConnectionNotify
  let _env: Env

  new iso create(env: Env)
  =>
    _env = env

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso): Bool =>
    _env.out.print("Control sender channel received data.")
    true
