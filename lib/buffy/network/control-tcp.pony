use "net"
use "collections"
use "buffy/messages"
use "buffy/metrics"
use "sendence/bytes"
use "time"
use "spike"
use "debug"

class ControlNotifier is TCPListenNotify
  let _env: Env
  let _auth: AmbientAuth
  let _name: String
  let _coordinator: Coordinator
  let _metrics_collector: MetricsCollector
  var _host: String = ""
  var _service: String = ""
  let _is_worker: Bool

  new iso create(env: Env, auth: AmbientAuth, name: String,
    coordinator: Coordinator, metrics_collector: MetricsCollector, is_worker: Bool = true) =>
    _env = env
    _auth = auth
    _name = name
    _coordinator = coordinator
    _metrics_collector = metrics_collector
    _is_worker = is_worker

  fun ref listening(listen: TCPListener ref) =>
    try
      (_host, _service) = listen.local_address().name()
      _env.out.print(_name + " control: listening on " + _host + ":" + _service)
      if _is_worker then
        _coordinator.identify_control_channel(_service)
      end
    else
      _env.out.print(_name + "control : couldn't get local address")
      listen.close()
    end

  fun ref not_listening(listen: TCPListener ref) =>
    _env.out.print(_name + "control : couldn't listen")
    listen.close()

  fun ref connected(listen: TCPListener ref) : TCPConnectionNotify iso^ =>
    ControlConnectNotify(_env, _auth, _name, _coordinator, _metrics_collector)

class ControlConnectNotify is TCPConnectionNotify
  let _env: Env
  let _auth: AmbientAuth
  let _coordinator: Coordinator
  let _metrics_collector: MetricsCollector
  let _name: String
  var _header: Bool = true

  new iso create(env: Env, auth: AmbientAuth, name: String, coordinator: Coordinator,
    metrics_collector: MetricsCollector) =>
    _env = env
    _auth = auth
    _name = name
    _coordinator = coordinator
    _metrics_collector = metrics_collector

  fun ref accepted(conn: TCPConnection ref) =>
    conn.expect(4)
    _coordinator.add_connection(conn)

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
      let msg = WireMsgDecoder(consume data, _auth)
      match msg
      | let m: ReconnectDataMsg val =>
        _coordinator.negotiate_data_reconnection(m.node_name)
      | let m: IdentifyControlPortMsg val =>
        try
          (let host, _) = conn.remote_address().name()

          ifdef debug then
            Debug.out("ControlConnectNotify.received() IdentifyControlPortMsg " + host)
          end

          _coordinator.assign_topology_control_conn(m.node_name, host,
            m.service)
        end
      | let m: IdentifyDataPortMsg val =>
        try
          (let host, _) = conn.remote_address().name()

          ifdef debug then
            Debug.out("ControlConnectNotify.received() IdentifyDataPortMsg " + host)
          end

          _coordinator.assign_topology_data_conn(m.node_name, host,
            m.service)
        end
      | let m: AddControlMsg val =>
        _coordinator.establish_control_connection(m.node_name, m.host, m.service)
      | let m: AddDataMsg val =>
        _coordinator.establish_data_connection(m.node_name, m.host, m.service)
      | let m: InitializationMsgsFinishedMsg val =>
        _coordinator.ack_initialization_msgs_finished(m.node_name)
      | let m: AckMsgIdMsg val =>
        _coordinator.process_data_ack(m.node_name, m.msg_id)
      | let m: AckConnectMsgIdMsg val =>
        _coordinator.process_data_connect_ack(m.node_name, m.msg_id)
      | let m: FinishedConnectionsMsg val =>
        _coordinator.ack_finished_connections(m.node_name)
      | let m: AckFinishedConnectionsMsg val =>
        _coordinator.process_finished_connections_ack()
      | let m: AckInitializedMsg val =>
        _coordinator.process_initialized_msg_ack()
      | let m: SpinUpMsg val =>
        _env.err.print(_name + " is spinning up a step!")
        _coordinator.add_step(m.step_id, m.step_builder)
      | let m: SpinUpStateStepMsg val =>
        _env.err.print(_name + " is spinning up a state step!")
        _coordinator.add_state_step(m.step_id, m.step_builder,
          m.shared_state_step_id, m.shared_state_step_node)
      | let m: SpinUpProxyMsg val =>
        _env.err.print(_name + " is spinning up a proxy!")
        _coordinator.add_proxy(m.proxy_id, m.step_id, m.target_node_name)
      | let m: SpinUpSinkMsg val =>
        _env.err.print(_name + " is spinning up a sink!")
        _coordinator.add_sink(m.sink_ids, m.sink_step_id, m.sink_builder, _auth)
      | let m: ConnectStepsMsg val =>
        _coordinator.connect_steps(m.in_step_id, m.out_step_id)
      | let d: ShutdownMsg val =>
        _coordinator.shutdown()
      | let m: UnknownMsg val =>
        _env.err.print("Unknown message type.")
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
