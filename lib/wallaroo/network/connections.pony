use "collections"
use "net"
use "sendence/messages"
use "wallaroo/boundary"
use "wallaroo/initialization"
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/tcp-source"
use "wallaroo/topology"

actor Connections
  let _worker_name: String
  let _env: Env
  let _auth: AmbientAuth
  let _is_initializer: Bool
  let _control_conns: Map[String, TCPConnection] = _control_conns.create()
  let _data_conns: Map[String, OutgoingBoundary] = _data_conns.create()
  var _phone_home: (TCPConnection | None) = None
  let _metrics_conn: TCPConnection
  let _init_d_host: String
  let _init_d_service: String
  // let _proxies: Map[String, Array[Step tag]] = _proxies.create()
  // let _partition_proxies: Map[String, Array[PartitionProxy tag]] = 
  //   _partition_proxies.create()
  let _listeners: Array[TCPListener] = Array[TCPListener]

  new create(worker_name: String, env: Env, auth: AmbientAuth,
    c_host: String, c_service: String, d_host: String, d_service: String, 
    ph_host: String, ph_service: String, metrics_conn: TCPConnection,
    is_initializer: Bool) 
  =>
    _worker_name = worker_name
    _env = env
    _auth = auth
    _is_initializer = is_initializer
    _metrics_conn = metrics_conn
    _init_d_host = d_host
    _init_d_service = d_service

    if not _is_initializer then
      create_control_connection("initializer", c_host, c_service)
      create_data_connection("initializer", d_host, d_service)
    end

    if (ph_host != "") and (ph_service != "") then
      let phone_home = TCPConnection(auth,
        HomeConnectNotify(env, _worker_name, this), ph_host, ph_service)
      _phone_home = phone_home
      if is_initializer then
        let ready_msg = ExternalMsgEncoder.ready(_worker_name)
        phone_home.writev(ready_msg)
      end
      _env.out.print("Set up phone home connection on " + ph_host 
        + ":" + ph_service)
    end

  be register_source_listener(listener: TCPSourceListener) =>
    // TODO: Handle source listeners for shutdown
    None

  be register_listener(listener: TCPListener) =>
    _listeners.push(listener)
    
  be create_initializer_data_channel(
    data_receivers: Map[String, DataReceiver] val) 
  =>
    let data_notifier: TCPListenNotify iso =
      DataChannelListenNotifier(_worker_name, _env, _auth, this,
        _is_initializer, data_receivers)
    register_listener(TCPListener(_auth, consume data_notifier,
      _init_d_host, _init_d_service))

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
      // @printf[I32](("Sent protocol message over outgoing boundary to " + worker + "\n").cstring())
    else
      @printf[I32](("No outgoing boundary to worker " + worker + "\n").cstring())
    end

  be send_phone_home(msg: Array[ByteSeq] val) =>
    match _phone_home
    | let tcp: TCPConnection =>
      tcp.writev(msg)
    else
      _env.err.print("There is no phone home connection to send on!")
    end

  be update_boundaries(local_topology_initializer: LocalTopologyInitializer) =>
    let out_bs: Map[String, OutgoingBoundary] trn = 
      recover Map[String, OutgoingBoundary] end

    for (target, boundary) in _data_conns.pairs() do
      out_bs(target) = boundary
    end

    local_topology_initializer.update_boundaries(consume out_bs)

  be create_connections(
    addresses: Map[String, Map[String, (String, String)]] val,
    local_topology_initializer: LocalTopologyInitializer) 
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

      update_boundaries(local_topology_initializer)

      let connections_ready_msg = ChannelMsgEncoder.connections_ready(
        _worker_name, _auth)

      send_control("initializer", connections_ready_msg)

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
    let outgoing_boundary = OutgoingBoundary(_auth,
      _worker_name, MetricsReporter(_worker_name, _metrics_conn), 
      host, service)
    _data_conns(target_name) = outgoing_boundary

  be update_boundary_ids(boundary_ids: Map[String, U128] val) =>
    for (worker, boundary) in _data_conns.pairs() do
      try
        boundary.register_step_id(boundary_ids(worker))
      else
        @printf[I32](("Could not register step id for boundary to " + worker + "\n").cstring())
      end
    end

  be ack_watermark_to_boundary(receiver_name: String, seq_id: U64) =>
    try
      _data_conns(receiver_name).ack(seq_id)
    else
      @printf[I32](("No outgoing boundary to worker " + receiver_name + "\n").cstring())
    end

  be request_replay(receiver_name: String) =>
    try
      _data_conns(receiver_name).replay_msgs()
    else
      @printf[I32](("No outgoing boundary to worker " + receiver_name + "\n").cstring())
    end

    // try
    //   for proxy in _proxies(target_name).values() do
    //     proxy.update_router(TCPRouter(data_conn))
    //   end
    // end

  // be register_proxy(worker: String, proxy: Step tag) =>
  //   try
  //     if _proxies.contains(worker) then
  //       _proxies(worker).push(proxy)
  //     else
  //       _proxies(worker) = Array[Step tag]
  //       _proxies(worker).push(proxy)
  //     end
  //   end

  // be register_partition_proxies(proxies: Map[String, PartitionProxy] val) =>
  //   for (worker, proxy) in proxies.pairs() do
  //     try
  //       if _partition_proxies.contains(worker) then
  //         _partition_proxies(worker).push(proxy)
  //         let tcp_router = TCPRouter(_data_conns(worker))
  //         proxy.update_router(tcp_router)
  //       else
  //         _partition_proxies(worker) = Array[PartitionProxy tag]
  //         _partition_proxies(worker).push(proxy)
  //         let tcp_router = TCPRouter(_data_conns(worker))
  //         proxy.update_router(tcp_router)
  //       end
  //     end
  //   end

  be shutdown() =>
    for listener in _listeners.values() do
      listener.dispose()
    end

    for (key, conn) in _control_conns.pairs() do
      conn.dispose()
    end
    // for (name, proxies) in _proxies.pairs() do
    //   for proxy in proxies.values() do
    //     proxy.dispose()
    //   end
    // end
    // for (name, proxies) in _partition_proxies.pairs() do
    //   for proxy in proxies.values() do
    //     proxy.dispose()
    //   end
    // end
    // for (key, receiver) in _data_connection_receivers.pairs() do
    //   receiver.dispose()
    // end

    match _phone_home
    | let phc: TCPConnection =>
      phc.writev(ExternalMsgEncoder.done_shutdown(_worker_name))
      phc.dispose()
    end

    _env.out.print("Connections: Finished shutdown procedure.")    


