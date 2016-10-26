use "collections"
use "net"
use "wallaroo/backpressure"
use "wallaroo/messages"

// TODO: Eliminate producer None when we can
interface Router
  fun route[D: Any val](metric_name: String, source_ts: U64, data: D,
    incoming_envelope: MsgEnvelope box, outgoing_envelope: MsgEnvelope,
    producer: (CreditFlowProducer ref | None)): Bool
  fun routes(): Array[CreditFlowConsumerStep] val

interface RouterBuilder
  fun apply(): Router val

class EmptyRouter
  fun route[D: Any val](metric_name: String, source_ts: U64, data: D,
    incoming_envelope: MsgEnvelope box, outgoing_envelope: MsgEnvelope,
    producer: (CreditFlowProducer ref | None)): Bool
  =>
    true

  fun routes(): Array[CreditFlowConsumerStep] val =>
    recover val Array[CreditFlowConsumerStep] end

class DirectRouter
  let _target: CreditFlowConsumerStep tag

  new val create(target: CreditFlowConsumerStep tag) =>
    _target = target

  fun route[D: Any val](metric_name: String, source_ts: U64, data: D,
    incoming_envelope: MsgEnvelope box, outgoing_envelope: MsgEnvelope,
    producer: (CreditFlowProducer ref | None)): Bool
  =>
    // TODO: CreditFlow
    // Lookup route from producer
    // Call run on the route we got from the producer

    let r = producer.route_to(_target)
    r.run[D]()

    _target.run[D](metric_name, source_ts, data,
      outgoing_envelope.origin,
      outgoing_envelope.msg_uid,
      outgoing_envelope.frac_ids,
      outgoing_envelope.seq_id,
      // TODO: Figure out how to determine route id
      0)
    false

  fun routes(): Array[CreditFlowConsumerStep] val =>
    recover val [_target] end

class DataRouter
  let _data_routes: Map[U128, Step tag] val

  new val create(data_routes: Map[U128, Step tag] val =
    recover Map[U128, Step tag] end)
  =>
    _data_routes = data_routes

  fun route[D: Any val](metric_name: String, source_ts: U64, data: D,
    incoming_envelope: MsgEnvelope box, outgoing_envelope: MsgEnvelope,
    producer: (CreditFlowProducer ref | None)): Bool
  =>
    try
      match data
      | let delivery_msg: DeliveryMsg val =>
        let target_id = delivery_msg.target_id()
        //TODO: create and deliver envelope
        delivery_msg.deliver(_data_routes(target_id))
        false
      else
        true
      end
    else
      true
    end

  fun routes(): Array[CreditFlowConsumerStep] val =>
    // TODO: CREDITFLOW - real implmentation?
    recover val Array[CreditFlowConsumerStep] end

  // fun routes(): Array[CreditFlowConsumer tag] val =>
  //   let rs: Array[CreditFlowConsumer tag] trn =
  //     recover Array[CreditFlowConsumer tag] end

  //   for (k, v) in _routes.pairs() do
  //     rs.push(v)
  //   end

  //   consume rs

trait PartitionRouter is Router
  fun local_map(): Map[U128, Step] val

class LocalPartitionRouter[In: Any val,
  Key: (Hashable val & Equatable[Key] val)] is PartitionRouter
  let _local_map: Map[U128, Step] val
  let _step_ids: Map[Key, U128] val
  let _partition_routes: Map[Key, (Step | PartitionProxy)] val
  let _partition_function: PartitionFunction[In, Key] val

  new val create(local_map': Map[U128, Step] val,
    s_ids: Map[Key, U128] val,
    partition_routes: Map[Key, (Step | PartitionProxy)] val,
    partition_function: PartitionFunction[In, Key] val)
  =>
    _local_map = local_map'
    _step_ids = s_ids
    _partition_routes = partition_routes
    _partition_function = partition_function

  fun route[D: Any val](metric_name: String, source_ts: U64, data: D,
    incoming_envelope: MsgEnvelope box, outgoing_envelope: MsgEnvelope,
    producer: (CreditFlowProducer ref | None)): Bool
  =>
    match data
    | let input: In =>
      let key = _partition_function(input)
      try
        match _partition_routes(key)
        | let s: Step =>
          // TODO- CreditFlow
          // Lookup route from producer
          // Call run on the route we got from the producer

          s.run[In](metric_name, source_ts, input,
            outgoing_envelope.origin,
            outgoing_envelope.msg_uid,
            outgoing_envelope.frac_ids,
            outgoing_envelope.seq_id,
            // TODO: Generate correct route id
            0)
          false
        | let p: PartitionProxy =>
          try
            p.forward[In](metric_name, source_ts, input, _step_ids(key),
              // TODO: We need to receive a from_step_id and pass it here
              0,
              outgoing_envelope.msg_uid,
              outgoing_envelope.frac_ids,
              outgoing_envelope.seq_id,
              // TODO: Generate correct route id
              0)
            false
          else
            @printf[I32]("Missing step ID for partition key\n".cstring())
            true
          end
        else
          true
        end
      else
        true
      end
    else
      true
    end

  fun routes(): Array[CreditFlowConsumerStep] val =>
    // TODO: CREDITFLOW - real implmentation
    recover val Array[CreditFlowConsumerStep] end

  fun local_map(): Map[U128, Step] val => _local_map

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
    incoming_envelope: MsgEnvelope box, outgoing_envelope: MsgEnvelope,
    producer: (CreditFlowProducer ref | None)): Bool
  =>
    match data
    | let d: Array[ByteSeq] val =>
      _tcp_writer(d)
    end
    false

  fun writev(d: Array[ByteSeq] val) =>
    _tcp_writer(d)

  fun dispose() => _tcp_writer.dispose()

  fun routes(): Array[CreditFlowConsumerStep] val =>
    // TODO: CREDITFLOW - real implmentation?
    recover val Array[CreditFlowConsumerStep] end

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

  fun apply(d: Array[ByteSeq] val) =>
    _conn.writev(d)

  fun dispose() => _conn.dispose()

class MultiTCPWriter
  let _conns: Array[TCPConnection] val

  new create(conns: Array[TCPConnection] val) =>
    _conns = conns

  fun apply(d: Array[ByteSeq] val) =>
    for c in _conns.values() do c.writev(d) end

  fun dispose() =>
    for c in _conns.values() do c.dispose() end
