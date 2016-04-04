use "net"
use "osc-pony"
use "collections"

actor LeaderTCPManager
  let _env: Env
  let _worker_count: USize
  let _workers: Map[I32, TCPConnection tag] = Map[I32, TCPConnection tag]
  var _latest_id: I32 = 0
  var _hellos: USize = 0
  var _acks: USize = 0
  var _phone_home_host: String = ""
  var _phone_home_service: String = ""

  new create(env: Env,
             worker_count: USize,
             phone_home: String) =>
    _env = env
    _worker_count = worker_count
    if phone_home != "" then
      let ph_addr = phone_home.split(":")
      try
        _phone_home_host = ph_addr(0)
        _phone_home_service = ph_addr(1)
      end
    end

    if _worker_count == 0 then _complete_initialization() end

  be assign_id(conn: TCPConnection tag) =>
    _latest_id = _latest_id + 1
    let latest_id = _latest_id
    _workers(_latest_id) = conn
    let message = OSCMessage("/buffy", recover [as OSCData val: OSCInt(MessageTypes.assign_id()),
                                                                OSCInt(latest_id)] end)
    conn.write(message.to_bytes())
    _env.out.print("Identified worker " + latest_id.string())
    _hellos = _hellos + 1
    if _hellos == _worker_count then
      _env.out.print("_--- All workers accounted for! ---_")
      initialize_topology()
    end

  be update_connection(conn: TCPConnection tag, id: I32) =>
    _workers(id) = conn

  be ack_initialized() =>
    _acks = _acks + 1
    if _acks == _worker_count then
      _complete_initialization()
    end

  fun initialize_topology() =>
    None

  fun _complete_initialization() =>
    _env.out.print("_--- Topology successfully initialized ---_")
    if _has_phone_home() then
      try
        let env = _env
        let auth = env.root as AmbientAuth
        let ph_host = _phone_home_host
        let ph_service = _phone_home_service
        let notifier: TCPConnectionNotify iso = recover HomeConnectNotify(env) end
        let conn: TCPConnection = TCPConnection(auth, consume notifier, ph_host, ph_service)

        let message = OSCMessage("/phone_home", recover [as OSCData val: OSCString("Buffy ready")] end)
        conn.write(message.to_bytes())
      else
        _env.out.print("Couldn't get ambient authority when completing initialization")
      end
    end

  fun _has_phone_home(): Bool =>
    (_phone_home_host != "") and (_phone_home_service != "")

class LeaderNotifier is TCPListenNotify
  let _env: Env
  let _manager: LeaderTCPManager
  var _host: String = ""
  var _service: String = ""

  new create(env: Env,
             auth: AmbientAuth,
             host: String,
             service: String,
             worker_count: USize,
             phone_home: String) =>
    _env = env
    _host = host
    _service = service
    _manager = LeaderTCPManager(env, worker_count, phone_home)

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
  let _manager: LeaderTCPManager

  new iso create(env: Env, manager: LeaderTCPManager) =>
    _env = env
    _manager = manager

  fun ref accepted(conn: TCPConnection ref) =>
    _env.out.print("buffy leader: connection accepted")

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso) =>
    try
      let message = OSCDecoder.from_bytes(consume data) as OSCMessage val
      match message.arguments(0)
      | let i: OSCInt val if i.value() == MessageTypes.greet() =>
        _manager.assign_id(conn)
      | let i: OSCInt val if i.value() == MessageTypes.reconnect() =>
        _manager.update_connection(conn, i.value())
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