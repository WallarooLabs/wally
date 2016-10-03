use "collections"
use "net"
use "sendence/messages"
use "wallaroo/topology"

actor Connections
  let _worker_name: String
  let _env: Env
  let _auth: AmbientAuth
  let _is_initializer: Bool
  let _control_conns: Map[String, TCPConnection] = _control_conns.create()
  let _data_conns: Map[String, TCPConnection] = _data_conns.create()
  var _phone_home: (TCPConnection | None) = None
  let _proxies: Map[String, Array[Step tag]] = _proxies.create()
  let _listeners: Array[TCPListener] = Array[TCPListener]

  new create(worker_name: String, env: Env, auth: AmbientAuth,
    c_host: String, c_service: String, d_host: String, d_service: String, 
    ph_host: String, ph_service: String, is_initializer: Bool) 
  =>
    _worker_name = worker_name
    _env = env
    _auth = auth
    _is_initializer = is_initializer

    if not _is_initializer then
      create_control_connection("initializer", c_host, c_service)
      create_data_connection("initializer", d_host, d_service)
    end

    if (ph_host != "") and (ph_service != "") then
      let phone_home = TCPConnection(auth,
        HomeConnectNotify(env, _worker_name, this), ph_host, ph_service)
      _phone_home = phone_home
      let ready_msg = ExternalMsgEncoder.ready(_worker_name)
      phone_home.writev(ready_msg)
      _env.out.print("Set up phone home connection on " + ph_host 
        + ":" + ph_service)
    end

  be register_listener(listener: TCPListener) =>
    _listeners.push(listener)
    
  be add_control_connection(worker: String, conn: TCPConnection) =>
    _control_conns(worker) = conn

  be add_data_connection(worker: String, conn: TCPConnection) =>
    _data_conns(worker) = conn

  be send_control(worker: String, data: Array[ByteSeq] val) =>
    try
      _control_conns(worker).writev(data)
      @printf[I32](("Sent control message to " + worker + "\n").cstring())
    else
      @printf[I32](("No control connection for worker " + worker + "\n").cstring())
    end

  be send_data(worker: String, data: Array[ByteSeq] val) =>
    try
      _data_conns(worker).writev(data)
      @printf[I32](("Sent data message to " + worker + "\n").cstring())
    else
      @printf[I32](("No data connection for worker " + worker + "\n").cstring())
    end

  be send_phone_home(msg: Array[ByteSeq] val) =>
    match _phone_home
    | let tcp: TCPConnection =>
      tcp.writev(msg)
    else
      _env.err.print("There is no phone home connection to send on!")
    end

  be create_connections(
    addresses: Map[String, Map[String, (String, String)]] val) 
  =>
    try
      let control_addrs = addresses("control")
      let data_addrs = addresses("data")
      for (target, address) in control_addrs.pairs() do
        create_control_connection(target, address._1, address._2)
      end
      for (target, address) in data_addrs.pairs() do
        create_data_connection(target, address._1, address._2)
      end
      _env.out.print(_worker_name + ": Interconnections with other workers created.")
    else
      _env.out.print("Problem creating interconnections with other workers")
    end 

  be create_control_connection(target_name: String, host: String, 
    service: String) 
  =>
    let control_notifier: TCPConnectionNotify iso =
      ControlSenderConnectNotifier(_env)
    let control_conn: TCPConnection =
      TCPConnection(_auth, consume control_notifier, host, service)
    _control_conns(target_name) = control_conn    

  be create_data_connection(target_name: String, host: String, 
    service: String) 
  =>
    let data_notifier: TCPConnectionNotify iso = 
      DataSenderConnectNotifier(_env)
    let data_conn: TCPConnection =
      TCPConnection(_auth, consume data_notifier, host, service)
    _data_conns(target_name) = data_conn
    try
      for proxy in _proxies(target_name).values() do
        proxy.update_connection(data_conn)
      end
    end

  be register_proxy(worker: String, proxy: Step tag) =>
    try
      if _proxies.contains(worker) then
        _proxies(worker).push(proxy)
      else
        _proxies(worker) = Array[Step tag]
        _proxies(worker).push(proxy)
      end
    end

  be shutdown() =>
    for listener in _listeners.values() do
      listener.dispose()
    end

    for (key, conn) in _control_conns.pairs() do
      conn.dispose()
    end
    for (name, proxies) in _proxies.pairs() do
      for proxy in proxies.values() do
        proxy.dispose()
      end
    end
    // for (key, receiver) in _data_connection_receivers.pairs() do
    //   receiver.dispose()
    // end

    match _phone_home
    | let phc: TCPConnection =>
      phc.writev(ExternalMsgEncoder.done_shutdown(_worker_name))
      phc.dispose()
    end

    _env.out.print("Connections: Finished shutdown procedure.")    


