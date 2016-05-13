type OSCEncodable is (String | I32 | F32)

trait StepMessage

class Message[A: OSCEncodable #send] is StepMessage
  let id: I32
  let source_ts: U64
  let last_ingress_ts: U64
  let data: A

  new val create(msg_id: I32, s_ts: U64, i_ts: U64, msg_data: A) =>
    id = msg_id
    source_ts = s_ts
    last_ingress_ts = i_ts
    data = consume msg_data
