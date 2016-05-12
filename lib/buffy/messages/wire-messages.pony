use "osc-pony"
use "sendence/bytes"
use "time"

primitive _Ready                                fun apply(): String => "/0"
primitive _TopologyReady                        fun apply(): String => "/1"
primitive _IdentifyControl                      fun apply(): String => "/2"
primitive _IdentifyInternal                     fun apply(): String => "/3"
primitive _Done                                 fun apply(): String => "/4"
primitive _Reconnect                            fun apply(): String => "/5"
primitive _Start                                fun apply(): String => "/6"
primitive _Shutdown                             fun apply(): String => "/7"
primitive _DoneShutdown                         fun apply(): String => "/8"
primitive _Forward                              fun apply(): String => "/9"
primitive _SpinUp                               fun apply(): String => "/10"
primitive _SpinUpProxy                          fun apply(): String => "/11"
primitive _SpinUpSink                           fun apply(): String => "/12"
primitive _ConnectSteps                         fun apply(): String => "/13"
primitive _InitializationMsgsFinished           fun apply(): String => "/14"
primitive _AckInitialized                       fun apply(): String => "/15"
primitive _External                             fun apply(): String => "/16"
primitive _ForwardI32                           fun apply(): String => "/17"
primitive _ForwardF32                           fun apply(): String => "/18"
primitive _ForwardString                        fun apply(): String => "/19"

