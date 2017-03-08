use "net"
use "collections"
use "time"
use "files"
use "sendence/bytes"
use "sendence/hub"
use "wallaroo/initialization"
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/topology"
use "wallaroo/resilience"

class ControlChannelListenNotifier is TCPListenNotify
  let _env: Env
  let _auth: AmbientAuth
  let _name: String
  var _host: String = ""
  var _service: String = ""
  let _is_initializer: Bool
  let _initializer: (WorkerInitializer | None)
  let _local_topology_initializer: LocalTopologyInitializer
  let _connections: Connections
  let _alfred: Alfred tag
  let _router_registry: RouterRegistry
  let _recovery_file: FilePath

  new iso create(name: String, env: Env, auth: AmbientAuth,
    connections: Connections, is_initializer: Bool,
    initializer: (WorkerInitializer | None) = None,
    local_topology_initializer: LocalTopologyInitializer, alfred: Alfred tag,
    router_registry: RouterRegistry, recovery_file: FilePath)
  =>
    _env = env
    _auth = auth
    _name = name
    _is_initializer = is_initializer
    _initializer = initializer
    _local_topology_initializer = local_topology_initializer
    _connections = connections
    _alfred = alfred
    _router_registry = router_registry
    _recovery_file = recovery_file

  fun ref listening(listen: TCPListener ref) =>
    try
      (_host, _service) = listen.local_address().name()
      ifdef "resilience" then
        if _recovery_file.exists() then
          @printf[I32]("Recovery file exists for control channel\n".cstring())
        end
        if not (_is_initializer or _recovery_file.exists()) then
          let message = ChannelMsgEncoder.identify_control_port(_name,
            _service, _auth)
          _connections.send_control("initializer", message)
        end
        let f = File(_recovery_file)
        f.print(_host)
        f.print(_service)
        f.sync()
        f.dispose()
      else
        if not _is_initializer then
          let message = ChannelMsgEncoder.identify_control_port(_name,
            _service, _auth)
          _connections.send_control("initializer", message)
        end
      end
      _env.out.print(_name + " control: listening on " + _host + ":" + _service)
    else
      _env.out.print(_name + "control : couldn't get local address")
      listen.close()
    end

  fun ref not_listening(listen: TCPListener ref) =>
    _env.out.print(_name + "control : couldn't listen")
    listen.close()

  fun ref connected(listen: TCPListener ref) : TCPConnectionNotify iso^ =>
    ControlChannelConnectNotifier(_name, _env, _auth, _connections,
      _initializer, _local_topology_initializer, _alfred, _router_registry)

