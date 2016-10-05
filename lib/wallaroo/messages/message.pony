use "collections"


class MsgEnvelope
  let _msg_uid: String
  let _fractional_msg_id_list: List[String]

  new val create(msg_uid: String, fractional_msg_id_list: List[String],
    payload: StateChange[State])
  =>
    _msg_uid = msg_uid
    _fractional_msg_id_list = fractional_msg_id_list

class Message
  let _envelope: MessageEnvelope
  let _payload: StateChange[State]

  new val create(envelope: MsgEnvelope, payload: StateChange[State])
  =>
    _envelope = envelope
    _payload = payload

  
