/*

Copyright 2018 The Wallaroo Authors.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
 implied. See the License for the specific language governing
 permissions and limitations under the License.

*/

use "net"
use "collections"
use "files"
use "promises"
use "time"
use "wallaroo"
use "wallaroo/core/common"
use "wallaroo/core/initialization"
use "wallaroo/core/messages"
use "wallaroo/core/metrics"
use "wallaroo/core/topology"
use "wallaroo/ent/barrier"
use "wallaroo/ent/recovery"
use "wallaroo/ent/router_registry"
use "wallaroo/ent/checkpoint"
use "wallaroo_labs/bytes"
use "wallaroo_labs/hub"
use "wallaroo_labs/mort"

class ControlChannelListenNotifier is TCPListenNotify
  let _auth: AmbientAuth
  let _worker_name: String
  let _c_host: String
  let _c_service: String
  var _d_host: String
  var _d_service: String
  let _is_initializer: Bool
  let _initializer: (ClusterInitializer | None)
  let _layout_initializer: LayoutInitializer
  let _connections: Connections
  let _recovery: Recovery
  let _recovery_replayer: RecoveryReconnecter
  let _router_registry: RouterRegistry
  let _barrier_initiator: BarrierInitiator
  let _checkpoint_initiator: CheckpointInitiator
  let _recovery_file: FilePath
  let _event_log: EventLog
  let _recovery_file_cleaner: RecoveryFileCleaner
  let _the_journal: SimpleJournal
  let _do_local_file_io: Bool

  new iso create(worker_name: String, auth: AmbientAuth,
    connections: Connections, is_initializer: Bool,
    initializer: (ClusterInitializer | None) = None,
    layout_initializer: LayoutInitializer, recovery: Recovery,
    recovery_replayer: RecoveryReconnecter, router_registry: RouterRegistry,
    barrier_initiator: BarrierInitiator, checkpoint_initiator: CheckpointInitiator,
    recovery_file: FilePath, data_host: String, data_service: String,
    event_log: EventLog, recovery_file_cleaner: RecoveryFileCleaner,
    the_journal: SimpleJournal, do_local_file_io: Bool,
    control_host: String, control_service: String)
  =>
    _auth = auth
    _worker_name = worker_name
    _d_host = data_host
    _d_service = data_service
    _is_initializer = is_initializer
    _initializer = initializer
    _layout_initializer = layout_initializer
    _connections = connections
    _recovery = recovery
    _recovery_replayer = recovery_replayer
    _router_registry = router_registry
    _barrier_initiator = barrier_initiator
    _checkpoint_initiator = checkpoint_initiator
    _recovery_file = recovery_file
    _event_log = event_log
    _recovery_file_cleaner = recovery_file_cleaner
    _the_journal = the_journal
    _do_local_file_io = do_local_file_io
    _c_host = control_host
    _c_service = control_service

  fun ref listening(listen: TCPListener ref) =>
    try
      if not _is_initializer then
        _connections.register_my_control_addr(_c_host, _c_service)
      end
      _router_registry.register_control_channel_listener(listen)

      if _recovery_file.exists() then
        @printf[I32]("Recovery file exists for control channel\n".cstring())
      end

      let message = ChannelMsgEncoder.identify_control_port(_worker_name,
        _c_service, _auth)?
      _connections.send_control_to_cluster(message)

      let f = AsyncJournalledFile(_recovery_file, _the_journal, _auth,
        _do_local_file_io)
      f.print(_c_host)
      f.print(_c_service)
      f.sync()
      f.dispose()
      // TODO: AsyncJournalledFile does not provide implicit sync semantics here

      @printf[I32]((_worker_name + " control: listening on " + _c_host +
        ":" + _c_service + "\n").cstring())
    else
      @printf[I32]((_worker_name + " control: couldn't get local address %s:%s\n")
        .cstring(), _c_host.cstring(), _c_service.cstring())
      listen.close()
    end

  fun ref not_listening(listen: TCPListener ref) =>
    @printf[I32]((_worker_name + " control: unable to listen on (%s:%s)\n")
      .cstring(), _c_host.cstring(), _c_service.cstring())
    Fail()

  fun ref connected(listen: TCPListener ref): TCPConnectionNotify iso^ =>
    ControlChannelConnectNotifier(_worker_name, _auth, _connections,
      _initializer, _layout_initializer, _recovery, _recovery_replayer,
      _router_registry, _barrier_initiator, _checkpoint_initiator,
      _d_host, _d_service, _event_log, _recovery_file_cleaner)

  fun ref closed(listen: TCPListener ref) =>
    @printf[I32]((_worker_name + " control: listener closed\n").cstring())