class ControlChannelConnectNotifier is TCPConnectionNotify
  let _env: Env
  let _auth: AmbientAuth
  let _name: String
  let _connections: Connections
  let _initializer: (WorkerInitializer | None)
  let _local_topology_initializer: LocalTopologyInitializer
  let _alfred: Alfred tag
  let _router_registry: RouterRegistry
  var _header: Bool = true

  new iso create(name: String, env: Env, auth: AmbientAuth,
    connections: Connections, initializer: (WorkerInitializer | None),
    local_topology_initializer: LocalTopologyInitializer, alfred: Alfred tag,
    router_registry: RouterRegistry)
  =>
    _env = env
    _auth = auth
    _name = name
    _connections = connections
    _initializer = initializer
    _local_topology_initializer = local_topology_initializer
    _alfred = alfred
    _router_registry = router_registry

  fun ref accepted(conn: TCPConnection ref) =>
    conn.expect(4)

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso,
    n: USize): Bool
  =>
    if _header then
      try
        let expect = Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()
        conn.expect(expect)
        _header = false
      else
        _env.err.print("Error reading header on control channel")
      end
    else
      ifdef "trace" then
        @printf[I32]("Received msg on Control Channel\n".cstring())
      end
      let msg = ChannelMsgDecoder(consume data, _auth)
      match msg
      | let m: IdentifyControlPortMsg val =>
        ifdef "trace" then
          @printf[I32]("Received IdentifyControlPortMsg on Control Channel\n".cstring())
        end
        try
          (let host, _) = conn.remote_address().name()
          match _initializer
          | let i: WorkerInitializer =>
            i.identify_control_address(m.worker_name, host, m.service)
          end
          _connections.create_control_connection(m.worker_name, host, m.service)
        end
      | let m: IdentifyDataPortMsg val =>
        ifdef "trace" then
          @printf[I32]("Received IdentifyDataPortMsg on Control Channel\n".cstring())
        end
        try
          (let host, _) = conn.remote_address().name()
          match _initializer
          | let i: WorkerInitializer =>
            i.identify_data_address(m.worker_name, host, m.service)
          end
          _connections.create_data_connection(m.worker_name, host, m.service)
        end
      | let m: ReconnectDataPortMsg val =>
        ifdef "trace" then
          @printf[I32]("Received ReconnectDataPortMsg on Control Channel\n".cstring())
        end
        _connections.reconnect_data_connection(m.worker_name)
      | let m: SpinUpLocalTopologyMsg val =>
        ifdef "trace" then
          @printf[I32]("Received SpinUpLocalTopologyMsg on Control Channel\n".cstring())
        end
        _local_topology_initializer.update_topology(m.local_topology)
        _local_topology_initializer.initialize()
      | let m: TopologyReadyMsg val =>
        ifdef "trace" then
          @printf[I32]("Received TopologyReadyMsg on Control Channel\n".cstring())
        end
        match _initializer
        | let i: WorkerInitializer =>
          ifdef debug then
            if m.worker_name == "initializer" then
              @printf[I32]("Initializer shouldn't be sending itself a TopologyReady message!\n".cstring())
            end
          end
          i.topology_ready(m.worker_name)
        end
      | let m: CreateConnectionsMsg val =>
        ifdef "trace" then
          @printf[I32]("Received CreateConnectionsMsg on Control Channel\n".cstring())
        end
        _connections.create_connections(m.addresses,
          _local_topology_initializer)
      | let m: ConnectionsReadyMsg val =>
        ifdef "trace" then
          @printf[I32]("Received ConnectionsReadyMsg on Control Channel\n".cstring())
        end
        match _initializer
        | let wi: WorkerInitializer =>
          wi.connections_ready(m.worker_name)
        end
      | let m: CreateDataReceivers val =>
        ifdef "trace" then
          @printf[I32]("Received CreateDataReceivers on Control Channel\n".cstring())
        end
        _local_topology_initializer.create_data_receivers(m.workers)
      | let m: JoinClusterMsg val =>
        _connections.inform_joining_worker(conn, m.worker_name)
      | let m: AnnounceNewStatefulStepMsg val =>
        m.update_registry(_router_registry)
      | let m: UnknownChannelMsg val =>
        _env.err.print("Unknown channel message type.")
      else
        _env.err.print("Incoming Channel Message type not handled by control channel.")
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
    _env.out.print("ControlChannelConnectNotifier :" + _name + ": server closed")

class ControlSenderConnectNotifier is TCPConnectionNotify
  let _env: Env
  let _auth: AmbientAuth
  let _worker_name: String
  var _header: Bool = true

  new iso create(env: Env, auth: AmbientAuth, worker_name: String)
  =>
    _env = env
    _auth = auth
    _worker_name = worker_name

  fun ref connected(conn: TCPConnection ref) =>
    conn.expect(4)
    _header = true

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso,
    n: USize): Bool
  =>
    if _header then
      try
        let expect = Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()
        conn.expect(expect)
        _header = false
      else
        _env.err.print("Error reading header on control channel")
      end
    else
      let msg = ChannelMsgDecoder(consume data, _auth)
      match msg
      | let m: InformJoiningWorkerMsg val =>
        let metrics_conn = MetricsSink(m.metrics_host, m.metrics_service)

        let connect_msg = HubProtocol.connect()
        let metrics_join_msg = HubProtocol.join_metrics(
          "metrics:" + m.metrics_app_name, _worker_name)
        metrics_conn.writev(connect_msg)
        metrics_conn.writev(metrics_join_msg)
        @printf[I32]("Received cluster information!\n".cstring())
      else
        _env.err.print("Incoming Channel Message type not handled by control channel.")
      end
      conn.expect(4)
      _header = true
    end
    true
