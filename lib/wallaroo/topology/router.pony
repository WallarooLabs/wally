use "collections"
use "net"
use "wallaroo/backpressure"
use "wallaroo/boundary"
use "wallaroo/messages"
use "wallaroo/tcp-sink"

interface Router
  fun route[D: Any val](metric_name: String, source_ts: U64, data: D,
    producer: Producer ref,
    i_origin: Origin, i_msg_uid: U128,
    i_frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId): Bool
  fun routes(): Array[CreditFlowConsumerStep] val

interface RouterBuilder
  fun apply(): Router val

class EmptyRouter
  fun route[D: Any val](metric_name: String, source_ts: U64, data: D,
    producer: Producer ref,
    i_origin: Origin, i_msg_uid: U128,
    i_frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId): Bool
  =>
    true

  fun routes(): Array[CreditFlowConsumerStep] val =>
    recover val Array[CreditFlowConsumerStep] end

class DirectRouter
  let _target: CreditFlowConsumerStep tag

  new val create(target: CreditFlowConsumerStep tag) =>
    _target = target

  fun route[D: Any val](metric_name: String, source_ts: U64, data: D,
    producer: Producer ref,
    i_origin: Origin, i_msg_uid: U128,
    i_frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId): Bool
  =>
    ifdef "trace" then
      @printf[I32]("Rcvd msg at DirectRouter\n".cstring())
    end

    let might_be_route = producer.route_to(_target)
    match might_be_route
    | let r: Route =>
      ifdef "trace" then
        @printf[I32]("DirectRouter found Route\n".cstring())
      end
      r.run[D](metric_name, source_ts, data,
        // hand down producer so we can call _next_sequence_id()
        producer,
        // incoming envelope
        i_origin, i_msg_uid, i_frac_ids, i_seq_id, i_route_id)
      false
    else
      // TODO: What do we do if we get None?
      true
    end


  fun routes(): Array[CreditFlowConsumerStep] val =>
    recover val [_target] end

  fun has_sink(): Bool =>
    match _target
    | let tcp: TCPSink =>
      true
    else
      false
    end

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
    producer: Producer ref,
    i_origin: Origin, msg_uid: U128,
    i_frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId): Bool
  =>
    ifdef "trace" then
      @printf[I32]("Rcvd msg at ProxyRouter\n".cstring())
    end

    let might_be_route = producer.route_to(_target)
    match might_be_route
    | let r: Route =>
      ifdef "trace" then
        @printf[I32]("DirectRouter found Route\n".cstring())
      end
      let delivery_msg = ForwardMsg[D](
        _target_proxy_address.step_id,
        _worker_name, source_ts, data, metric_name,
        _target_proxy_address,
        msg_uid, i_frac_ids)

      r.forward(delivery_msg, producer, i_origin, msg_uid, i_frac_ids,
        i_seq_id, i_route_id)

      false
    else
      // TODO: What do we do if we get None?
      true
    end

  fun copy_with_new_target_id(target_id: U128): ProxyRouter val =>
    ProxyRouter(_worker_name,
      _target,
      ProxyAddress(_target_proxy_address.worker, target_id),
      _auth)

  fun routes(): Array[CreditFlowConsumerStep] val =>
    recover val [_target] end

trait OmniRouter
  fun route_with_target_id[D: Any val](target_id: U128,
    metric_name: String, source_ts: U64, data: D,
    producer: Producer ref,
    i_origin: Origin, msg_uid: U128,
    i_frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId): Bool

class EmptyOmniRouter is OmniRouter
  fun route_with_target_id[D: Any val](target_id: U128,
    metric_name: String, source_ts: U64, data: D,
    producer: Producer ref,
    i_origin: Origin, msg_uid: U128,
    i_frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId): Bool
  =>
    @printf[I32]("route_with_target_id() was called on an EmptyOmniRouter\n".cstring())
    true

