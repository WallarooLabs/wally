use "collections"
use "net"
use "sendence/equality"
use "wallaroo/boundary"
use "wallaroo/fail"
use "wallaroo/messages"
use "wallaroo/routing"
use "wallaroo/tcp_sink"

interface Router
  fun route[D: Any val](metric_name: String, pipeline_time_spent: U64, data: D,
    producer: Producer ref,
    i_origin: Producer, i_msg_uid: U128,
    i_frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64): (Bool, Bool, U64)
  fun routes(): Array[ConsumerStep] val

interface RouterBuilder
  fun apply(): Router val

class EmptyRouter
  fun route[D: Any val](metric_name: String, pipeline_time_spent: U64, data: D,
    producer: Producer ref,
    i_origin: Producer, i_msg_uid: U128,
    i_frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64): (Bool, Bool, U64)
  =>
    (true, true, latest_ts)

  fun routes(): Array[ConsumerStep] val =>
    recover val Array[ConsumerStep] end

class DirectRouter
  let _target: ConsumerStep tag

  new val create(target: ConsumerStep tag) =>
    _target = target

  fun route[D: Any val](metric_name: String, pipeline_time_spent: U64, data: D,
    producer: Producer ref,
    i_origin: Producer, i_msg_uid: U128,
    i_frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64): (Bool, Bool, U64)
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
      let keep_sending = r.run[D](metric_name, pipeline_time_spent, data,
        // hand down producer so we can call _next_sequence_id()
        producer,
        // incoming envelope
        i_origin, i_msg_uid, i_frac_ids, i_seq_id, i_route_id,
        latest_ts, metrics_id, worker_ingress_ts)
      (false, keep_sending, latest_ts)
    else
      // TODO: What do we do if we get None?
      (true, true, latest_ts)
    end


  fun routes(): Array[ConsumerStep] val =>
    recover val [_target] end

  fun has_sink(): Bool =>
    match _target
    | let tcp: TCPSink =>
      true
    else
      false
    end

class ProxyRouter is Equatable[ProxyRouter]
  let _worker_name: String
  let _target: ConsumerStep tag
  let _target_proxy_address: ProxyAddress val
  let _auth: AmbientAuth

  new val create(worker_name: String, target: ConsumerStep tag,
    target_proxy_address: ProxyAddress val, auth: AmbientAuth)
  =>
    _worker_name = worker_name
    _target = target
    _target_proxy_address = target_proxy_address
    _auth = auth

  fun route[D: Any val](metric_name: String, pipeline_time_spent: U64, data: D,
    producer: Producer ref,
    i_origin: Producer, msg_uid: U128,
    i_frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64): (Bool, Bool, U64)
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
        _worker_name, data, metric_name,
        _target_proxy_address,
        msg_uid, i_frac_ids)

      let keep_sending = r.forward(delivery_msg, pipeline_time_spent, producer,
        i_origin, msg_uid, i_frac_ids, i_seq_id, i_route_id, latest_ts,
        metrics_id, metric_name, worker_ingress_ts)

      (false, keep_sending, latest_ts)
    else
      // TODO: What do we do if we get None?
      (true, true, latest_ts)
    end

  fun copy_with_new_target_id(target_id: U128): ProxyRouter val =>
    ProxyRouter(_worker_name,
      _target,
      ProxyAddress(_target_proxy_address.worker, target_id),
      _auth)

  fun routes(): Array[ConsumerStep] val =>
    recover val [_target] end

  fun update_proxy_address(pa: ProxyAddress val): ProxyRouter val =>
    ProxyRouter(_worker_name, _target, pa, _auth)

  fun eq(that: box->ProxyRouter): Bool =>
    (_worker_name == that._worker_name) and
      (_target is that._target) and
      (_target_proxy_address == that._target_proxy_address)

