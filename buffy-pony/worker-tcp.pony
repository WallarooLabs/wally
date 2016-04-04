use "net"
use "osc-pony"

class WorkerNotifier is TCPListenNotify
  let _env: Env
  let _auth: AmbientAuth
  let _leader_host: String
  let _leader_service: String
  var _host: String = ""
  var _service: String = ""

  new create(env: Env, auth: AmbientAuth, leader_host: String, leader_service: String) =>
    _env = env
    _auth = auth
    _leader_host = leader_host
    _leader_service = leader_service

  fun ref listening(listen: TCPListener ref) =>
    try
      let env: Env = _env
      let auth: AmbientAuth = _auth
      (_host, _service) = listen.local_address().name()
      let host = _host
      let service = _service
      _env.out.print("buffy worker: listening on " + _host + ":" + _service)

      let leader_host = _leader_host
      let leader_service = _leader_service
      let notifier: TCPConnectionNotify iso = recover WorkerConnectNotify(env, leader_host, leader_service) end
      let conn: TCPConnection = TCPConnection(_auth, consume notifier, _leader_host, _leader_service)

      let message = OSCMessage("/buffy", recover [as OSCData val: OSCInt(MessageTypes.greet())] end)
      conn.write(message.to_bytes())
    else
      _env.out.print("buffy worker: couldn't get local address")
      listen.close()
    end

  fun ref not_listening(listen: TCPListener ref) =>
    _env.out.print("buffy worker: couldn't listen")
    listen.close()

  fun ref connected(listen: TCPListener ref) : TCPConnectionNotify iso^ =>
    WorkerConnectNotify(_env, _leader_host, _leader_service)

class WorkerConnectNotify is TCPConnectionNotify
  let _env: Env
  let _leader_host: String
  let _leader_service: String
  // An id of 0 means unassigned
  var _id: I32 = 0

  new iso create(env: Env, leader_host: String, leader_service: String) =>
    _env = env
    _leader_host = leader_host
    _leader_service = leader_service

  fun ref accepted(conn: TCPConnection ref) =>
    _env.out.print("buffy worker: connection accepted")

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso) =>
    try
      let message = OSCDecoder.from_bytes(consume data) as OSCMessage val
      match message.arguments(0)
      | let i: OSCInt val if i.value() == MessageTypes.assign_id() =>
        _update_id(conn, message.arguments(1))
      end
    else
      _env.err.print("Error decoding incoming message.")
    end

  fun ref connected(conn: TCPConnection ref) =>
    if _id != 0 then
      let id = _id
      let message = OSCMessage("/buffy", recover [as OSCData val: OSCInt(MessageTypes.reconnect()),
                                                                  OSCInt(id)] end)
      conn.write(message.to_bytes())
      _env.out.print("Re-established connection for worker " + id.string())
    end

  fun ref _update_id(conn: TCPConnection ref, osc_id: OSCData val) =>
    match osc_id
    | let id: OSCInt val =>
      _id = id.value()
      _env.out.print("buffy worker: received")
      _env.out.print("ID assigned: " + _id.string())
    end

  fun ref closed(conn: TCPConnection ref) =>
    _env.out.print("buffy worker: server closed")