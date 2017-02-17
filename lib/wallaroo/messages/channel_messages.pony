use "buffered"
use "serialise"
use "net"
use "collections"
use "wallaroo/boundary"
use "wallaroo/initialization"
use "wallaroo/routing"
use "wallaroo/topology"

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
    pipeline_time_spent: U64, seq_id: U64, wb: Writer, auth: AmbientAuth,
    latest_ts: U64, metrics_id: U16, metric_name: String): Array[ByteSeq] val ?
  =>
    _encode(DataMsg(delivery_msg, pipeline_time_spent, seq_id, latest_ts,
      metrics_id, metric_name), auth, wb)

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

  fun spin_up_step(step_id: U64, step_builder: StepBuilder val,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(SpinUpStepMsg(step_id, step_builder), auth)

  fun topology_ready(worker_name: String, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    _encode(TopologyReadyMsg(worker_name), auth)

  fun create_connections(
    addresses: Map[String, Map[String, (String, String)]] val,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(CreateConnectionsMsg(addresses), auth)

  fun connections_ready(worker_name: String, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    _encode(ConnectionsReadyMsg(worker_name), auth)

  fun create_data_receivers(workers: Array[String] val, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    _encode(CreateDataReceivers(workers), auth)

  fun data_connect(sender_name: String, sender_step_id: U128,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(DataConnectMsg(sender_name, sender_step_id), auth)

  fun request_replay(sender_name: String, target_id: U128, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    _encode(RequestReplayMsg(sender_name, target_id), auth)

  fun replay_complete(sender_name: String, auth: AmbientAuth):
    Array[ByteSeq] val ?
  =>
    _encode(ReplayCompleteMsg(sender_name), auth)

  fun ack_watermark(sender_name: String, sender_step_id: U128, seq_id: U64,
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
  fun inform_joining_worker(metric_app_name: String, metric_host: String,
    metric_service: String, auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    """
    This message is sent as a response to a JoinCluster message. Currently it
    only informs the new worker of metrics-related info
    """
    _encode(InformJoiningWorkerMsg(metric_app_name, metric_host, metric_service), auth)

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
  let addresses: Map[String, Map[String, (String, String)]] val

  new val create(addrs: Map[String, Map[String, (String, String)]] val) =>
    addresses = addrs

class ConnectionsReadyMsg is ChannelMsg
  let worker_name: String

  new val create(name: String) =>
    worker_name = name

class CreateDataReceivers is ChannelMsg
  let workers: Array[String] val

  new val create(ws: Array[String] val) =>
    workers = ws

class DataConnectMsg is ChannelMsg
  let sender_name: String
  let sender_step_id: U128

  new val create(sender_name': String, sender_step_id': U128) =>
    sender_name = sender_name'
    sender_step_id = sender_step_id'

class ReplayCompleteMsg is ChannelMsg
  let _sender_name: String

  new val create(from: String) =>
    _sender_name = from

  fun sender_name(): String => _sender_name

class AckWatermarkMsg is ChannelMsg
  let sender_name: String
  let sender_step_id: U128
  let seq_id: U64

  new val create(sender_name': String, sender_step_id': U128, seq_id': U64) =>
    sender_name = sender_name'
    sender_step_id = sender_step_id'
    seq_id = seq_id'

class DataMsg is ChannelMsg
  let pipeline_time_spent: U64
  let seq_id: U64
  let delivery_msg: ReplayableDeliveryMsg val
  let latest_ts: U64
  let metrics_id: U16
  let metric_name: String

  new val create(msg: ReplayableDeliveryMsg val, pipeline_time_spent': U64,
    seq_id': U64, latest_ts': U64, metrics_id': U16, metric_name': String)
  =>
    seq_id = seq_id'
    pipeline_time_spent = pipeline_time_spent'
    delivery_msg = msg
    latest_ts = latest_ts'
    metrics_id = metrics_id'
    metric_name = metric_name'

class ReplayMsg is ChannelMsg
  let data_bytes: Array[ByteSeq] val

  new val create(db: Array[ByteSeq] val) =>
    data_bytes = db

  fun data_msg(auth: AmbientAuth): DataMsg val ? =>
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

class RequestReplayMsg is DeliveryMsg
  let _sender_name: String
  let _target_id: U128

  new val create(sender_name': String, target_id': U128) =>
    _sender_name = sender_name'
    _target_id = target_id'

  fun target_id(): U128 => _target_id
  fun sender_name(): String => _sender_name

  fun deliver(pipeline_time_spent: U64, target_step: RunnableStep tag, origin: Producer,
    seq_id: SeqId = 0, route_id: RouteId = 0, latest_ts: U64 = 0,
    metrics_id: U16 = 0, worker_ingress_ts: U64): Bool
  =>
    match target_step
    | let ob: OutgoingBoundary =>
      ob.replay_msgs()
    else
      @printf[I32]("RequestReplayMsg was not directed to an OutgoingBoundary!\n".cstring())
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
  let metrics_app_name: String
  let metrics_host: String
  let metrics_service: String

  new val create(app: String, host: String, service: String) =>
    metrics_app_name = app
    metrics_host = host
    metrics_service = service

