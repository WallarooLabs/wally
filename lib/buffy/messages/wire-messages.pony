use "sendence/bytes"
use "buffy/network"
use "buffy/topology"
use "serialise"
use "net"

primitive WireMsgEncoder
  fun _encode(msg: WireMsg val, auth: AmbientAuth): Array[ByteSeq] val ? =>
    let wb = WriteBuffer
    let serialised: Array[U8] val =
      Serialised(SerialiseAuth(auth), msg).output(OutputSerialisedAuth(auth))
    let size = serialised.size()
    if size > 0 then
      wb.u32_be(size.u32())
      wb.write(serialised)
    end
    wb.done()

  fun ready(node_name: String, auth: AmbientAuth): Array[ByteSeq] val ? =>
    _encode(ReadyMsg(node_name), auth)

  fun topology_ready(node_name: String, auth: AmbientAuth): Array[ByteSeq] val ? =>
    _encode(TopologyReadyMsg(node_name), auth)

  fun identify_control_port(node_name: String, service: String,
    auth: AmbientAuth): Array[ByteSeq] val ? =>
    _encode(IdentifyControlPortMsg(node_name, service), auth)

  fun identify_data_port(node_name: String, service: String,
    auth: AmbientAuth): Array[ByteSeq] val ? =>
    _encode(IdentifyDataPortMsg(node_name, service), auth)

  fun add_control(node_name: String, host: String, service: String,
    auth: AmbientAuth): Array[ByteSeq] val ? =>
    _encode(AddControlMsg(node_name, host, service), auth)

  fun add_data(node_name: String, host: String, service: String,
    auth: AmbientAuth): Array[ByteSeq] val ? =>
    _encode(AddDataMsg(node_name, host, service), auth)

  fun done(node_name: String, auth: AmbientAuth): Array[ByteSeq] val ? =>
    _encode(DoneMsg(node_name), auth)

  fun reconnect(node_name: String, auth: AmbientAuth): Array[ByteSeq] val ? =>
    _encode(ReconnectMsg(node_name), auth)

  fun start(auth: AmbientAuth): Array[ByteSeq] val ? =>
    _encode(StartMsg, auth)

  fun shutdown(node_name: String, auth: AmbientAuth): Array[ByteSeq] val ? =>
    _encode(ShutdownMsg(node_name), auth)

  fun done_shutdown(node_name: String, auth: AmbientAuth): Array[ByteSeq] val ? =>
    _encode(DoneShutdownMsg(node_name), auth)

  fun spin_up(step_id: U64, step_builder: BasicStepBuilder val, auth: AmbientAuth)
    : Array[ByteSeq] val ? =>
    _encode(SpinUpMsg(step_id, step_builder), auth)

  fun spin_up_state_step(step_id: U64, step_builder: BasicStateStepBuilder val,
    shared_state_step_id: U64, shared_state_step_node: String, auth: AmbientAuth)
    : Array[ByteSeq] val ? =>
    _encode(SpinUpStateStepMsg(step_id, step_builder, shared_state_step_id,
      shared_state_step_node), auth)

  fun spin_up_proxy(proxy_id: U64, step_id: U64, target_node_name: String
    , auth: AmbientAuth): Array[ByteSeq] val ? =>
    _encode(SpinUpProxyMsg(proxy_id, step_id, target_node_name), auth)

  fun spin_up_sink(sink_ids: Array[U64] iso, sink_step_id: U64, sink_builder: SinkBuilder val,
    auth: AmbientAuth)
    : Array[ByteSeq] val ? =>
    _encode(SpinUpSinkMsg(consume sink_ids, sink_step_id, sink_builder), auth)

  fun connect_steps(from_step_id: U64, to_step_id: U64, auth: AmbientAuth)
    : Array[ByteSeq] val ? =>
    _encode(ConnectStepsMsg(from_step_id, to_step_id), auth)

  fun initialization_msgs_finished(node_name: String, auth: AmbientAuth)
    : Array[ByteSeq] val ? =>
    _encode(InitializationMsgsFinishedMsg(node_name), auth)

  fun ack_initialized(node_name: String, auth: AmbientAuth): Array[ByteSeq] val ? =>
    _encode(AckInitializedMsg(node_name), auth)

  fun ack_message_id(node_name: String, msg_id: U64,
    auth: AmbientAuth): Array[ByteSeq] val ? =>
    _encode(AckMsgIdMsg(node_name, msg_id), auth)
 
  fun reconnect_data(node_name: String, auth: AmbientAuth): Array[ByteSeq] val ? =>
    _encode(ReconnectDataMsg(node_name), auth)

  fun data_sender_ready(node_name: String, auth: AmbientAuth)
    : Array[ByteSeq] val ? =>
    _encode(DataSenderReadyMsg(node_name), auth)

  fun data_receiver_ready(node_name: String, auth: AmbientAuth)
    : Array[ByteSeq] val ? =>
    _encode(DataReceiverReadyMsg(node_name), auth)

  fun control_sender_ready(node_name: String, auth: AmbientAuth)
    : Array[ByteSeq] val ? =>
    _encode(ControlSenderReadyMsg(node_name), auth)

  fun finished_connections(node_name: String, auth: AmbientAuth)
    : Array[ByteSeq] val ? =>
    _encode(FinishedConnectionsMsg(node_name), auth)

  fun ack_finished_connections(node_name: String, auth: AmbientAuth)
    : Array[ByteSeq] val ? =>
    _encode(AckFinishedConnectionsMsg(node_name), auth)

  fun ack_connect_message_id(node_name: String, msg_id: U64,
    auth: AmbientAuth): Array[ByteSeq] val ? =>
    _encode(AckConnectMsgIdMsg(node_name, msg_id), auth)

  fun data_channel[D: Any val](data_ch_id: U64, step_id: U64, 
    from_node_name: String, msg_id: U64, source_ts: U64, ingress_ts: U64,
    msg_data: D, auth: AmbientAuth)
    : Array[ByteSeq] val ? 
  =>
    _encode(ForwardMsg[D](data_ch_id, step_id, from_node_name, msg_id, 
      source_ts, ingress_ts, msg_data), auth)

