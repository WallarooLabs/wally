use "net"
use "collections"

actor TopologyManager
  let _env: Env
  let _id: I32
  let _worker_count: USize
  let _workers: Map[I32, TCPConnection tag] = Map[I32, TCPConnection tag]
  let _steps: Map[I32, I32] = Map[I32, I32]
  // Keep track of how many workers identified themselves
  var _hellos: USize = 0
  // Keep track of how many workers acknowledged they're running their
  // part of the topology
  var _acks: USize = 0
  var _phone_home_host: String = ""
  var _phone_home_service: String = ""

  new create(env: Env, id: I32, worker_count: USize, phone_home: String) =>
    _env = env
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

  be assign_id(conn: TCPConnection tag, worker_id: I32) =>
    _workers(worker_id) = conn
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

  be forward_message(step_id: I32, msg: Message[I32] val) =>
    let tcp_msg = TCPMessageEncoder.forward(step_id, msg)
    try
      _workers(_steps(step_id)).write(tcp_msg)
      _env.out.print("Forwarded to proxy!")
    end

  fun ref initialize_topology() =>
    try
      let double_node: Step[I32, I32] tag = Step[I32, I32](Double)
      let remote_node_id: I32 = _workers.keys().next()
      let halve_step_id: I32 = 1
      let print_step_id: I32 = 2
      _steps(halve_step_id) = remote_node_id
      _steps(print_step_id) = remote_node_id
      let halve_create_msg =
        TCPMessageEncoder.spin_up(halve_step_id, ComputationTypes.halve())
      let print_create_msg =
        TCPMessageEncoder.spin_up(print_step_id, ComputationTypes.print())
      let connect_msg =
        TCPMessageEncoder.connect_steps(halve_step_id, print_step_id)
      let finished_msg =
        TCPMessageEncoder.initialization_msgs_finished()
      var conn = _workers(remote_node_id)
      conn.write(halve_create_msg)
      conn.write(print_create_msg)
      conn.write(connect_msg)
      conn.write(finished_msg)
      let halve_proxy = Proxy(_env, halve_step_id, this)
      double_node.add_output(halve_proxy)
      _env.out.print("Getting ready to send data messages")

      for i in Range(0, 10) do
        let next_msg = Message[I32](i.i32(), i.i32())
        double_node(next_msg)
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
  let _manager: TopologyManager
  var _host: String = ""
  var _service: String = ""

  new iso create(env: Env, auth: AmbientAuth, id: I32, host: String,
    service: String, worker_count: USize, phone_home: String) =>
    _env = env
    _host = host
    _service = service
    _manager = TopologyManager(env, id, worker_count, phone_home)

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
    LeaderConnectNotify(_env, _manager)

class LeaderConnectNotify is TCPConnectionNotify
  let _env: Env
  let _manager: TopologyManager
  var _buffer: Array[U8] = Array[U8]
  // How many bytes are left to process for current message
  var _left: U32 = 0
  // For building up the two bytes of a U16 message length
  var _len_bytes: Array[U8] = Array[U8]

  new iso create(env: Env, manager: TopologyManager) =>
    _env = env
    _manager = manager

  fun ref accepted(conn: TCPConnection ref) =>
    _env.out.print("buffy leader: connection accepted")

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso) =>
    _env.out.print("buffy worker: data received")

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
      | let m: GreetMsg val =>
        _manager.assign_id(conn, m.worker_id)
      | let m: AckInitializedMsg val =>
        _manager.ack_initialized()
      | let m: ReconnectMsg val =>
        _manager.update_connection(conn, m.node_id)
      end
    else
      _env.err.print("Error decoding incoming message.")
    end
    _env.out.print("buffy leader: received")

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
