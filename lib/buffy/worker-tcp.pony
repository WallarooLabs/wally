use "net"
use "collections"
use "buffy/messages"
use "sendence/bytes"
use "sendence/tcp"

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
    leader_service: String, step_manager: StepManager) =>
    _env = env
    _auth = auth
    _name = name
    _leader_host = leader_host
    _leader_service = leader_service
    _step_manager = step_manager

  fun ref listening(listen: TCPListener ref) =>
    try
      (_host, _service) = listen.local_address().name()
      _env.out.print(_name + ": listening on " + _host + ":" + _service)

      let notifier: TCPConnectionNotify iso =
        WorkerConnectNotify(_env, _auth, _name, _leader_host, _leader_service,
          _step_manager)
      let conn: TCPConnection =
        TCPConnection(_auth, consume notifier, _leader_host, _leader_service)

      let message = WireMsgEncoder.identify(_name, _host, _service)
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
  let _framer: Framer = Framer
  let _nodes: Map[String, TCPConnection tag] = Map[String, TCPConnection tag]
  let _name: String

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
    for chunked in _framer.chunk(consume data).values() do
      try
        let msg = WireMsgDecoder(consume chunked)
        match msg
        | let m: ReadyMsg val =>
          _nodes(m.node_name) = conn
        | let m: SpinUpMsg val =>
          _step_manager.add_step(m.step_id, m.computation_type)
        | let m: SpinUpProxyMsg val =>
          _spin_up_proxy(m)
        | let m: SpinUpSinkMsg val =>
          _step_manager.add_sink(m.sink_id, m.sink_step_id, _auth)
        | let m: ForwardMsg val =>
          _step_manager(m.step_id, m.msg)
        | let m: ConnectStepsMsg val =>
          _step_manager.connect_steps(m.in_step_id, m.out_step_id)
        | let m: InitializationMsgsFinishedMsg val =>
          let ack_msg = WireMsgEncoder.ack_initialized(_name)
          conn.write(ack_msg)
        | let m: UnknownMsg val =>
          _env.err.print("Unknown message type.")
        end
      else
        _env.err.print("Error decoding incoming message.")
      end
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
      target_conn.write(WireMsgEncoder.ready(_name))
      _step_manager.add_proxy(msg.proxy_id, msg.step_id, target_conn)
      _nodes(msg.target_node_name) = target_conn
    end

  fun ref connected(conn: TCPConnection ref) =>
    _env.out.print(_name + " is connected.")

  fun ref connect_failed(conn: TCPConnection ref) =>
    _env.out.print(_name + ": Connection to leader failed!")

  fun ref closed(conn: TCPConnection ref) =>
    _env.out.print(_name + ": server closed")
