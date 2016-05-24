use "net"
use "collections"
use "buffy/messages"
use "buffy/metrics"
use "sendence/bytes"
use "sendence/tcp"
use "../topology"
use "time"
use "spike"

class LeaderControlNotifier is TCPListenNotify
  let _env: Env
  let _auth: AmbientAuth
  let _name: String
  let _topology_manager: TopologyManager
  let _coordinator: Coordinator
  let _metrics_collector: MetricsCollector
  var _host: String = ""
  var _service: String = ""

  new iso create(env: Env, auth: AmbientAuth, name: String,
    coordinator: Coordinator, topology_manager: TopologyManager,
    metrics_collector: MetricsCollector) =>
    _env = env
    _auth = auth
    _name = name
    _coordinator = coordinator
    _topology_manager = topology_manager
    _metrics_collector = metrics_collector

  fun ref listening(listen: TCPListener ref) =>
    try
      (_host, _service) = listen.local_address().name()
      _env.out.print(_name + ": listening on " + _host + ":" + _service)

      let message = ExternalMsgEncoder.ready(_name)
      _coordinator.send_phone_home_message(message)
    else
      _env.out.print(_name + ": couldn't get local address")
      listen.close()
    end

  fun ref not_listening(listen: TCPListener ref) =>
    _env.out.print(_name + ": couldn't listen")
    listen.close()

  fun ref connected(listen: TCPListener ref) : TCPConnectionNotify iso^ =>
    LeaderConnectNotify(_env, _auth, _name, _topology_manager,
      _coordinator, _metrics_collector)

class LeaderConnectNotify is TCPConnectionNotify
  let _env: Env
  let _auth: AmbientAuth
  let _name: String
  let _topology_manager: TopologyManager
  let _coordinator: Coordinator
  let _metrics_collector: MetricsCollector
  let _framer: Framer = Framer

  new iso create(env: Env, auth: AmbientAuth, name: String, t_manager: TopologyManager,
    coordinator: Coordinator, metrics_collector: MetricsCollector) =>
    _env = env
    _auth = auth
    _name = name
    _topology_manager = t_manager
    _coordinator = coordinator
    _metrics_collector = metrics_collector


  fun ref accepted(conn: TCPConnection ref) =>
    _coordinator.add_connection(conn)

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso) =>
    for chunked in _framer.chunk(consume data).values() do
      let msg = WireMsgDecoder(chunked, _auth)
      match msg
      | let m: ReconnectDataMsg val =>
        _coordinator.negotiate_data_reconnection(m.node_name)
      | let m: IdentifyControlMsg val =>
        _topology_manager.assign_control_conn(m.node_name, m.host, m.service)
      | let m: IdentifyDataMsg val =>
        _topology_manager.assign_data_conn(m.node_name, m.host, m.service)
      | let m: AckFinishedConnectionsMsg val =>
        _topology_manager.ack_finished_connections()
      | let m: AckInitializedMsg val =>
        _topology_manager.ack_initialized()
      | let m: AckMsgsReceivedMsg val =>
        _coordinator.process_data_ack(m.node_name, m.msg_count)
      | let m: AckReconnectMsgsReceivedMsg val =>
        _coordinator.process_data_reconnect_ack(m.node_name, m.msg_count)
      | let m: SpinUpMsg val =>
        _coordinator.add_step(m.step_id, m.step_builder)
      | let m: SpinUpProxyMsg val =>
        _env.err.print(_name + " is spinning up a proxy!")
        _coordinator.add_proxy(m.proxy_id, m.step_id, m.target_node_name)
      | let m: SpinUpSinkMsg val =>
        _coordinator.add_sink(m.sink_id, m.sink_step_id, m.sink_builder, _auth)
      | let m: ConnectStepsMsg val =>
        _coordinator.connect_steps(m.in_step_id, m.out_step_id)
      | let d: ShutdownMsg val =>
        _topology_manager.shutdown()
      | let m: UnknownMsg val =>
        _env.err.print("Unknown control message type.")
      else
        _env.err.print("Error decoding incoming control message.")
      end
    end

  fun ref closed(conn: TCPConnection ref) =>
    _env.out.print(_name + ": server closed")
