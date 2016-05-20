use "osc-pony"
use "sendence/bytes"
use "buffy/topology"
use "serialise"
use "time"

primitive WireMsgEncoder
  fun _serialise(msg: WireMsg val, auth: AmbientAuth): Array[U8] val ? =>
    let serialised: Array[U8] val =
      Serialised(SerialiseAuth(auth), msg).output(OutputSerialisedAuth(auth))
    Bytes.length_encode(serialised)

  fun ready(node_name: String, auth: AmbientAuth): Array[U8] val ? =>
    _serialise(ReadyMsg(node_name), auth)

  fun topology_ready(node_name: String, auth: AmbientAuth): Array[U8] val ? =>
    _serialise(TopologyReadyMsg(node_name), auth)

  fun identify_control(node_name: String, host: String, service: String,
    auth: AmbientAuth): Array[U8] val ? =>
    _serialise(IdentifyControlMsg(node_name, host, service), auth)

  fun identify_data(node_name: String, host: String, service: String,
    auth: AmbientAuth): Array[U8] val ? =>
    _serialise(IdentifyDataMsg(node_name, host, service), auth)

  fun done(node_name: String, auth: AmbientAuth): Array[U8] val ? =>
    _serialise(DoneMsg(node_name), auth)

  fun reconnect(node_name: String, auth: AmbientAuth): Array[U8] val ? =>
    _serialise(ReconnectMsg(node_name), auth)

  fun start(auth: AmbientAuth): Array[U8] val ? =>
    _serialise(StartMsg, auth)

  fun shutdown(node_name: String, auth: AmbientAuth): Array[U8] val ? =>
    _serialise(ShutdownMsg(node_name), auth)

  fun done_shutdown(node_name: String, auth: AmbientAuth): Array[U8] val ? =>
    _serialise(DoneShutdownMsg(node_name), auth)

  fun forward(step_id: U64, node_name: String, step_msg: StepMessage val,
    auth: AmbientAuth): Array[U8] val ? =>
    _serialise(ForwardMsg(step_id, node_name, step_msg), auth)

  fun spin_up(step_id: U64, step_builder: BasicStepBuilder val, auth: AmbientAuth)
    : Array[U8] val ? =>
    _serialise(SpinUpMsg(step_id, step_builder), auth)

  fun spin_up_proxy(proxy_id: U64, step_id: U64, target_node_name: String
    , auth: AmbientAuth): Array[U8] val ? =>
    _serialise(SpinUpProxyMsg(proxy_id, step_id, target_node_name), auth)

  fun spin_up_sink(sink_id: U64, sink_step_id: U64, sink_builder: SinkBuilder val,
    auth: AmbientAuth)
    : Array[U8] val ? =>
    _serialise(SpinUpSinkMsg(sink_id, sink_step_id, sink_builder), auth)

  fun connect_steps(from_step_id: U64, to_step_id: U64, auth: AmbientAuth)
    : Array[U8] val ? =>
    _serialise(ConnectStepsMsg(from_step_id, to_step_id), auth)

  fun initialization_msgs_finished(node_name: String, auth: AmbientAuth)
    : Array[U8] val ? =>
    _serialise(InitializationMsgsFinishedMsg(node_name), auth)

  fun ack_initialized(node_name: String, auth: AmbientAuth): Array[U8] val ? =>
    _serialise(AckInitializedMsg(node_name), auth)

  fun ack_messages_received(node_name: String, msg_count: U64,
    auth: AmbientAuth): Array[U8] val ? =>
    _serialise(AckMsgsReceivedMsg(node_name, msg_count), auth)
 
  fun reconnect_data(node_name: String, auth: AmbientAuth): Array[U8] val ? =>
    _serialise(ReconnectDataMsg(node_name), auth)

  fun data_sender_ready(node_name: String, auth: AmbientAuth)
    : Array[U8] val ? =>
    _serialise(DataSenderReadyMsg(node_name), auth)

  fun data_receiver_ready(node_name: String, auth: AmbientAuth)
    : Array[U8] val ? =>
    _serialise(DataReceiverReadyMsg(node_name), auth)

  fun control_sender_ready(node_name: String, auth: AmbientAuth)
    : Array[U8] val ? =>
    _serialise(ControlSenderReadyMsg(node_name), auth)

  fun finished_connections(node_name: String, auth: AmbientAuth)
    : Array[U8] val ? =>
    _serialise(FinishedConnectionsMsg(node_name), auth)

  fun ack_finished_connections(node_name: String, auth: AmbientAuth)
    : Array[U8] val ? =>
    _serialise(AckFinishedConnectionsMsg(node_name), auth)

  fun ack_reconnect_messages_received(node_name: String, msg_count: U64,
    auth: AmbientAuth): Array[U8] val ? =>
    _serialise(AckReconnectMsgsReceivedMsg(node_name, msg_count), auth)

primitive WireMsgDecoder
  fun apply(data: Array[U8] val, auth: AmbientAuth): WireMsg val =>
    try
      match Serialised.input(InputSerialisedAuth(auth), data)(DeserialiseAuth(auth))
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

class IdentifyControlMsg is WireMsg
  let node_name: String
  let host: String
  let service: String

  new val create(name: String, h: String, s: String) =>
    node_name = name
    host = h
    service = s

class IdentifyDataMsg is WireMsg
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

class ForwardMsg is WireMsg
  let step_id: U64
  let from_node_name: String
  let msg: StepMessage val

  new val create(s_id: U64, from: String, m: StepMessage val) =>
    step_id = s_id
    from_node_name = from
    msg = m

class SpinUpMsg is WireMsg
  let step_id: U64
  let step_builder: BasicStepBuilder val

  new val create(s_id: U64, s_builder: BasicStepBuilder val) =>
    step_id = s_id
    step_builder = s_builder

class SpinUpProxyMsg is WireMsg
  let proxy_id: U64
  let step_id: U64
  let target_node_name: String

  new val create(p_id: U64, s_id: U64, name: String) =>
      proxy_id = p_id
      step_id = s_id
      target_node_name = name

class SpinUpSinkMsg is WireMsg
  let sink_id: U64
  let sink_step_id: U64
  let sink_builder: SinkBuilder val

  new val create(s_id: U64, s_step_id: U64, s_builder: SinkBuilder val) =>
      sink_id = s_id
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

class AckMsgsReceivedMsg is WireMsg
  let node_name: String
  let msg_count: U64

  new val create(name: String, m_count: U64) =>
      node_name = name
      msg_count = m_count

class AckReconnectMsgsReceivedMsg is WireMsg
  let node_name: String
  let msg_count: U64

  new val create(name: String, m_count: U64) =>
      node_name = name
      msg_count = m_count

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
