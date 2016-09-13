use "net"
use "time"
use "buffered"
use "collections"
use "sendence/bytes"
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/topology"

class DataChannelNotify is TCPConnectionNotify
  let _router: Router[Array[U8] val, Step tag] val
  let _metrics: JrMetrics
  var _header: Bool = true

  new iso create(router: Router[Array[U8] val, Step tag] val, 
    metrics: JrMetrics) =>
    _router = router
    _metrics = metrics

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

class DataChannelListenerNotify is TCPListenNotify
  let _name: String
  let _env: Env
  let _auth: AmbientAuth
  let _is_initializer: Bool
  let _router: Router[Array[U8] val, Step tag] val
  let _metrics: JrMetrics
  var _host: String = ""
  var _service: String = ""

  new iso create(name: String, env: Env, auth: AmbientAuth, 
    router: Router[Array[U8] val, Step tag] val, metrics: JrMetrics, 
    is_initializer: Bool = false) 
  =>
    _name = name
    _env = env
    _auth = auth
    _is_initializer = is_initializer
    _router = router
    _metrics = metrics

  fun ref listening(listen: TCPListener ref) =>
    try
      (_host, _service) = listen.local_address().name()
      _env.out.print(_name + " data channel: listening on " + _host + ":" + _service)
      if not _is_initializer then
        let message = ChannelMsgEncoder.identify_data_port(_name, _service,
          _auth)
        //CONTROL_CONN.writev(message)
      end
    else
      _env.out.print(_name + "control : couldn't get local address")
      listen.close()
    end

  fun ref connected(listen: TCPListener ref): TCPConnectionNotify iso^ =>
    DataChannelNotify(_router, _metrics)