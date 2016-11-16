use "collections"
use "net"
use "wallaroo/backpressure"
use "wallaroo/boundary"
use "wallaroo/messages"
use "wallaroo/tcp-sink"

//!!
use "sendence/fix"
use "sendence/new-fix"

// TODO: Eliminate producer None when we can
interface Router
  fun route[D: Any val](metric_name: String, source_ts: U64, data: D,
    producer: (CreditFlowProducer ref | None),
    // incoming envelope
    i_origin: Origin tag, i_msg_uid: U128, 
    i_frac_ids: None, i_seq_id: U64, i_route_id: U64,
    // outgoing envelope
    o_origin: Origin tag, o_msg_uid: U128, o_frac_ids: None,
    o_seq_id: U64): Bool
  fun routes(): Array[CreditFlowConsumerStep] val

interface RouterBuilder
  fun apply(): Router val

class EmptyRouter
  fun route[D: Any val](metric_name: String, source_ts: U64, data: D,
    producer: (CreditFlowProducer ref | None),
    // incoming envelope
    i_origin: Origin tag, i_msg_uid: U128, 
    i_frac_ids: None, i_seq_id: U64, i_route_id: U64,
    // outgoing envelope
    o_origin: Origin tag, o_msg_uid: U128, o_frac_ids: None,
    o_seq_id: U64): Bool
  =>
    @printf[I32]("!!EmptyRouter RECVD\n".cstring())
    true

  fun routes(): Array[CreditFlowConsumerStep] val =>
    recover val Array[CreditFlowConsumerStep] end

class DirectRouter
  let _target: CreditFlowConsumerStep tag

  new val create(target: CreditFlowConsumerStep tag) =>
    _target = target

  fun route[D: Any val](metric_name: String, source_ts: U64, data: D,
    producer: (CreditFlowProducer ref | None),
    // incoming envelope
    i_origin: Origin tag, i_msg_uid: U128, 
    i_frac_ids: None, i_seq_id: U64, i_route_id: U64,
    // outgoing envelope
    o_origin: Origin tag, o_msg_uid: U128, o_frac_ids: None,
    o_seq_id: U64): Bool
  =>
    // TODO: Remove that producer can be None
    match producer
    | let cfp: CreditFlowProducer ref =>
      let might_be_route = cfp.route_to(_target)
      match might_be_route
      | let r: Route =>
        r.run[D](metric_name, source_ts, data,
          // hand down cfp so we can update route_id
          cfp,
          // outgoing envelope
          o_origin, o_msg_uid, o_frac_ids, o_seq_id)        
        false
      else
        // TODO: What do we do if we get None?
        true
      end
    else
      true
    end

  fun routes(): Array[CreditFlowConsumerStep] val =>
    recover val [_target] end

class ProxyRouter
  let _worker_name: String
  let _target: CreditFlowConsumerStep tag
  let _target_proxy_address: ProxyAddress val
  let _auth: AmbientAuth

  new val create(worker_name: String, target: CreditFlowConsumerStep tag, 
    target_proxy_address: ProxyAddress val, auth: AmbientAuth)
  =>
    _worker_name = worker_name
    _target = target
    _target_proxy_address = target_proxy_address
    _auth = auth

  fun route[D: Any val](metric_name: String, source_ts: U64, data: D,
    producer: (CreditFlowProducer ref | None),
    // incoming envelope
    i_origin: Origin tag, i_msg_uid: U128, 
    i_frac_ids: None, i_seq_id: U64, i_route_id: U64,
    // outgoing envelope
    o_origin: Origin tag, o_msg_uid: U128, o_frac_ids: None,
    o_seq_id: U64): Bool
  =>
    // TODO: Remove that producer can be None
    match producer
    | let cfp: CreditFlowProducer ref =>
      let might_be_route = cfp.route_to(_target)
      match might_be_route
      | let r: Route =>
        let delivery_msg = ForwardMsg[D](
          _target_proxy_address.step_id,
          _worker_name, source_ts, data, metric_name,
          _target_proxy_address, 
          o_msg_uid, o_frac_ids)

        r.forward(delivery_msg)
        false
      else
        // TODO: What do we do if we get None?
        true
      end
    else
      true
    end

  fun copy_with_new_target_id(target_id: U128): ProxyRouter val =>
    ProxyRouter(_worker_name, 
      _target, 
      ProxyAddress(_target_proxy_address.worker, target_id), 
      _auth)

  fun routes(): Array[CreditFlowConsumerStep] val =>
    recover val [_target] end

