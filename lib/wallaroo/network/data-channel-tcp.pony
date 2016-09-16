use "net"
use "time"
use "buffered"
use "collections"
use "sendence/bytes"
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/topology"

class DataChannelNotifier is TCPConnectionNotify
  var _header: Bool = true

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso): Bool =>
    if _header then
      try
        let expect = Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()

        conn.expect(expect)
        _header = false
      end
    else
      // process consume data

      conn.expect(4)
      _header = true
    end
    false

  fun ref accepted(conn: TCPConnection ref) =>
    @printf[None]("accepted\n".cstring())
    conn.expect(4)

  fun ref connected(sock: TCPConnection ref) =>
    @printf[None]("incoming connected\n".cstring())

class DataChannelListenerNotifier is TCPListenNotify
  let _name: String
  let _env: Env
  let _auth: AmbientAuth
  let _is_initializer: Bool
  var _host: String = ""
  var _service: String = ""
  let _connections: Connections

  new iso create(name: String, env: Env, auth: AmbientAuth, 
    connections: Connections, is_initializer: Bool = false)
  =>
    _name = name
    _env = env
    _auth = auth
    _is_initializer = is_initializer
    _connections = connections

  fun ref listening(listen: TCPListener ref) =>
    try
      (_host, _service) = listen.local_address().name()
      _env.out.print(_name + " data channel: listening on " + _host + ":" + _service)
      if not _is_initializer then
        let message = ChannelMsgEncoder.identify_data_port(_name, _service,
          _auth)
        _connections.send_data("initializer", message)
      end
    else
      _env.out.print(_name + "control : couldn't get local address")
      listen.close()
    end

  fun ref connected(listen: TCPListener ref): TCPConnectionNotify iso^ =>
    DataChannelNotifier

class DataSenderConnectNotify is TCPConnectionNotify
  let _env: Env

  new iso create(env: Env)
  =>
    _env = env

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso): Bool =>
    _env.out.print("Data sender channel received data.")
    true

  // fun ref closed(conn: TCPConnection ref) =>
  //   _coordinator.reconnect_data(_target_name)