primitive WireMsgEncoder
  fun ready(node_name: String): Array[U8] val =>
    let osc = OSCMessage(_Ready(),
      recover
        [as OSCData val: OSCString(node_name)]
      end)
    Bytes.length_encode(osc.to_bytes())

  fun topology_ready(node_name: String): Array[U8] val =>
    let osc = OSCMessage(_TopologyReady(),
      recover
        [as OSCData val: OSCString(node_name)]
      end)
    Bytes.length_encode(osc.to_bytes())

  fun identify_control(node_name: String, host: String, service: String)
    : Array[U8] val =>
    let osc = OSCMessage(_IdentifyControl(),
      recover
        [as OSCData val: OSCString(node_name),
                         OSCString(host),
                         OSCString(service)]
      end)
    Bytes.length_encode(osc.to_bytes())

  fun identify_internal(node_name: String, host: String, service: String)
    : Array[U8] val =>
    let osc = OSCMessage(_IdentifyInternal(),
      recover
        [as OSCData val: OSCString(node_name),
                         OSCString(host),
                         OSCString(service)]
      end)
    Bytes.length_encode(osc.to_bytes())

  fun done(node_name: String): Array[U8] val =>
    let osc = OSCMessage(_Done(),
      recover
        [as OSCData val: OSCString(node_name)]
      end)
    Bytes.length_encode(osc.to_bytes())

  fun reconnect(node_name: String): Array[U8] val =>
    let osc = OSCMessage(_Reconnect(),
      recover
        [as OSCData val: OSCString(node_name)]
      end)
    Bytes.length_encode(osc.to_bytes())

  fun start(): Array[U8] val =>
    let osc = OSCMessage(_Start(), recover Arguments end)
    Bytes.length_encode(osc.to_bytes())

  fun shutdown(node_name: String): Array[U8] val =>
    let osc = OSCMessage(_Shutdown(),
      recover
        [as OSCData val: OSCString(node_name)]
      end)
    Bytes.length_encode(osc.to_bytes())

  fun done_shutdown(node_name: String): Array[U8] val =>
    let osc = OSCMessage(_DoneShutdown(),
      recover
        [as OSCData val: OSCString(node_name)]
      end)
    Bytes.length_encode(osc.to_bytes())

  fun forward(step_id: I32, msg: Message[I32] val): Array[U8] val =>
    let source_ts_byte_0 = (msg.source_ts >> 32).i32()
    let source_ts_byte_1 = (msg.source_ts and 0xFFFF_FFFF).i32()
    let osc = OSCMessage(_Forward(),
      recover
        [as OSCData val: OSCInt(step_id),
                         OSCInt(msg.id),
                         OSCInt(source_ts_byte_0),
                         OSCInt(source_ts_byte_1),
                         OSCInt(msg.data)]
      end)
    Bytes.length_encode(osc.to_bytes())

  fun forward_i32(step_id: I32, msg: Message[I32] val): Array[U8] val =>
    let source_ts_byte_0 = (msg.source_ts >> 32).i32()
    let source_ts_byte_1 = (msg.source_ts and 0xFFFF_FFFF).i32()
    let osc = OSCMessage(_ForwardI32(),
      recover
        [as OSCData val: OSCInt(step_id),
                         OSCInt(msg.id),
                         OSCInt(source_ts_byte_0),
                         OSCInt(source_ts_byte_1),
                         OSCInt(msg.data)]
      end)
    Bytes.length_encode(osc.to_bytes())

  fun forward_f32(step_id: I32, msg: Message[F32] val): Array[U8] val =>
    let source_ts_byte_0 = (msg.source_ts >> 32).i32()
    let source_ts_byte_1 = (msg.source_ts and 0xFFFF_FFFF).i32()
    let osc = OSCMessage(_ForwardF32(),
      recover
        [as OSCData val: OSCInt(step_id),
                         OSCInt(msg.id),
                         OSCInt(source_ts_byte_0),
                         OSCInt(source_ts_byte_1),
                         OSCFloat(msg.data)]
      end)
    Bytes.length_encode(osc.to_bytes())

  fun forward_string(step_id: I32, msg: Message[String] val): Array[U8] val =>
    let source_ts_byte_0 = (msg.source_ts >> 32).i32()
    let source_ts_byte_1 = (msg.source_ts and 0xFFFF_FFFF).i32()
    let osc = OSCMessage(_ForwardString(),
      recover
        [as OSCData val: OSCInt(step_id),
                         OSCInt(msg.id),
                         OSCInt(source_ts_byte_0),
                         OSCInt(source_ts_byte_1),
                         OSCString(msg.data)]
      end)
    Bytes.length_encode(osc.to_bytes())

  fun spin_up(step_id: I32, computation_type: String): Array[U8] val =>
    let osc = OSCMessage(_SpinUp(),
      recover
        [as OSCData val: OSCInt(step_id),
                         OSCString(computation_type)]
      end)
    Bytes.length_encode(osc.to_bytes())

  fun spin_up_proxy(proxy_id: I32, step_id: I32, target_node_name: String,
    target_host: String, target_service: String):
    Array[U8] val =>
    let osc = OSCMessage(_SpinUpProxy(),
      recover
        [as OSCData val: OSCInt(proxy_id),
                         OSCInt(step_id),
                         OSCString(target_node_name),
                         OSCString(target_host),
                         OSCString(target_service)]
      end)
    Bytes.length_encode(osc.to_bytes())

  fun spin_up_sink(sink_id: I32, sink_step_id: I32): Array[U8] val =>
    let osc = OSCMessage(_SpinUpSink(),
      recover
        [as OSCData val: OSCInt(sink_id),
                         OSCInt(sink_step_id)]
      end)
    Bytes.length_encode(osc.to_bytes())

  fun connect_steps(from_step_id: I32, to_step_id: I32): Array[U8] val =>
    let osc = OSCMessage(_ConnectSteps(),
      recover
        [as OSCData val: OSCInt(from_step_id),
                         OSCInt(to_step_id)]
      end)
    Bytes.length_encode(osc.to_bytes())

  fun initialization_msgs_finished(): Array[U8] val =>
    let osc = OSCMessage(_InitializationMsgsFinished(),
      recover
        Arguments
      end)
    Bytes.length_encode(osc.to_bytes())

  fun ack_initialized(node_name: String): Array[U8] val =>
    let osc = OSCMessage(_AckInitialized(),
      recover
        [as OSCData val: OSCString(node_name)]
      end)
    Bytes.length_encode(osc.to_bytes())

  fun external(data: Stringable val): Array[U8] val =>
    let osc = OSCMessage(_External(),
      recover
        [as OSCData val: OSCString(data.string())]
      end)
    Bytes.length_encode(osc.to_bytes())