class DataRouter
  let _data_routes: Map[U128, CreditFlowConsumerStep tag] val

  new val create(data_routes: Map[U128, CreditFlowConsumerStep tag] val =
    recover Map[U128, CreditFlowConsumerStep tag] end)
  =>
    _data_routes = data_routes

  fun route(d_msg: DeliveryMsg val, origin: Origin tag, seq_id: U64) =>
    try
      let target_id = d_msg.target_id()
      //TODO: create and deliver envelope
      d_msg.deliver(_data_routes(target_id), origin, seq_id)
      false
    else
      true
    end

  fun replay_route(r_msg: ReplayableDeliveryMsg val, origin: Origin tag,
    seq_id: U64)
  =>
    try
      let target_id = r_msg.target_id()
      //TODO: create and deliver envelope
      r_msg.replay_deliver(_data_routes(target_id), origin, seq_id)
      false
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

trait AugmentablePartitionRouter[Key: (Hashable val & Equatable[Key] val)] is
  PartitionRouter
  fun clone_and_augment[NewIn: Any val](
    new_p_function: PartitionFunction[NewIn, Key] val): PartitionRouter val

//!!
interface Sy
  fun symbol(): String

class LocalPartitionRouter[In: Any val,
  Key: (Hashable val & Equatable[Key] val)] is AugmentablePartitionRouter[Key]
  let _local_map: Map[U128, Step] val
  let _step_ids: Map[Key, U128] val
  let _partition_routes: Map[Key, (Step | ProxyRouter val)] val
  let _partition_function: PartitionFunction[In, Key] val
  let _default_router: (Router val | None)

  new val create(local_map': Map[U128, Step] val,
    s_ids: Map[Key, U128] val,
    partition_routes: Map[Key, (Step | ProxyRouter val)] val,
    partition_function: PartitionFunction[In, Key] val,
    default_router: (Router val | None) = None)
  =>
    _local_map = local_map'
    _step_ids = s_ids
    _partition_routes = partition_routes
    _partition_function = partition_function
    _default_router = default_router

  fun route[D: Any val](metric_name: String, source_ts: U64, data: D,
    producer: (CreditFlowProducer ref | None),
    // incoming envelope
    i_origin: Origin tag, i_msg_uid: U128, 
    i_frac_ids: None, i_seq_id: U64, i_route_id: U64,
    // outgoing envelope
    o_origin: Origin tag, o_msg_uid: U128, o_frac_ids: None,
    o_seq_id: U64): Bool
  =>
    match data
    // TODO: Using an untyped input wrapper that returns an Any val might
    // cause perf slowdowns and should be reevaluated.
    | let iw: InputWrapper val =>
      match iw.input()
      | let input: In =>
        let key = _partition_function(input)
        try
          match _partition_routes(key)
          | let s: Step =>
            // TODO: Remove that producer can be None
            match producer
            | let cfp: CreditFlowProducer ref =>
              let might_be_route = cfp.route_to(s)
              match might_be_route
              | let r: Route =>
                r.run[D](metric_name, source_ts, data,
                  // hand down cfp so we can update route_id
                  cfp,
                  // outgoing envelope
                  o_origin, o_msg_uid, o_frac_ids, o_seq_id)
                false
              else
                // TODO: What do we do if we get None?
                true
              end
            else
              true
            end    
          | let p: ProxyRouter val =>
            p.route[D](metric_name, source_ts, data, producer,
              // incoming envelope
              i_origin, i_msg_uid, i_frac_ids, i_seq_id, i_route_id,
              // outgoing envelope
              o_origin, o_msg_uid, o_frac_ids, o_seq_id)
          else
            // No step or proxyrouter
            true
          end
        else
          // There is no entry for this key!
          // If there's a default, use that
          match _default_router
          | let r: Router val =>
            r.route[In](metric_name, source_ts, input, producer,
              // incoming envelope
              i_origin, i_msg_uid, i_frac_ids, i_seq_id, i_route_id,
              // outgoing envelope
              o_origin, o_msg_uid, o_frac_ids, o_seq_id)
          else
            true
          end
        end
      else
        // InputWrapper doesn't wrap In
        true
      end
    else
      true
    end

  fun clone_and_augment[NewIn: Any val](
    new_p_function: PartitionFunction[NewIn, Key] val): PartitionRouter val
  =>
    LocalPartitionRouter[NewIn, Key](_local_map, _step_ids, _partition_routes, 
      new_p_function)

  fun routes(): Array[CreditFlowConsumerStep] val =>
    // TODO: CREDITFLOW we need to handle proxies once we have boundary actors
    let cs: Array[CreditFlowConsumerStep] trn =
      recover Array[CreditFlowConsumerStep] end

    for s in _partition_routes.values() do
      match s
      | let step: Step =>
        cs.push(step)
      end
    end

    consume cs

  fun local_map(): Map[U128, Step] val => _local_map

