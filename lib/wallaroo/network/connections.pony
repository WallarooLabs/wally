use "collections"
use "net"

actor Connections
  let _name: String
  let _env: Env
  let _auth: AmbientAuth
  let _is_initializer: Bool
  let _initializer: (Initializer | None)
  let _control_conns: Map[String, TCPConnection] = _control_conns.create()
  let _data_conns: Map[String, TCPConnection] = _data_conns.create()

  new create(name: String, env: Env, auth: AmbientAuth,
    c_host: String, c_service: String, d_host: String, d_service: String, 
    is_initializer: Bool, initializer: (Initializer | None) = None) 
  =>
    _name = name
    _env = env
    _auth = auth
    _is_initializer = is_initializer
    _initializer = initializer

    if not _is_initializer then
      create_control_connection("initializer", c_host, c_service)
      create_data_connection("initializer", d_host, d_service)
    end

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
      _env.out.print(_name + ": Interconnections with other workers created.")
    else
      _env.out.print("Problem creating interconnections with other workers")
    end 

  be create_control_connection(target_name: String, host: String, 
    service: String) 
  =>
    let control_notifier: TCPConnectionNotify iso =
      ControlChannelConnectNotifier(_name, _env, _auth, this, _initializer)
    let control_conn: TCPConnection =
      TCPConnection(_auth, consume control_notifier, host, service)
    _control_conns(target_name) = control_conn    

  be create_data_connection(target_name: String, host: String, 
    service: String) 
  =>
    let data_notifier: TCPConnectionNotify iso = 
      DataChannelConnectNotifier(_initializer)
    let data_conn: TCPConnection =
      TCPConnection(_auth, consume data_notifier, host, service)
    _data_conns(target_name) = data_conn

