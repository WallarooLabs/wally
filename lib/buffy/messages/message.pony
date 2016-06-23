trait StepMessage
  fun id(): U64
  fun source_ts(): U64
  fun last_ingress_ts(): U64

class Message[A: Any val] is StepMessage
  let _id: U64
  let _source_ts: U64
  let _last_ingress_ts: U64
  let _data: A

  new val create(msg_id: U64, s_ts: U64, i_ts: U64, msg_data: A) =>
    _id = msg_id
    _source_ts = s_ts
    _last_ingress_ts = i_ts
    _data = consume msg_data

  fun id(): U64 => _id
  fun source_ts(): U64 => _source_ts
  fun last_ingress_ts(): U64 => _last_ingress_ts
  fun data(): A => _data

class Forward
  let step_id: U64
  let from_node_name: String
  let msg: StepMessage val

  new val create(s_id: U64, from: String, m: StepMessage val) =>
    step_id = s_id
    from_node_name = from
    msg = m

class ExternalMessage[A: Any val] is StepMessage
  let _id: U64
  let _source_ts: U64
  let _last_ingress_ts: U64
  let _sent_to_external_ts: U64
  let _data: A

  new val create(msg_id: U64, s_ts: U64, i_ts: U64, external_ts: U64, msg_data: A) =>
    _id = msg_id
    _source_ts = s_ts
    _last_ingress_ts = i_ts
    _sent_to_external_ts = external_ts
    _data = consume msg_data

  fun id(): U64 => _id
  fun source_ts(): U64 => _source_ts
  fun last_ingress_ts(): U64 => _last_ingress_ts
  fun sent_to_external_ts(): U64 => _sent_to_external_ts
  fun data(): A => _data
