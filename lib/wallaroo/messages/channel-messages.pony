use "buffered"
use "serialise"
use "net"
use "collections"

primitive ChannelMsgEncoder
  fun _encode(msg: ChannelMsg val, auth: AmbientAuth, 
    wb: Writer = Writer): Array[ByteSeq] val ? 
  =>
    let serialised: Array[U8] val =
      Serialised(SerialiseAuth(auth), msg).output(OutputSerialisedAuth(auth))
    let size = serialised.size()
    if size > 0 then
      wb.u32_be(size.u32())
      wb.write(serialised)
    end
    wb.done()

  fun data_channel[D: Any val](ack_id: U64, from_worker_name: String, 
    msg_id: U64, source_ts: U64, msg_data: D, auth: AmbientAuth)
    : Array[ByteSeq] val ?
  =>
    _encode(ForwardMsg[D](ack_id, from_worker_name, msg_id, source_ts, 
      msg_data), auth)

  fun identify_control_port(worker_name: String, service: String,
    auth: AmbientAuth): Array[ByteSeq] val ? =>
    _encode(IdentifyControlPortMsg(worker_name, service), auth)

  fun identify_data_port(worker_name: String, service: String,
    auth: AmbientAuth): Array[ByteSeq] val ? =>
    _encode(IdentifyDataPortMsg(worker_name, service), auth)

  fun add_control(worker_name: String, host: String, service: String, 
    auth: AmbientAuth): Array[ByteSeq] val ? 
  =>
    _encode(AddControlMsg(worker_name, host, service), auth)

  fun add_data(worker_name: String, host: String, service: String, 
    auth: AmbientAuth): Array[ByteSeq] val ? 
  =>
    _encode(AddDataMsg(worker_name, host, service), auth)

  fun create_connections(
    addresses: Map[String, Map[String, (String, String)]] val, 
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(CreateConnectionsMsg(addresses), auth)

primitive ChannelMsgDecoder
  fun apply(data: Array[U8] val, auth: AmbientAuth): ChannelMsg val =>
    try
      match Serialised.input(InputSerialisedAuth(auth), data)(
        DeserialiseAuth(auth))
      | let m: ChannelMsg val => m
      else
        UnknownChannelMsg(data)
      end
    else
      UnknownChannelMsg(data)
    end

trait val ChannelMsg
  // fun ack_id(): U64
  // fun from_name(): String
  // fun deliver(data_receiver: DataReceiver)

class UnknownChannelMsg is ChannelMsg
  let data: Array[U8] val

  new val create(d: Array[U8] val) =>
    data = d

class IdentifyControlPortMsg is ChannelMsg
  let worker_name: String
  let service: String

  new val create(name: String, s: String) =>
    worker_name = name
    service = s

class IdentifyDataPortMsg is ChannelMsg
  let worker_name: String
  let service: String

  new val create(name: String, s: String) =>
    worker_name = name
    service = s

class AddControlMsg is ChannelMsg
  let worker_name: String
  let host: String
  let service: String

  new val create(name: String, h: String, s: String) =>
    worker_name = name
    host = h
    service = s

class AddDataMsg is ChannelMsg
  let worker_name: String
  let host: String
  let service: String

  new val create(name: String, h: String, s: String) =>
    worker_name = name
    host = h
    service = s

class CreateConnectionsMsg is ChannelMsg
  let addresses: Map[String, Map[String, (String, String)]] val

  new val create(addrs: Map[String, Map[String, (String, String)]] val) =>
    addresses = addrs

class ForwardMsg[D: Any val] is ChannelMsg
  let _ack_id: U64
  let _from_worker_name: String
  let _msg_id: U64
  let _source_ts: U64
  let _data: D

  new val create(a_id: U64, from: String, m_id: U64, s_ts: U64, m_data: D) 
  =>
    _ack_id = a_id
    _from_worker_name = from
    _msg_id = m_id
    _source_ts = s_ts
    _data = m_data

  fun ack_id(): U64 => _ack_id
  fun from_name(): String => _from_worker_name

  // fun deliver(data_receiver: DataReceiver) =>
  //   data_receiver.received[D](_data_ch_id, _step_id, _msg_id, _source_ts,
  //     _ingress_ts, _data, step_manager)