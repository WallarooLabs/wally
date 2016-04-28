use "osc-pony"

primitive _Ready                                fun apply(): String => "0"
primitive _Identify                             fun apply(): String => "1"
primitive _Done                                 fun apply(): String => "2"
primitive _Reconnect                            fun apply(): String => "3"
primitive _Shutdown                             fun apply(): String => "4"
primitive _DoneShutdown                         fun apply(): String => "5"
primitive _Forward                              fun apply(): String => "6"
primitive _SpinUp                               fun apply(): String => "7"
primitive _SpinUpProxy                          fun apply(): String => "8"
primitive _ConnectSteps                         fun apply(): String => "9"
primitive _InitializationMsgsFinished           fun apply(): String => "10"
primitive _AckInitialized                       fun apply(): String => "11"

primitive TCPMessageEncoder
  fun ready(node_id: I32): Array[U8] val =>
    let osc = OSCMessage(_Ready(),
      recover
        [as OSCData val: OSCInt(node_id)]
      end)
    _encode_osc(osc)

  fun identify(node_id: I32, host: String, service: String): Array[U8] val =>
    let osc = OSCMessage(_Identify(),
      recover
        [as OSCData val: OSCInt(node_id),
                         OSCString(host),
                         OSCString(service)]
      end)
    _encode_osc(osc)

  fun done(node_id: I32): Array[U8] val =>
    let osc = OSCMessage(_Done(),
      recover
        [as OSCData val: OSCInt(node_id)]
      end)
    _encode_osc(osc)

  fun reconnect(node_id: I32): Array[U8] val =>
    let osc = OSCMessage(_Reconnect(),
      recover
        [as OSCData val: OSCInt(node_id)]
      end)
    _encode_osc(osc)

  fun shutdown(node_id: I32): Array[U8] val =>
    let osc = OSCMessage(_Shutdown(),
      recover
        [as OSCData val: OSCInt(node_id)]
      end)
    _encode_osc(osc)

  fun done_shutdown(node_id: I32): Array[U8] val =>
    let osc = OSCMessage(_DoneShutdown(),
      recover
        [as OSCData val: OSCInt(node_id)]
      end)
    _encode_osc(osc)

  fun forward(step_id: I32, msg: Message[I32] val): Array[U8] val =>
    let osc = OSCMessage(_Forward(),
      recover
        [as OSCData val: OSCInt(step_id),
                         OSCInt(msg.id),
                         OSCInt(msg.data)]
      end)
    _encode_osc(osc)

  fun spin_up(step_id: I32, computation_type_id: I32): Array[U8] val =>
    let osc = OSCMessage(_SpinUp(),
      recover
        [as OSCData val: OSCInt(step_id),
                         OSCInt(computation_type_id)]
      end)
    _encode_osc(osc)

  fun spin_up_proxy(proxy_id: I32, step_id: I32, target_node_id: I32,
    target_host: String, target_service: String):
    Array[U8] val =>
    let osc = OSCMessage(_SpinUpProxy(),
      recover
        [as OSCData val: OSCInt(proxy_id),
                         OSCInt(step_id),
                         OSCInt(target_node_id),
                         OSCString(target_host),
                         OSCString(target_service)]
      end)
    _encode_osc(osc)

  fun connect_steps(from_step_id: I32, to_step_id: I32): Array[U8] val =>
    let osc = OSCMessage(_ConnectSteps(),
      recover
        [as OSCData val: OSCInt(from_step_id),
                         OSCInt(to_step_id)]
      end)
    _encode_osc(osc)

  fun initialization_msgs_finished(): Array[U8] val =>
    let osc = OSCMessage(_InitializationMsgsFinished(),
      recover
        Arguments
      end)
    _encode_osc(osc)

  fun ack_initialized(worker_id: I32): Array[U8] val =>
    let osc = OSCMessage(_AckInitialized(),
      recover
        [as OSCData val: OSCInt(worker_id)]
      end)
    _encode_osc(osc)

  fun _encode_osc(msg: OSCMessage val): Array[U8] val =>
    let msg_bytes = msg.to_bytes()
    let len: U32 = msg_bytes.size().u32()
    let arr: Array[U8] iso = Bytes.from_u32(len, recover Array[U8] end)
    arr.append(msg_bytes)
    consume arr