trait OmniRouter is Equatable[OmniRouter]
  fun route_with_target_id[D: Any val](target_id: U128,
    metric_name: String, pipeline_time_spent: U64, data: D,
    producer: Producer ref,
    i_origin: Producer, msg_uid: U128,
    i_frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64): (Bool, Bool, U64)
  fun val add_boundary(w: String, boundary: OutgoingBoundary): OmniRouter val
  fun val update_route_to_proxy(id: U128,
    pa: ProxyAddress val): OmniRouter val
  fun val update_route_to_step(id: U128,
    step: ConsumerStep tag): OmniRouter val

class val EmptyOmniRouter is OmniRouter
  fun route_with_target_id[D: Any val](target_id: U128,
    metric_name: String, pipeline_time_spent: U64, data: D,
    producer: Producer ref,
    i_origin: Producer, msg_uid: U128,
    i_frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64): (Bool, Bool, U64)
  =>
    @printf[I32]("route_with_target_id() was called on an EmptyOmniRouter\n".cstring())
    (true, true, latest_ts)

  fun val add_boundary(w: String,
    boundary: OutgoingBoundary): OmniRouter val
  =>
    this

  fun val update_route_to_proxy(id: U128, pa: ProxyAddress val):
    OmniRouter val
  =>
    this

  fun val update_route_to_step(id: U128,
    step: ConsumerStep tag): OmniRouter val
  =>
    this

  fun eq(that: box->OmniRouter): Bool =>
    false

