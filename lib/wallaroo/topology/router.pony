use "collections"
use "net"
use "wallaroo/backpressure"
use "wallaroo/messages"

// TODO: Eliminate producer None when we can
interface Router
  fun route[D: Any val](metric_name: String, source_ts: U64, data: D,
    producer: (CreditFlowProducer ref | None)): Bool
  // fun routes(): Array[CreditFlowConsumer tag] val

interface RouterBuilder
  fun apply(): Router val

class EmptyRouter
  fun route[D: Any val](metric_name: String, source_ts: U64, data: D,
    producer: (CreditFlowProducer ref | None)): Bool 
  =>
    true

class DirectRouter
  let _target: RunnableStep tag

  new val create(target: RunnableStep tag) =>
    _target = target

  fun route[D: Any val](metric_name: String, source_ts: U64, data: D,
    producer: (CreditFlowProducer ref | None)): Bool 
  =>
    // TODO: Use producer here

    _target.run[D](metric_name, source_ts, data)
    false

  // fun routes(): Array[CreditFlowConsumer tag] val =>
  //   recover [_target] end

class DataRouter
  let _routes: Map[U128, Step tag] val

  new val create(routes: Map[U128, Step tag] val = 
    recover Map[U128, Step tag] end) 
  =>
    _routes = routes

  fun route[D: Any val](metric_name: String, source_ts: U64, data: D,
    producer: (CreditFlowProducer ref | None)): Bool 
  =>
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
  let _routes: Map[Key, (Step | PartitionProxy)] val
  let _partition_function: PartitionFunction[In, Key] val

  new val create(local_map': Map[U128, Step] val,
    s_ids: Map[Key, U128] val, routes: Map[Key, (Step | PartitionProxy)] val,
    partition_function: PartitionFunction[In, Key] val)
  =>
    _local_map = local_map'
    _step_ids = s_ids
    _routes = routes
    _partition_function = partition_function

  fun route[D: Any val](metric_name: String, source_ts: U64, data: D,
    producer: (CreditFlowProducer ref | None)): Bool 
  =>
    match data
    | let input: In =>
      let key = _partition_function(input)
      try
        match _routes(key)  
        | let s: Step =>
          s.run[In](metric_name, source_ts, input)
          false
        | let p: PartitionProxy =>
          try
            p.forward[In](metric_name, source_ts, input, _step_ids(key))
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

  fun local_map(): Map[U128, Step] val => _local_map

class OldPartitionRouter
  let _partition_finder: PartitionFinder val

  new val create(p_finder: PartitionFinder val) =>
    _partition_finder = p_finder

  fun route[D: Any val](metric_name: String, source_ts: U64, data: D,
    producer: (CreditFlowProducer ref | None)): Bool 
  =>
    let router = 
      match data
      | let pfable: PartitionFindable val =>
        pfable.find_partition(_partition_finder)
      else
        _partition_finder.find[D](data)
      end

    match router
    | let r: Router val =>
      r.route[D](metric_name, source_ts, data, producer)
    else
      true
    end

  // fun routes(): Array[CreditFlowConsumer tag] val =>
  //   // Fix this
  //   recover [] end

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

// interface Router[In: Any val, RoutesTo: Any tag]
//   fun route(input: In): (RoutesTo | None)

// class DirectRouter[In: Any val, RoutesTo: Any tag]
//   let _target: RoutesTo

//   new iso create(target: RoutesTo) =>
//     _target = target

//   fun route(input: In): RoutesTo =>
//     _target

// class DataRouter is Router[U128, Step tag]
//   let _routes: Map[U128, Step tag] val

//   new val create(routes: Map[U128, Step tag] val = 
//     recover Map[U128, Step tag] end) 
//   =>
//     _routes = routes

//   fun route(input: U128): (Step tag | None) =>
//     try
//       _routes(input)
//     else
//       None
//     end