class ControlChannelConnectNotifier is TCPConnectionNotify
  let _auth: AmbientAuth
  let _worker_name: String
  let _connections: Connections
  let _initializer: (ClusterInitializer | None)
  let _layout_initializer: LayoutInitializer
  let _recovery: Recovery
  let _recovery_replayer: RecoveryReconnecter
  let _router_registry: RouterRegistry
  let _barrier_initiator: BarrierInitiator
  let _checkpoint_initiator: CheckpointInitiator
  let _d_host: String
  let _d_service: String
  let _event_log: EventLog
  let _recovery_file_cleaner: RecoveryFileCleaner
  var _header: Bool = true

  new iso create(worker_name: String, auth: AmbientAuth,
    connections: Connections, initializer: (ClusterInitializer | None),
    layout_initializer: LayoutInitializer, recovery: Recovery,
    recovery_replayer: RecoveryReconnecter, router_registry: RouterRegistry,
    barrier_initiator: BarrierInitiator, checkpoint_initiator: CheckpointInitiator,
    data_host: String, data_service: String, event_log: EventLog,
    recovery_file_cleaner: RecoveryFileCleaner)
  =>
    _auth = auth
    _worker_name = worker_name
    _connections = connections
    _initializer = initializer
    _layout_initializer = layout_initializer
    _recovery = recovery
    _recovery_replayer = recovery_replayer
    _router_registry = router_registry
    _barrier_initiator = barrier_initiator
    _checkpoint_initiator = checkpoint_initiator
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
          @printf[I32]("_create_control_connection: call from control_channel_tcp line %d\n".cstring(), __loc.line())
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
          @printf[I32]("create_data_connection: call from control_channel_tcp line %d\n".cstring(), __loc.line())
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
        try
          (let host, _) = conn.remote_address().name()?
          _router_registry.update_worker_data_service(m.worker_name,
            host, m.service)
          _router_registry.reconnect_source_boundaries(m.worker_name)
        end
      | let m: InformOfBoundaryCountMsg =>
        ifdef "trace" then
          @printf[I32]("Received InformOfBoundaryCountMsg on Control Channel\n"
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
      | let m: RequestRecoveryInfoMsg =>
        ifdef "trace" then
          @printf[I32]("Received RequestRecoveryInfoMsg on Control Channel\n"
            .cstring())
        end
        _checkpoint_initiator.inform_recovering_worker(m.sender, conn)
      | let m: JoinClusterMsg =>
        ifdef "trace" then
          @printf[I32]("Received JoinClusterMsg on Control Channel\n"
            .cstring())
        end
        ifdef "autoscale" then
          match _layout_initializer
          | let lti: LocalTopologyInitializer =>
            lti.worker_join(conn, m.worker_name, m.worker_count)
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
      | let m: AnnounceConnectionsMsg =>
        for w in m.control_addrs.keys() do
          try
            let host = m.control_addrs(w)?._1
            let control_addr = m.control_addrs(w)?
            let data_addr = m.data_addrs(w)?
            let new_state_routing_ids = m.new_state_routing_ids(w)?
            let new_stateless_partition_routing_ids =
              m.new_stateless_partition_routing_ids(w)?
            match _layout_initializer
            | let lti: LocalTopologyInitializer =>
              lti.add_joining_worker(w, host, control_addr, data_addr,
                new_state_routing_ids, new_stateless_partition_routing_ids)
            else
              Fail()
            end
          else
            Fail()
          end
        end
      | let m: AnnounceJoiningWorkersMsg =>
        match _layout_initializer
        | let lti: LocalTopologyInitializer =>
          lti.connect_to_joining_workers(m.sender, m.control_addrs,
            m.data_addrs, m.new_state_routing_ids,
            m.new_stateless_partition_routing_ids)
        else
          Fail()
        end
      | let m: AnnounceHashPartitionsGrowMsg =>
        _router_registry.update_partition_routers_after_grow(m.joining_workers,
          m.hash_partitions)
      | let m: ConnectedToJoiningWorkersMsg =>
        _router_registry.report_connected_to_joining_worker(m.sender)
      | let m: AnnounceNewSourceMsg =>
        _router_registry.register_remote_source(m.sender, m.source_id)
      | let m: KeyMigrationCompleteMsg =>
        _router_registry.key_migration_complete(m.key)
      | let m: JoiningWorkerInitializedMsg =>
        ifdef debug then
          @printf[I32](("Rcvd JoiningWorkerInitializedMsg on Control " +
            "Channel\n").cstring())
        end
        try
          (let joining_host, _) = conn.remote_address().name()?
          match _layout_initializer
          | let lti: LocalTopologyInitializer =>
            lti.add_joining_worker(m.worker_name, joining_host, m.control_addr,
              m.data_addr, m.state_routing_ids,
              m.stateless_partition_routing_ids)
          else
            Fail()
          end
        else
          Fail()
        end
      | let m: InitiateStopTheWorldForJoinMigrationMsg =>
        _router_registry.remote_stop_the_world_for_join_migration_request(
          m.sender, m.new_workers)
      | let m: InitiateJoinMigrationMsg =>
        _router_registry.remote_join_migration_request(m.new_workers,
          m.checkpoint_id)
      | let m: AutoscaleCompleteMsg =>
        _router_registry.autoscale_complete()
      | let m: InitiateStopTheWorldForShrinkMigrationMsg =>
        _router_registry.remote_stop_the_world_for_shrink_migration_request(
          m.sender, m.remaining_workers, m.leaving_workers)
      | let m: LeavingMigrationAckRequestMsg =>
        match _layout_initializer
        | let lti: LocalTopologyInitializer =>
          lti.remove_worker_connection_info(m.sender)
        else
          Fail()
        end
        try
          // We're acking immediately here, but in the future we may need
          // to take other steps first, plugging this directly into the
          // Autoscale protocol.
          let ack_msg = ChannelMsgEncoder.leaving_migration_ack(_worker_name,
            _auth)?
          _connections.send_control(m.sender, ack_msg)
        else
          Fail()
        end
        _router_registry.disconnect_from_leaving_worker(m.sender)
      | let m: LeavingMigrationAckMsg =>
        _router_registry.receive_leaving_migration_ack(m.sender)
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
        _router_registry.prepare_leaving_migration(m.remaining_workers,
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
      | let m: ForwardInjectBarrierMsg =>
        let promise = Promise[BarrierToken]
        promise.next[None]({(t: BarrierToken) =>
          try
            let msg = ChannelMsgEncoder.forwarded_inject_barrier_complete(t,
              _auth)?
            _connections.send_control(m.sender, msg)
          else
            Fail()
          end
        })
        _barrier_initiator.inject_barrier(m.token, promise)
      | let m: ForwardInjectBlockingBarrierMsg =>
        let promise = Promise[BarrierToken]
        promise.next[None]({(t: BarrierToken) =>
          try
            let msg = ChannelMsgEncoder.forwarded_inject_barrier_complete(t,
              _auth)?
            _connections.send_control(m.sender, msg)
          else
            Fail()
          end
        })
        _barrier_initiator.inject_blocking_barrier(m.token, promise,
          m.wait_for_token)
      | let m: ForwardedInjectBarrierCompleteMsg =>
        _barrier_initiator.forwarded_inject_barrier_complete(m.token)
      | let m: RemoteInitiateBarrierMsg =>
        _barrier_initiator.remote_initiate_barrier(m.sender, m.token)
      | let m: WorkerAckBarrierStartMsg =>
        _barrier_initiator.worker_ack_barrier_start(m.sender, m.token)
      | let m: WorkerAckBarrierMsg =>
        _barrier_initiator.worker_ack_barrier(m.sender, m.token)
      | let m: BarrierCompleteMsg =>
        _barrier_initiator.remote_barrier_complete(m.token)
      | let m: EventLogInitiateCheckpointMsg =>
        let promise = Promise[CheckpointId]
        promise.next[None]({(s_id: CheckpointId) =>
          try
            let msg = ChannelMsgEncoder.event_log_ack_checkpoint(s_id,
              _worker_name, _auth)?
            _connections.send_control(m.sender, msg)
          else
            Fail()
          end
        })
        _event_log.initiate_checkpoint(m.checkpoint_id, promise)
      | let m: EventLogWriteCheckpointIdMsg =>
        let promise = Promise[CheckpointId]
        promise.next[None]({(s_id: CheckpointId) =>
          try
            let msg = ChannelMsgEncoder.event_log_ack_checkpoint_id_written(
              s_id, _worker_name, _auth)?
            _connections.send_control(m.sender, msg)
          else
            Fail()
          end
        })
        _event_log.write_checkpoint_id(m.checkpoint_id, promise)
      | let m: EventLogAckCheckpointMsg =>
        ifdef "checkpoint_trace" then
          @printf[I32]("Rcvd EventLogAckCheckpointMsg!\n".cstring())
        end
        _checkpoint_initiator.event_log_checkpoint_complete(m.sender,
          m.checkpoint_id)
      | let m: EventLogAckCheckpointIdWrittenMsg =>
        ifdef "checkpoint_trace" then
          @printf[I32]("Rcvd EventLogAckCheckpointIdWrittenMsg!\n".cstring())
        end
        _checkpoint_initiator.event_log_id_written(m.sender,
          m.checkpoint_id)
      | let m: CommitCheckpointIdMsg =>
        _checkpoint_initiator.commit_checkpoint_id(m.checkpoint_id, m.rollback_id,
          m.sender)
      | let m: RecoveryInitiatedMsg =>
        _recovery.recovery_initiated_at_worker(m.sender, m.token)
      | let m: AckRecoveryInitiatedMsg =>
        _recovery.ack_recovery_initiated(m.sender, m.token)
      | let m: InitiateRollbackBarrierMsg =>
        let promise = Promise[CheckpointRollbackBarrierToken]
        promise.next[None]({(t: CheckpointRollbackBarrierToken) =>
          try
            let msg = ChannelMsgEncoder.rollback_barrier_complete(t,
              _worker_name, _auth)?
            _connections.send_control(m.sender, msg)
          else
            Fail()
          end
        })
        _checkpoint_initiator.initiate_rollback(promise, m.sender)
      | let m: PrepareForRollbackMsg =>
        // !@ TODO: This promise can be used for acking. Right now it's a
        // placeholder.
        let promise = Promise[None]
        _event_log.prepare_for_rollback(promise, _checkpoint_initiator)
      | let m: RollbackLocalKeysMsg =>
        ifdef "checkpoint_trace" then
          @printf[I32]("Rcvd RollbackLocalKeysMsg\n".cstring())
        end
        let promise = Promise[None]
        promise.next[None]({(n: None) =>
          try
            let msg = ChannelMsgEncoder.ack_rollback_local_keys( _worker_name, m.checkpoint_id, _auth)?
            _connections.send_control(m.sender, msg)
          else
            Fail()
          end
        })
        _layout_initializer.rollback_local_keys(m.checkpoint_id,
          promise)
      | let m: AckRollbackLocalKeysMsg =>
        _recovery.worker_ack_local_keys_rollback(m.sender, m.checkpoint_id)
      | let m: RegisterProducersMsg =>
        let promise = Promise[None]
        promise.next[None]({(n: None) =>
          try
            let msg = ChannelMsgEncoder.ack_register_producers( _worker_name,
              _auth)?
            _connections.send_control(m.sender, msg)
          else
            Fail()
          end
        })
        _router_registry.producers_register_downstream(promise)
      | let m: AckRegisterProducersMsg =>
        _recovery.worker_ack_register_producers(m.sender)
      | let m: RollbackBarrierCompleteMsg =>
        _recovery.rollback_barrier_complete(m.token)
      | let m: EventLogInitiateRollbackMsg =>
        let promise = Promise[CheckpointRollbackBarrierToken]
        promise.next[None]({(t: CheckpointRollbackBarrierToken) =>
          try
            let msg = ChannelMsgEncoder.event_log_ack_rollback(t, _worker_name,
              _auth)?
            _connections.send_control(m.sender, msg)
          else
            Fail()
          end
        })
        _event_log.initiate_rollback(m.token, promise)
      | let m: EventLogAckRollbackMsg =>
        _recovery.rollback_complete(m.sender, m.token)
      | let m: ResumeCheckpointMsg =>
        ifdef "checkpoint_trace" then
          @printf[I32]("Rcvd ResumeCheckpointMsg!!\n".cstring())
        end
        _checkpoint_initiator.resume_checkpoint()
      | let m: ResumeProcessingMsg =>
        ifdef "trace" then
          @printf[I32]("Received ResumeTheWorldMsg from %s\n".cstring(),
            m.sender.cstring())
        end
        _router_registry.resume_processing(m.sender)
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
    _connections.register_disposable(conn)
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