class StepIdRouter is OmniRouter
  let _worker_name: String
  let _data_routes: Map[U128, ConsumerStep tag] val
  let _step_map: Map[U128, (ProxyAddress val | U128)] val
  let _outgoing_boundaries: Map[String, OutgoingBoundary] val

  new val create(worker_name: String,
    data_routes: Map[U128, ConsumerStep tag] val,
    step_map: Map[U128, (ProxyAddress val | U128)] val,
    outgoing_boundaries: Map[String, OutgoingBoundary] val)
  =>
    _worker_name = worker_name
    _data_routes = data_routes
    _step_map = step_map
    _outgoing_boundaries = outgoing_boundaries

  fun route_with_target_id[D: Any val](target_id: U128,
    metric_name: String, pipeline_time_spent: U64, data: D,
    producer: Producer ref,
    i_origin: Producer, msg_uid: U128,
    i_frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64): (Bool, Bool, U64)
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
        let keep_sending = r.run[D](metric_name, pipeline_time_spent, data,
          // hand down producer so we can update route_id
          producer,
          // incoming envelope
          i_origin, msg_uid, i_frac_ids, i_seq_id, i_route_id,
          latest_ts, metrics_id, worker_ingress_ts)

        (false, keep_sending, latest_ts)
      else
        // No route for this target
        (true, true, latest_ts)
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
                @printf[I32]("OmniRouter found Route to OutgoingBoundary\n"
                  .cstring())
              end
              let delivery_msg = ForwardMsg[D](pa.step_id,
                _worker_name, data, metric_name,
                pa, msg_uid, i_frac_ids)

              let keep_sending = r.forward(delivery_msg, pipeline_time_spent,
                producer, i_origin, msg_uid, i_frac_ids,
                i_seq_id, i_route_id, latest_ts, metrics_id, metric_name,
                worker_ingress_ts)
              (false, keep_sending, latest_ts)
            else
              // We don't have a route to this boundary
              ifdef debug then
                @printf[I32]("OmniRouter had no Route\n".cstring())
              end
              (true, true, latest_ts)
            end
          else
            // We don't have a reference to the right outgoing boundary
            ifdef debug then
              @printf[I32]("OmniRouter has no reference to OutgoingBoundary\n".cstring())
            end
            (true, true, latest_ts)
          end
        | let sink_id: U128 =>
          (true, true, latest_ts)
        else
          (true, true, latest_ts)
        end
      else
        // Apparently this target_id does not refer to a valid step id
        ifdef debug then
          @printf[I32]("OmniRouter: target id does not refer to valid step id\n".cstring())
        end
        (true, true, latest_ts)
      end
    end

    fun val add_boundary(w: String,
      boundary: OutgoingBoundary): OmniRouter val
    =>
      // TODO: Using persistent maps for our fields would make this more
      // efficient
      let new_outgoing_boundaries: Map[String, OutgoingBoundary] trn =
        recover Map[String, OutgoingBoundary] end
      for (k, v) in _outgoing_boundaries.pairs() do
        new_outgoing_boundaries(k) = v
      end
      new_outgoing_boundaries(w) = boundary
      StepIdRouter(_worker_name, _data_routes, _step_map,
        consume new_outgoing_boundaries)

    fun val update_route_to_proxy(id: U128,
      pa: ProxyAddress val): OmniRouter val
    =>
      // TODO: Using persistent maps for our fields would make this more
      // efficient
      let new_data_routes: Map[U128, ConsumerStep tag] trn =
        recover Map[U128, ConsumerStep tag] end
      let new_step_map: Map[U128, (ProxyAddress val | U128)] trn =
        recover Map[U128, (ProxyAddress val | U128)] end
      for (k, v) in _data_routes.pairs() do
        if k != id then new_data_routes(k) = v end
      end

      for (k, v) in _step_map.pairs() do
        new_step_map(k) = v
      end
      new_step_map(id) = pa

      StepIdRouter(_worker_name, consume new_data_routes, consume new_step_map,
        _outgoing_boundaries)

    fun val update_route_to_step(id: U128,
      step: ConsumerStep tag): OmniRouter val
    =>
      // TODO: Using persistent maps for our fields would make this more
      // efficient
      let new_data_routes: Map[U128, ConsumerStep tag] trn =
        recover Map[U128, ConsumerStep tag] end
      let new_step_map: Map[U128, (ProxyAddress val | U128)] trn =
        recover Map[U128, (ProxyAddress val | U128)] end
      for (k, v) in _data_routes.pairs() do
        if k != id then new_data_routes(k) = v end
      end
      new_data_routes(id) = step

      for (k, v) in _step_map.pairs() do
        new_step_map(k) = v
      end
      new_step_map(id) = ProxyAddress(_worker_name, id)

      StepIdRouter(_worker_name, consume new_data_routes, consume new_step_map,
        _outgoing_boundaries)

  fun eq(that: box->OmniRouter): Bool =>
    match that
    | let o: box->StepIdRouter =>
      (_worker_name == o._worker_name) and
        MapTagEquality[U128, ConsumerStep tag](_data_routes,
          o._data_routes) and
        MapEquality2[U128, ProxyAddress val, U128](_step_map, o._step_map) and
        MapTagEquality[String, OutgoingBoundary](_outgoing_boundaries,
          o._outgoing_boundaries)
    else
      false
    end

