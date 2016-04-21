type OSCEncodable is (String | I32 | F32)

class Message[A: OSCEncodable #send]
  let _id: I32
  let _data: A

  new val create(msg_id: I32, msg_data: A) =>
    _id = msg_id
    _data = consume msg_data

  fun id(): I32 => _id
  fun data(): this->A => _data
