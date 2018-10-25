/*

Copyright 2017 The Wallaroo Authors.

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

use "buffered"
use "serialise"
use "net"
use "collections"
use "wallaroo_labs/mort"
use "wallaroo/core/boundary"
use "wallaroo/core/common"
use "wallaroo/core/initialization"
use "wallaroo/core/routing"
use "wallaroo/core/topology"
use "wallaroo/ent/barrier"
use "wallaroo/ent/data_receiver"
use "wallaroo/ent/router_registry"
use "wallaroo/ent/checkpoint"


primitive ChannelMsgEncoder
  fun _encode(msg: ChannelMsg, auth: AmbientAuth,
    wb: Writer = Writer): Array[ByteSeq] val ?
  =>
    let serialised: Array[U8] val =
      Serialised(SerialiseAuth(auth), msg)?.output(OutputSerialisedAuth(auth))
    let size = serialised.size()
    if size > 0 then
      wb.u32_be(size.u32())
      wb.write(serialised)
    end
    wb.done()

  fun data_channel(delivery_msg: DeliveryMsg,
    producer_id: RoutingId, pipeline_time_spent: U64, seq_id: SeqId,
    wb: Writer, auth: AmbientAuth, latest_ts: U64, metrics_id: U16,
    metric_name: String): Array[ByteSeq] val ?
  =>
    _encode(DataMsg(delivery_msg, producer_id, pipeline_time_spent, seq_id,
      latest_ts, metrics_id, metric_name), auth, wb)?

  fun migrate_key(state_name: String, key: Key, checkpoint_id: CheckpointId,
    state: ByteSeq val, worker: String, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    _encode(KeyMigrationMsg(state_name, key, checkpoint_id, state,
      worker), auth)?

  fun migration_batch_complete(sender: String,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    """
    Sent to signal to joining worker that a batch of steps has finished
    emigrating from this step.
    """
    _encode(MigrationBatchCompleteMsg(sender), auth)?

  fun ack_migration_batch_complete(worker: String,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    """
    Sent to ack that a batch of steps has finished immigrating to this step
    """
    _encode(AckMigrationBatchCompleteMsg(worker), auth)?

  fun key_migration_complete(key: Key,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    """
    Sent when the migration of key is complete
    """
    _encode(KeyMigrationCompleteMsg(key), auth)?

  fun begin_leaving_migration(remaining_workers: Array[String] val,
    leaving_workers: Array[String] val, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    """
    This message is sent by the current worker coordinating autoscale shrink to
    all leaving workers once all in-flight messages have finished processing
    after stopping the world. At that point, it's safe for leaving workers to
    migrate steps to the remaining workers.
    """
    _encode(BeginLeavingMigrationMsg(remaining_workers, leaving_workers),
      auth)?

  fun initiate_shrink(remaining_workers: Array[String] val,
    leaving_workers: Array[String] val, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    _encode(InitiateShrinkMsg(remaining_workers, leaving_workers), auth)?

  fun prepare_shrink(remaining_workers: Array[String] val,
    leaving_workers: Array[String] val, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    """
    The worker initially contacted for autoscale shrink sends this message to
    all other remaining workers so they can prepare for the shrink event.
    """
    _encode(PrepareShrinkMsg(remaining_workers, leaving_workers), auth)?

  fun leaving_migration_ack_request(sender: String, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    """
    When a leaving worker migrates all its steps, it requests acks from all
    remaining workers.
    """
    _encode(LeavingMigrationAckRequestMsg(sender), auth)?

  fun leaving_migration_ack(sender: String, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    """
    A remaining worker sends this to ack that a leaving workers has finished
    migrating.
    """
    _encode(LeavingMigrationAckMsg(sender), auth)?

  fun mute_request(originating_worker: String, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    _encode(MuteRequestMsg(originating_worker), auth)?

  fun unmute_request(originating_worker: String, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    _encode(UnmuteRequestMsg(originating_worker), auth)?

  fun identify_control_port(worker_name: String, service: String,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(IdentifyControlPortMsg(worker_name, service), auth)?

  fun identify_data_port(worker_name: String, service: String,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(IdentifyDataPortMsg(worker_name, service), auth)?

  fun reconnect_data_port(worker_name: String, service: String,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(ReconnectDataPortMsg(worker_name, service), auth)?

  fun spin_up_local_topology(local_topology: LocalTopology,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(SpinUpLocalTopologyMsg(local_topology), auth)?

  fun spin_up_step(step_id: U64, step_builder: StepBuilder,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(SpinUpStepMsg(step_id, step_builder), auth)?

  fun topology_ready(worker_name: String, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    _encode(TopologyReadyMsg(worker_name), auth)?

  fun create_connections(
    c_addrs: Map[String, (String, String)] val,
    d_addrs: Map[String, (String, String)] val,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(CreateConnectionsMsg(c_addrs, d_addrs), auth)?

  fun connections_ready(worker_name: String, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    _encode(ConnectionsReadyMsg(worker_name), auth)?

  fun create_data_channel_listener(workers: Array[String] val,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(CreateDataChannelListener(workers), auth)?

  fun data_connect(sender_name: String, sender_step_id: RoutingId,
    highest_seq_id: SeqId, auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(DataConnectMsg(sender_name, sender_step_id, highest_seq_id), auth)?

  fun ack_data_connect(last_id_seen: SeqId, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    _encode(AckDataConnectMsg(last_id_seen), auth)?

  fun data_disconnect(auth: AmbientAuth): Array[ByteSeq] val ? =>
    _encode(DataDisconnectMsg, auth)?

  fun start_normal_data_sending(last_id_seen: SeqId, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    _encode(StartNormalDataSendingMsg(last_id_seen), auth)?

  fun ack_data_received(sender_name: String, sender_step_id: RoutingId,
    seq_id: SeqId, auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(AckDataReceivedMsg(sender_name, sender_step_id, seq_id), auth)?

  fun request_recovery_info(worker_name: WorkerName, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    """
    This message is sent to the cluster when beginning recovery.
    """
    _encode(RequestRecoveryInfoMsg(worker_name), auth)?

  fun inform_recovering_worker(worker_name: String, checkpoint_id: CheckpointId,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    """
    This message is sent as a response to a RequestRecoveryInfo message.
    """
    _encode(InformRecoveringWorkerMsg(worker_name, checkpoint_id), auth)?

  fun join_cluster(worker_name: String, worker_count: USize,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    """
    This message is sent from a worker requesting to join a running cluster to
    any existing worker in the cluster.
    """
    _encode(JoinClusterMsg(worker_name, worker_count), auth)?

  // TODO: Update this once new workers become first class citizens
  fun inform_joining_worker(worker_name: String, metric_app_name: String,
    l_topology: LocalTopology, checkpoint_id: CheckpointId,
    rollback_id: RollbackId, metric_host: String, metric_service: String,
    control_addrs: Map[String, (String, String)] val,
    data_addrs: Map[String, (String, String)] val,
    worker_names: Array[String] val, primary_checkpoint_worker: String,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    """
    This message is sent as a response to a JoinCluster message.
    """
    _encode(InformJoiningWorkerMsg(worker_name, metric_app_name, l_topology,
      checkpoint_id, rollback_id, metric_host, metric_service, control_addrs,
      data_addrs, worker_names, primary_checkpoint_worker), auth)?

  fun inform_join_error(msg: String, auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    """
    This message is sent as a response to a JoinCluster message when there is
    a join error and the joiner should shut down.
    """
    _encode(InformJoinErrorMsg(msg), auth)?

  fun joining_worker_initialized(worker_name: String, c_addr: (String, String),
    d_addr: (String, String), state_routing_ids: Map[StateName, RoutingId] val,
    stateless_partition_routing_ids: Map[RoutingId, RoutingId] val,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    """
    This message is sent after a joining worker initializes its topology. It
    indicates that it is ready to receive migrated steps.
    """
    _encode(JoiningWorkerInitializedMsg(worker_name, c_addr, d_addr,
      state_routing_ids, stateless_partition_routing_ids), auth)?

  fun initiate_stop_the_world_for_join_migration(sender: WorkerName,
    new_workers: Array[String] val, auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(InitiateStopTheWorldForJoinMigrationMsg(sender, new_workers),
      auth)?

  fun initiate_join_migration(new_workers: Array[String] val,
    checkpoint_id: CheckpointId, auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    """
    One worker is contacted by all joining workers and initially coordinates
    state migration to those workers. When it is ready to migrate steps, it
    sends this message to every other current worker informing them to begin
    migration as well. We include the next checkpoint id so that local key
    changes can be logged correctly.
    """
    _encode(InitiateJoinMigrationMsg(new_workers, checkpoint_id), auth)?

  fun autoscale_complete(auth: AmbientAuth): Array[ByteSeq] val ? =>
    """
    The autoscale coordinator sends this message to indicate that autoscale is
    complete.
    """
    _encode(AutoscaleCompleteMsg, auth)?

  fun initiate_stop_the_world_for_shrink_migration(sender: WorkerName,
    remaining_workers: Array[String] val,
    leaving_workers: Array[String] val, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    _encode(InitiateStopTheWorldForShrinkMigrationMsg(sender,
      remaining_workers, leaving_workers), auth)?

  fun leaving_worker_done_migrating(worker_name: String, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    """
    A leaving worker sends this to indicate it has migrated all steps back to
    remaining workers.
    """
    _encode(LeavingWorkerDoneMigratingMsg(worker_name), auth)?

  fun request_boundary_count(sender: String, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    _encode(RequestBoundaryCountMsg(sender), auth)?

  fun inform_of_boundary_count(sender: String, count: USize,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(InformOfBoundaryCountMsg(sender, count), auth)?

  fun announce_connections(control_addrs: Map[String, (String, String)] val,
    data_addrs: Map[String, (String, String)] val,
    new_state_routing_ids: Map[WorkerName, Map[StateName, RoutingId] val] val,
    new_stateless_partition_routing_ids:
      Map[WorkerName, Map[RoutingId, RoutingId] val] val,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(AnnounceConnectionsMsg(control_addrs, data_addrs,
      new_state_routing_ids, new_stateless_partition_routing_ids), auth)?

  fun announce_joining_workers(sender: String,
    control_addrs: Map[String, (String, String)] val,
    data_addrs: Map[String, (String, String)] val,
    new_state_routing_ids: Map[WorkerName, Map[StateName, RoutingId] val] val,
    new_stateless_partition_routing_ids:
      Map[WorkerName, Map[RoutingId, RoutingId] val] val,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(AnnounceJoiningWorkersMsg(sender, control_addrs, data_addrs,
      new_state_routing_ids, new_stateless_partition_routing_ids), auth)?

  fun announce_hash_partitions_grow(sender: String,
    joining_workers: Array[String] val,
    hash_partitions: Map[String, HashPartitions] val, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    """
    Once migration is complete, the coordinator of a grow autoscale event
    informs all joining workers of all hash partitions. We include the joining
    workers list to make it more straightforward for the recipients to update
    the HashProxyRouters in their StatePartitionRouters.
    """
    _encode(AnnounceHashPartitionsGrowMsg(sender, joining_workers,
      hash_partitions), auth)?

  fun connected_to_joining_workers(sender: String, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    """
    Once a non-coordinator in the autoscale protocol connects boundaries to
    all joining workers, it informs the coordinator.
    """
    _encode(ConnectedToJoiningWorkersMsg(sender), auth)?

  fun announce_new_source(worker_name: String, id: RoutingId,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    """
    This message is sent to notify another worker that a new source
    has been created on this worker and that routers should be
    updated.
    """
    _encode(AnnounceNewSourceMsg(worker_name, id), auth)?

  fun rotate_log_files(auth: AmbientAuth): Array[ByteSeq] val ? =>
    _encode(RotateLogFilesMsg, auth)?

  fun clean_shutdown(auth: AmbientAuth, msg: String = ""): Array[ByteSeq] val ?
  =>
    _encode(CleanShutdownMsg(msg), auth)?

  fun report_status(code: ReportStatusCode, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    _encode(ReportStatusMsg(code), auth)?

  fun forward_inject_barrier(token: BarrierToken, sender: WorkerName,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
  _encode(ForwardInjectBarrierMsg(token, sender), auth)?

  fun forward_inject_blocking_barrier(token: BarrierToken,
    wait_for_token: BarrierToken, sender: WorkerName, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
  _encode(ForwardInjectBlockingBarrierMsg(token, wait_for_token, sender),
    auth)?

  fun forwarded_inject_barrier_complete(token: BarrierToken,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
  _encode(ForwardedInjectBarrierCompleteMsg(token), auth)?

  fun remote_initiate_barrier(sender: String, token: BarrierToken,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(RemoteInitiateBarrierMsg(sender, token), auth)?

  fun worker_ack_barrier_start(sender: String, token: BarrierToken,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(WorkerAckBarrierStartMsg(sender, token), auth)?

  fun worker_ack_barrier(sender: String, token: BarrierToken,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(WorkerAckBarrierMsg(sender, token), auth)?

  fun forward_barrier(target_step_id: RoutingId,
    origin_step_id: RoutingId, token: BarrierToken, seq_id: SeqId,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(ForwardBarrierMsg(target_step_id, origin_step_id, token,
      seq_id), auth)?

  fun barrier_complete(token: BarrierToken, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    _encode(BarrierCompleteMsg(token), auth)?

  fun event_log_initiate_checkpoint(checkpoint_id: CheckpointId,
    sender: String, auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(EventLogInitiateCheckpointMsg(checkpoint_id, sender), auth)?

  fun event_log_write_checkpoint_id(checkpoint_id: CheckpointId,
    sender: String, auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(EventLogWriteCheckpointIdMsg(checkpoint_id, sender), auth)?

  fun event_log_ack_checkpoint(checkpoint_id: CheckpointId, sender: String,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(EventLogAckCheckpointMsg(checkpoint_id, sender), auth)?

  fun event_log_ack_checkpoint_id_written(checkpoint_id: CheckpointId,
    sender: String, auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(EventLogAckCheckpointIdWrittenMsg(checkpoint_id, sender), auth)?

  fun commit_checkpoint_id(checkpoint_id: CheckpointId,
    rollback_id: RollbackId, sender: WorkerName, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    _encode(CommitCheckpointIdMsg(checkpoint_id, rollback_id, sender), auth)?

  fun recovery_initiated(token: CheckpointRollbackBarrierToken,
    sender: WorkerName, auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    """
    Sent to all workers in cluster when a recovering worker has connected so
    that currently recovering workers can cede control.
    """
    _encode(RecoveryInitiatedMsg(token, sender), auth)?

  fun ack_recovery_initiated(token: CheckpointRollbackBarrierToken,
    sender: WorkerName, auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    """
    Worker acking that they received a RecoveryInitiatedMsg.
    """
    _encode(AckRecoveryInitiatedMsg(token, sender), auth)?

  fun initiate_rollback_barrier(sender: WorkerName, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    """
    Sent to the primary checkpoint worker from a recovering worker to initiate
    rollback during rollback recovery phase.
    """
    _encode(InitiateRollbackBarrierMsg(sender), auth)?

  fun prepare_for_rollback(sender: WorkerName, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    """
    Sent to all workers in cluster by recovering worker.
    """
    _encode(PrepareForRollbackMsg(sender), auth)?

  fun rollback_local_keys(sender: WorkerName, checkpoint_id: CheckpointId,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    """
    Sent to all workers in cluster by recovering worker.
    """
    _encode(RollbackLocalKeysMsg(sender, checkpoint_id), auth)?

  fun ack_rollback_local_keys(sender: WorkerName, checkpoint_id: CheckpointId,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    """
    Sent to ack rolling back topology graph.
    """
    _encode(AckRollbackLocalKeysMsg(sender, checkpoint_id), auth)?

  fun register_producers(sender: WorkerName, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    """
    Sent to all workers in cluster by recovering worker.
    """
    _encode(RegisterProducersMsg(sender), auth)?

  fun ack_register_producers(sender: WorkerName, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    """
    Sent to ack register producers.
    """
    _encode(AckRegisterProducersMsg(sender), auth)?

  fun rollback_barrier_complete(token: CheckpointRollbackBarrierToken,
    sender: WorkerName, auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    """
    Sent from the primary checkpoint worker to the recovering worker to indicate
    that rollback barrier is complete.
    """
    _encode(RollbackBarrierCompleteMsg(token, sender), auth)?

  fun event_log_initiate_rollback(token: CheckpointRollbackBarrierToken,
    sender: String, auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(EventLogInitiateRollbackMsg(token, sender), auth)?

  fun event_log_ack_rollback(token: CheckpointRollbackBarrierToken,
    sender: String, auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(EventLogAckRollbackMsg(token, sender), auth)?

  fun resume_checkpoint(sender: WorkerName, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    _encode(ResumeCheckpointMsg(sender), auth)?

  fun resume_processing(sender: String, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    _encode(ResumeProcessingMsg(sender), auth)?

  fun register_producer(sender: String, source_id: RoutingId, target_id: RoutingId,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(RegisterProducerMsg(sender, source_id, target_id), auth)?

  fun unregister_producer(sender: String, source_id: RoutingId, target_id: RoutingId,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(UnregisterProducerMsg(sender, source_id, target_id), auth)?

primitive ChannelMsgDecoder
  fun apply(data: Array[U8] val, auth: AmbientAuth): ChannelMsg =>
    try
      match Serialised.input(InputSerialisedAuth(auth), data)(
        DeserialiseAuth(auth))?
      | let m: ChannelMsg =>
        m
      else
        UnknownChannelMsg(data)
      end
    else
      UnknownChannelMsg(data)
    end

trait val ChannelMsg

class val UnknownChannelMsg is ChannelMsg
  let data: Array[U8] val

  new val create(d: Array[U8] val) =>
    data = d

class val IdentifyControlPortMsg is ChannelMsg
  let worker_name: String
  let service: String

  new val create(name: String, s: String) =>
    worker_name = name
    service = s

class val IdentifyDataPortMsg is ChannelMsg
  let worker_name: String
  let service: String

  new val create(name: String, s: String) =>
    worker_name = name
    service = s

class val ReconnectDataPortMsg is ChannelMsg
  let worker_name: String
  let service: String

  new val create(name: String, s: String) =>
    worker_name = name
    service = s

class val SpinUpLocalTopologyMsg is ChannelMsg
  let local_topology: LocalTopology

  new val create(lt: LocalTopology) =>
    local_topology = lt

class val SpinUpStepMsg is ChannelMsg
  let step_id: U64
  let step_builder: StepBuilder

  new val create(s_id: U64, s_builder: StepBuilder) =>
    step_id = s_id
    step_builder = s_builder

class val TopologyReadyMsg is ChannelMsg
  let worker_name: String

  new val create(name: String) =>
    worker_name = name

class val CreateConnectionsMsg is ChannelMsg
  let control_addrs: Map[String, (String, String)] val
  let data_addrs: Map[String, (String, String)] val

  new val create(c_addrs: Map[String, (String, String)] val,
    d_addrs: Map[String, (String, String)] val)
  =>
    control_addrs = c_addrs
    data_addrs = d_addrs

class val ConnectionsReadyMsg is ChannelMsg
  let worker_name: String

  new val create(name: String) =>
    worker_name = name

class val CreateDataChannelListener is ChannelMsg
  let workers: Array[String] val

  new val create(ws: Array[String] val) =>
    workers = ws

class val DataConnectMsg is ChannelMsg
  let sender_name: String
  let sender_boundary_id: U128
  let highest_seq_id: SeqId

  new val create(sender_name': String, sender_boundary_id': U128,
    highest_seq_id': SeqId)
  =>
    sender_name = sender_name'
    sender_boundary_id = sender_boundary_id'
    highest_seq_id = highest_seq_id'

primitive DataDisconnectMsg is ChannelMsg

class val AckDataConnectMsg is ChannelMsg
  let last_id_seen: SeqId

  new val create(last_id_seen': SeqId) =>
    last_id_seen = last_id_seen'

class val StartNormalDataSendingMsg is ChannelMsg
  let last_id_seen: SeqId

  new val create(last_id_seen': SeqId) =>
    last_id_seen = last_id_seen'

class val RequestBoundaryCountMsg is ChannelMsg
  let sender_name: String

  new val create(from: String) =>
    sender_name = from

class val InformOfBoundaryCountMsg is ChannelMsg
  let sender_name: String
  let boundary_count: USize

  new val create(from: String, count: USize) =>
    sender_name = from
    boundary_count = count

class val ReplayCompleteMsg is ChannelMsg
  let sender_name: String
  let boundary_id: U128

  new val create(from: String, b_id: U128) =>
    sender_name = from
    boundary_id = b_id

class val KeyMigrationMsg is ChannelMsg
  let _state_name: String
  let _key: Key
  // The next checkpoint that this migrated step will be a part of
  let _checkpoint_id: CheckpointId
  let _state: ByteSeq val
  let _worker: String

  new val create(state_name': String, key': Key,
    checkpoint_id': CheckpointId, state': ByteSeq val, worker': String)
  =>
    _state_name = state_name'
    _key = key'
    _checkpoint_id = checkpoint_id'
    _state = state'
    _worker = worker'

  fun state_name(): String => _state_name
  fun checkpoint_id(): CheckpointId => _checkpoint_id
  fun state(): ByteSeq val => _state
  fun key(): Key => _key
  fun worker(): String => _worker

class val MigrationBatchCompleteMsg is ChannelMsg
  let sender_name: String

  new val create(sender: String) =>
    sender_name = sender

class val AckMigrationBatchCompleteMsg is ChannelMsg
  let sender_name: String

  new val create(sender: String) =>
    sender_name = sender

class val MuteRequestMsg is ChannelMsg
  let originating_worker: String

  new val create(worker: String) =>
    originating_worker = worker

class val UnmuteRequestMsg is ChannelMsg
  let originating_worker: String

  new val create(worker: String) =>
    originating_worker = worker

class val KeyMigrationCompleteMsg is ChannelMsg
  let key: Key

  new val create(k: Key)
  =>
    key = k

class val BeginLeavingMigrationMsg is ChannelMsg
  let remaining_workers: Array[String] val
  let leaving_workers: Array[String] val

  new val create(remaining_workers': Array[String] val,
    leaving_workers': Array[String] val)
  =>
    remaining_workers = remaining_workers'
    leaving_workers = leaving_workers'

class val InitiateShrinkMsg is ChannelMsg
  let remaining_workers: Array[String] val
  let leaving_workers: Array[String] val

  new val create(remaining_workers': Array[String] val,
    leaving_workers': Array[String] val)
  =>
    remaining_workers = remaining_workers'
    leaving_workers = leaving_workers'

class val PrepareShrinkMsg is ChannelMsg
  let remaining_workers: Array[String] val
  let leaving_workers: Array[String] val

  new val create(remaining_workers': Array[String] val,
    leaving_workers': Array[String] val)
  =>
    remaining_workers = remaining_workers'
    leaving_workers = leaving_workers'

class val LeavingMigrationAckRequestMsg is ChannelMsg
  let sender: String

  new val create(sender': String) =>
    sender = sender'

class val LeavingMigrationAckMsg is ChannelMsg
  let sender: String

  new val create(sender': String) =>
    sender = sender'

class val AckDataReceivedMsg is ChannelMsg
  let sender_name: String
  let sender_step_id: RoutingId
  let seq_id: SeqId

  new val create(sender_name': String, sender_step_id': U128,
    seq_id': SeqId)
  =>
    sender_name = sender_name'
    sender_step_id = sender_step_id'
    seq_id = seq_id'

class val DataMsg is ChannelMsg
  let pipeline_time_spent: U64
  let producer_id: RoutingId
  let seq_id: SeqId
  let delivery_msg: DeliveryMsg
  let latest_ts: U64
  let metrics_id: U16
  let metric_name: String

  new val create(msg: DeliveryMsg, producer_id': RoutingId,
    pipeline_time_spent': U64, seq_id': SeqId, latest_ts': U64,
    metrics_id': U16, metric_name': String)
  =>
    producer_id = producer_id'
    seq_id = seq_id'
    pipeline_time_spent = pipeline_time_spent'
    delivery_msg = msg
    latest_ts = latest_ts'
    metrics_id = metrics_id'
    metric_name = metric_name'

trait val DeliveryMsg is ChannelMsg
  fun sender_name(): String
  fun val deliver(pipeline_time_spent: U64,
    producer_id: RoutingId, producer: Producer ref, seq_id: SeqId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64,
    data_routes: Map[RoutingId, Consumer] val,
    state_steps: Map[StateName, Array[Step] val] val,
    stateless_partitions: Map[RoutingId, Array[Step] val] val,
    consumer_ids: MapIs[Consumer, RoutingId] val,
    target_ids_to_route_ids: Map[RoutingId, RouteId] val,
    route_ids_to_target_ids: Map[RouteId, RoutingId] val): RouteId ?
  fun metric_name(): String
  fun msg_uid(): U128

class val ForwardMsg[D: Any val] is DeliveryMsg
  let _target_id: RoutingId
  let _sender_name: String
  let _data: D
  let _key: Key
  let _metric_name: String
  let _proxy_address: ProxyAddress
  let _msg_uid: MsgId
  let _frac_ids: FractionalMessageId

  fun input(): Any val => _data
  fun metric_name(): String => _metric_name
  fun msg_uid(): U128 => _msg_uid
  fun frac_ids(): FractionalMessageId => _frac_ids

  new val create(t_id: RoutingId, from: String,
    m_data: D, k: Key, m_name: String, proxy_address: ProxyAddress,
    msg_uid': MsgId, frac_ids': FractionalMessageId)
  =>
    _target_id = t_id
    _sender_name = from
    _data = m_data
    _key = k
    _metric_name = m_name
    _proxy_address = proxy_address
    _msg_uid = msg_uid'
    _frac_ids = frac_ids'

  fun sender_name(): String => _sender_name

  fun val deliver(pipeline_time_spent: U64,
    producer_id: RoutingId, producer: Producer ref, seq_id: SeqId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64,
    data_routes: Map[RoutingId, Consumer] val,
    state_steps: Map[StateName, Array[Step] val] val,
    stateless_partitions: Map[RoutingId, Array[Step] val] val,
    consumer_ids: MapIs[Consumer, RoutingId] val,
    target_ids_to_route_ids: Map[RoutingId, RouteId] val,
    route_ids_to_target_ids: Map[RouteId, RoutingId] val): RouteId ?
  =>
    let target_step = data_routes(_target_id)?
    ifdef "trace" then
      @printf[I32]("DataRouter found Step\n".cstring())
    end

    let route_id = target_ids_to_route_ids(_target_id)?

    target_step.run[D](_metric_name, pipeline_time_spent, _data, _key,
      producer_id, producer, _msg_uid, _frac_ids, seq_id, route_id, latest_ts,
      metrics_id, worker_ingress_ts)
    route_id

class val ForwardStatePartitionMsg[D: Any val] is DeliveryMsg
  let _target_state_name: String
  let _target_key: Key
  let _sender_name: String
  let _data: D
  let _metric_name: String
  let _msg_uid: MsgId
  let _frac_ids: FractionalMessageId

  fun input(): Any val => _data
  fun metric_name(): String => _metric_name
  fun msg_uid(): U128 => _msg_uid
  fun frac_ids(): FractionalMessageId => _frac_ids

  new val create(state_name: StateName, from: String, m_data: D, k: Key,
    m_name: String, msg_uid': MsgId, frac_ids': FractionalMessageId)
  =>
    _target_state_name = state_name
    _target_key = k
    _sender_name = from
    _data = m_data
    _metric_name = m_name
    _msg_uid = msg_uid'
    _frac_ids = frac_ids'

  fun sender_name(): String => _sender_name

  fun val deliver(pipeline_time_spent: U64,
    producer_id: RoutingId, producer: Producer ref, seq_id: SeqId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64,
    data_routes: Map[RoutingId, Consumer] val,
    state_steps: Map[StateName, Array[Step] val] val,
    stateless_partitions: Map[RoutingId, Array[Step] val] val,
    consumer_ids: MapIs[Consumer, RoutingId] val,
    target_ids_to_route_ids: Map[RoutingId, RouteId] val,
    route_ids_to_target_ids: Map[RouteId, RoutingId] val): RouteId ?
  =>
    ifdef "trace" then
      @printf[I32]("DataRouter found Step\n".cstring())
    end

    try
      let local_state_steps = state_steps(_target_state_name)?
      let idx =
        (HashKey(_target_key) % local_state_steps.size().u128()).usize()
      let target_step = local_state_steps(idx)?

      let target_id = consumer_ids(target_step)?
      let route_id = target_ids_to_route_ids(target_id)?

      target_step.run[D](_metric_name, pipeline_time_spent, _data, _target_key,
        producer_id, producer, _msg_uid, _frac_ids, seq_id, route_id,
        latest_ts, metrics_id, worker_ingress_ts)
      route_id
    else
      error
    end

class val ForwardStatelessPartitionMsg[D: Any val] is DeliveryMsg
  let _target_partition_id: RoutingId
  let _key: Key
  let _sender_name: String
  let _data: D
  let _metric_name: String
  let _msg_uid: MsgId
  let _frac_ids: FractionalMessageId

  fun input(): Any val => _data
  fun metric_name(): String => _metric_name
  fun msg_uid(): U128 => _msg_uid
  fun frac_ids(): FractionalMessageId => _frac_ids

  new val create(target_p_id: RoutingId, from: String, m_data: D, k: Key,
    m_name: String, msg_uid': MsgId, frac_ids': FractionalMessageId)
  =>
    _target_partition_id = target_p_id
    _key = k
    _sender_name = from
    _data = m_data
    _metric_name = m_name
    _msg_uid = msg_uid'
    _frac_ids = frac_ids'

  fun sender_name(): String => _sender_name

  fun val deliver(pipeline_time_spent: U64,
    producer_id: RoutingId, producer: Producer ref, seq_id: SeqId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64,
    data_routes: Map[RoutingId, Consumer] val,
    state_steps: Map[StateName, Array[Step] val] val,
    stateless_partitions: Map[RoutingId, Array[Step] val] val,
    consumer_ids: MapIs[Consumer, RoutingId] val,
    target_ids_to_route_ids: Map[RoutingId, RouteId] val,
    route_ids_to_target_ids: Map[RouteId, RoutingId] val): RouteId ?
  =>
    ifdef "trace" then
      @printf[I32]("DataRouter found Step\n".cstring())
    end

    try
      @printf[I32]("!@--1\n".cstring())
      let partitions = stateless_partitions(_target_partition_id)?
      let idx = HashKey(_key).usize() % partitions.size()
      @printf[I32]("!@--2\n".cstring())
      let target_step = partitions(idx)?

      @printf[I32]("!@--3\n".cstring())
      let target_id = consumer_ids(target_step)?
      @printf[I32]("!@--4\n".cstring())
      let route_id = target_ids_to_route_ids(target_id)?

      target_step.run[D](_metric_name, pipeline_time_spent, _data, _key,
        producer_id, producer, _msg_uid, _frac_ids, seq_id, route_id,
        latest_ts, metrics_id, worker_ingress_ts)
      route_id
    else
      error
    end

class val RequestRecoveryInfoMsg is ChannelMsg
  """
  This message is sent to the cluster when beginning recovery.
  """
  let sender: String

  new val create(sender': String) =>
    sender = sender'

class val InformRecoveringWorkerMsg is ChannelMsg
  """
  This message is sent as a response to a RequestRecoveryInfo message.
  """
  let sender: String
  let checkpoint_id: CheckpointId

  new val create(sender': String, s_id: CheckpointId) =>
    sender = sender'
    checkpoint_id = s_id

class val JoinClusterMsg is ChannelMsg
  """
  This message is sent from a worker requesting to join a running cluster to
  any existing worker in the cluster.
  """
  let worker_name: String
  let worker_count: USize

  new val create(w: String, wc: USize) =>
    worker_name = w
    worker_count = wc

class val InformJoiningWorkerMsg is ChannelMsg
  """
  This message is sent as a response to a JoinCluster message.
  """
  let sender_name: WorkerName
  let local_topology: LocalTopology
  let checkpoint_id: CheckpointId
  let rollback_id: CheckpointId
  let metrics_app_name: String
  let metrics_host: String
  let metrics_service: String
  let control_addrs: Map[WorkerName, (String, String)] val
  let data_addrs: Map[WorkerName, (String, String)] val
  let worker_names: Array[WorkerName] val
  // The worker currently in control of checkpoints
  let primary_checkpoint_worker: WorkerName

  new val create(sender: WorkerName, app: String, l_topology: LocalTopology,
    checkpoint_id': CheckpointId, rollback_id': RollbackId,
    m_host: String, m_service: String,
    c_addrs: Map[WorkerName, (String, String)] val,
    d_addrs: Map[WorkerName, (String, String)] val,
    w_names: Array[String] val,
    p_checkpoint_worker: WorkerName)
  =>
    sender_name = sender
    local_topology = l_topology
    checkpoint_id = checkpoint_id'
    rollback_id = rollback_id'
    metrics_app_name = app
    metrics_host = m_host
    metrics_service = m_service
    control_addrs = c_addrs
    data_addrs = d_addrs
    worker_names = w_names
    primary_checkpoint_worker = p_checkpoint_worker

class val InformJoinErrorMsg is ChannelMsg
  let message: String

  new val create(m: String) =>
    message = m

// TODO: Don't send host over since we need to determine that on receipt
class val JoiningWorkerInitializedMsg is ChannelMsg
  let worker_name: String
  let control_addr: (String, String)
  let data_addr: (String, String)
  let state_routing_ids: Map[StateName, RoutingId] val
  let stateless_partition_routing_ids: Map[RoutingId, RoutingId] val

  new val create(name: String, c_addr: (String, String),
    d_addr: (String, String), s_routing_ids: Map[StateName, RoutingId] val,
    s_p_routing_ids: Map[RoutingId, RoutingId] val)
  =>
    worker_name = name
    control_addr = c_addr
    data_addr = d_addr
    state_routing_ids = s_routing_ids
    stateless_partition_routing_ids = s_p_routing_ids

class val InitiateStopTheWorldForJoinMigrationMsg is ChannelMsg
  let sender: WorkerName
  let new_workers: Array[String] val

  new val create(s: WorkerName, ws: Array[String] val) =>
    sender = s
    new_workers = ws

class val InitiateJoinMigrationMsg is ChannelMsg
  let new_workers: Array[String] val
  let checkpoint_id: CheckpointId

  new val create(ws: Array[String] val, s_id: CheckpointId) =>
    new_workers = ws
    checkpoint_id = s_id

primitive AutoscaleCompleteMsg is ChannelMsg

class val InitiateStopTheWorldForShrinkMigrationMsg is ChannelMsg
  let sender: WorkerName
  let remaining_workers: Array[String] val
  let leaving_workers: Array[String] val

  new val create(s: WorkerName, r_ws: Array[String] val,
    l_ws: Array[String] val)
  =>
    sender = s
    remaining_workers = r_ws
    leaving_workers = l_ws

class val LeavingWorkerDoneMigratingMsg is ChannelMsg
  let worker_name: String

  new val create(name: String)
  =>
    worker_name = name

class val AnnounceConnectionsMsg is ChannelMsg
  let control_addrs: Map[String, (String, String)] val
  let data_addrs: Map[String, (String, String)] val
  let new_state_routing_ids: Map[WorkerName, Map[StateName, RoutingId] val] val
  let new_stateless_partition_routing_ids:
    Map[WorkerName, Map[RoutingId, RoutingId] val] val

  new val create(c_addrs: Map[String, (String, String)] val,
    d_addrs: Map[String, (String, String)] val,
    sri: Map[WorkerName, Map[StateName, RoutingId] val] val,
    spri: Map[WorkerName, Map[RoutingId, RoutingId] val] val)
  =>
    control_addrs = c_addrs
    data_addrs = d_addrs
    new_state_routing_ids = sri
    new_stateless_partition_routing_ids = spri

class val AnnounceJoiningWorkersMsg is ChannelMsg
  let sender: String
  let control_addrs: Map[String, (String, String)] val
  let data_addrs: Map[String, (String, String)] val
  let new_state_routing_ids: Map[WorkerName, Map[StateName, RoutingId] val] val
  let new_stateless_partition_routing_ids:
    Map[WorkerName, Map[RoutingId, RoutingId] val] val

  new val create(sender': String,
    c_addrs: Map[String, (String, String)] val,
    d_addrs: Map[String, (String, String)] val,
    sri: Map[WorkerName, Map[StateName, RoutingId] val] val,
    spri: Map[WorkerName, Map[RoutingId, RoutingId] val] val)
  =>
    sender = sender'
    control_addrs = c_addrs
    data_addrs = d_addrs
    new_state_routing_ids = sri
    new_stateless_partition_routing_ids = spri

class val AnnounceHashPartitionsGrowMsg is ChannelMsg
  let sender: String
  let joining_workers: Array[String] val
  let hash_partitions: Map[String, HashPartitions] val

  new val create(sender': String, joining_workers': Array[String] val,
    hash_partitions': Map[String, HashPartitions] val)
  =>
    sender = sender'
    joining_workers = joining_workers'
    hash_partitions = hash_partitions'

class val ConnectedToJoiningWorkersMsg is ChannelMsg
  let sender: String

  new val create(sender': String) =>
    sender = sender'

class val AnnounceNewSourceMsg is ChannelMsg
  """
  This message is sent to notify another worker that a new source has
  been created on this worker and that routers should be updated.
  """
  let sender: String
  let source_id: RoutingId

  new val create(sender': String, id: RoutingId) =>
    sender = sender'
    source_id = id

primitive RotateLogFilesMsg is ChannelMsg
  """
  This message is sent to a worker instructing it to rotate its log files.
  """

class val CleanShutdownMsg is ChannelMsg
  let msg: String

  new val create(m: String) =>
    msg = m

class val ForwardInjectBarrierMsg is ChannelMsg
  let token: BarrierToken
  let sender: WorkerName

  new val create(token': BarrierToken, sender': WorkerName) =>
    token = token'
    sender = sender'

class val ForwardInjectBlockingBarrierMsg is ChannelMsg
  let token: BarrierToken
  let wait_for_token: BarrierToken
  let sender: WorkerName

  new val create(token': BarrierToken, wait_for_token': BarrierToken,
    sender': WorkerName)
  =>
    token = token'
    wait_for_token = wait_for_token'
    sender = sender'

class val ForwardedInjectBarrierCompleteMsg is ChannelMsg
  let token: BarrierToken

  new val create(token': BarrierToken) =>
    token = token'

class val RemoteInitiateBarrierMsg is ChannelMsg
  let sender: String
  let token: BarrierToken

  new val create(sender': String, token': BarrierToken) =>
    sender = sender'
    token = token'

class val WorkerAckBarrierStartMsg is ChannelMsg
  let sender: String
  let token: BarrierToken

  new val create(sender': String, token': BarrierToken) =>
    sender = sender'
    token = token'

class val WorkerAckBarrierMsg is ChannelMsg
  let sender: String
  let token: BarrierToken

  new val create(sender': String, token': BarrierToken) =>
    sender = sender'
    token = token'

class val ForwardBarrierMsg is ChannelMsg
  let target_id: RoutingId
  let origin_id: RoutingId
  let token: BarrierToken
  // Seq id assigned by boundary
  let seq_id: SeqId

  new val create(target_id': RoutingId, origin_id': RoutingId,
    token': BarrierToken, seq_id': SeqId)
  =>
    target_id = target_id'
    origin_id = origin_id'
    token = token'
    seq_id = seq_id'

class val BarrierCompleteMsg is ChannelMsg
  let token: BarrierToken

  new val create(token': BarrierToken)
  =>
    token = token'

class val EventLogInitiateCheckpointMsg is ChannelMsg
  let checkpoint_id: CheckpointId
  let sender: WorkerName

  new val create(checkpoint_id': CheckpointId, sender': WorkerName) =>
    checkpoint_id = checkpoint_id'
    sender = sender'

class val EventLogWriteCheckpointIdMsg is ChannelMsg
  let checkpoint_id: CheckpointId
  let sender: WorkerName

  new val create(checkpoint_id': CheckpointId, sender': WorkerName) =>
    checkpoint_id = checkpoint_id'
    sender = sender'

class val EventLogAckCheckpointMsg is ChannelMsg
  let checkpoint_id: CheckpointId
  let sender: WorkerName

  new val create(checkpoint_id': CheckpointId, sender': WorkerName) =>
    checkpoint_id = checkpoint_id'
    sender = sender'

class val EventLogAckCheckpointIdWrittenMsg is ChannelMsg
  let checkpoint_id: CheckpointId
  let sender: WorkerName

  new val create(checkpoint_id': CheckpointId, sender': WorkerName) =>
    checkpoint_id = checkpoint_id'
    sender = sender'

class val CommitCheckpointIdMsg is ChannelMsg
  let checkpoint_id: CheckpointId
  let rollback_id: RollbackId
  let sender: WorkerName

  new val create(checkpoint_id': CheckpointId, rollback_id': RollbackId,
    sender': WorkerName)
  =>
    checkpoint_id = checkpoint_id'
    rollback_id = rollback_id'
    sender = sender'

class val RecoveryInitiatedMsg is ChannelMsg
  let token: CheckpointRollbackBarrierToken
  let sender: WorkerName

  new val create(token': CheckpointRollbackBarrierToken, sender': WorkerName) =>
    token = token'
    sender = sender'

class val AckRecoveryInitiatedMsg is ChannelMsg
  let token: CheckpointRollbackBarrierToken
  let sender: WorkerName

  new val create(token': CheckpointRollbackBarrierToken, sender': WorkerName) =>
    token = token'
    sender = sender'

class val EventLogInitiateRollbackMsg is ChannelMsg
  let token: CheckpointRollbackBarrierToken
  let sender: WorkerName

  new val create(token': CheckpointRollbackBarrierToken, sender': WorkerName) =>
    token = token'
    sender = sender'

class val EventLogAckRollbackMsg is ChannelMsg
  let token: CheckpointRollbackBarrierToken
  let sender: WorkerName

  new val create(token': CheckpointRollbackBarrierToken, sender': WorkerName) =>
    token = token'
    sender = sender'

class val InitiateRollbackBarrierMsg is ChannelMsg
  let sender: WorkerName

  new val create(sender': WorkerName) =>
    sender = sender'

class val PrepareForRollbackMsg is ChannelMsg
  let sender: WorkerName

  new val create(sender': WorkerName) =>
    sender = sender'

class val RollbackLocalKeysMsg is ChannelMsg
  let sender: WorkerName
  let checkpoint_id: CheckpointId

  new val create(sender': WorkerName, s_id: CheckpointId) =>
    sender = sender'
    checkpoint_id = s_id

class val AckRollbackLocalKeysMsg is ChannelMsg
  let sender: WorkerName
  let checkpoint_id: CheckpointId

  new val create(sender': WorkerName, s_id: CheckpointId) =>
    sender = sender'
    checkpoint_id = s_id

class val RegisterProducersMsg is ChannelMsg
  let sender: WorkerName

  new val create(sender': WorkerName) =>
    sender = sender'

class val AckRegisterProducersMsg is ChannelMsg
  let sender: WorkerName

  new val create(sender': WorkerName) =>
    sender = sender'

class val RollbackBarrierCompleteMsg is ChannelMsg
  let token: CheckpointRollbackBarrierToken
  let sender: WorkerName

  new val create(token': CheckpointRollbackBarrierToken, sender': WorkerName) =>
    token = token'
    sender = sender'

class val ResumeCheckpointMsg is ChannelMsg
  let sender: String

  new val create(sender': String) =>
    sender = sender'

class val ResumeProcessingMsg is ChannelMsg
  let sender: String

  new val create(sender': String) =>
    sender = sender'

class val RegisterProducerMsg is ChannelMsg
  let sender: String
  let source_id: RoutingId
  let target_id: RoutingId

  new val create(sender': String, source_id': RoutingId, target_id': RoutingId)
  =>
    sender = sender'
    source_id = source_id'
    target_id = target_id'

class val UnregisterProducerMsg is ChannelMsg
  let sender: String
  let source_id: RoutingId
  let target_id: RoutingId

  new val create(sender': String, source_id': RoutingId, target_id': RoutingId)
  =>
    sender = sender'
    source_id = source_id'
    target_id = target_id'

class val ReportStatusMsg is ChannelMsg
  let code: ReportStatusCode

  new val create(c: ReportStatusCode) =>
    code = c