primitive WireMsgDecoder
  fun apply(data: Array[U8] val): WireMsg val ? =>
    let msg = OSCDecoder.from_bytes(data) as OSCMessage val
    match msg.address
    | _Ready() =>
      ReadyMsg(msg)
    | _TopologyReady() =>
      TopologyReadyMsg(msg)
    | _IdentifyControl() =>
      IdentifyControlMsg(msg)
    | _IdentifyInternal() =>
      IdentifyInternalMsg(msg)
    | _Done() =>
      DoneMsg(msg)
    | _Start() =>
      StartMsg
    | _Reconnect() =>
      ReconnectMsg(msg)
    | _Shutdown() =>
      ShutdownMsg(msg)
    | _DoneShutdown() =>
      DoneShutdownMsg(msg)
    | _Forward() =>
      ForwardMsg(msg)
    | _ForwardI32() =>
      ForwardI32Msg(msg)
    | _ForwardF32() =>
      ForwardF32Msg(msg)
    | _ForwardString() =>
      ForwardStringMsg(msg)
    | _SpinUp() =>
      SpinUpMsg(msg)
    | _SpinUpProxy() =>
      SpinUpProxyMsg(msg)
    | _SpinUpSink() =>
      SpinUpSinkMsg(msg)
    | _ConnectSteps() =>
      ConnectStepsMsg(msg)
    | _InitializationMsgsFinished() =>
      InitializationMsgsFinishedMsg
    | _AckInitialized() =>
      AckInitializedMsg(msg)
    | _External() =>
      ExternalMsg(msg)
    else
      UnknownMsg(data)
    end

trait val WireMsg

class ReadyMsg is WireMsg
  let node_name: String

  new val create(msg: OSCMessage val) ? =>
    match msg.arguments(0)
    | let n: OSCString val =>
      node_name = n.value()
    else
      error
    end

class TopologyReadyMsg is WireMsg
  let node_name: String

  new val create(msg: OSCMessage val) ? =>
    match msg.arguments(0)
    | let n: OSCString val =>
      node_name = n.value()
    else
      error
    end

class IdentifyControlMsg is WireMsg
  let node_name: String
  let host: String
  let service: String

  new val create(msg: OSCMessage val) ? =>
    match (msg.arguments(0), msg.arguments(1), msg.arguments(2))
    | (let n: OSCString val, let h: OSCString val, let s: OSCString val) =>
      node_name = n.value()
      host = h.value()
      service = s.value()
    else
      error
    end

class IdentifyInternalMsg is WireMsg
  let node_name: String
  let host: String
  let service: String

  new val create(msg: OSCMessage val) ? =>
    match (msg.arguments(0), msg.arguments(1), msg.arguments(2))
    | (let n: OSCString val, let h: OSCString val, let s: OSCString val) =>
      node_name = n.value()
      host = h.value()
      service = s.value()
    else
      error
    end

class DoneMsg is WireMsg
  let node_name: String

  new val create(msg: OSCMessage val) ? =>
    match msg.arguments(0)
    | let n: OSCString val =>
      node_name = n.value()
    else
      error
    end

primitive StartMsg is WireMsg

class ReconnectMsg is WireMsg
  let node_name: String

  new val create(msg: OSCMessage val) ? =>
    match msg.arguments(0)
    | let n: OSCString val => node_name = n.value()
    else
      error
    end

class ShutdownMsg is WireMsg
  let node_name: String

  new val create(msg: OSCMessage val) ? =>
    match msg.arguments(0)
    | let n: OSCString val =>
      node_name = n.value()
    else
      error
    end

class DoneShutdownMsg is WireMsg
  let node_name: String

  new val create(msg: OSCMessage val) ? =>
    match msg.arguments(0)
    | let n: OSCString val =>
      node_name = n.value()
    else
      error
    end

class ForwardMsg is WireMsg
  let step_id: I32
  let msg: Message[I32] val

  new val create(m: OSCMessage val) ? =>
    match (m.arguments(0), m.arguments(1), m.arguments(2), m.arguments(3),
      m.arguments(4))
    | (let a_id: OSCInt val, let m_id: OSCInt val, let s_ts_0: OSCInt val,
      let s_ts_1: OSCInt val, let m_data: OSCInt val) =>
      step_id = a_id.value()
      let source_ts = (s_ts_0.value().u64() << 32) + s_ts_1.value().u64()
      msg = Message[I32](m_id.value(), source_ts, Time.millis(), m_data.value())
    else
      error
    end

