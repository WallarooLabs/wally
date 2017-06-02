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
use "wallaroo/recovery"
use "wallaroo/w_actor"

class ControlChannelListenNotifier is TCPListenNotify
  let _auth: AmbientAuth
  let _name: String
  var _host: String = ""
  var _service: String = ""
  var _d_host: String
  var _d_service: String
  let _is_initializer: Bool
  let _initializer: (ClusterInitializer | None)
  let _layout_initializer: LayoutInitializer
  let _connections: Connections
  let _recovery: Recovery
  let _recovery_replayer: RecoveryReplayer
  let _router_registry: RouterRegistry
  let _recovery_file: FilePath
  let _joining_existing_cluster: Bool

  new iso create(name: String, auth: AmbientAuth,
    connections: Connections, is_initializer: Bool,
    initializer: (ClusterInitializer | None) = None,
    layout_initializer: LayoutInitializer, recovery: Recovery,
    recovery_replayer: RecoveryReplayer, router_registry: RouterRegistry,
    recovery_file: FilePath, data_host: String, data_service: String,
    joining: Bool = false)
  =>
    _auth = auth
    _name = name
    _d_host = data_host
    _d_service = data_service
    _is_initializer = is_initializer
    _initializer = initializer
    _layout_initializer = layout_initializer
    _connections = connections
    _recovery = recovery
    _recovery_replayer = recovery_replayer
    _router_registry = router_registry
    _recovery_file = recovery_file
    _d_host = data_host
    _d_service = data_service
    _joining_existing_cluster = joining

  fun ref listening(listen: TCPListener ref) =>
    try
      (_host, _service) = listen.local_address().name()
      if _host == "::1" then _host = "127.0.0.1" end

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
          let message = ChannelMsgEncoder.identify_control_port(_name,
            _service, _auth)
          _connections.send_control_to_cluster(message)
        end
        let f = File(_recovery_file)
        f.print(_host)
        f.print(_service)
        f.sync()
        f.dispose()
      else
        let message = ChannelMsgEncoder.identify_control_port(_name,
          _service, _auth)
        _connections.send_control_to_cluster(message)
      end

      @printf[I32]((_name + " control: listening on " + _host + ":" + _service
        + "\n").cstring())
    else
      @printf[I32]((_name + "control : couldn't get local address\n").cstring())
      listen.close()
    end

  fun ref not_listening(listen: TCPListener ref) =>
    @printf[I32]((_name + "control : couldn't listen\n").cstring())
    listen.close()

  fun ref connected(listen: TCPListener ref) : TCPConnectionNotify iso^ =>
    ControlChannelConnectNotifier(_name, _auth, _connections,
      _initializer, _layout_initializer, _recovery, _recovery_replayer,
      _router_registry, _d_host, _d_service)

