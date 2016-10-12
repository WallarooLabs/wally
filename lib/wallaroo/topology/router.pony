use "collections"
use "net"
use "wallaroo/messages"

trait Router
  fun route[D: Any val](metric_name: String, source_ts: U64, data: D,
                        outgoing_envelope: MsgEnvelope ref,
                        incoming_envelope: MsgEnvelope val): Bool
  //TODO: outgoing_envelope to become MsgEnvelope trn so we don't clone?

interface RouterBuilder
  fun ref apply(): Router val

class EmptyRouter is Router

  fun route[D: Any val](metric_name: String, source_ts: U64, data: D,
                        outgoing_envelope: MsgEnvelope ref,
                        incoming_envelope: MsgEnvelope val): Bool =>
    true

class DirectRouter is Router
  let _target: Step tag
  let _id: U64

  new val create(target: Step tag, id: U64) =>
    _target = target
    _id = id

  fun route[D: Any val](metric_name: String, source_ts: U64, data: D,
                        outgoing_envelope: MsgEnvelope ref,
                        incoming_envelope: MsgEnvelope val): Bool
  =>
    outgoing_envelope.route_id = _id
    _target.run[D](metric_name, source_ts, data, outgoing_envelope.clone())
    false

  fun route_id(): U64 => _id

class DataRouter is Router
  let _routes: Map[U128, Step tag] val

  new val create(routes: Map[U128, Step tag] val = 
    recover Map[U128, Step tag] end) 
  =>
    _routes = routes

  fun route[D: Any val](metric_name: String, source_ts: U64, data: D,
                        outgoing_envelope: MsgEnvelope ref,
                        incoming_envelope: MsgEnvelope val): Bool =>
    try
      match data
      | let delivery_msg: DeliveryMsg val =>
        let target_id = delivery_msg.target_id()
        //TODO: deliver envelope
        outgoing_envelope.route_id = target_id.u64()
        delivery_msg.deliver(_routes(target_id))
        false
      else
        true
      end
    else
      true
    end

class PartitionRouter is Router
  let _partition_finder: PartitionFinder val
  let _id: U64

  new val create(p_finder: PartitionFinder val, id: U64) =>
    _partition_finder = p_finder
    _id = id

  fun route[D: Any val](metric_name: String, source_ts: U64, data: D,
                        outgoing_envelope: MsgEnvelope ref,
                        incoming_envelope: MsgEnvelope val): Bool =>
    let router = 
      match data
      | let pfable: PartitionFindable val =>
        pfable.find_partition(_partition_finder)
      else
        _partition_finder.find[D](data)
      end

    match router
    | let r: Router val =>
      //delegate to the actual router to stamp the route_id
      r.route[D](metric_name, source_ts, data, outgoing_envelope, incoming_envelope)
    else
      true
    end

class TCPRouter is Router
  let _tcp_writer: TCPWriter
  let _id: U64

  new val create(target: (TCPConnection | Array[TCPConnection] val), id: U64) =>
    _tcp_writer = 
      match target
      | let c: TCPConnection =>
        SingleTCPWriter(c)
      | let cs: Array[TCPConnection] val =>
        MultiTCPWriter(cs)
      else
        EmptyTCPWriter
      end
    _id = id

  fun route[D: Any val](metric_name: String, source_ts: U64, data: D,
                        outgoing_envelope: MsgEnvelope ref,
                        incoming_envelope: MsgEnvelope val): Bool
  =>
    match data
    | let d: Array[ByteSeq] val =>
      //TODO: pass the envelope
      outgoing_envelope.route_id = _id
      _tcp_writer(d)
    end
    false

  fun writev(d: Array[ByteSeq] val) =>
    _tcp_writer(d)

  fun dispose() => _tcp_writer.dispose()

interface TCPWriter
  fun apply(d: Array[ByteSeq] val)
  fun dispose()

class EmptyTCPWriter
  fun apply(d: Array[ByteSeq] val) => None
  fun dispose() => None

class SingleTCPWriter
  let _conn: TCPConnection

  new create(conn: TCPConnection) =>
    _conn = conn

  fun apply(d: Array[ByteSeq] val) => _conn.writev(d)

  fun dispose() => _conn.dispose()

class MultiTCPWriter
  let _conns: Array[TCPConnection] val

  new create(conns: Array[TCPConnection] val) =>
    _conns = conns

  fun apply(d: Array[ByteSeq] val) =>
    for c in _conns.values() do c.writev(d) end

  fun dispose() =>
    for c in _conns.values() do c.dispose() end