class ForwardI32Msg is WireMsg
  let step_id: I32
  let msg: Message[I32] val

  new val create(m: OSCMessage val) ? =>
    match (m.arguments(0), m.arguments(1), m.arguments(2), m.arguments(3),
      m.arguments(4))
    | (let a_id: OSCInt val, let m_id: OSCInt val, let s_ts_0: OSCInt val,
      let s_ts_1: OSCInt val, let m_data: OSCInt val) =>
      step_id = a_id.value()
      let source_ts = (s_ts_0.value().u64() << 32) + s_ts_1.value().u64()
      msg = Message[I32](m_id.value(), source_ts, Time.millis(), m_data.value())
    else
      error
    end

class ForwardF32Msg is WireMsg
  let step_id: I32
  let msg: Message[F32] val

  new val create(m: OSCMessage val) ? =>
    match (m.arguments(0), m.arguments(1), m.arguments(2), m.arguments(3),
      m.arguments(4))
    | (let a_id: OSCInt val, let m_id: OSCInt val, let s_ts_0: OSCInt val,
      let s_ts_1: OSCInt val, let m_data: OSCFloat val) =>
      step_id = a_id.value()
      let source_ts = (s_ts_0.value().u64() << 32) + s_ts_1.value().u64()
      msg = Message[F32](m_id.value(), source_ts, Time.millis(), m_data.value())
    else
      error
    end

class ForwardStringMsg is WireMsg
  let step_id: I32
  let msg: Message[String] val

  new val create(m: OSCMessage val) ? =>
    match (m.arguments(0), m.arguments(1), m.arguments(2), m.arguments(3),
      m.arguments(4))
    | (let a_id: OSCInt val, let m_id: OSCInt val, let s_ts_0: OSCInt val,
      let s_ts_1: OSCInt val, let m_data: OSCString val) =>
      step_id = a_id.value()
      let source_ts = (s_ts_0.value().u64() << 32) + s_ts_1.value().u64()
      msg = Message[String](m_id.value(), source_ts, Time.millis(), m_data.value())
    else
      error
    end

class SpinUpMsg is WireMsg
  let step_id: I32
  let computation_type: String

  new val create(msg: OSCMessage val) ? =>
    match (msg.arguments(0), msg.arguments(1))
    | (let a_id: OSCInt val, let c_type: OSCString val) =>
      step_id = a_id.value()
      computation_type = c_type.value()
    else
      error
    end

class SpinUpProxyMsg is WireMsg
  let proxy_id: I32
  let step_id: I32
  let target_node_name: String
  let target_host: String
  let target_service: String

  new val create(msg: OSCMessage val) ? =>
    match (msg.arguments(0), msg.arguments(1), msg.arguments(2),
      msg.arguments(3), msg.arguments(4))
    | (let p_id: OSCInt val, let s_id: OSCInt val, let t_node_name: OSCString val,
      let t_host: OSCString val, let t_service: OSCString val) =>
      proxy_id = p_id.value()
      step_id = s_id.value()
      target_node_name = t_node_name.value()
      target_host = t_host.value()
      target_service = t_service.value()
    else
      error
    end

class SpinUpSinkMsg is WireMsg
  let sink_id: I32
  let sink_step_id: I32

  new val create(msg: OSCMessage val) ? =>
    match (msg.arguments(0), msg.arguments(1))
    | (let s_id: OSCInt val, let s_step_id: OSCInt val) =>
      sink_id = s_id.value()
      sink_step_id = s_step_id.value()
    else
      error
    end

class ConnectStepsMsg is WireMsg
  let in_step_id: I32
  let out_step_id: I32

  new val create(msg: OSCMessage val) ? =>
    match (msg.arguments(0), msg.arguments(1))
    | (let in_a_id: OSCInt val, let out_a_id: OSCInt val) =>
      in_step_id = in_a_id.value()
      out_step_id = out_a_id.value()
    else
      error
    end

primitive InitializationMsgsFinishedMsg is WireMsg

class AckInitializedMsg is WireMsg
  let node_name: String

  new val create(msg: OSCMessage val) ? =>
    match msg.arguments(0)
    | let n: OSCString val =>
      node_name = n.value()
    else
      error
    end

class ExternalMsg is WireMsg
  let data: String

  new val create(msg: OSCMessage val) ? =>
    match msg.arguments(0)
    | let d: OSCString val => data = d.value()
    else
      error
    end

class UnknownMsg is WireMsg
  let data: Array[U8] val

  new val create(d: Array[U8] val) =>
    data = d