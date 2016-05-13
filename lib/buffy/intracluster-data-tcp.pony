use "net"
use "collections"
use "buffy/messages"
use "buffy/metrics"
use "sendence/bytes"
use "sendence/tcp"
use "time"
use "spike"

class LeaderIntraclusterDataNotifier is TCPListenNotify
  let _env: Env
  let _auth: AmbientAuth
  let _name: String
  let _step_manager: StepManager
  let _spike_config: SpikeConfig val
  let _coordinator: Coordinator
  var _host: String = ""
  var _service: String = ""

  new iso create(env: Env, auth: AmbientAuth, name: String,
    step_manager: StepManager, coordinator: Coordinator,
    spike_config: SpikeConfig val) =>
    _env = env
    _auth = auth
    _name = name
    _step_manager = step_manager
    _coordinator = coordinator
    _spike_config = spike_config

  fun ref listening(listen: TCPListener ref) =>
    try
      (_host, _service) = listen.local_address().name()
      _env.out.print(_name + " data: listening on " + _host + ":" + _service)
    else
      _env.out.print(_name + " data: couldn't get local address")
      listen.close()
    end

  fun ref not_listening(listen: TCPListener ref) =>
    _env.out.print(_name + " data: couldn't listen")
    listen.close()

  fun ref connected(listen: TCPListener ref) : TCPConnectionNotify iso^ =>
    SpikeWrapper(IntraclusterDataConnectNotify(_env, _name,
      _step_manager, _coordinator), _spike_config)

class WorkerIntraclusterDataNotifier is TCPListenNotify
  let _env: Env
  let _auth: AmbientAuth
  let _name: String
  let _step_manager: StepManager
  let _spike_config: SpikeConfig val
  let _leader_host: String
  let _leader_service: String
  let _coordinator: Coordinator
  var _host: String = ""
  var _service: String = ""

  new iso create(env: Env, auth: AmbientAuth, name: String, leader_host: String,
    leader_service: String, step_manager: StepManager, coordinator: Coordinator,
    spike_config: SpikeConfig val) =>
    _env = env
    _auth = auth
    _name = name
    _leader_host = leader_host
    _leader_service = leader_service
    _step_manager = step_manager
    _coordinator = coordinator
    _spike_config = spike_config

  fun ref listening(listen: TCPListener ref) =>
    try
      (_host, _service) = listen.local_address().name()
      _env.out.print(_name + " data: listening on " + _host + ":" + _service)

      _coordinator.identify_data_channel(_host, _service, _spike_config)
    else
      _env.out.print(_name + " data: couldn't get local address")
      listen.close()
    end

  fun ref not_listening(listen: TCPListener ref) =>
    _env.out.print(_name + " data: couldn't listen")
    listen.close()

  fun ref connected(listen: TCPListener ref) : TCPConnectionNotify iso^ =>
    SpikeWrapper(IntraclusterDataConnectNotify(_env, _name,
      _step_manager, _coordinator), _spike_config)

class IntraclusterDataConnectNotify is TCPConnectionNotify
  let _env: Env
  let _name: String
  let _step_manager: StepManager
  let _framer: Framer = Framer
  let _coordinator: Coordinator

  new iso create(env: Env, name: String, s_manager: StepManager,
    coordinator: Coordinator) =>
    _env = env
    _name = name
    _step_manager = s_manager
    _coordinator = coordinator

  fun ref accepted(conn: TCPConnection ref) =>
    _coordinator.add_connection(conn)

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso) =>
    for chunked in _framer.chunk(consume data).values() do
      try
        let msg = WireMsgDecoder(consume chunked)
        match msg
        | let m: ForwardI32Msg val =>
          _step_manager(m.step_id, m.msg)
        | let m: ForwardF32Msg val =>
          _step_manager(m.step_id, m.msg)
        | let m: ForwardStringMsg val =>
          _step_manager(m.step_id, m.msg)
        | let m: UnknownMsg val =>
          _env.err.print("Unknown data Buffy message type.")
        end
      else
        _env.err.print("Error decoding incoming data Buffy message.")
      end
    end

  fun ref closed(conn: TCPConnection ref) =>
    _env.out.print(_name + ": data Buffy server closed")
