use "net"
use "collections"
use "time"
use "files"
use "sendence/bytes"
use "sendence/hub"
use "wallaroo"
use "wallaroo/fail"
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
  var _d_host: String
  var _d_service: String
  let _is_initializer: Bool
  let _initializer: (WorkerInitializer | None)
  let _local_topology_initializer: LocalTopologyInitializer
  let _connections: Connections
  let _alfred: Alfred tag
  let _router_registry: RouterRegistry
  let _recovery_file: FilePath
  let _joining_existing_cluster: Bool

  new iso create(name: String, env: Env, auth: AmbientAuth,
    connections: Connections, is_initializer: Bool,
    initializer: (WorkerInitializer | None) = None,
    local_topology_initializer: LocalTopologyInitializer, alfred: Alfred tag,
    router_registry: RouterRegistry, recovery_file: FilePath,
    data_host: String, data_service: String,
    joining: Bool = false)
  =>
    _env = env
    _auth = auth
    _name = name
    _d_host = data_host
    _d_service = data_service
    _is_initializer = is_initializer
    _initializer = initializer
    _local_topology_initializer = local_topology_initializer
    _connections = connections
    _alfred = alfred
    _router_registry = router_registry
    _recovery_file = recovery_file
    _d_host = data_host
    _d_service = data_service
    _joining_existing_cluster = joining

  fun ref listening(listen: TCPListener ref) =>
    try
      (_host, _service) = listen.local_address().name()

      if not _is_initializer then
        _connections.register_my_control_addr(_host, _service)
      end
      _router_registry.register_control_channel_listener(listen)

      ifdef "resilience" then
        if _recovery_file.exists() then
          @printf[I32]("Recovery file exists for control channel\n".cstring())
        end
        if _joining_existing_cluster then
          //TODO: Do we actually need to do this? Isn't this sent as
          // part of joining worker initialized message?
          let message = ChannelMsgEncoder.identify_control_port(_name,
            _service, _auth)
          _connections.send_control_to_cluster(message)
        else
          if not (_is_initializer or _recovery_file.exists()) then
            let message = ChannelMsgEncoder.identify_control_port(_name,
              _service, _auth)
            _connections.send_control("initializer", message)
          end
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
      _initializer, _local_topology_initializer, _alfred, _router_registry,
      _d_host, _d_service)

class ControlChannelConnectNotifier is TCPConnectionNotify
  let _env: Env
  let _auth: AmbientAuth
  let _name: String
  let _connections: Connections
  let _initializer: (WorkerInitializer | None)
  let _local_topology_initializer: LocalTopologyInitializer
  let _alfred: Alfred tag
  let _router_registry: RouterRegistry
  let _d_host: String
  let _d_service: String
  var _header: Bool = true

  new iso create(name: String, env: Env, auth: AmbientAuth,
    connections: Connections, initializer: (WorkerInitializer | None),
    local_topology_initializer: LocalTopologyInitializer, alfred: Alfred tag,
    router_registry: RouterRegistry, data_host: String, data_service: String)
  =>
    _env = env
    _auth = auth
    _name = name
    _connections = connections
    _initializer = initializer
    _local_topology_initializer = local_topology_initializer
    _alfred = alfred
    _router_registry = router_registry
    _d_host = data_host
    _d_service = data_service

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
        _connections.create_connections(m.control_addrs, m.data_addrs,
          _local_topology_initializer)
      | let m: ConnectionsReadyMsg val =>
        ifdef "trace" then
          @printf[I32]("Received ConnectionsReadyMsg on Control Channel\n".cstring())
        end
        match _initializer
        | let wi: WorkerInitializer =>
          wi.connections_ready(m.worker_name)
        end
      | let m: CreateDataChannelListener val =>
        ifdef "trace" then
          @printf[I32]("Received CreateDataChannelListener on Control Channel\n".cstring())
        end
        _local_topology_initializer.create_data_channel_listener(m.workers,
          _d_host, _d_service)
      | let m: JoinClusterMsg val =>
        _local_topology_initializer.inform_joining_worker(conn, m.worker_name)
      | let m: AnnounceNewStatefulStepMsg val =>
        m.update_registry(_router_registry)
      | let m: StepMigrationCompleteMsg val =>
        _router_registry.step_migration_complete(m.step_id)
      | let m: JoiningWorkerInitializedMsg val =>
        try
          (let joining_host, _) = conn.remote_address().name()
          _local_topology_initializer.add_new_worker(m.worker_name,
            joining_host, m.control_addr, m.data_addr)
        else
          Fail()
        end
      | let m: AckMigrationBatchCompleteMsg val =>
        ifdef "trace" then
          @printf[I32]("Received AckMigrationBatchCompleteMsg on Control Channel\n".cstring())
        end
        _router_registry.process_migrating_target_ack(m.sender_name)
      | let m: MuteRequestMsg val =>
        @printf[I32]("Control Ch: Received Mute Request from %s\n".cstring(),
          m.originating_worker.cstring())
        _router_registry.remote_mute_request(m.originating_worker)
      | let m: UnmuteRequestMsg val =>
        @printf[I32]("Control Ch: Received Unmute Request from %s\n".cstring(),
          m.originating_worker.cstring())
        _router_registry.remote_unmute_request(m.originating_worker)
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
    true

class JoiningControlSenderConnectNotifier is TCPConnectionNotify
  let _env: Env
  let _auth: AmbientAuth
  let _worker_name: String
  let _startup: Startup
  var _header: Bool = true

  new iso create(env: Env, auth: AmbientAuth, worker_name: String,
    startup: Startup)
  =>
    _env = env
    _auth = auth
    _worker_name = worker_name
    _startup = startup

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
        try
          // We need to get the host here because the sender didn't know
          // how its host string appears externally. We'll use it to
          // make sure we have the correct addresses in Connections
          (let remote_host, _) = conn.remote_address().name()
          @printf[I32]("***Received cluster information!***\n".cstring())
          _startup.complete_join(remote_host, m)
        else
          Fail()
        end
      else
        _env.err.print("Incoming Channel Message type not handled by control channel.")
      end
      conn.expect(4)
      _header = true
    end
    true