primitive WireMsgDecoder
  fun apply(data: Array[U8] val, auth: AmbientAuth): WireMsg val =>
    try
      match Serialised.input(InputSerialisedAuth(auth), data)(
        DeserialiseAuth(auth))
      | let m: WireMsg val => m
      else
        UnknownMsg(data)
      end
    else
      UnknownMsg(data)
    end

trait val WireMsg

class ReadyMsg is WireMsg
  let node_name: String

  new val create(name: String) =>
    node_name = name

class TopologyReadyMsg is WireMsg
  let node_name: String

  new val create(name: String) =>
    node_name = name

class IdentifyControlPortMsg is WireMsg
  let node_name: String
  let service: String

  new val create(name: String, s: String) =>
    node_name = name
    service = s

class IdentifyDataPortMsg is WireMsg
  let node_name: String
  let service: String

  new val create(name: String, s: String) =>
    node_name = name
    service = s
    
class AddControlMsg is WireMsg
  let node_name: String
  let host: String
  let service: String

  new val create(name: String, h: String, s: String) =>
    node_name = name
    host = h
    service = s

class AddDataMsg is WireMsg
  let node_name: String
  let host: String
  let service: String

  new val create(name: String, h: String, s: String) =>
    node_name = name
    host = h
    service = s

class DoneMsg is WireMsg
  let node_name: String

  new val create(name: String) =>
    node_name = name

primitive StartMsg is WireMsg

class ReconnectMsg is WireMsg
  let node_name: String

  new val create(name: String) =>
    node_name = name

class ShutdownMsg is WireMsg
  let node_name: String

  new val create(name: String) =>
    node_name = name

class DoneShutdownMsg is WireMsg
  let node_name: String

  new val create(name: String) =>
    node_name = name

