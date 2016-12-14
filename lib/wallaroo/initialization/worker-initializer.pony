use "collections"
use "net"
use "sendence/guid"
use "sendence/messages"
use "wallaroo"
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/network"
use "wallaroo/topology"
use "wallaroo/resilience"

actor WorkerInitializer
  let _auth: AmbientAuth
  let _expected: USize
  let _connections: Connections
  let _application_initializer: ApplicationInitializer
  let _local_topology_initializer: LocalTopologyInitializer
  let _initializer_data_addr: Array[String] val
  let _metrics_conn: MetricsSink
  let _connections_ready_workers: Set[String] = Set[String]
  let _ready_workers: Set[String] = Set[String]
  var _control_identified: USize = 1
  var _data_receivers: USize = 1
  var _data_identified: USize = 0
  var _interconnected: USize = 1
  var _initialized: USize = 0

  let _worker_names: Array[String] = Array[String]
  let _control_addrs: Map[String, (String, String)] = _control_addrs.create()
  let _data_addrs: Map[String, (String, String)] = _data_addrs.create()

  new create(auth: AmbientAuth, workers: USize, connections: Connections,
    application_initializer: ApplicationInitializer,
    local_topology_initializer: LocalTopologyInitializer,
    data_addr: Array[String] val, metrics_conn: MetricsSink)
  =>
    _auth = auth
    _expected = workers
    _connections = connections
    _initializer_data_addr = data_addr
    _metrics_conn = metrics_conn
    _application_initializer = application_initializer
    _local_topology_initializer = local_topology_initializer

  be start(a: Application val) =>
    _application_initializer.update_application(a)

    if _expected == 1 then
      _application_initializer.initialize(this, _expected,
        recover Array[String] end)
    end

  be identify_control_address(worker: String, host: String, service: String) =>
    if _control_addrs.contains(worker) then
      @printf[I32](("Initializer: " + worker +
        " tried registering control channel twice\n").cstring())
    else  
      _worker_names.push(worker)
      _control_addrs(worker) = (host, service)
      _control_identified = _control_identified + 1
      if _control_identified == _expected then
        @printf[I32]("All worker channels identified\n".cstring())

        _create_data_receivers()
      end
    end

  be identify_data_address(worker: String, host: String, service: String) =>
    if _data_addrs.contains(worker) then
      @printf[I32](("Initializer: " + worker +
        " tried registering data channel twice.\n").cstring())
    else  
      _data_addrs(worker) = (host, service)
      _data_identified = _data_identified + 1
      if _data_identified == _expected then
        @printf[I32]("All worker channels identified\n".cstring())

        _create_interconnections()
      end
    end

  be distribute_local_topologies(ts: Map[String, LocalTopology val] val) =>
    if _worker_names.size() != ts.size() then
      @printf[I32]("We need one local topology for each worker\n".cstring())
    else
      @printf[I32]("Distributing local topologies to workers\n".cstring())
      for (worker, topology) in ts.pairs() do
        try
          let spin_up_msg = ChannelMsgEncoder.spin_up_local_topology(
            topology, _auth)
          _connections.send_control(worker, spin_up_msg)
        end
      end
      @printf[I32]("Finished distributing\n".cstring())
    end

 be connections_ready(worker_name: String) =>
    if not _connections_ready_workers.contains(worker_name) then
      _connections_ready_workers.set(worker_name)
      _interconnected = _interconnected + 1
      if _interconnected == _expected then
        let names: Array[String] trn = recover Array[String] end
        for name in _worker_names.values() do
          names.push(name)
        end

        _application_initializer.initialize(this, _expected,
          consume names)
      end
    end

  be topology_ready(worker_name: String) =>
    if not _ready_workers.contains(worker_name) then
      @printf[I32]("%s reported topology ready!\n".cstring(),
        worker_name.cstring())
      _ready_workers.set(worker_name)
      _initialized = _initialized + 1
      if _initialized == _expected then
        @printf[I32]("All %llu workers reporting Topology ready!\n".cstring(),
          _expected)
        _application_initializer.topology_ready()

        let topology_ready_msg =
          ExternalMsgEncoder.topology_ready("initializer")
        _connections.send_phone_home(topology_ready_msg)
      end
    else
      @printf[I32]("Duplicate topology ready sent to worker initializer!\n".cstring())
    end

  // be register_proxy(worker: String, proxy: Step tag) =>
  //   _connections.register_proxy(worker, proxy)
    
  fun _create_data_receivers() =>
    let ws: Array[String] trn = recover Array[String] end

    ws.push("initializer")
    for w in _worker_names.values() do
      ws.push(w)
    end

    let workers: Array[String] val = consume ws

    try
      let create_data_receivers_msg = ChannelMsgEncoder.create_data_receivers(
        workers, _auth)
      for key in _control_addrs.keys() do
        _connections.send_control(key, create_data_receivers_msg)
      end

      _local_topology_initializer.create_data_receivers(workers, this)
    else
      @printf[I32]("Failed to create message to create data receivers\n".cstring())
    end

  fun _create_interconnections() =>
    let addresses = _generate_addresses_map()
    try
      let message = ChannelMsgEncoder.create_connections(addresses, _auth)
      for key in _control_addrs.keys() do
        _connections.send_control(key, message)
      end

      _connections.update_boundaries(_local_topology_initializer)
    else
      @printf[I32]("Initializer: Error initializing interconnections\n".cstring())
    end

  fun _generate_addresses_map(): Map[String, Map[String, (String, String)]] val
  =>
    let map: Map[String, Map[String, (String, String)]] trn =
      recover Map[String, Map[String, (String, String)]] end
    let control_map: Map[String, (String, String)] trn =
      recover Map[String, (String, String)] end
    for (key, value) in _control_addrs.pairs() do
      control_map(key) = value
    end
    let data_map: Map[String, (String, String)] trn =
      recover Map[String, (String, String)] end
    for (key, value) in _data_addrs.pairs() do
      data_map(key) = value
    end

    map("control") = consume control_map
    map("data") = consume data_map
    consume map
