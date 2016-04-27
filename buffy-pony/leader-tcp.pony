use "net"
use "collections"
use "./messages"

actor TopologyManager
  let _env: Env
  let _step_manager: StepManager
  let _id: I32
  let _worker_count: USize
  let _workers: Map[I32, TCPConnection tag] = Map[I32, TCPConnection tag]
  let _worker_addrs: Map[I32, (String, String)] = Map[I32, (String, String)]
  // Keep track of how many workers identified themselves
  var _hellos: USize = 0
  // Keep track of how many workers acknowledged they're running their
  // part of the topology
  var _acks: USize = 0
  var _phone_home_host: String = ""
  var _phone_home_service: String = ""

  new create(env: Env, id: I32, worker_count: USize, phone_home: String,
    step_manager: StepManager) =>
    _env = env
    _step_manager = step_manager
    _id = id
    _worker_count = worker_count
    if phone_home != "" then
      let ph_addr = phone_home.split(":")
      try
        _phone_home_host = ph_addr(0)
        _phone_home_service = ph_addr(1)
      end
    end

    if _worker_count == 0 then _complete_initialization() end

  be assign_id(conn: TCPConnection tag, worker_id: I32,
    host: String, service: String) =>
    _workers(worker_id) = conn
    _worker_addrs(worker_id) = (host, service)
    _env.out.print("Identified worker " + worker_id.string())
    _hellos = _hellos + 1
    if _hellos == _worker_count then
      _env.out.print("_--- All workers accounted for! ---_")
      initialize_topology()
    end

  be update_connection(conn: TCPConnection tag, worker_id: I32) =>
    _workers(worker_id) = conn

  be ack_initialized() =>
    _acks = _acks + 1
    if _acks == _worker_count then
      _complete_initialization()
    end

  fun ref initialize_topology() =>
    try
      let keys = _workers.keys()
      let remote_node_id1: I32 = keys.next()
      let remote_node_id2: I32 = keys.next()
      let node2_addr = _worker_addrs(remote_node_id2)

      let double_step_id: I32 = 1
      let halve_step_id: I32 = 2
      let halve_to_print_proxy_id: I32 = 3
      let print_step_id: I32 = 4


      let halve_create_msg =
        TCPMessageEncoder.spin_up(halve_step_id, ComputationTypes.halve())
      let halve_to_print_proxy_create_msg =
        TCPMessageEncoder.spin_up_proxy(halve_to_print_proxy_id,
          print_step_id, remote_node_id2, node2_addr._1, node2_addr._2)
      let print_create_msg =
        TCPMessageEncoder.spin_up(print_step_id, ComputationTypes.print())
      let connect_msg =
        TCPMessageEncoder.connect_steps(halve_step_id, halve_to_print_proxy_id)
      let finished_msg =
        TCPMessageEncoder.initialization_msgs_finished()

      //Leader node (i.e. this one)
      _step_manager.add_step(double_step_id, ComputationTypes.double())

      //First worker node
      var conn1 = _workers(remote_node_id1)
      conn1.write(halve_create_msg)
      conn1.write(halve_to_print_proxy_create_msg)
      conn1.write(connect_msg)
      conn1.write(finished_msg)

      //Second worker node
      var conn2 = _workers(remote_node_id2)
      conn2.write(print_create_msg)
      conn2.write(finished_msg)

      let halve_proxy_id: I32 = 5
      _step_manager.add_proxy(halve_proxy_id, halve_step_id, conn1)
      _step_manager.connect_steps(1, 5)
      _env.out.print("Getting ready to send data messages")

      for i in Range(150, 160) do
        let next_msg = Message[I32](i.i32() - 149, i.i32())
        _step_manager(1, next_msg)
      end
    else
      _env.out.print("Buffy Leader: Failed to initialize topology")
    end

  fun _complete_initialization() =>
    _env.out.print("_--- Topology successfully initialized ---_")
    if _has_phone_home() then
      try
        let env = _env
        let auth = env.root as AmbientAuth
        let ph_host = _phone_home_host
        let ph_service = _phone_home_service
        let notifier: TCPConnectionNotify iso =
          recover HomeConnectNotify(env) end
        let conn: TCPConnection =
          TCPConnection(auth, consume notifier, ph_host, ph_service)

//        let message = OSCMessage("/phone_home", recover [as OSCData val: OSCString("Buffy ready")] end)
//        conn.write(Bytes.encode_osc(message))
      else
        _env.out.print("Couldn't get ambient authority when completing "
          + "initialization")
      end
    end

  fun _has_phone_home(): Bool =>
    (_phone_home_host != "") and (_phone_home_service != "")