class ControlChannelConnectNotifier is TCPConnectionNotify
  let _auth: AmbientAuth
  let _name: String
  let _connections: Connections
  let _initializer: (ClusterInitializer | None)
  let _layout_initializer: LayoutInitializer
  let _recovery: Recovery
  let _recovery_replayer: RecoveryReplayer
  let _router_registry: RouterRegistry
  let _d_host: String
  let _d_service: String
  var _header: Bool = true

  new iso create(name: String, auth: AmbientAuth,
    connections: Connections, initializer: (ClusterInitializer | None),
    layout_initializer: LayoutInitializer, recovery: Recovery,
    recovery_replayer: RecoveryReplayer, router_registry: RouterRegistry,
    data_host: String, data_service: String)
  =>
    _auth = auth
    _name = name
    _connections = connections
    _initializer = initializer
    _layout_initializer = layout_initializer
    _recovery = recovery
    _recovery_replayer = recovery_replayer
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
        @printf[I32]("Error reading header on control channel\n".cstring())
      end
    else
      ifdef "trace" then
        @printf[I32]("Received msg on Control Channel\n".cstring())
      end
      let msg = ChannelMsgDecoder(consume data, _auth)
      match msg
      | let m: IdentifyControlPortMsg val =>
        ifdef "trace" then
          @printf[I32]("Received IdentifyControlPortMsg on Control Channel\n"
            .cstring())
        end
        try
          (let host, _) = conn.remote_address().name()
          match _initializer
          | let i: ClusterInitializer =>
            i.identify_control_address(m.worker_name, host, m.service)
          end
          _connections.create_control_connection(m.worker_name, host, m.service)
        end
      | let m: IdentifyDataPortMsg val =>
        ifdef "trace" then
          @printf[I32]("Received IdentifyDataPortMsg on Control Channel\n"
            .cstring())
        end
        try
          (let host, _) = conn.remote_address().name()
          match _initializer
          | let i: ClusterInitializer =>
            i.identify_data_address(m.worker_name, host, m.service)
          end
          _connections.create_data_connection(m.worker_name, host, m.service)
        end
      | let m: RequestBoundaryCountMsg val =>
        ifdef "trace" then
          @printf[I32]("Received RequestBoundaryCountMsg on Control Channel\n"
            .cstring())
        end
        _router_registry.inform_worker_of_boundary_count(m.sender_name)
      | let m: ReconnectDataPortMsg val =>
        // Sending worker is telling us we need to reconnect all boundaries
        // to that worker
        ifdef "trace" then
          @printf[I32]("Received ReconnectDataPortMsg on Control Channel\n"
            .cstring())
        end
        _connections.reconnect_data_connection(m.worker_name)
        _router_registry.reconnect_source_boundaries(m.worker_name)
      | let m: ReplayBoundaryCountMsg val =>
        ifdef "trace" then
          @printf[I32]("Received ReplayBoundaryCountMsg on Control Channel\n"
            .cstring())
        end
        _recovery_replayer.add_expected_boundary_count(m.sender_name,
          m.boundary_count)
      | let m: SpinUpLocalTopologyMsg val =>
        ifdef "trace" then
          @printf[I32]("Received SpinUpLocalTopologyMsg on Control Channel\n"
            .cstring())
        end
        match _layout_initializer
        | let lti: LocalTopologyInitializer =>
          lti.update_topology(m.local_topology)
          lti.initialize()
        else
          Fail()
        end
      | let m: SpinUpLocalActorSystemMsg val =>
        ifdef "trace" then
          @printf[I32](("Received SpinUpLocalActorSystemMsg on Control" +
            "Channel\n").cstring())
        end
        match _layout_initializer
        | let wai: WActorInitializer =>
          wai.update_local_actor_system(m.local_actor_system)
          wai.initialize()
        else
          Fail()
        end
      | let m: RegisterActorForWorkerMsg val =>
        ifdef "trace" then
          @printf[I32](("Received RegisterActorForWorkerMsg on Control" +
            "Channel\n").cstring())
        end
        _router_registry.register_actor_for_worker(m.id, m.worker)
      | let m: RegisterAsRoleMsg val =>
        ifdef "trace" then
          @printf[I32](("Received RegisterAsRoleMsg on Control" +
            "Channel\n").cstring())
        end
        _router_registry.register_as_role(m.role, m.id)
      | let m: BroadcastToActorsMsg val =>
        ifdef "trace" then
          @printf[I32](("Received BroadcastToActorsMsg on Control" +
            "Channel\n").cstring())
        end
        // TODO: If we actually want to use broadcast_to_actors, this will
        // create a bottleneck through the router registry and the central
        // actor registry.
        _router_registry.broadcast_to_actors(m.data)
      | let m: WActorRegistryDigestMsg val =>
        ifdef "trace" then
          @printf[I32](("Received WActorRegistryDigestMsg on Control" +
            "Channel\n").cstring())
        end
        _router_registry.process_digest(m.digest)
        // Assumption: We only receive this digest message during
        // registry recovery phase of Recovery
        _recovery.w_actor_registry_recovery_finished()
      | let m: RequestWActorRegistryDigestMsg val =>
        ifdef "trace" then
          @printf[I32](("Received RequestWActorRegistryDigestMsg on Control" +
            "Channel\n").cstring())
        end
        _router_registry.send_digest_to(m.sender)
      | let m: TopologyReadyMsg val =>
        ifdef "trace" then
          @printf[I32]("Received TopologyReadyMsg on Control Channel\n"
            .cstring())
        end
        match _initializer
        | let i: ClusterInitializer =>
          ifdef debug then
            if m.worker_name == "initializer" then
              @printf[I32](("Initializer shouldn't be sending itself a " +
                "TopologyReady message!\n").cstring())
            end
          end
          i.topology_ready(m.worker_name)
        end
      | let m: CreateConnectionsMsg val =>
        ifdef "trace" then
          @printf[I32]("Received CreateConnectionsMsg on Control Channel\n"
            .cstring())
        end
        _connections.create_connections(m.control_addrs, m.data_addrs,
          _layout_initializer)
      | let m: ConnectionsReadyMsg val =>
        ifdef "trace" then
          @printf[I32]("Received ConnectionsReadyMsg on Control Channel\n"
            .cstring())
        end
        match _initializer
        | let ci: ClusterInitializer =>
          ci.connections_ready(m.worker_name)
        end
      | let m: CreateDataChannelListener val =>
        ifdef "trace" then
          @printf[I32](("Received CreateDataChannelListener on Control " +
            "Channel\n").cstring())
        end
        _layout_initializer.create_data_channel_listener(m.workers,
          _d_host, _d_service)
      | let m: JoinClusterMsg val =>
        match _layout_initializer
        | let lti: LocalTopologyInitializer =>
          lti.inform_joining_worker(conn, m.worker_name)
        else
          Fail()
        end
      | let m: AnnounceNewStatefulStepMsg val =>
        m.update_registry(_router_registry)
      | let m: StepMigrationCompleteMsg val =>
        _router_registry.step_migration_complete(m.step_id)
      | let m: JoiningWorkerInitializedMsg val =>
        try
          (let joining_host, _) = conn.remote_address().name()
          match _layout_initializer
          | let lti: LocalTopologyInitializer =>
            lti.add_new_worker(m.worker_name, joining_host, m.control_addr,
              m.data_addr)
          else
            Fail()
          end
        else
          Fail()
        end
      | let m: AckMigrationBatchCompleteMsg val =>
        ifdef "trace" then
          @printf[I32](("Received AckMigrationBatchCompleteMsg on Control " +
            "Channel\n").cstring())
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
        @printf[I32]("Unknown channel message type.\n".cstring())
      else
        @printf[I32](("Incoming Channel Message type not handled by control " +
          "channel.\n").cstring())
      end

      conn.expect(4)
      _header = true
    end
    true

  fun ref connected(conn: TCPConnection ref) =>
    @printf[I32]((_name + " is connected.\n").cstring())

  fun ref connect_failed(conn: TCPConnection ref) =>
    @printf[I32]((_name + ": connection failed!\n").cstring())

  fun ref closed(conn: TCPConnection ref) =>
    @printf[I32](("ControlChannelConnectNotifier :" + _name +
      ": server closed\n").cstring())

class ControlSenderConnectNotifier is TCPConnectionNotify
  let _auth: AmbientAuth
  let _worker_name: String
  var _header: Bool = true

  new iso create(auth: AmbientAuth, worker_name: String)
  =>
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
  let _auth: AmbientAuth
  let _worker_name: String
  let _startup: Startup
  var _header: Bool = true

  new iso create(auth: AmbientAuth, worker_name: String,
    startup: Startup)
  =>
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
        @printf[I32]("Error reading header on control channel\n".cstring())
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
        @printf[I32](("Incoming Channel Message type not handled by control " +
          "channel.\n").cstring())
      end
      conn.expect(4)
      _header = true
    end
    true