class StepIdRouter is OmniRouter
  let _worker_name: String
  let _data_routes: Map[U128, CreditFlowConsumerStep tag] val
  let _step_map: Map[U128, (ProxyAddress val | U128)] val
  let _outgoing_boundaries: Map[String, OutgoingBoundary] val

  new val create(worker_name: String,
    data_routes: Map[U128, CreditFlowConsumerStep tag] val,
    step_map: Map[U128, (ProxyAddress val | U128)] val,
    outgoing_boundaries: Map[String, OutgoingBoundary] val)
  =>
    _worker_name = worker_name
    _data_routes = data_routes
    _step_map = step_map
    _outgoing_boundaries = outgoing_boundaries

  fun route_with_target_id[D: Any val](target_id: U128,
    metric_name: String, source_ts: U64, data: D,
    producer: Producer ref,
    i_origin: Origin, msg_uid: U128,
    i_frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId): Bool
  =>
    ifdef "trace" then
      @printf[I32]("Rcvd msg at OmniRouter\n".cstring())
    end

    try
      // Try as though this target_id step exists on this worker
      let target = _data_routes(target_id)

      let might_be_route = producer.route_to(target)
      match might_be_route
      | let r: Route =>
        ifdef "trace" then
          @printf[I32]("OmniRouter found Route to Step\n".cstring())
        end
        r.run[D](metric_name, source_ts, data,
          // hand down producer so we can update route_id
          producer,
          // incoming envelope
          i_origin, msg_uid, i_frac_ids, i_seq_id, i_route_id)

        false
      else
        // No route for this target
        true
      end
    else
      // This target_id step exists on another worker
      try
        match _step_map(target_id)
        | let pa: ProxyAddress val =>
          try
            // Try as though we have a reference to the right boundary
            let boundary = _outgoing_boundaries(pa.worker)
            let might_be_route = producer.route_to(boundary)
            match might_be_route
            | let r: Route =>
              ifdef "trace" then
                @printf[I32]("OmniRouter found Route to OutgoingBoundary\n".cstring())
              end
              let delivery_msg = ForwardMsg[D](pa.step_id,
                _worker_name, source_ts, data, metric_name,
                pa, msg_uid, i_frac_ids)

              r.forward(delivery_msg, producer, i_origin, msg_uid, i_frac_ids,
                i_seq_id, i_route_id)
              false
            else
              // We don't have a route to this boundary
              ifdef debug then
                @printf[I32]("OmniRouter had no Route\n".cstring())
              end
              true
            end
          else
            // We don't have a reference to the right outgoing boundary
            ifdef debug then
              @printf[I32]("OmniRouter has no reference to OutgoingBoundary\n".cstring())
            end
            true
          end
        | let sink_id: U128 =>
          true
        else
          true
        end
      else
        // Apparently this target_id does not refer to a valid step id
        ifdef debug then
          @printf[I32]("OmniRouter: target id does not refer to valid step id\n".cstring())
        end
        true
      end
    end

class DataRouter
  let _data_routes: Map[U128, CreditFlowConsumerStep tag] val

  new val create(data_routes: Map[U128, CreditFlowConsumerStep tag] val =
      recover Map[U128, CreditFlowConsumerStep tag] end)
  =>
    _data_routes = data_routes

  fun route(d_msg: DeliveryMsg val, origin: Origin, seq_id: SeqId) =>
    ifdef "trace" then
      @printf[I32]("Rcvd msg at DataRouter\n".cstring())
    end
    let target_id = d_msg.target_id()
    try
      let target = _data_routes(target_id)
      ifdef "trace" then
        @printf[I32]("DataRouter found Step\n".cstring())
      end
      d_msg.deliver(target, origin, seq_id)
      false
    else
      ifdef debug then
        @printf[I32]("DataRouter failed to find route\n".cstring())
      end
      true
    end

  fun replay_route(r_msg: ReplayableDeliveryMsg val, origin: Origin,
    seq_id: SeqId)
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
  fun register_routes(router: Router val, route_builder: RouteBuilder val)

trait AugmentablePartitionRouter[Key: (Hashable val & Equatable[Key] val)] is
  PartitionRouter
  fun clone_and_set_input_type[NewIn: Any val](
    new_p_function: PartitionFunction[NewIn, Key] val,
    new_default_router: (Router val | None) = None): PartitionRouter val

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
    producer: Producer ref,
    i_origin: Origin, i_msg_uid: U128,
    i_frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId): Bool
  =>
    ifdef "trace" then
      @printf[I32]("Rcvd msg at PartitionRouter\n".cstring())
    end
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
            let might_be_route = producer.route_to(s)
            match might_be_route
            | let r: Route =>
              ifdef "trace" then
                @printf[I32]("PartitionRouter found Route\n".cstring())
              end
              r.run[D](metric_name, source_ts, data,
                // hand down producer so we can update route_id
                producer,
                // incoming envelope
                i_origin, i_msg_uid, i_frac_ids, i_seq_id, i_route_id)
              false
            else
              // TODO: What do we do if we get None?
              true
            end
          | let p: ProxyRouter val =>
            p.route[D](metric_name, source_ts, data, producer,
              i_origin, i_msg_uid, i_frac_ids, i_seq_id, i_route_id)
          else
            // No step or proxyrouter
            true
          end
        else
          // There is no entry for this key!
          // If there's a default, use that
          match _default_router
          | let r: Router val =>
            ifdef "trace" then
              @printf[I32]("PartitionRouter sending to default step as there was no entry for key\n".cstring())
            end
            r.route[In](metric_name, source_ts, input, producer,
              i_origin, i_msg_uid, i_frac_ids, i_seq_id, i_route_id)
          else
            ifdef debug then
              @printf[I32](("LocalPartitionRouter.route: No entry for this" +
                "key and no default\n\n").cstring())
            end
            true
          end
        end
      else
        // InputWrapper doesn't wrap In
        ifdef debug then
          @printf[I32]("LocalPartitionRouter.route: InputWrapper doesn't contain data of type In\n".cstring())
        end
        true
      end
    else
      true
    end

  fun clone_and_set_input_type[NewIn: Any val](
    new_p_function: PartitionFunction[NewIn, Key] val,
    new_d_router: (Router val | None) = None): PartitionRouter val
  =>
    match new_d_router
    | let dr: Router val =>
      LocalPartitionRouter[NewIn, Key](_local_map, _step_ids,
        _partition_routes, new_p_function, dr)
    else
      LocalPartitionRouter[NewIn, Key](_local_map, _step_ids,
        _partition_routes, new_p_function, _default_router)
    end

  fun register_routes(router: Router val, route_builder: RouteBuilder val) =>
    for r in _partition_routes.values() do
      match r
      | let step: Step =>
        step.register_routes(router, route_builder)
      end
    end

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
