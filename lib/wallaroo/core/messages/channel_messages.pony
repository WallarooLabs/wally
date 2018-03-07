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
use "wallaroo/core/boundary"
use "wallaroo/core/common"
use "wallaroo/ent/data_receiver"
use "wallaroo/ent/router_registry"
use "wallaroo/core/initialization"
use "wallaroo/core/routing"
use "wallaroo/core/topology"

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

  fun data_channel(delivery_msg: ReplayableDeliveryMsg,
    pipeline_time_spent: U64, seq_id: SeqId, wb: Writer, auth: AmbientAuth,
    latest_ts: U64, metrics_id: U16, metric_name: String): Array[ByteSeq] val ?
  =>
    _encode(DataMsg(delivery_msg, pipeline_time_spent, seq_id, latest_ts,
      metrics_id, metric_name), auth, wb)?

  fun migrate_step[K: (Hashable val & Equatable[K] val)](step_id: StepId,
    state_name: String, key: K, state: ByteSeq val, worker: String,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(KeyedStepMigrationMsg[K](step_id, state_name, key, state, worker),
      auth)?

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

  fun step_migration_complete(step_id: StepId,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    """
    Sent when the migration of step step_id is complete
    """
    _encode(StepMigrationCompleteMsg(step_id), auth)?

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

  fun mute_request(originating_worker: String, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    _encode(MuteRequestMsg(originating_worker), auth)?

  fun unmute_request(originating_worker: String, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    _encode(UnmuteRequestMsg(originating_worker), auth)?

  fun delivery[D: Any val](target_id: StepId,
    from_worker_name: String, msg_data: D,
    metric_name: String, auth: AmbientAuth,
    proxy_address: ProxyAddress, msg_uid: MsgId,
    frac_ids: FractionalMessageId): Array[ByteSeq] val ?
  =>
    _encode(ForwardMsg[D](target_id, from_worker_name,
      msg_data, metric_name, proxy_address, msg_uid, frac_ids), auth)?

  fun identify_control_port(worker_name: String, service: String,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(IdentifyControlPortMsg(worker_name, service), auth)?

  fun identify_data_port(worker_name: String, service: String,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(IdentifyDataPortMsg(worker_name, service), auth)?

  fun reconnect_data_port(worker_name: String,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(ReconnectDataPortMsg(worker_name), auth)?

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

  fun data_connect(sender_name: String, sender_step_id: StepId,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(DataConnectMsg(sender_name, sender_step_id), auth)?

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

  fun replay_complete(sender_name: String, boundary_id: U128,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(ReplayCompleteMsg(sender_name, boundary_id), auth)?

  fun ack_watermark(sender_name: String, sender_step_id: StepId, seq_id: SeqId,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(AckWatermarkMsg(sender_name, sender_step_id, seq_id), auth)?

  fun replay(delivery_bytes: Array[ByteSeq] val, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    _encode(ReplayMsg(delivery_bytes), auth)?

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
    l_topology: LocalTopology, metric_host: String,
    metric_service: String, control_addrs: Map[String, (String, String)] val,
    data_addrs: Map[String, (String, String)] val,
    worker_names: Array[String] val,
    partition_blueprints: Map[String, PartitionRouterBlueprint] val,
    stateless_partition_blueprints:
      Map[U128, StatelessPartitionRouterBlueprint] val,
    omni_router_blueprint: OmniRouterBlueprint,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    """
    This message is sent as a response to a JoinCluster message. Currently it
    only informs the new worker of metrics-related info
    """
    _encode(InformJoiningWorkerMsg(worker_name, metric_app_name, l_topology,
      metric_host, metric_service, control_addrs, data_addrs, worker_names,
      partition_blueprints, stateless_partition_blueprints,
      omni_router_blueprint), auth)?

  fun inform_join_error(msg: String, auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    """
    This message is sent as a response to a JoinCluster message when there is
    a join error and the joiner should shut down.
    """
    _encode(InformJoinErrorMsg(msg), auth)?

  fun inform_recover_not_join(auth: AmbientAuth): Array[ByteSeq] val ? =>
    """
    This message is sent as a response to a JoinCluster message when we
    already know the worker name (which indicates that it is recovering, not
    joining)
    """
    _encode(InformRecoverNotJoinMsg, auth)?

  fun joining_worker_initialized(worker_name: String, c_addr: (String, String),
    d_addr: (String, String), auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    """
    This message is sent after a joining worker uses partition blueprints and
    other topology information to initialize its topology. It indicates that
    it is ready to receive migrated steps.
    """
    _encode(JoiningWorkerInitializedMsg(worker_name, c_addr, d_addr), auth)?

  fun initiate_join_migration(new_workers: Array[String] val,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    """
    One worker is contacted by all joining workers and initially coordinates
    state migration to those workers. When it is ready to migrate steps, it
    sends this message to every other current worker informing them to begin
    migration as well.
    """
    _encode(InitiateJoinMigrationMsg(new_workers), auth)?

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

  fun replay_boundary_count(sender: String, count: USize, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    _encode(ReplayBoundaryCountMsg(sender, count), auth)?

  fun announce_new_stateful_step[K: (Hashable val & Equatable[K] val)](
    id: U128, worker_name: String, key: K, state_name: String,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    """
    This message is sent to notify another worker that a new stateful step
    has been created on this worker and that partition routers should be
    updated.
    """
    _encode(KeyedAnnounceNewStatefulStepMsg[K](id, worker_name, key,
      state_name), auth)?

  fun rotate_log_files(auth: AmbientAuth): Array[ByteSeq] val ? =>
    _encode(RotateLogFilesMsg, auth)?

  fun clean_shutdown(auth: AmbientAuth, msg: String = ""): Array[ByteSeq] val ?
  =>
    _encode(CleanShutdownMsg(msg), auth)?

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

  new val create(name: String) =>
    worker_name = name

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

  new val create(sender_name': String, sender_boundary_id': U128) =>
    sender_name = sender_name'
    sender_boundary_id = sender_boundary_id'

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

class val ReplayBoundaryCountMsg is ChannelMsg
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


trait val StepMigrationMsg is ChannelMsg
  fun state_name(): String
  fun step_id(): U128
  fun state(): ByteSeq val
  fun worker(): String
  fun update_router_registry(router_registry: RouterRegistry, target: Consumer)

class val KeyedStepMigrationMsg[K: (Hashable val & Equatable[K] val)] is
  StepMigrationMsg
  let _state_name: String
  let _key: K
  let _step_id: StepId
  let _state: ByteSeq val
  let _worker: String

  new val create(step_id': U128, state_name': String, key': K,
    state': ByteSeq val, worker': String)
  =>
    _state_name = state_name'
    _key = key'
    _step_id = step_id'
    _state = state'
    _worker = worker'

  fun state_name(): String => _state_name
  fun step_id(): U128 => _step_id
  fun state(): ByteSeq val => _state
  fun worker(): String => _worker
  fun update_router_registry(router_registry: RouterRegistry, target: Consumer)
  =>
    router_registry.move_proxy_to_stateful_step[K](_step_id, target, _key,
      _state_name, _worker)

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

class val StepMigrationCompleteMsg is ChannelMsg
  let step_id: StepId

  new val create(step_id': U128)
  =>
    step_id = step_id'

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

class val AckWatermarkMsg is ChannelMsg
  let sender_name: String
  let sender_step_id: StepId
  let seq_id: SeqId

  new val create(sender_name': String, sender_step_id': U128,
    seq_id': SeqId)
  =>
    sender_name = sender_name'
    sender_step_id = sender_step_id'
    seq_id = seq_id'

class val DataMsg is ChannelMsg
  let pipeline_time_spent: U64
  let seq_id: SeqId
  let delivery_msg: ReplayableDeliveryMsg
  let latest_ts: U64
  let metrics_id: U16
  let metric_name: String

  new val create(msg: ReplayableDeliveryMsg, pipeline_time_spent': U64,
    seq_id': SeqId, latest_ts': U64, metrics_id': U16, metric_name': String)
  =>
    seq_id = seq_id'
    pipeline_time_spent = pipeline_time_spent'
    delivery_msg = msg
    latest_ts = latest_ts'
    metrics_id = metrics_id'
    metric_name = metric_name'


class val ReplayMsg is ChannelMsg
  let data_bytes: Array[ByteSeq] val

  new val create(db: Array[ByteSeq] val) =>
    data_bytes = db

  fun data_msg(auth: AmbientAuth): DataMsg ? =>
    var size: USize = 0
    for bytes in data_bytes.values() do
      size = size + bytes.size()
    end

    let buffer = recover trn Array[U8](size) end
    for bytes in data_bytes.values() do
      buffer.append(bytes)
    end

    // trim first 4 bytes that are for size of tcp header
    buffer.trim_in_place(4)

    match ChannelMsgDecoder(consume buffer, auth)
    | let r: DataMsg =>
      r
    else
      @printf[I32]("Trouble reconstituting replayed data msg\n".cstring())
      error
    end


trait val DeliveryMsg is ChannelMsg
  fun target_id(): StepId
  fun sender_name(): String
  fun deliver(pipeline_time_spent: U64, target_step: Consumer,
    producer: Producer, seq_id: SeqId, route_id: RouteId, latest_ts: U64,
    metrics_id: U16, worker_ingress_ts: U64): Bool

trait val ReplayableDeliveryMsg is DeliveryMsg
  fun replay_deliver(pipeline_time_spent: U64, target_step: Consumer,
    producer: Producer, seq_id: SeqId, route_id: RouteId, latest_ts: U64,
    metrics_id: U16, worker_ingress_ts: U64): Bool
  fun input(): Any val
  fun metric_name(): String
  fun msg_uid(): U128

class val ForwardMsg[D: Any val] is ReplayableDeliveryMsg
  let _target_id: StepId
  let _sender_name: String
  let _data: D
  let _metric_name: String
  let _proxy_address: ProxyAddress
  let _msg_uid: MsgId
  let _frac_ids: FractionalMessageId

  fun input(): Any val => _data
  fun metric_name(): String => _metric_name
  fun msg_uid(): U128 => _msg_uid
  fun frac_ids(): FractionalMessageId => _frac_ids

  new val create(t_id: StepId, from: String,
    m_data: D, m_name: String, proxy_address: ProxyAddress,
    msg_uid': U128, frac_ids': FractionalMessageId)
  =>
    _target_id = t_id
    _sender_name = from
    _data = m_data
    _metric_name = m_name
    _proxy_address = proxy_address
    _msg_uid = msg_uid'
    _frac_ids = frac_ids'

  fun target_id(): StepId => _target_id
  fun sender_name(): String => _sender_name

  fun deliver(pipeline_time_spent: U64, target_step: Consumer,
    producer: Producer, seq_id: SeqId, route_id: RouteId, latest_ts: U64,
    metrics_id: U16, worker_ingress_ts: U64): Bool
  =>
    target_step.run[D](_metric_name, pipeline_time_spent, _data, producer,
      _msg_uid, _frac_ids, seq_id, route_id, latest_ts, metrics_id,
      worker_ingress_ts)
    false

  fun replay_deliver(pipeline_time_spent: U64, target_step: Consumer,
    producer: Producer, seq_id: SeqId, route_id: RouteId, latest_ts: U64,
    metrics_id: U16, worker_ingress_ts: U64): Bool
  =>
    target_step.replay_run[D](_metric_name, pipeline_time_spent, _data, producer,
      _msg_uid, _frac_ids, seq_id, route_id, latest_ts, metrics_id,
      worker_ingress_ts)
    false

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
  This message is sent as a response to a JoinCluster message. Currently it
  only informs the new worker of metrics-related info
  """
  let sender_name: String
  let local_topology: LocalTopology
  let metrics_app_name: String
  let metrics_host: String
  let metrics_service: String
  let control_addrs: Map[String, (String, String)] val
  let data_addrs: Map[String, (String, String)] val
  let worker_names: Array[String] val
  let partition_router_blueprints: Map[String, PartitionRouterBlueprint] val
  let stateless_partition_router_blueprints:
    Map[U128, StatelessPartitionRouterBlueprint] val
  let omni_router_blueprint: OmniRouterBlueprint

  new val create(sender: String, app: String, l_topology: LocalTopology,
    m_host: String, m_service: String,
    c_addrs: Map[String, (String, String)] val,
    d_addrs: Map[String, (String, String)] val,
    w_names: Array[String] val,
    p_blueprints: Map[String, PartitionRouterBlueprint] val,
    stateless_p_blueprints: Map[U128, StatelessPartitionRouterBlueprint] val,
    omr_blueprint: OmniRouterBlueprint)
  =>
    sender_name = sender
    local_topology = l_topology
    metrics_app_name = app
    metrics_host = m_host
    metrics_service = m_service
    control_addrs = c_addrs
    data_addrs = d_addrs
    worker_names = w_names
    partition_router_blueprints = p_blueprints
    stateless_partition_router_blueprints = stateless_p_blueprints
    omni_router_blueprint = omr_blueprint

class val InformJoinErrorMsg is ChannelMsg
  let message: String

  new val create(m: String) =>
    message = m

primitive InformRecoverNotJoinMsg is ChannelMsg

// TODO: Don't send host over since we need to determine that on receipt
class val JoiningWorkerInitializedMsg is ChannelMsg
  let worker_name: String
  let control_addr: (String, String)
  let data_addr: (String, String)

  new val create(name: String, c_addr: (String, String),
    d_addr: (String, String))
  =>
    worker_name = name
    control_addr = c_addr
    data_addr = d_addr

class val InitiateJoinMigrationMsg is ChannelMsg
  let new_workers: Array[String] val

  new val create(ws: Array[String] val) =>
    new_workers = ws

class val LeavingWorkerDoneMigratingMsg is ChannelMsg
  let worker_name: String

  new val create(name: String)
  =>
    worker_name = name

trait val AnnounceNewStatefulStepMsg is ChannelMsg
  fun update_registry(r: RouterRegistry)

class val KeyedAnnounceNewStatefulStepMsg[
  K: (Hashable val & Equatable[K] val)] is AnnounceNewStatefulStepMsg
  """
  This message is sent to notify another worker that a new stateful step has
  been created on this worker and that partition routers should be updated.
  """
  let _step_id: StepId
  let _worker_name: String
  let _key: K
  let _state_name: String

  new val create(id: U128, worker: String, k: K, s_name: String) =>
    _step_id = id
    _worker_name = worker
    _key = k
    _state_name = s_name

  fun update_registry(r: RouterRegistry) =>
    r.add_state_proxy[K](_step_id, ProxyAddress(_worker_name, _step_id), _key,
      _state_name)

primitive RotateLogFilesMsg is ChannelMsg
  """
  This message is sent to a worker instructing it to rotate its log files.
  """

class val CleanShutdownMsg is ChannelMsg
  let msg: String

  new val create(m: String) =>
    msg = m
