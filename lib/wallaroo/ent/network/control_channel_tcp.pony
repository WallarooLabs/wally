/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "net"
use "collections"
use "time"
use "files"
use "wallaroo_labs/bytes"
use "wallaroo_labs/hub"
use "wallaroo"
use "wallaroo/core/common"
use "wallaroo/ent/recovery"
use "wallaroo/ent/router_registry"
use "wallaroo_labs/mort"
use "wallaroo/core/initialization"
use "wallaroo/core/messages"
use "wallaroo/core/metrics"
use "wallaroo/core/topology"

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
  let _event_log: EventLog
  let _recovery_file_cleaner: RecoveryFileCleaner

  new iso create(name: String, auth: AmbientAuth,
    connections: Connections, is_initializer: Bool,
    initializer: (ClusterInitializer | None) = None,
    layout_initializer: LayoutInitializer, recovery: Recovery,
    recovery_replayer: RecoveryReplayer, router_registry: RouterRegistry,
    recovery_file: FilePath, data_host: String, data_service: String,
    event_log: EventLog, recovery_file_cleaner: RecoveryFileCleaner)
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
    _event_log = event_log
    _recovery_file_cleaner = recovery_file_cleaner

  fun ref listening(listen: TCPListener ref) =>
    try
      (_host, _service) = listen.local_address().name()?
      if _host == "::1" then _host = "127.0.0.1" end

      if not _is_initializer then
        _connections.register_my_control_addr(_host, _service)
      end
      _router_registry.register_control_channel_listener(listen)

      if _recovery_file.exists() then
        @printf[I32]("Recovery file exists for control channel\n".cstring())
      end

      let message = ChannelMsgEncoder.identify_control_port(_name,
        _service, _auth)?
      _connections.send_control_to_cluster(message)

      let f = File(_recovery_file)
      f.print(_host)
      f.print(_service)
      f.sync()
      f.dispose()

      @printf[I32]((_name + " control: listening on " + _host + ":" + _service
        + "\n").cstring())
    else
      @printf[I32]((_name + " control: couldn't get local address\n")
        .cstring())
      listen.close()
    end

  fun ref not_listening(listen: TCPListener ref) =>
    @printf[I32]((_name + " control: unable to listen on (%s:%s)\n").cstring(),
      _host.cstring(), _service.cstring())
    Fail()

  fun ref connected(listen: TCPListener ref): TCPConnectionNotify iso^ =>
    ControlChannelConnectNotifier(_name, _auth, _connections,
      _initializer, _layout_initializer, _recovery, _recovery_replayer,
      _router_registry, _d_host, _d_service, _event_log,
      _recovery_file_cleaner)

  fun ref closed(listen: TCPListener ref) =>
    @printf[I32]((_name + " control: listener closed\n").cstring())

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
  let _event_log: EventLog
  let _recovery_file_cleaner: RecoveryFileCleaner
  var _header: Bool = true

  new iso create(name: String, auth: AmbientAuth,
    connections: Connections, initializer: (ClusterInitializer | None),
    layout_initializer: LayoutInitializer, recovery: Recovery,
    recovery_replayer: RecoveryReplayer, router_registry: RouterRegistry,
    data_host: String, data_service: String, event_log: EventLog,
    recovery_file_cleaner: RecoveryFileCleaner)
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
    _event_log = event_log
    _recovery_file_cleaner = recovery_file_cleaner

  fun ref accepted(conn: TCPConnection ref) =>
    _connections.register_disposable(conn)
    conn.expect(4)

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso,
    n: USize): Bool
  =>
    if _header then
      try
        let expect = Bytes.to_u32(data(0)?, data(1)?, data(2)?, data(3)?).usize()
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
      | let m: IdentifyControlPortMsg =>
        ifdef "trace" then
          @printf[I32]("Received IdentifyControlPortMsg on Control Channel\n"
            .cstring())
        end
        try
          (let host, _) = conn.remote_address().name()?
          match _initializer
          | let i: ClusterInitializer =>
            i.identify_control_address(m.worker_name, host, m.service)
          end
          _connections.create_control_connection(m.worker_name, host,
            m.service)
        else
          @printf[I32]("Error retrieving remote control address\n".cstring())
        end
      | let m: IdentifyDataPortMsg =>
        ifdef "trace" then
          @printf[I32]("Received IdentifyDataPortMsg on Control Channel\n"
            .cstring())
        end
        try
          (let host, _) = conn.remote_address().name()?
          match _initializer
          | let i: ClusterInitializer =>
            i.identify_data_address(m.worker_name, host, m.service)
          end
          _connections.create_data_connection(m.worker_name, host, m.service)
        end
      | let m: RequestBoundaryCountMsg =>
        ifdef "trace" then
          @printf[I32]("Received RequestBoundaryCountMsg on Control Channel\n"
            .cstring())
        end
        _router_registry.inform_worker_of_boundary_count(m.sender_name)
      | let m: ReconnectDataPortMsg =>
        // Sending worker is telling us we need to reconnect all boundaries
        // to that worker
        ifdef "trace" then
          @printf[I32]("Received ReconnectDataPortMsg on Control Channel\n"
            .cstring())
        end
        _connections.reconnect_data_connection(m.worker_name)
        _router_registry.reconnect_source_boundaries(m.worker_name)
      | let m: ReplayBoundaryCountMsg =>
        ifdef "trace" then
          @printf[I32]("Received ReplayBoundaryCountMsg on Control Channel\n"
            .cstring())
        end
        _recovery_replayer.add_expected_boundary_count(m.sender_name,
          m.boundary_count)
      | let m: SpinUpLocalTopologyMsg =>
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
      | let m: TopologyReadyMsg =>
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
      | let m: CreateConnectionsMsg =>
        ifdef "trace" then
          @printf[I32]("Received CreateConnectionsMsg on Control Channel\n"
            .cstring())
        end
        _connections.create_connections(m.control_addrs, m.data_addrs,
          _layout_initializer)
      | let m: ConnectionsReadyMsg =>
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
      | let m: JoinClusterMsg =>
        ifdef "trace" then
          @printf[I32]("Received JoinClusterMsg on Control Channel\n"
            .cstring())
        end
        ifdef "autoscale" then
          match _layout_initializer
          | let lti: LocalTopologyInitializer =>
            lti.inform_joining_worker(conn, m.worker_name, m.worker_count)
          else
            Fail()
          end
        else
          @printf[I32](("Worker is trying to join the cluster. This is only " +
            "supported in autoscale mode\n").cstring())
          try
            let clean_shutdown_msg = ChannelMsgEncoder.clean_shutdown(_auth,
              "Joining a cluster is only supported in autoscale mode.")?
            conn.writev(clean_shutdown_msg)
          else
            Fail()
          end
        end
      | let m: AnnounceNewStatefulStepMsg =>
        m.update_registry(_router_registry)
      | let m: StepMigrationCompleteMsg =>
        _router_registry.step_migration_complete(m.step_id)
      | let m: JoiningWorkerInitializedMsg =>
        try
          (let joining_host, _) = conn.remote_address().name()?
          match _layout_initializer
          | let lti: LocalTopologyInitializer =>
            lti.add_joining_worker(m.worker_name, joining_host, m.control_addr,
              m.data_addr)
          else
            Fail()
          end
        else
          Fail()
        end
      | let m: InitiateJoinMigrationMsg =>
        _router_registry.remote_migration_request(m.new_workers)
      | let m: LeavingWorkerDoneMigratingMsg =>
        _router_registry.disconnect_from_leaving_worker(m.worker_name)
      | let m: AckMigrationBatchCompleteMsg =>
        ifdef "trace" then
          @printf[I32](("Received AckMigrationBatchCompleteMsg on Control " +
            "Channel\n").cstring())
        end
        _router_registry.process_migrating_target_ack(m.sender_name)
      | let m: BeginLeavingMigrationMsg =>
        ifdef "trace" then
          @printf[I32](("Received BeginLeavingMigrationMsg on Control " +
            "Channel\n").cstring())
        end
        _router_registry.begin_leaving_migration(m.remaining_workers,
          m.leaving_workers)
      | let m: InitiateShrinkMsg =>
        match _layout_initializer
        | let lti: LocalTopologyInitializer =>
          lti.take_over_initiate_shrink(m.remaining_workers,
            m.leaving_workers)
        else
          Fail()
        end
      | let m: PrepareShrinkMsg =>
        ifdef "trace" then
          @printf[I32](("Received PrepareShrinkMsg on Control " +
            "Channel\n").cstring())
        end
        match _layout_initializer
        | let lti: LocalTopologyInitializer =>
          lti.prepare_shrink(m.remaining_workers, m.leaving_workers)
        else
          Fail()
        end
      | let m: MuteRequestMsg =>
        @printf[I32]("Control Ch: Received Mute Request from %s\n".cstring(),
          m.originating_worker.cstring())
        _router_registry.remote_mute_request(m.originating_worker)
      | let m: UnmuteRequestMsg =>
        @printf[I32]("Control Ch: Received Unmute Request from %s\n".cstring(),
          m.originating_worker.cstring())
        _router_registry.remote_unmute_request(m.originating_worker)
      | let m: RequestFinishedAckMsg =>
        _router_registry.remote_request_finished_ack(m.sender,
          m.request_id, m.requester_id)
      | let m: RequestFinishedAckCompleteMsg =>
        _router_registry.remote_request_finished_ack_complete(m.sender,
          m.requester_id)
      | let m: FinishedAckMsg =>
        @printf[I32]("Received FinishedAckMsg from %s\n".cstring(),
          m.sender)
        _router_registry.receive_finished_ack(m.request_id)
      | let m: RotateLogFilesMsg =>
        @printf[I32]("Control Ch: Received Rotate Log Files request\n"
          .cstring())
        _event_log.start_rotation()
      | let m: CleanShutdownMsg =>
        _recovery_file_cleaner.clean_recovery_files()
      | let m: UnknownChannelMsg =>
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
    @printf[I32]("ControlChannelConnectNotifier: connected.\n".cstring())

  fun ref connect_failed(conn: TCPConnection ref) =>
    @printf[I32]("ControlChannelConnectNotifier: connection failed!\n"
      .cstring())

  fun ref closed(conn: TCPConnection ref) =>
    @printf[I32](("ControlChannelConnectNotifier: server closed\n").cstring())

