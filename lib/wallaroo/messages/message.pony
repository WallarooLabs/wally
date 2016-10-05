use "collections"


class MsgEnvelope
  let _msg_uid: U64
  let _fractional_msg_ids: Array[U64]

  new val create(msg_uid: String, fractional_msg_ids: Array[U64],
    payload: StateChange[State])
  =>
    _msg_uid = msg_uid
    _fractional_msg_ids = fractional_msg_ids

class Message
  let _envelope: MessageEnvelope
  let _payload: StateChange[State]

  new val create(envelope: MsgEnvelope, payload: StateChange[State])
  =>
    _envelope = envelope
    _payload = payload

  
