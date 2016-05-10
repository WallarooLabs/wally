use "net"
use "collections"
use "buffy/messages"
use "sendence/bytes"
use "sendence/tcp"

actor TopologyManager
  let _env: Env
  let _auth: AmbientAuth
  let _step_manager: StepManager
  let _coordinator: Coordinator
  let _name: String
  let _worker_count: USize
  let _workers: Map[String, TCPConnection tag] = Map[String, TCPConnection tag]
  let _worker_addrs: Map[String, (String, String)] = Map[String, (String, String)]
  let _topology: Topology val
  // Keep track of how many workers identified themselves
  var _hellos: USize = 0
  // Keep track of how many workers acknowledged they're running their
  // part of the topology
  var _acks: USize = 0
  let _leader_host: String
  let _leader_service: String
  let _phone_home_connection: TCPConnection

  new create(env: Env, auth: AmbientAuth, name: String, worker_count: USize,
    leader_host: String, leader_service: String, phone_home_conn: TCPConnection,
    step_manager: StepManager, coordinator: Coordinator, topology: Topology val) =>
    _env = env
    _auth = auth
    _step_manager = step_manager
    _coordinator = coordinator
    _name = name
    _worker_count = worker_count
    _topology = topology
    _leader_host = leader_host
    _leader_service = leader_service
    _phone_home_connection = phone_home_conn
    _worker_addrs(name) = (leader_host, leader_service)

    let message = WireMsgEncoder.ready(_name)
    _phone_home_connection.write(message)

    if _worker_count == 0 then _complete_initialization() end

  be assign_name(conn: TCPConnection tag, node_name: String,
    host: String, service: String) =>
    _workers(node_name) = conn
    _worker_addrs(node_name) = (host, service)
    _env.out.print("Identified worker " + node_name)
    _hellos = _hellos + 1
    if _hellos == _worker_count then
      _env.out.print("_--- All workers accounted for! ---_")
      _initialize_topology()
    end

  // Currently assigns steps in pipeline using round robin among nodes
  fun ref _initialize_topology() =>
    try
      let nodes = Array[String]
      nodes.push(_name)
      let keys = _workers.keys()
      for key in keys do
        nodes.push(key)
      end

      let pipeline: PipelineSteps val = _topology.pipelines(0)
      var step_id: USize = 0
      var count: USize = 0
      // Round robin node assignment
      while count < pipeline.size() do
        let cur_node_idx = count % nodes.size()
        let cur_node = nodes(count % nodes.size())
        let next_node_idx = (cur_node_idx + 1) % nodes.size()
        let next_node = nodes((cur_node_idx + 1) % nodes.size())
        let proxy_step_id = step_id + 1
        let proxy_step_target_id = proxy_step_id + 1
        _env.out.print(next_node)
        let next_node_addr =
          if next_node_idx == 0 then
            (_leader_host, _leader_service)
          else
            _worker_addrs(next_node)
          end
        let pipeline_step = pipeline(count)
        _env.out.print("Spinning up computation " + pipeline_step.computation_type() + " on node " + cur_node)

        if cur_node_idx == 0 then // if cur_node is the leader/source
          let target_conn = _workers(next_node)
          _step_manager.add_step(step_id.i32(), pipeline_step.computation_type())
//          _step_manager.add_proxy(proxy_step_id.i32(), proxy_step_target_id.i32(),
//            target_conn)
          _step_manager.connect_steps(step_id.i32(), proxy_step_id.i32())
        else
          let create_step_msg =
            WireMsgEncoder.spin_up(step_id.i32(), pipeline_step.computation_type())
          let create_proxy_msg =
            WireMsgEncoder.spin_up_proxy(proxy_step_id.i32(), proxy_step_target_id.i32(),
              next_node, next_node_addr._1, next_node_addr._2)
          let connect_msg =
            WireMsgEncoder.connect_steps(step_id.i32(), proxy_step_id.i32())

          let conn = _workers(cur_node)
          conn.write(create_step_msg)
          conn.write(create_proxy_msg)
          conn.write(connect_msg)
        end

        count = count + 1
        step_id = step_id + 2
      end
      let sink_node_idx = count % nodes.size()
      let sink_node = nodes(sink_node_idx)
      _env.out.print("Spinning up sink on node " + sink_node)

      if sink_node_idx == 0 then // if cur_node is the leader
        _step_manager.add_sink(0, step_id.i32(), _auth)
      else
        let create_sink_msg =
          WireMsgEncoder.spin_up_sink(0, step_id.i32())
        let conn = _workers(sink_node)
        conn.write(create_sink_msg)
      end

      let finished_msg =
        WireMsgEncoder.initialization_msgs_finished()
      // Send finished_msg to all workers
      for i in Range(1, nodes.size()) do
        let node = nodes(i)
        let next_conn = _workers(node)
        next_conn.write(finished_msg)
      end
    else
      @printf[String]("Buffy Leader: Failed to initialize topology".cstring())
    end

  be update_connection(conn: TCPConnection tag, node_name: String) =>
    _coordinator.add_connection(conn)
    _workers(node_name) = conn

  be ack_initialized() =>
    _acks = _acks + 1
    if _acks == _worker_count then
      _complete_initialization()
    end

  fun _complete_initialization() =>
    _env.out.print("_--- Topology successfully initialized ---_")
    try
      let env = _env
      let auth = env.root as AmbientAuth
      let name = _name

      let message = WireMsgEncoder.topology_ready(_name)
      _phone_home_connection.write(message)
    else
      _env.out.print("Couldn't get ambient authority when completing "
        + "initialization")
    end

  be shutdown() =>
    let message = WireMsgEncoder.shutdown(_name)
    for (key, conn) in _workers.pairs() do
      conn.write(message)
    end
    _coordinator.shutdown()

