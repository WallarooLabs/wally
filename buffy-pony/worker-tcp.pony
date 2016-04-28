use "net"
use "collections"
use "./messages"

class WorkerNotifier is TCPListenNotify
  let _env: Env
  let _auth: AmbientAuth
  let _name: String
  let _leader_host: String
  let _leader_service: String
  let _step_manager: StepManager
  var _host: String = ""
  var _service: String = ""

  new iso create(env: Env, auth: AmbientAuth, name: String, leader_host: String,
    leader_service: String) =>
    _env = env
    _auth = auth
    _name = name
    _leader_host = leader_host
    _leader_service = leader_service
    _step_manager = StepManager(env)

  fun ref listening(listen: TCPListener ref) =>
    try
      (_host, _service) = listen.local_address().name()
      _env.out.print(_name + ": listening on " + _host + ":" + _service)

      let notifier: TCPConnectionNotify iso =
        WorkerConnectNotify(_env, _auth, _name, _leader_host, _leader_service,
          _step_manager)
      let conn: TCPConnection =
        TCPConnection(_auth, consume notifier, _leader_host, _leader_service)

      let message = TCPMessageEncoder.identify(_name, _host, _service)
      _env.out.print("My name is " + _name)
      conn.write(message)
    else
      _env.out.print(_name + ": couldn't get local address")
      listen.close()
    end

  fun ref not_listening(listen: TCPListener ref) =>
    _env.out.print(_name + ": couldn't listen")
    listen.close()

  fun ref connected(listen: TCPListener ref) : TCPConnectionNotify iso^ =>
    WorkerConnectNotify(_env, _auth, _name, _leader_host, _leader_service,
      _step_manager)

class WorkerConnectNotify is TCPConnectionNotify
  let _env: Env
  let _auth: AmbientAuth
  let _leader_host: String
  let _leader_service: String
  let _step_manager: StepManager
  let _nodes: Map[String, TCPConnection tag] = Map[String, TCPConnection tag]
  let _name: String
  var _buffer: Array[U8] = Array[U8]
  // How many bytes are left to process for current message
  var _left: U32 = 0
  // For building up the two bytes of a U16 message length
  var _len_bytes: Array[U8] = Array[U8]
  var _data_index: USize = 0

  new iso create(env: Env, auth: AmbientAuth, name: String, leader_host: String,
    leader_service: String, step_manager: StepManager) =>
    _env = env
    _auth = auth
    _name = name
    _leader_host = leader_host
    _leader_service = leader_service
    _step_manager = step_manager

  fun ref accepted(conn: TCPConnection ref) =>
    _env.out.print(_name + ": connection accepted")

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso) =>
    _env.out.print(_name + ": data received")

    let d: Array[U8] ref = consume data
    try
      _data_index = 0
      while d.size() > 0 do
        if _left == 0 then
          if _len_bytes.size() < 4 then
            let next = d(_data_index = _data_index + 1)
            _len_bytes.push(next)
          else
            // Set _left to the length of the current message in bytes
            _left = Bytes.to_u32(_len_bytes(0), _len_bytes(1), _len_bytes(2),
              _len_bytes(3))
            _len_bytes = Array[U8]
          end
        else
          _buffer.push(d(_data_index = _data_index + 1))
          _left = _left - 1
          if _left == 0 then
            let copy: Array[U8] iso = recover Array[U8] end
            for byte in _buffer.values() do
              copy.push(byte)
            end
            _process_data(conn, consume copy)
            _buffer = Array[U8]
          end
        end
      end
    end

  fun ref _process_data(conn: TCPConnection ref, data: Array[U8] val) =>
    try
      let msg: TCPMsg val = TCPMessageDecoder(data)
      match msg
      | let m: ReadyMsg val =>
        _env.out.print("GREET from " + m.node_name)
        _nodes(m.node_name) = conn
      | let m: SpinUpMsg val =>
        _env.out.print("SPIN UP " + m.step_id.string())
        _step_manager.add_step(m.step_id, m.computation_type_id)
      | let m: SpinUpProxyMsg val =>
        _env.out.print("SPIN UP PROXY " + m.proxy_id.string())
        _spin_up_proxy(m)
      | let m: ForwardMsg val =>
        _env.out.print("FORWARD message " + m.msg.id.string())
        _step_manager(m.step_id, m.msg)
      | let m: ConnectStepsMsg val =>
        _env.out.print("CONNECT STEPS " + m.in_step_id.string() + " to "
          + m.out_step_id.string())
        _step_manager.connect_steps(m.in_step_id, m.out_step_id)
      | let m: InitializationMsgsFinishedMsg val =>
        _env.out.print("INITIALIZATION FINISHED")
        let ack_msg = TCPMessageEncoder.ack_initialized(_name)
        conn.write(ack_msg)
      end
    else
      _env.err.print("Error decoding incoming message.")
    end

  fun ref _spin_up_proxy(msg: SpinUpProxyMsg val) =>
    try
      let target_conn = _nodes(msg.target_node_name)
      _step_manager.add_proxy(msg.proxy_id, msg.step_id, target_conn)
    else
      let notifier: TCPConnectionNotify iso =
        WorkerConnectNotify(_env, _auth, _name, _leader_host, _leader_service,
          _step_manager)
      let target_conn =
        TCPConnection(_auth, consume notifier, msg.target_host,
          msg.target_service)
      target_conn.write(TCPMessageEncoder.ready(_name))
      _step_manager.add_proxy(msg.proxy_id, msg.step_id, target_conn)
      _nodes(msg.target_node_name) = target_conn
    end

  fun ref connected(conn: TCPConnection ref) =>
    if _name != "0" then
      let name = _name
      let message =
        TCPMessageEncoder.reconnect(name)
      conn.write(message)
      _env.out.print("Re-established connection for worker " + name)
    end

  fun ref connect_failed(conn: TCPConnection ref) =>
    _env.out.print(_name + ": Connection to leader failed!")

  fun ref closed(conn: TCPConnection ref) =>
    _env.out.print(_name + ": server closed")
