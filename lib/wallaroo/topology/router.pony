use "collections"
use "net"
use "wallaroo/messages"

//TODO: generate route ids somewhere

interface Router
  fun route[D: Any val](metric_name: String, source_ts: U64, data: D,
                        outgoing_envelope: MsgEnvelope ref): Bool

interface RouterBuilder
  fun apply(): Router val

class EmptyRouter
  fun route[D: Any val](metric_name: String, source_ts: U64, data: D,
                        outgoing_envelope: MsgEnvelope ref): Bool =>
    true

class DirectRouter
  let _target: Step tag

  new val create(target: Step tag) =>
    _target = target

  fun route[D: Any val](metric_name: String, source_ts: U64, data: D,
                        outgoing_envelope: MsgEnvelope ref): Bool
  =>
    _target.run[D](metric_name, source_ts, data, outgoing_envelope.clone())
    false

class DataRouter
  let _routes: Map[U128, Step tag] val

  new val create(routes: Map[U128, Step tag] val = 
    recover Map[U128, Step tag] end) 
  =>
    _routes = routes

  fun route[D: Any val](metric_name: String, source_ts: U64, data: D,
                        outgoing_envelope: MsgEnvelope ref): Bool =>
    try
      match data
      | let delivery_msg: DeliveryMsg val =>
        let target_id = delivery_msg.target_id()
        delivery_msg.deliver(_routes(target_id))
        false
      else
        true
      end
    else
      true
    end

class PartitionRouter
  let _partition_finder: PartitionFinder val

  new val create(p_finder: PartitionFinder val) =>
    _partition_finder = p_finder

  fun route[D: Any val](metric_name: String, source_ts: U64, data: D,
                        outgoing_envelope: MsgEnvelope ref): Bool =>
    let router = 
      match data
      | let pfable: PartitionFindable val =>
        pfable.find_partition(_partition_finder)
      else
        _partition_finder.find[D](data)
      end

    match router
    | let r: Router val =>
      r.route[D](metric_name, source_ts, data, outgoing_envelope)
    else
      true
    end

class TCPRouter
  let _tcp_writer: TCPWriter

  new val create(target: (TCPConnection | Array[TCPConnection] val)) =>
    _tcp_writer = 
      match target
      | let c: TCPConnection =>
        SingleTCPWriter(c)
      | let cs: Array[TCPConnection] val =>
        MultiTCPWriter(cs)
      else
        EmptyTCPWriter
      end

  fun route[D: Any val](metric_name: String, source_ts: U64, data: D, 
                        outgoing_envelope: MsgEnvelope ref): Bool
  =>
    match data
    | let d: Array[ByteSeq] val =>
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