class JoiningControlSenderConnectNotifier is TCPConnectionNotify
  let _auth: AmbientAuth
  let _worker_name: String
  let _worker_count: USize
  let _startup: Startup
  var _header: Bool = true

  new iso create(auth: AmbientAuth, worker_name: String,
    worker_count: (USize | None), startup: Startup)
  =>
    _auth = auth
    _worker_name = worker_name
    _worker_count =
      match worker_count
      | let u: USize => u
      else
        1
      end
    _startup = startup

  fun ref connected(conn: TCPConnection ref) =>
    try
      let cluster_join_msg =
        ChannelMsgEncoder.join_cluster(_worker_name, _worker_count, _auth)?
      conn.writev(cluster_join_msg)
    else
      Fail()
    end
    conn.expect(4)
    _header = true

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso,
    n: USize): Bool
  =>
    if _header then
      try
        let expect = Bytes.to_u32(data(0)?, data(1)?, data(2)?, data(3)?).usize()
        conn.expect(expect)
        _header = false
      else
        @printf[I32]("Error reading header on control channel\n".cstring())
      end
    else
      let msg = ChannelMsgDecoder(consume data, _auth)
      match msg
      | let m: InformJoiningWorkerMsg =>
        try
          // We need to get the host here because the sender didn't know
          // how its host string appears externally. We'll use it to
          // make sure we have the correct addresses in Connections
          (let remote_host, _) = conn.remote_address().name()?
          @printf[I32]("***Received cluster information!***\n".cstring())
          _startup.complete_join(remote_host, m)
        else
          Fail()
        end
      | let m: InformJoinErrorMsg =>
        @printf[I32]("Join Error: %s\n".cstring(), m.message.cstring())
        FatalUserError("Join Error: " + m.message)
      | let m: InformRecoverNotJoinMsg =>
        @printf[I32]("Informed that we should recover.\n".cstring())
        _startup.recover_not_join()
      | let m: CleanShutdownMsg =>
        @printf[I32]("Shutting down early: %s\n".cstring(), m.msg.cstring())
        _startup.dispose()
      else
        @printf[I32](("Incoming Channel Message type not handled by joining " +
          "control channel.\n").cstring())
      end
      conn.expect(4)
      _header = true
    end
    true

  fun ref connect_failed(conn: TCPConnection ref) =>
    @printf[I32]("JoiningControlSenderConnectNotifier: connection failed!\n"
      .cstring())

  fun ref closed(conn: TCPConnection ref) =>
    @printf[I32]("JoiningControlSenderConnectNotifier: server closed\n"
      .cstring())