class SpinUpMsg is WireMsg
  let step_id: U64
  let step_builder: BasicStepBuilder val

  new val create(s_id: U64, s_builder: BasicStepBuilder val) =>
    step_id = s_id
    step_builder = s_builder

class SpinUpStateStepMsg is WireMsg
  let step_id: U64
  let step_builder: BasicStateStepBuilder val
  let shared_state_step_id: U64
  let shared_state_step_node: String

  new val create(s_id: U64, s_builder: BasicStateStepBuilder val,
    sss_id: U64, sss_node: String) =>
    step_id = s_id
    step_builder = s_builder
    shared_state_step_id = sss_id
    shared_state_step_node = sss_node

class SpinUpProxyMsg is WireMsg
  let proxy_id: U64
  let step_id: U64
  let target_node_name: String

  new val create(p_id: U64, s_id: U64, name: String) =>
      proxy_id = p_id
      step_id = s_id
      target_node_name = name

class SpinUpSinkMsg is WireMsg
  let sink_ids: Array[U64] val
  let sink_step_id: U64
  let sink_builder: SinkBuilder val

  new val create(s_ids: Array[U64] iso, s_step_id: U64, s_builder: SinkBuilder val) =>
      sink_ids = consume s_ids
      sink_step_id = s_step_id
      sink_builder = s_builder

class ConnectStepsMsg is WireMsg
  let in_step_id: U64
  let out_step_id: U64

  new val create(i_id: U64, o_id: U64) =>
      in_step_id = i_id
      out_step_id = o_id

class InitializationMsgsFinishedMsg is WireMsg
  let node_name: String

  new val create(name: String) =>
    node_name = name

class AckInitializedMsg is WireMsg
  let node_name: String

  new val create(name: String) =>
    node_name = name

class UnknownMsg is WireMsg
  let data: Array[U8] val

  new val create(d: Array[U8] val) =>
    data = d

class AckMsgIdMsg is WireMsg
  let node_name: String
  let msg_id: U64

  new val create(name: String, m_id: U64) =>
      node_name = name
      msg_id = m_id

class AckConnectMsgIdMsg is WireMsg
  let node_name: String
  let msg_id: U64

  new val create(name: String, m_id: U64) =>
      node_name = name
      msg_id = m_id

class ReconnectDataMsg is WireMsg
  let node_name: String

  new val create(name: String) =>
    node_name = name

class DataSenderReadyMsg is WireMsg
  let node_name: String

  new val create(name: String) =>
    node_name = name

class DataReceiverReadyMsg is WireMsg
  let node_name: String

  new val create(name: String) =>
    node_name = name

class ControlSenderReadyMsg is WireMsg
  let node_name: String

  new val create(name: String) =>
    node_name = name

class FinishedConnectionsMsg is WireMsg
  let node_name: String

  new val create(name: String) =>
    node_name = name

class AckFinishedConnectionsMsg is WireMsg
  let node_name: String

  new val create(name: String) =>
    node_name = name

trait DataChannelMsg is WireMsg
  fun data_channel_id(): U64
  fun from_name(): String
  fun deliver(data_receiver: DataReceiver, step_manager: StepManager tag)  

class ForwardMsg[D: Any val] is DataChannelMsg
  let _data_ch_id: U64
  let _step_id: U64
  let _from_node_name: String
  let _msg_id: U64
  let _source_ts: U64
  let _ingress_ts: U64
  let _data: D

  new val create(data_ch_id: U64, s_id: U64, from: String, m_id: U64, 
    s_ts: U64, i_ts: U64, m_data: D) =>
    _data_ch_id = data_ch_id
    _step_id = s_id
    _from_node_name = from
    _msg_id = m_id
    _source_ts = s_ts
    _ingress_ts = i_ts
    _data = m_data

  fun data_channel_id(): U64 => _data_ch_id
  fun from_name(): String => _from_node_name
  fun deliver(data_receiver: DataReceiver, step_manager: StepManager tag) =>
    data_receiver.received[D](_data_ch_id, _step_id, _msg_id, _source_ts, 
      _ingress_ts, _data, step_manager)