// // TODO: Remove this by updating market-test once single prestate work
// // is finished
// class StateAddressesRouter[In: Any val, 
//   Key: (Hashable val & Equatable[Key] val)]
//   let _state_addresses: StateAddresses val
//   let _partition_function: PartitionFunction[In, Key] val
  
//   new val create(state_addresses: StateAddresses val,
//     partition_function: PartitionFunction[In, Key] val) 
//   =>
//     _state_addresses = state_addresses
//     _partition_function = partition_function
    
//   fun route[D: Any val](metric_name: String, source_ts: U64, data: D,
//     producer: (CreditFlowProducer ref | None),
//     // incoming envelope
//     i_origin: Origin tag, i_msg_uid: U128, 
//     i_frac_ids: None, i_seq_id: U64, i_route_id: U64,
//     // outgoing envelope
//     o_origin: Origin tag, o_msg_uid: U128, o_frac_ids: None,
//     o_seq_id: U64): Bool
//   =>
//     match data
//     | let iw: InputWrapper val =>
//       let key = _partition_function(iw.input())
//       match _state_addresses(key)
//       | let s: Step =>
//         // TODO: Remove that producer can be None
//         match producer
//         | let cfp: CreditFlowProducer ref =>
//           let might_be_route = cfp.route_to(s)
//           match might_be_route
//           | let r: Route =>
//             r.run[D](metric_name, source_ts, data,
//               // hand down cfp so we can update route_id
//               cfp,
//               // outgoing envelope
//               o_origin, o_msg_uid, o_frac_ids, o_seq_id)
//             false
//           else
//             // TODO: What do we do if we get None?
//             true
//           end
//         else
//           true
//         end
//       | let p: ProxyRouter val =>
//         p.route[D](metric_name, source_ts, data, producer,
//           // incoming envelope
//           i_origin, i_msg_uid, i_frac_ids, i_seq_id, i_route_id,
//           // outgoing envelope
//           o_origin, o_msg_uid, o_frac_ids, o_seq_id)
//       else
//         true    
//       end
//     else
//       @printf[I32]("Wrong input type to partition router!\n".cstring())
//       true
//     end

//   fun routes(): Array[CreditFlowConsumerStep] val =>
//     _state_addresses.steps()