class LeaderNotifier is TCPListenNotify
  let _env: Env
  let _auth: AmbientAuth
  let _name: String
  let _topology_manager: TopologyManager
  let _step_manager: StepManager
  let _coordinator: Coordinator
  var _host: String = ""
  var _service: String = ""

  new iso create(env: Env, auth: AmbientAuth, name: String, host: String,
    service: String, worker_count: USize, phone_home_conn: TCPConnection,
    topology: Topology val, step_manager: StepManager, coordinator: Coordinator) =>
    _env = env
    _auth = auth
    _name = name
    _host = host
    _service = service
    _step_manager = step_manager
    _coordinator = coordinator
    _topology_manager = TopologyManager(env, auth, name, worker_count, _host,
      _service, phone_home_conn, _step_manager, _coordinator, topology)

  fun ref listening(listen: TCPListener ref) =>
    try
      (_host, _service) = listen.local_address().name()
      _env.out.print(_name + ": listening on " + _host + ":" + _service)
    else
      _env.out.print(_name + ": couldn't get local address")
      listen.close()
    end

  fun ref not_listening(listen: TCPListener ref) =>
    _env.out.print(_name + ": couldn't listen")
    listen.close()

  fun ref connected(listen: TCPListener ref) : TCPConnectionNotify iso^ =>
    LeaderConnectNotify(_env, _auth, _name, _topology_manager, _step_manager,
      _coordinator)

class LeaderConnectNotify is TCPConnectionNotify
  let _env: Env
  let _auth: AmbientAuth
  let _name: String
  let _topology_manager: TopologyManager
  let _step_manager: StepManager
  let _coordinator: Coordinator
  let _framer: Framer = Framer
  let _nodes: Map[String, TCPConnection tag] = Map[String, TCPConnection tag]

  new iso create(env: Env, auth: AmbientAuth, name: String, t_manager: TopologyManager,
    s_manager: StepManager, coordinator: Coordinator) =>
    _env = env
    _auth = auth
    _name = name
    _topology_manager = t_manager
    _step_manager = s_manager
    _coordinator = coordinator

  fun ref accepted(conn: TCPConnection ref) =>
    _coordinator.add_connection(conn)

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso) =>
    for chunked in _framer.chunk(consume data).values() do
      try
        let msg = WireMsgDecoder(consume chunked)
        match msg
        | let m: IdentifyMsg val =>
          _nodes(m.node_name) = conn
          _topology_manager.assign_name(conn, m.node_name, m.host, m.service)
        | let m: AckInitializedMsg val =>
          _topology_manager.ack_initialized()
        | let m: ReconnectMsg val =>
          _topology_manager.update_connection(conn, m.node_name)
        | let m: SpinUpMsg val =>
          _step_manager.add_step(m.step_id, m.computation_type)
        | let m: SpinUpProxyMsg val =>
          _spin_up_proxy(m)
        | let m: SpinUpSinkMsg val =>
          _step_manager.add_sink(m.sink_id, m.sink_step_id, _auth)
        | let m: ForwardI32Msg val =>
          _step_manager(m.step_id, m.msg)
        | let m: ForwardF32Msg val =>
          _step_manager(m.step_id, m.msg)
        | let m: ForwardStringMsg val =>
          _step_manager(m.step_id, m.msg)
        | let m: ConnectStepsMsg val =>
          _step_manager.connect_steps(m.in_step_id, m.out_step_id)
        | let d: ShutdownMsg val =>
          _topology_manager.shutdown()
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
        LeaderConnectNotify(_env, _auth, _name, _topology_manager, _step_manager,
          _coordinator)
      let target_conn =
        TCPConnection(_auth, consume notifier, msg.target_host,
          msg.target_service)
      _step_manager.add_proxy(msg.proxy_id, msg.step_id, target_conn)
      _nodes(msg.target_node_name) = target_conn
    end

  fun ref closed(conn: TCPConnection ref) =>
    _env.out.print(_name + ": server closed")

class HomeConnectNotify is TCPConnectionNotify
  let _env: Env
  let _name: String

  new iso create(env: Env, name: String) =>
    _env = env
    _name = name

  fun ref accepted(conn: TCPConnection ref) =>
    _env.out.print(_name + ": phone home connection accepted")

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso) =>
    _env.out.print(_name + ": received from phone home")

  fun ref closed(conn: TCPConnection ref) =>
    _env.out.print(_name + ": server closed")
