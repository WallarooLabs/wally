use "net"
use "collections"
use "buffy/messages"
use "buffy/metrics"
use "sendence/bytes"
use "sendence/tcp"
use "time"
use "spike"

class WorkerControlNotifier is TCPListenNotify
  let _env: Env
  let _auth: AmbientAuth
  let _name: String
  let _leader_host: String
  let _leader_service: String
  let _coordinator: Coordinator
  let _metrics_collector: MetricsCollector
  var _host: String = ""
  var _service: String = ""

  new iso create(env: Env, auth: AmbientAuth, name: String, leader_host: String,
    leader_service: String, coordinator: Coordinator,
    metrics_collector: MetricsCollector) =>
    _env = env
    _auth = auth
    _name = name
    _leader_host = leader_host
    _leader_service = leader_service
    _coordinator = coordinator
    _metrics_collector = metrics_collector

  fun ref listening(listen: TCPListener ref) =>
    try
      (_host, _service) = listen.local_address().name()
      _env.out.print(_name + " control: listening on " + _host + ":" + _service)

      _coordinator.identify_control_channel(_host, _service)
    else
      _env.out.print(_name + "control : couldn't get local address")
      listen.close()
    end

  fun ref not_listening(listen: TCPListener ref) =>
    _env.out.print(_name + "control : couldn't listen")
    listen.close()

  fun ref connected(listen: TCPListener ref) : TCPConnectionNotify iso^ =>
    WorkerConnectNotify(_env, _auth, _name, _leader_host,
      _leader_service, _coordinator, _metrics_collector)

class WorkerConnectNotify is TCPConnectionNotify
  let _env: Env
  let _auth: AmbientAuth
  let _leader_host: String
  let _leader_service: String
  let _coordinator: Coordinator
  let _metrics_collector: MetricsCollector
  let _framer: Framer = Framer
  let _name: String

  new iso create(env: Env, auth: AmbientAuth, name: String, leader_host: String,
    leader_service: String, coordinator: Coordinator,
    metrics_collector: MetricsCollector) =>
    _env = env
    _auth = auth
    _name = name
    _leader_host = leader_host
    _leader_service = leader_service
    _coordinator = coordinator
    _metrics_collector = metrics_collector

  fun ref accepted(conn: TCPConnection ref) =>
    _coordinator.add_connection(conn)

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso) =>
    for chunked in _framer.chunk(consume data).values() do
      let msg = WireMsgDecoder(consume chunked, _auth)
      match msg
      | let m: ReconnectDataMsg val =>
        _coordinator.negotiate_data_reconnection(m.node_name)
      | let m: IdentifyControlMsg val =>
        _coordinator.establish_control_connection(m.node_name, m.host, m.service)
      | let m: IdentifyDataMsg val =>
        _coordinator.establish_data_connection(m.node_name, m.host, m.service)
      | let m: InitializationMsgsFinishedMsg val =>
        _coordinator.ack_initialization_msgs_finished(m.node_name)
      | let m: AckMsgsReceivedMsg val =>
        _coordinator.process_data_ack(m.node_name, m.msg_count)
      | let m: AckReconnectMsgsReceivedMsg val =>
        _coordinator.process_data_reconnect_ack(m.node_name, m.msg_count)
      | let m: FinishedConnectionsMsg val =>
        _coordinator.ack_finished_connections(m.node_name)
      | let m: SpinUpMsg val =>
        _env.err.print(_name + " is spinning up a step!")
        _coordinator.add_step(m.step_id, m.step_builder)
      | let m: SpinUpProxyMsg val =>
        _env.err.print(_name + " is spinning up a proxy!")
        _coordinator.add_proxy(m.proxy_id, m.step_id, m.target_node_name)
      | let m: SpinUpSinkMsg val =>
        _env.err.print(_name + " is spinning up a sink!")
        _coordinator.add_sink(m.sink_id, m.sink_step_id, m.sink_builder, _auth)
      | let m: ConnectStepsMsg val =>
        _coordinator.connect_steps(m.in_step_id, m.out_step_id)
      | let d: ShutdownMsg val =>
        _coordinator.shutdown()
      | let m: UnknownMsg val =>
        _env.err.print("Unknown message type.")
      else
        _env.err.print("Error decoding incoming message.")
      end
    end

  fun ref connected(conn: TCPConnection ref) =>
    _env.out.print(_name + " is connected.")

  fun ref connect_failed(conn: TCPConnection ref) =>
    _env.out.print(_name + ": Connection to leader failed!")

  fun ref closed(conn: TCPConnection ref) =>
    _env.out.print(_name + ": server closed")
