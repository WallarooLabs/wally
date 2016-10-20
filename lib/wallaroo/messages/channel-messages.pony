use "buffered"
use "serialise"
use "net"
use "collections"
use "wallaroo/backpressure"
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

  fun data_channel[D: Any val](target_id: U128, ack_id: U64, 
    from_worker_name: String, source_ts: U64, msg_data: D,
    metric_name: String, auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(ForwardMsg[D](target_id, ack_id, from_worker_name, source_ts, 
      msg_data, metric_name), auth)

  fun identify_control_port(worker_name: String, service: String,
    auth: AmbientAuth): Array[ByteSeq] val ? 
  =>
    _encode(IdentifyControlPortMsg(worker_name, service), auth)

  fun identify_data_port(worker_name: String, service: String,
    auth: AmbientAuth): Array[ByteSeq] val ? 
  =>
    _encode(IdentifyDataPortMsg(worker_name, service), auth)

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

primitive ChannelMsgDecoder
  fun apply(data: Array[U8] val, auth: AmbientAuth): ChannelMsg val =>
    try
      match Serialised.input(InputSerialisedAuth(auth), data)(
        DeserialiseAuth(auth))
      | let m: ChannelMsg val => m
      else
        UnknownChannelMsg(data)
      end
    else
      UnknownChannelMsg(data)
    end

trait val ChannelMsg
  // fun ack_id(): U64
  // fun from_name(): String
  // fun deliver(data_receiver: DataReceiver)

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

trait DeliveryMsg is ChannelMsg
  fun target_id(): U128
  fun ack_id(): U64
  fun source_ts(): U64
  fun metric_name(): String
  fun from_name(): String
  fun deliver(target_step: Step tag): Bool

class ForwardMsg[D: Any val] is DeliveryMsg
  let _target_id: U128
  let _ack_id: U64
  let _from_worker_name: String
  let _source_ts: U64
  let _data: D
  let _metric_name: String

  new val create(t_id: U128, a_id: U64, from: String, s_ts: U64, 
    m_data: D, m_name: String) 
  =>
    _target_id = t_id
    _ack_id = a_id
    _from_worker_name = from
    _source_ts = s_ts
    _data = m_data
    _metric_name = m_name

  fun target_id(): U128 => _target_id
  fun ack_id(): U64 => _ack_id
  fun from_name(): String => _from_worker_name
  fun source_ts(): U64 => _source_ts
  fun metric_name(): String => _metric_name

  fun deliver(target_step: Step tag): Bool =>//data_receiver: DataReceiver) =>
    target_step.run[D](_metric_name, _source_ts, _data)
    false
    // data_receiver.received[D](_data_ch_id, _step_id, _msg_id, _source_ts,
      // _ingress_ts, _data, step_manager)