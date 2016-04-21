use "osc-pony"

primitive TCPMessageTypes
  // [0, worker_id]
  fun greet(): I32 => 0
  // [1, reconnecting_node_id]
  fun reconnect(): I32 => 1
  // [2, step_id, msg_id, msg_data]
  fun forward(): I32 => 2
  // [3, step_id, computation_type_id]
  fun spin_up(): I32 => 3
  // [4, in_step_id, out_step_id]
  fun connect_steps(): I32 => 4
  // [5]
  fun initialization_msgs_finished(): I32 => 5
  // [6]
  fun ack_initialized(): I32 => 6

primitive TCPMessageEncoder
  fun greet(node_id: I32): Array[U8] val =>
    let osc = OSCMessage("/buffy",
      recover
        [as OSCData val: OSCInt(TCPMessageTypes.greet()),
                         OSCInt(node_id)]
      end)
    _encode_osc(osc)

  fun reconnect(node_id: I32): Array[U8] val =>
    let osc = OSCMessage("/buffy",
      recover
        [as OSCData val: OSCInt(TCPMessageTypes.reconnect()),
                         OSCInt(node_id)]
      end)
    _encode_osc(osc)

  fun forward(step_id: I32, msg: Message[I32] val): Array[U8] val =>
    let osc = OSCMessage("/buffy",
      recover
        [as OSCData val: OSCInt(TCPMessageTypes.forward()),
                         OSCInt(step_id),
                         OSCInt(msg.id()),
                         OSCInt(msg.data())]
      end)
    _encode_osc(osc)

  fun spin_up(step_id: I32, computation_type_id: I32): Array[U8] val =>
    let osc = OSCMessage("/buffy",
      recover
        [as OSCData val: OSCInt(TCPMessageTypes.spin_up()),
                         OSCInt(step_id),
                         OSCInt(computation_type_id)]
      end)
    _encode_osc(osc)

  fun connect_steps(from_step_id: I32, to_step_id: I32): Array[U8] val =>
    let osc = OSCMessage("/buffy",
      recover
        [as OSCData val: OSCInt(TCPMessageTypes.connect_steps()),
                         OSCInt(from_step_id),
                         OSCInt(to_step_id)]
      end)
    _encode_osc(osc)

  fun initialization_msgs_finished(): Array[U8] val =>
    let osc = OSCMessage("/buffy",
      recover
        [as OSCData val: OSCInt(TCPMessageTypes.initialization_msgs_finished())]
      end)
    _encode_osc(osc)

  fun ack_initialized(): Array[U8] val =>
    let osc = OSCMessage("/buffy",
      recover
        [as OSCData val: OSCInt(TCPMessageTypes.ack_initialized())]
      end)
    _encode_osc(osc)

  fun _encode_osc(msg: OSCMessage val): Array[U8] val =>
    let msg_bytes = msg.to_bytes()
    let len: U32 = msg_bytes.size().u32()
    let arr: Array[U8] iso = recover Array[U8] end
    arr.append(Bytes.from_u32(len))
    arr.append(msg_bytes)
    consume arr

primitive TCPMessageDecoder
  fun apply(data: Array[U8] val): TCPMsg val ? =>
    let msg = OSCDecoder.from_bytes(data) as OSCMessage val
    match msg.arguments(0)
    | let i: OSCInt val =>
      match i.value()
      | TCPMessageTypes.greet() =>
        GreetMsg(msg)
      | TCPMessageTypes.reconnect() =>
        ReconnectMsg(msg)
      | TCPMessageTypes.forward() =>
        ForwardMsg(msg)
      | TCPMessageTypes.spin_up() =>
        SpinUpMsg(msg)
      | TCPMessageTypes.connect_steps() =>
        ConnectStepsMsg(msg)
      | TCPMessageTypes.initialization_msgs_finished() =>
        InitializationMsgsFinishedMsg
      | TCPMessageTypes.ack_initialized() =>
        AckInitializedMsg
      end
    end

interface TCPMsg

class GreetMsg is TCPMsg
  let worker_id: I32

  new val create(msg: OSCMessage val) ? =>
    match msg.arguments(1)
    | let i: OSCInt val => worker_id = i.value()
    else
      error
    end

class ReconnectMsg is TCPMsg
  let node_id: I32

  new val create(msg: OSCMessage val) ? =>
    match msg.arguments(1)
    | let i: OSCInt val => node_id = i.value()
    else
      error
    end

class ForwardMsg is TCPMsg
  let step_id: I32
  let msg: Message[I32] val

  new val create(m: OSCMessage val) ? =>
    match (m.arguments(1), m.arguments(2), m.arguments(3))
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
    match (msg.arguments(1), msg.arguments(2))
    | (let a_id: OSCInt val, let c_id: OSCInt val) =>
      step_id = a_id.value()
      computation_type_id = c_id.value()
    else
      error
    end

class ConnectStepsMsg is TCPMsg
  let in_step_id: I32
  let out_step_id: I32

  new val create(msg: OSCMessage val) ? =>
    match (msg.arguments(1), msg.arguments(2))
    | (let in_a_id: OSCInt val, let out_a_id: OSCInt val) =>
      in_step_id = in_a_id.value()
      out_step_id = out_a_id.value()
    else
      error
    end

class val InitializationMsgsFinishedMsg is TCPMsg

class val AckInitializedMsg is TCPMsg
