use "buffered"
use "serialise"
use "net"
use "collections"
use "wallaroo/boundary"
use "wallaroo/broadcast"
use "wallaroo/initialization"
use "wallaroo/routing"
use "wallaroo/topology"
use "wallaroo/w_actor"

primitive ChannelMsgEncoder
  fun _encode(msg: ChannelMsg val, auth: AmbientAuth,
    wb: Writer = Writer): Array[ByteSeq] val ?
  =>
    let serialised: Array[U8] val =
      Serialised(SerialiseAuth(auth), msg).output(OutputSerialisedAuth(auth))
    let size = serialised.size()
    if size > 0 then
      wb.u32_be(size.u32())
      wb.write(serialised)
    end
    wb.done()

  fun data_channel(delivery_msg: ReplayableDeliveryMsg val,
    pipeline_time_spent: U64, seq_id: SeqId, wb: Writer, auth: AmbientAuth,
    latest_ts: U64, metrics_id: U16, metric_name: String): Array[ByteSeq] val ?
  =>
    _encode(DataMsg(delivery_msg, pipeline_time_spent, seq_id, latest_ts,
      metrics_id, metric_name), auth, wb)

  fun data_channel_actor(delivery_msg: ActorDeliveryMsg val, seq_id: SeqId,
    wb: Writer, auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(ActorDataMsg(delivery_msg, seq_id), auth, wb)

  fun migrate_step[K: (Hashable val & Equatable[K] val)](step_id: U128,
    state_name: String, key: K, state: ByteSeq val, worker: String,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(KeyedStepMigrationMsg[K](step_id, state_name, key, state, worker),
      auth)

  fun migration_batch_complete(sender: String,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    """
    Sent to signal to joining worker that a batch of steps has finished
    emigrating from this step.
    """
    _encode(MigrationBatchCompleteMsg(sender), auth)

  fun ack_migration_batch_complete(worker: String,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    """
    Sent to ack that a batch of steps has finished immigrating to this step
    """
    _encode(AckMigrationBatchCompleteMsg(worker), auth)

  fun step_migration_complete(step_id: U128,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    """
    Sent when the migration of step step_id is complete
    """
    _encode(StepMigrationCompleteMsg(step_id), auth)

  fun mute_request(originating_worker: String, auth: AmbientAuth): Array[ByteSeq] val ? =>
    _encode(MuteRequestMsg(originating_worker), auth)

  fun unmute_request(originating_worker: String, auth: AmbientAuth): Array[ByteSeq] val ? =>
    _encode(UnmuteRequestMsg(originating_worker), auth)

  fun delivery[D: Any val](target_id: U128,
    from_worker_name: String, msg_data: D,
    metric_name: String, auth: AmbientAuth,
    proxy_address: ProxyAddress val, msg_uid: U128,
    frac_ids: None): Array[ByteSeq] val ?
  =>
    _encode(ForwardMsg[D](target_id, from_worker_name,
      msg_data, metric_name, proxy_address, msg_uid, frac_ids), auth)

  fun identify_control_port(worker_name: String, service: String,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(IdentifyControlPortMsg(worker_name, service), auth)

  fun identify_data_port(worker_name: String, service: String,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(IdentifyDataPortMsg(worker_name, service), auth)

  fun reconnect_data_port(worker_name: String,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(ReconnectDataPortMsg(worker_name), auth)

  fun spin_up_local_topology(local_topology: LocalTopology val,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(SpinUpLocalTopologyMsg(local_topology), auth)

  fun spin_up_local_actor_system(local_actor_system: LocalActorSystem val,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(SpinUpLocalActorSystemMsg(local_actor_system), auth)

  fun spin_up_step(step_id: U64, step_builder: StepBuilder val,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(SpinUpStepMsg(step_id, step_builder), auth)

  fun topology_ready(worker_name: String, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    _encode(TopologyReadyMsg(worker_name), auth)

  fun create_connections(
    c_addrs: Map[String, (String, String)] val,
    d_addrs: Map[String, (String, String)] val,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(CreateConnectionsMsg(c_addrs, d_addrs), auth)

  fun connections_ready(worker_name: String, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    _encode(ConnectionsReadyMsg(worker_name), auth)

  fun create_data_channel_listener(workers: Array[String] val,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(CreateDataChannelListener(workers), auth)

  fun data_connect(sender_name: String, sender_step_id: U128,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(DataConnectMsg(sender_name, sender_step_id), auth)

  fun ack_data_connect(last_id_seen: SeqId, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    _encode(AckDataConnectMsg(last_id_seen), auth)

  fun start_normal_data_sending(auth: AmbientAuth): Array[ByteSeq] val ? =>
    _encode(StartNormalDataSendingMsg, auth)

  fun replay_complete(sender_name: String, boundary_id: U128,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(ReplayCompleteMsg(sender_name, boundary_id), auth)

  fun ack_watermark(sender_name: String, sender_step_id: U128, seq_id: SeqId,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(AckWatermarkMsg(sender_name, sender_step_id, seq_id), auth)

  fun replay(delivery_bytes: Array[ByteSeq] val, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    _encode(ReplayMsg(delivery_bytes), auth)

  fun join_cluster(worker_name: String, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    """
    This message is sent from a worker requesting to join a running cluster to
    any existing worker in the cluster.
    """
    _encode(JoinClusterMsg(worker_name), auth)

  // TODO: Update this once new workers become first class citizens
  fun inform_joining_worker(worker_name: String, metric_app_name: String,
    l_topology: LocalTopology val, metric_host: String,
    metric_service: String, control_addrs: Map[String, (String, String)] val,
    data_addrs: Map[String, (String, String)] val,
    worker_names: Array[String] val, auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    """
    This message is sent as a response to a JoinCluster message. Currently it
    only informs the new worker of metrics-related info
    """
    _encode(InformJoiningWorkerMsg(worker_name, metric_app_name, l_topology,
      metric_host, metric_service, control_addrs, data_addrs, worker_names),
      auth)

  fun joining_worker_initialized(worker_name: String, c_addr: (String, String),
    d_addr: (String, String), auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(JoiningWorkerInitializedMsg(worker_name, c_addr, d_addr), auth)

  fun request_boundary_count(sender: String, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    _encode(RequestBoundaryCountMsg(sender), auth)

  fun replay_boundary_count(sender: String, count: USize, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    _encode(ReplayBoundaryCountMsg(sender, count), auth)

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
      state_name), auth)

  fun register_actor_for_worker(id: U128, worker: String,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(RegisterActorForWorkerMsg(id, worker), auth)

  fun register_as_role(role: String, w_actor: U128, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    _encode(RegisterAsRoleMsg(role, w_actor), auth)

  fun forget_actor(id: U128, auth: AmbientAuth): Array[ByteSeq] val ? =>
    _encode(ForgetActorMsg(id), auth)

  fun broadcast_to_role(role: String, data: Any val, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    _encode(BroadcastToRoleMsg(role, data), auth)

  fun broadcast_to_actors(data: Any val, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    _encode(BroadcastToActorsMsg(data), auth)

  fun broadcast_variable(k: String, v: Any val, ts: VectorTimestamp,
    worker: String, auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(BroadcastVariableMsg(k, v, ts, worker), auth)

  fun request_w_actor_registry_digest(sender: String, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    _encode(RequestWActorRegistryDigestMsg(sender), auth)

  fun w_actor_registry_digest(digest: WActorRegistryDigest, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    _encode(WActorRegistryDigestMsg(digest), auth)

primitive ChannelMsgDecoder
  fun apply(data: Array[U8] val, auth: AmbientAuth): ChannelMsg val =>
    try
      match Serialised.input(InputSerialisedAuth(auth), data)(
        DeserialiseAuth(auth))
      | let m: ChannelMsg val =>
        m
      else
        UnknownChannelMsg(data)
      end
    else
      UnknownChannelMsg(data)
    end

trait val ChannelMsg

class UnknownChannelMsg is ChannelMsg
  let data: Array[U8] val

  new val create(d: Array[U8] val) =>
    data = d

class IdentifyControlPortMsg is ChannelMsg
  let worker_name: String
  let service: String

  new val create(name: String, s: String) =>
    worker_name = name
    service = s

class IdentifyDataPortMsg is ChannelMsg
  let worker_name: String
  let service: String

  new val create(name: String, s: String) =>
    worker_name = name
    service = s

class ReconnectDataPortMsg is ChannelMsg
  let worker_name: String

  new val create(name: String) =>
    worker_name = name

class SpinUpLocalTopologyMsg is ChannelMsg
  let local_topology: LocalTopology val

  new val create(lt: LocalTopology val) =>
    local_topology = lt

class SpinUpLocalActorSystemMsg is ChannelMsg
  let local_actor_system: LocalActorSystem val

  new val create(las: LocalActorSystem val) =>
    local_actor_system = las

class SpinUpStepMsg is ChannelMsg
  let step_id: U64
  let step_builder: StepBuilder val

  new val create(s_id: U64, s_builder: StepBuilder val) =>
    step_id = s_id
    step_builder = s_builder

class TopologyReadyMsg is ChannelMsg
  let worker_name: String

  new val create(name: String) =>
    worker_name = name

class CreateConnectionsMsg is ChannelMsg
  let control_addrs: Map[String, (String, String)] val
  let data_addrs: Map[String, (String, String)] val

  new val create(c_addrs: Map[String, (String, String)] val,
    d_addrs: Map[String, (String, String)] val)
  =>
    control_addrs = c_addrs
    data_addrs = d_addrs

class ConnectionsReadyMsg is ChannelMsg
  let worker_name: String

  new val create(name: String) =>
    worker_name = name

class CreateDataChannelListener is ChannelMsg
  let workers: Array[String] val

  new val create(ws: Array[String] val) =>
    workers = ws

class DataConnectMsg is ChannelMsg
  let sender_name: String
  let sender_boundary_id: U128

  new val create(sender_name': String, sender_boundary_id': U128) =>
    sender_name = sender_name'
    sender_boundary_id = sender_boundary_id'

class AckDataConnectMsg is ChannelMsg
  let last_id_seen: SeqId

  new val create(last_id_seen': SeqId) =>
    last_id_seen = last_id_seen'

primitive StartNormalDataSendingMsg is ChannelMsg

class RequestBoundaryCountMsg is ChannelMsg
  let sender_name: String

  new val create(from: String) =>
    sender_name = from

class ReplayBoundaryCountMsg is ChannelMsg
  let sender_name: String
  let boundary_count: USize

  new val create(from: String, count: USize) =>
    sender_name = from
    boundary_count = count

class ReplayCompleteMsg is ChannelMsg
  let sender_name: String
  let boundary_id: U128

  new val create(from: String, b_id: U128) =>
    sender_name = from
    boundary_id = b_id

class val RegisterActorForWorkerMsg is ChannelMsg
  let id: U128
  let worker: String

  new val create(i: U128, w: String) =>
    id = i
    worker = w

class val ForgetActorMsg is ChannelMsg
  let id: U128

  new val create(i: U128) =>
    id = i

class val RegisterAsRoleMsg is ChannelMsg
  let role: String
  let id: U128

  new val create(role': String, id': U128) =>
    role = role'
    id = id'

class val BroadcastToRoleMsg is ChannelMsg
  let role: String
  let data: Any val

  new val create(role': String, data': Any val) =>
    role = role'
    data = data'

class val BroadcastToActorsMsg is ChannelMsg
  let data: Any val

  new val create(data': Any val) =>
    data = data'

class val WActorRegistryDigestMsg is ChannelMsg
  let digest: WActorRegistryDigest

  new val create(digest': WActorRegistryDigest) =>
    digest = digest'

class val RequestWActorRegistryDigestMsg is ChannelMsg
  let sender: String

  new val create(sender': String) =>
    sender = sender'

trait StepMigrationMsg is ChannelMsg
  fun state_name(): String
  fun step_id(): U128
  fun state(): ByteSeq val
  fun worker(): String
  fun update_router_registry(router_registry: RouterRegistry,
    target: ConsumerStep)

class KeyedStepMigrationMsg[K: (Hashable val & Equatable[K] val)] is
  StepMigrationMsg
  let _state_name: String
  let _key: K
  let _step_id: U128
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
  fun update_router_registry(router_registry: RouterRegistry,
    target: ConsumerStep)
  =>
    router_registry.move_proxy_to_stateful_step[K](_step_id, target, _key,
      _state_name, _worker)

class MigrationBatchCompleteMsg is ChannelMsg
  let sender_name: String

  new val create(sender: String) =>
    sender_name = sender

class AckMigrationBatchCompleteMsg is ChannelMsg
  let sender_name: String

  new val create(sender: String) =>
    sender_name = sender

class MuteRequestMsg is ChannelMsg
  let originating_worker: String
  new val create(worker: String) =>
    originating_worker = worker

class UnmuteRequestMsg is ChannelMsg
  let originating_worker: String
  new val create(worker: String) =>
    originating_worker = worker

class StepMigrationCompleteMsg is ChannelMsg
  let step_id: U128
  new val create(step_id': U128)
  =>
    step_id = step_id'

class AckWatermarkMsg is ChannelMsg
  let sender_name: String
  let sender_step_id: U128
  let seq_id: SeqId

  new val create(sender_name': String, sender_step_id': U128,
    seq_id': SeqId)
  =>
    sender_name = sender_name'
    sender_step_id = sender_step_id'
    seq_id = seq_id'

class DataMsg is ChannelMsg
  let pipeline_time_spent: U64
  let seq_id: SeqId
  let delivery_msg: ReplayableDeliveryMsg val
  let latest_ts: U64
  let metrics_id: U16
  let metric_name: String

  new val create(msg: ReplayableDeliveryMsg val, pipeline_time_spent': U64,
    seq_id': SeqId, latest_ts': U64, metrics_id': U16, metric_name': String)
  =>
    seq_id = seq_id'
    pipeline_time_spent = pipeline_time_spent'
    delivery_msg = msg
    latest_ts = latest_ts'
    metrics_id = metrics_id'
    metric_name = metric_name'

class ActorDataMsg is ChannelMsg
  let seq_id: SeqId
  let delivery_msg: ActorDeliveryMsg val

  new val create(msg: ActorDeliveryMsg val, seq_id': SeqId) =>
    seq_id = seq_id'
    delivery_msg = msg

class val BroadcastVariableMsg is ChannelMsg
  let k: String
  let v: Any val
  let ts: VectorTimestamp
  let worker: String

  new val create(k': String, v': Any val, ts': VectorTimestamp,
    worker': String)
  =>
    k = k'
    v = v'
    ts = ts'
    worker = worker'

class ReplayMsg is ChannelMsg
  let data_bytes: Array[ByteSeq] val

  new val create(db: Array[ByteSeq] val) =>
    data_bytes = db

  fun data_msg(auth: AmbientAuth): (DataMsg val | ActorDataMsg val) ? =>
    var size: USize = 0
    for bytes in data_bytes.values() do
      size = size + bytes.size()
    end

    let buffer: Array[U8] trn = recover Array[U8](size) end
    for bytes in data_bytes.values() do
      buffer.append(bytes)
    end

    // trim first 4 bytes that are for size of tcp header
    buffer.trim_in_place(4)

    match ChannelMsgDecoder(consume buffer, auth)
    | let r: DataMsg val =>
      r
    | let a: ActorDataMsg val =>
      a
    else
      @printf[I32]("Trouble reconstituting replayed data msg\n".cstring())
      error
    end


trait DeliveryMsg is ChannelMsg
  fun target_id(): U128
  fun sender_name(): String
  fun deliver(pipeline_time_spent: U64, target_step: RunnableStep tag,
    origin: Producer, seq_id: SeqId, route_id: RouteId, latest_ts: U64,
    metrics_id: U16, worker_ingress_ts: U64): Bool

trait ReplayableDeliveryMsg is DeliveryMsg
  fun replay_deliver(pipeline_time_spent: U64, target_step: RunnableStep tag,
    origin: Producer, seq_id: SeqId, route_id: RouteId, latest_ts: U64,
    metrics_id: U16, worker_ingress_ts: U64): Bool
  fun input(): Any val
  fun metric_name(): String
  fun msg_uid(): U128
  fun frac_ids(): None => None

class ForwardMsg[D: Any val] is ReplayableDeliveryMsg
  let _target_id: U128
  let _sender_name: String
  let _data: D
  let _metric_name: String
  let _proxy_address: ProxyAddress val
  let _msg_uid: U128
  let _frac_ids: None

  fun input(): Any val => _data
  fun metric_name(): String => _metric_name
  fun msg_uid(): U128 => _msg_uid

  new val create(t_id: U128, from: String,
    m_data: D, m_name: String, proxy_address: ProxyAddress val, msg_uid': U128,
    frac_ids': None)
  =>
    _target_id = t_id
    _sender_name = from
    _data = m_data
    _metric_name = m_name
    _proxy_address = proxy_address
    _msg_uid = msg_uid'
    _frac_ids = frac_ids'

  fun target_id(): U128 => _target_id
  fun sender_name(): String => _sender_name

  fun deliver(pipeline_time_spent: U64, target_step: RunnableStep tag,
    origin: Producer, seq_id: SeqId, route_id: RouteId, latest_ts: U64,
    metrics_id: U16, worker_ingress_ts: U64): Bool
  =>
    target_step.run[D](_metric_name, pipeline_time_spent, _data, origin,
      _msg_uid, _frac_ids, seq_id, route_id, latest_ts, metrics_id,
      worker_ingress_ts)
    false

  fun replay_deliver(pipeline_time_spent: U64, target_step: RunnableStep tag,
    origin: Producer, seq_id: SeqId, route_id: RouteId, latest_ts: U64,
    metrics_id: U16, worker_ingress_ts: U64): Bool
  =>
    target_step.replay_run[D](_metric_name, pipeline_time_spent, _data, origin,
      _msg_uid, _frac_ids, seq_id, route_id, latest_ts, metrics_id,
      worker_ingress_ts)
    false

class val ActorDeliveryMsg is ChannelMsg
  let _sender_name: String
  let _target_id: U128
  let _sender_id: (U128 | None)
  let _data: Any val

  fun input(): Any val => _data

  new val create(from: String, t_id: U128, m_data: Any val,
    sender_id: (U128 | None) = None)
  =>
    _target_id = t_id
    _sender_name = from
    _sender_id = sender_id
    _data = m_data

  fun target_id(): U128 => _target_id
  fun sender_name(): String => _sender_name

  fun deliver(registry: CentralWActorRegistry): Bool
  =>
    match _sender_id
    | let id: U128 =>
      registry.send_to(_target_id, WMessage(id, _target_id, _data))
    else
      registry.send_for_process(_target_id, _data)
    end
    false

class JoinClusterMsg is ChannelMsg
  """
  This message is sent from a worker requesting to join a running cluster to
  any existing worker in the cluster.
  """
  let worker_name: String

  new val create(w: String) =>
    worker_name = w

class InformJoiningWorkerMsg is ChannelMsg
  """
  This message is sent as a response to a JoinCluster message. Currently it
  only informs the new worker of metrics-related info
  """
  let sender_name: String
  let local_topology: LocalTopology val
  let metrics_app_name: String
  let metrics_host: String
  let metrics_service: String
  let control_addrs: Map[String, (String, String)] val
  let data_addrs: Map[String, (String, String)] val
  let worker_names: Array[String] val

  new val create(sender: String, app: String, l_topology: LocalTopology val,
    m_host: String, m_service: String,
    c_addrs: Map[String, (String, String)] val,
    d_addrs: Map[String, (String, String)] val,
    w_names: Array[String] val)
  =>
    sender_name = sender
    local_topology = l_topology
    metrics_app_name = app
    metrics_host = m_host
    metrics_service = m_service
    control_addrs = c_addrs
    data_addrs = d_addrs
    worker_names = w_names

// TODO: Don't send host over since we need to determine that on receipt
class JoiningWorkerInitializedMsg is ChannelMsg
  let worker_name: String
  let control_addr: (String, String)
  let data_addr: (String, String)

  new val create(name: String, c_addr: (String, String),
    d_addr: (String, String))
  =>
    worker_name = name
    control_addr = c_addr
    data_addr = d_addr

trait AnnounceNewStatefulStepMsg is ChannelMsg
  fun update_registry(r: RouterRegistry)

class KeyedAnnounceNewStatefulStepMsg[K: (Hashable val & Equatable[K] val)] is
  AnnounceNewStatefulStepMsg
  """
  This message is sent to notify another worker that a new stateful step has
  been created on this worker and that partition routers should be updated.
  """
  let _step_id: U128
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