class DataRouter is Equatable[DataRouter]
  let _data_routes: Map[U128, ConsumerStep tag] val
  let _target_ids_to_route_ids: Map[U128, RouteId] val
  let _route_ids_to_target_ids: Map[RouteId, U128] val

  new val create(data_routes: Map[U128, ConsumerStep tag] val =
      recover Map[U128, ConsumerStep tag] end)
  =>
    _data_routes = data_routes
    var route_id: RouteId = 0
    let keys: Array[U128] = keys.create()
    let tid_map: Map[U128, RouteId] trn =
      recover Map[U128, RouteId] end
    let rid_map: Map[RouteId, U128] trn =
      recover Map[RouteId, U128] end
    for step_id in _data_routes.keys() do
      keys.push(step_id)
    end
    for key in Sort[Array[U128], U128](keys).values() do
      route_id = route_id + 1
      tid_map(key) = route_id
    end
    for (t_id, r_id) in tid_map.pairs() do
      rid_map(r_id) = t_id
    end
    _target_ids_to_route_ids = consume tid_map
    _route_ids_to_target_ids = consume rid_map

  new val with_route_ids(data_routes: Map[U128, ConsumerStep tag] val,
    target_ids_to_route_ids: Map[U128, RouteId] val,
    route_ids_to_target_ids: Map[RouteId, U128] val)
  =>
    _data_routes = data_routes
    _target_ids_to_route_ids = target_ids_to_route_ids
    _route_ids_to_target_ids = route_ids_to_target_ids

  fun route(d_msg: DeliveryMsg val, pipeline_time_spent: U64,
    origin: DataReceiver ref, seq_id: SeqId, latest_ts: U64, metrics_id: U16,
    worker_ingress_ts: U64)
  =>
    ifdef "trace" then
      @printf[I32]("Rcvd msg at DataRouter\n".cstring())
    end
    let target_id = d_msg.target_id()
    try
      let target = _data_routes(target_id)
      ifdef "trace" then
        @printf[I32]("DataRouter found Step\n".cstring())
      end
      try
        let route_id = _target_ids_to_route_ids(target_id)
        d_msg.deliver(pipeline_time_spent, target, origin, seq_id, route_id,
          latest_ts, metrics_id, worker_ingress_ts)
        ifdef "resilience" then
          origin.bookkeeping(route_id, seq_id)
        end
        false
      else
        // This shouldn't happen. If we have a route, we should have a route
        // id.
        Fail()
        false
      end
    else
      ifdef debug then
        @printf[I32]("DataRouter failed to find route\n".cstring())
      end
      Fail()
      true
    end

  fun replay_route(r_msg: ReplayableDeliveryMsg val, pipeline_time_spent: U64,
    origin: DataReceiver ref, seq_id: SeqId, latest_ts: U64, metrics_id: U16,
    worker_ingress_ts: U64)
  =>
    try
      let target_id = r_msg.target_id()
      let route_id = _target_ids_to_route_ids(target_id)
      //TODO: create and deliver envelope
      r_msg.replay_deliver(pipeline_time_spent, _data_routes(target_id),
        origin, seq_id, route_id, latest_ts, metrics_id, worker_ingress_ts)
      ifdef "resilience" then
        origin.bookkeeping(route_id, seq_id)
      end
      false
    else
      ifdef debug then
        @printf[I32]("DataRouter failed to find route on replay\n".cstring())
      end
      Fail()
      true
    end

  fun register_producer(producer: Producer) =>
    for step in _data_routes.values() do
      step.register_producer(producer)
    end

  fun unregister_producer(producer: Producer) =>
    for step in _data_routes.values() do
      step.unregister_producer(producer)
    end

  fun request_ack(r_ids: Array[RouteId]) =>
    try
      for r_id in r_ids.values() do
        let t_id = _route_ids_to_target_ids(r_id)
        _data_routes(t_id).request_ack()
      end
    else
      Fail()
    end

  fun route_ids(): Array[RouteId] =>
    let ids: Array[RouteId] = ids.create()
    for id in _target_ids_to_route_ids.values() do
      ids.push(id)
    end
    ids

  fun routes(): Array[ConsumerStep] val =>
    // TODO: CREDITFLOW - real implmentation?
    recover val Array[ConsumerStep] end

  fun remove_route(id: U128): DataRouter val =>
    // TODO: Using persistent maps for our fields would make this much more
    // efficient
    let new_data_routes: Map[U128, ConsumerStep tag] trn =
      recover Map[U128, ConsumerStep tag] end
    for (k, v) in _data_routes.pairs() do
      if k != id then new_data_routes(k) = v end
    end
    let new_tid_map: Map[U128, RouteId] trn =
      recover Map[U128, RouteId] end
    for (k, v) in _target_ids_to_route_ids.pairs() do
      if k != id then new_tid_map(k) = v end
    end
    let new_rid_map: Map[RouteId, U128] trn =
      recover Map[RouteId, U128] end
    for (k, v) in _route_ids_to_target_ids.pairs() do
      if v != id then new_rid_map(k) = v end
    end
    DataRouter.with_route_ids(consume new_data_routes,
      consume new_tid_map, consume new_rid_map)

  fun add_route(id: U128, target: ConsumerStep tag): DataRouter val =>
    // TODO: Using persistent maps for our fields would make this much more
    // efficient
    let new_data_routes: Map[U128, ConsumerStep tag] trn =
      recover Map[U128, ConsumerStep tag] end
    for (k, v) in _data_routes.pairs() do
      new_data_routes(k) = v
    end
    new_data_routes(id) = target

    let new_tid_map: Map[U128, RouteId] trn =
      recover Map[U128, RouteId] end
    var highest_route_id: RouteId = 0
    for (k, v) in _target_ids_to_route_ids.pairs() do
      new_tid_map(k) = v
      if v > highest_route_id then highest_route_id = v end
    end
    let new_route_id = highest_route_id + 1
    new_tid_map(id) = new_route_id

    let new_rid_map: Map[RouteId, U128] trn =
      recover Map[RouteId, U128] end
    for (k, v) in _route_ids_to_target_ids.pairs() do
      new_rid_map(k) = v
    end
    new_rid_map(new_route_id) = id

    DataRouter.with_route_ids(consume new_data_routes,
      consume new_tid_map, consume new_rid_map)

  fun eq(that: box->DataRouter): Bool =>
    MapTagEquality[U128, ConsumerStep tag](_data_routes, that._data_routes) and
      MapEquality[U128, RouteId](_target_ids_to_route_ids,
        that._target_ids_to_route_ids) //and
      // MapEquality[RouteId, U128](_route_ids_to_target_ids,
      //   that._route_ids_to_target_ids)

  fun migrate_state(target_id: U128, s: ByteSeq val) =>
    try
      let target = _data_routes(target_id)
      target.receive_state(s)
    else
      Fail()
    end