primitive TCPMessageDecoder
  fun apply(data: Array[U8] val): TCPMsg val ? =>
    let msg = OSCDecoder.from_bytes(data) as OSCMessage val
    match msg.address
    | _Ready() =>
      ReadyMsg(msg)
    | _Identify() =>
      IdentifyMsg(msg)
    | _Reconnect() =>
      ReconnectMsg(msg)
    | _Forward() =>
      ForwardMsg(msg)
    | _SpinUp() =>
      SpinUpMsg(msg)
    | _SpinUpProxy() =>
      SpinUpProxyMsg(msg)
    | _ConnectSteps() =>
      ConnectStepsMsg(msg)
    | _InitializationMsgsFinished() =>
      InitializationMsgsFinishedMsg
    | _AckInitialized() =>
      AckInitializedMsg(msg)
    else
      error
    end

trait val TCPMsg

class ReadyMsg is TCPMsg
  let worker_id: I32

  new val create(msg: OSCMessage val) ? =>
    match msg.arguments(0)
    | let i: OSCInt val =>
      worker_id = i.value()
    else
      error
    end

class IdentifyMsg is TCPMsg
  let worker_id: I32
  let host: String
  let service: String

  new val create(msg: OSCMessage val) ? =>
    match (msg.arguments(0), msg.arguments(1), msg.arguments(2))
    | (let i: OSCInt val, let h: OSCString val, let s: OSCString val) =>
      worker_id = i.value()
      host = h.value()
      service = s.value()
    else
      error
    end

class ReconnectMsg is TCPMsg
  let node_id: I32

  new val create(msg: OSCMessage val) ? =>
    match msg.arguments(0)
    | let i: OSCInt val => node_id = i.value()
    else
      error
    end

class ForwardMsg is TCPMsg
  let step_id: I32
  let msg: Message[I32] val

  new val create(m: OSCMessage val) ? =>
    match (m.arguments(0), m.arguments(1), m.arguments(2))
    | (let a_id: OSCInt val, let m_id: OSCInt val, let m_data: OSCInt val) =>
      step_id = a_id.value()
      msg = Message[I32](m_id.value(), m_data.value())
    else
      error
    end

class SpinUpMsg is TCPMsg
  let step_id: I32
  let computation_type_id: I32

  new val create(msg: OSCMessage val) ? =>
    match (msg.arguments(0), msg.arguments(1))
    | (let a_id: OSCInt val, let c_id: OSCInt val) =>
      step_id = a_id.value()
      computation_type_id = c_id.value()
    else
      error
    end

class SpinUpProxyMsg is TCPMsg
  let proxy_id: I32
  let step_id: I32
  let target_node_id: I32
  let target_host: String
  let target_service: String

  new val create(msg: OSCMessage val) ? =>
    match (msg.arguments(0), msg.arguments(1), msg.arguments(2),
      msg.arguments(3), msg.arguments(4))
    | (let p_id: OSCInt val, let s_id: OSCInt val, let t_node_id: OSCInt val,
      let t_host: OSCString val, let t_service: OSCString val) =>
      proxy_id = p_id.value()
      step_id = s_id.value()
      target_node_id = t_node_id.value()
      target_host = t_host.value()
      target_service = t_service.value()
    else
      error
    end

class ConnectStepsMsg is TCPMsg
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

primitive InitializationMsgsFinishedMsg is TCPMsg

class AckInitializedMsg is TCPMsg
  let worker_id: I32

  new val create(msg: OSCMessage val) ? =>
    match msg.arguments(0)
    | let i: OSCInt val =>
      worker_id = i.value()
    else
      error
    end