class LeaderNotifier is TCPListenNotify
  let _env: Env
  let _auth: AmbientAuth
  let _topology_manager: TopologyManager
  let _step_manager: StepManager
  var _host: String = ""
  var _service: String = ""

  new iso create(env: Env, auth: AmbientAuth, id: I32, host: String,
    service: String, worker_count: USize, phone_home: String) =>
    _env = env
    _auth = auth
    _host = host
    _service = service
    _step_manager = StepManager(env)
    _topology_manager = TopologyManager(env, id, worker_count, phone_home,
      _step_manager)

  fun ref listening(listen: TCPListener ref) =>
    try
      (_host, _service) = listen.local_address().name()
      _env.out.print("buffy leader: listening on " + _host + ":" + _service)
    else
      _env.out.print("buffy leader: couldn't get local address")
      listen.close()
    end

  fun ref not_listening(listen: TCPListener ref) =>
    _env.out.print("buffy leader: couldn't listen")
    listen.close()

  fun ref connected(listen: TCPListener ref) : TCPConnectionNotify iso^ =>
    LeaderConnectNotify(_env, _auth, _topology_manager, _step_manager)

class LeaderConnectNotify is TCPConnectionNotify
  let _env: Env
  let _auth: AmbientAuth
  let _topology_manager: TopologyManager
  let _step_manager: StepManager
  let _nodes: Map[I32, TCPConnection tag] = Map[I32, TCPConnection tag]
  var _buffer: Array[U8] = Array[U8]
  // How many bytes are left to process for current message
  var _left: U32 = 0
  // For building up the two bytes of a U16 message length
  var _len_bytes: Array[U8] = Array[U8]

  new iso create(env: Env, auth: AmbientAuth, t_manager: TopologyManager,
    s_manager: StepManager) =>
    _env = env
    _auth = auth
    _topology_manager = t_manager
    _step_manager = s_manager

  fun ref accepted(conn: TCPConnection ref) =>
    _env.out.print("buffy leader: connection accepted")

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso) =>
    _env.out.print("buffy leader: data received")

    let d: Array[U8] ref = consume data
    try
      while d.size() > 0 do
        if _left == 0 then
          if _len_bytes.size() < 4 then
            let next = d.shift()
            _len_bytes.push(next)
          else
            // Set _left to the length of the current message in bytes
            _left = Bytes.to_u32(_len_bytes(0), _len_bytes(1), _len_bytes(2),
              _len_bytes(3))
            _len_bytes = Array[U8]
          end
        else
          _buffer.push(d.shift())
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
      | let m: IdentifyMsg val =>
        _env.out.print("GREET from " + m.worker_id.string())
        _nodes(m.worker_id) = conn
        _topology_manager.assign_id(conn, m.worker_id, m.host, m.service)
      | let m: AckInitializedMsg val =>
        _env.out.print("ACK INITIALIZED MSG from " + m.worker_id.string())
        _topology_manager.ack_initialized()
      | let m: ReconnectMsg val =>
        _env.out.print("RECONNECTING from " + m.node_id.string())
        _topology_manager.update_connection(conn, m.node_id)
      | let m: SpinUpMsg val =>
        _env.out.print("SPIN UP STEP " + m.step_id.string())
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
      else
        _env.err.print("Error decoding incoming message.")
      end
    else
      _env.err.print("Error decoding incoming message.")
    end
    _env.out.print("buffy leader: received")

  fun ref _spin_up_proxy(msg: SpinUpProxyMsg val) =>
    try
      let target_conn = _nodes(msg.target_node_id)
      _step_manager.add_proxy(msg.proxy_id, msg.step_id, target_conn)
    else
      let env = _env
      let auth = _auth
      let topology_manager = _topology_manager
      let step_manager = _step_manager
      let notifier: TCPConnectionNotify iso =
        recover
          LeaderConnectNotify(env, auth, topology_manager, step_manager)
        end
      let target_conn =
        TCPConnection(_auth, consume notifier, msg.target_host,
          msg.target_service)
      _step_manager.add_proxy(msg.proxy_id, msg.step_id, target_conn)
      _nodes(msg.target_node_id) = target_conn
    end

  fun ref closed(conn: TCPConnection ref) =>
    _env.out.print("buffy leader: server closed")

class HomeConnectNotify is TCPConnectionNotify
  let _env: Env

  new iso create(env: Env) =>
    _env = env

  fun ref accepted(conn: TCPConnection ref) =>
    _env.out.print("buffy leader: phone home connection accepted")

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso) =>
    _env.out.print("buffy leader: received from phone home")

  fun ref closed(conn: TCPConnection ref) =>
    _env.out.print("buffy leader: server closed")