trait PartitionRouter is (Router & Equatable[PartitionRouter])
  fun local_map(): Map[U128, Step] val
  fun register_routes(router: Router val, route_builder: RouteBuilder val)
  fun update_route[K: (Hashable val & Equatable[K] val)](
    raw_k: K, target: (Step | ProxyRouter val)): PartitionRouter val ?

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

  fun migrate_step[K: (Hashable val & Equatable[K] val)](
    boundary: OutgoingBoundary, state_name: String,  k: K)
  =>
    match k
    | let key: Key =>
      try
        match _partition_routes(key)
        | let s: Step => s.send_state(boundary, state_name, k)
        //TODO: update routing with a Proxy to the new location
        else
          Fail()
        end
      else
        Fail()
      end
    else
      Fail()
    end

  fun route[D: Any val](metric_name: String, pipeline_time_spent: U64, data: D,
    producer: Producer ref,
    i_origin: Producer, i_msg_uid: U128,
    i_frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64): (Bool, Bool, U64)
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
              let keep_sending =r.run[D](metric_name, pipeline_time_spent, data,
                // hand down producer so we can update route_id
                producer,
                // incoming envelope
                i_origin, i_msg_uid, i_frac_ids, i_seq_id, i_route_id,
                latest_ts, metrics_id, worker_ingress_ts)
              (false, keep_sending, latest_ts)
            else
              // TODO: What do we do if we get None?
              (true, true, latest_ts)
            end
          | let p: ProxyRouter val =>
            p.route[D](metric_name, pipeline_time_spent, data, producer,
              i_origin, i_msg_uid, i_frac_ids, i_seq_id, i_route_id,
              latest_ts, metrics_id, worker_ingress_ts)
          else
            // No step or proxyrouter
            (true, true, latest_ts)
          end
        else
          // There is no entry for this key!
          // If there's a default, use that
          match _default_router
          | let r: Router val =>
            ifdef "trace" then
              @printf[I32]("PartitionRouter sending to default step as there was no entry for key\n".cstring())
            end
            r.route[In](metric_name, pipeline_time_spent, input, producer,
              i_origin, i_msg_uid, i_frac_ids, i_seq_id, i_route_id,
              latest_ts, metrics_id, worker_ingress_ts)
          else
            ifdef debug then
              @printf[I32](("LocalPartitionRouter.route: No entry for this" +
                "key and no default\n\n").cstring())
            end
            (true, true, latest_ts)
          end
        end
      else
        // InputWrapper doesn't wrap In
        ifdef debug then
          @printf[I32]("LocalPartitionRouter.route: InputWrapper doesn't contain data of type In\n".cstring())
        end
        (true, true, latest_ts)
      end
    else
      (true, true, latest_ts)
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

  fun routes(): Array[ConsumerStep] val =>
    // TODO: CREDITFLOW we need to handle proxies once we have boundary actors
    let cs: Array[ConsumerStep] trn =
      recover Array[ConsumerStep] end

    for s in _partition_routes.values() do
      match s
      | let step: Step =>
        cs.push(step)
      end
    end

    consume cs

  fun local_map(): Map[U128, Step] val => _local_map

  fun update_route[K: (Hashable val & Equatable[K] val)](
    raw_k: K, target: (Step | ProxyRouter val)): PartitionRouter val ?
  =>
    // TODO: Using persistent maps for our fields would make this much more
    // efficient
    match raw_k
    | let key: Key =>
      let target_id = _step_ids(key)
      let new_local_map: Map[U128, Step] trn = recover Map[U128, Step] end
      let new_partition_routes: Map[Key, (Step | ProxyRouter val)] trn =
        recover Map[Key, (Step | ProxyRouter val)] end
      match target
      | let step: Step =>
        for (id, s) in _local_map.pairs() do
          new_local_map(id) = s
        end
        new_local_map(target_id) = step
        for (k, t) in _partition_routes.pairs() do
          if k == key then
            new_partition_routes(k) = target
          else
            new_partition_routes(k) = t
          end
        end
        LocalPartitionRouter[In, Key](consume new_local_map, _step_ids,
          consume new_partition_routes, _partition_function, _default_router)
      | let proxy_router: ProxyRouter val =>
        for (id, s) in _local_map.pairs() do
          if id != target_id then new_local_map(id) = s end
        end
        for (k, t) in _partition_routes.pairs() do
          if k == key then
            new_partition_routes(k) = target
          else
            new_partition_routes(k) = t
          end
        end
        LocalPartitionRouter[In, Key](consume new_local_map, _step_ids,
          consume new_partition_routes, _partition_function, _default_router)
      else
        error
      end
    else
      error
    end

  fun eq(that: box->PartitionRouter): Bool =>
    match that
    | let o: box->LocalPartitionRouter[In, Key] =>
      MapTagEquality[U128, Step](_local_map, o._local_map) and
        MapEquality[Key, U128](_step_ids, o._step_ids) and
        _partition_routes_eq(o._partition_routes) and
        (_partition_function is o._partition_function) and
        (_default_router is o._default_router)
    else
      false
    end

  fun _partition_routes_eq(
    opr: Map[Key, (Step | ProxyRouter val)] val): Bool
  =>
    try
      // These equality checks depend on the identity of Step or ProxyRouter
      // val which means we don't expect them to be created independently
      if _partition_routes.size() != opr.size() then return false end
      for (k, v) in _partition_routes.pairs() do
        match v
        | let s: Step =>
          if opr(k) isnt v then return false end
        | let pr: ProxyRouter val =>
          match opr(k)
          | let pr2: ProxyRouter val =>
            pr == pr2
          else
            false
          end
        else
          false
        end
      end
      true
    else
      false
    end
