/*

Copyright 2017 The Wallaroo Authors.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
 implied. See the License for the specific language governing
 permissions and limitations under the License.

*/

use "collections"
use "net"
use "wallaroo_labs/equality"
use "wallaroo_labs/mort"
use "wallaroo/core/boundary"
use "wallaroo/core/common"
use "wallaroo/ent/data_receiver"
use "wallaroo/ent/rebalancing"
use "wallaroo/ent/router_registry"
use "wallaroo/core/invariant"
use "wallaroo/core/messages"
use "wallaroo/core/routing"
use "wallaroo/core/sink"

interface val Router
  fun route[D: Any val](metric_name: String, pipeline_time_spent: U64, data: D,
    producer: Producer ref, i_msg_uid: MsgId, frac_ids: FractionalMessageId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64): (Bool, Bool, U64)
  fun routes(): Array[Consumer] val
  fun routes_not_in(router: Router): Array[Consumer] val

class val EmptyRouter
  fun route[D: Any val](metric_name: String, pipeline_time_spent: U64, data: D,
    producer: Producer ref, i_msg_uid: MsgId, frac_ids: FractionalMessageId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64): (Bool, Bool, U64)
  =>
    (true, true, latest_ts)

  fun routes(): Array[Consumer] val =>
    recover Array[Consumer] end

  fun routes_not_in(router: Router): Array[Consumer] val =>
    recover Array[Consumer] end

class val DirectRouter
  let _target: Consumer

  new val create(target: Consumer) =>
    _target = target

  fun route[D: Any val](metric_name: String, pipeline_time_spent: U64, data: D,
    producer: Producer ref, i_msg_uid: MsgId, frac_ids: FractionalMessageId,
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
        i_msg_uid, frac_ids,
        latest_ts, metrics_id, worker_ingress_ts)
      (false, keep_sending, latest_ts)
    else
      // TODO: What do we do if we get None?
      (true, true, latest_ts)
    end


  fun routes(): Array[Consumer] val =>
    recover [_target] end

  fun routes_not_in(router: Router): Array[Consumer] val =>
    if router.routes().contains(_target) then
      recover Array[Consumer] end
    else
      recover [_target] end
    end

  fun has_sink(): Bool =>
    match _target
    | let tcp: Sink =>
      true
    else
      false
    end

class val ProxyRouter is Equatable[ProxyRouter]
  let _worker_name: String
  let _target: OutgoingBoundary
  let _target_proxy_address: ProxyAddress
  let _auth: AmbientAuth

  new val create(worker_name: String, target: OutgoingBoundary,
    target_proxy_address: ProxyAddress, auth: AmbientAuth)
  =>
    _worker_name = worker_name
    _target = target
    _target_proxy_address = target_proxy_address
    _auth = auth

  fun route[D: Any val](metric_name: String, pipeline_time_spent: U64, data: D,
    producer: Producer ref, msg_uid: MsgId, frac_ids: FractionalMessageId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64): (Bool, Bool, U64)
  =>
    ifdef "trace" then
      @printf[I32]("Rcvd msg at ProxyRouter\n".cstring())
    end

    let might_be_route = producer.route_to(_target)
    match might_be_route
    | let r: Route =>
      ifdef "trace" then
        @printf[I32]("ProxyRouter found Route\n".cstring())
      end
      let delivery_msg = ForwardMsg[D](
        _target_proxy_address.step_id,
        _worker_name, data, metric_name,
        _target_proxy_address,
        msg_uid, frac_ids)

      let keep_sending = r.forward(delivery_msg, pipeline_time_spent, producer,
        latest_ts, metrics_id, metric_name, worker_ingress_ts)

      (false, keep_sending, latest_ts)
    else
      Fail()
      (true, true, latest_ts)
    end

  fun copy_with_new_target_id(target_id: U128): ProxyRouter =>
    ProxyRouter(_worker_name, _target,
      ProxyAddress(_target_proxy_address.worker, target_id), _auth)

  fun routes(): Array[Consumer] val =>
    try
      recover [_target as Consumer] end
    else
      Fail()
      recover Array[Consumer] end
    end

  fun routes_not_in(router: Router): Array[Consumer] val =>
    if router.routes().contains(_target) then
      recover Array[Consumer] end
    else
      try
        recover [_target as Consumer] end
      else
        Fail()
        recover Array[Consumer] end
      end
    end

  fun update_proxy_address(pa: ProxyAddress): ProxyRouter =>
    ProxyRouter(_worker_name, _target, pa, _auth)

  fun val update_boundary(ob: box->Map[String, OutgoingBoundary]):
    ProxyRouter
  =>
    try
      let new_target = ob(_target_proxy_address.worker)?
      if new_target isnt _target then
        ProxyRouter(_worker_name, new_target, _target_proxy_address, _auth)
      else
        this
      end
    else
      this
    end

  fun proxy_address(): ProxyAddress =>
    _target_proxy_address

  fun eq(that: box->ProxyRouter): Bool =>
    (_worker_name == that._worker_name) and
      (_target is that._target) and
      (_target_proxy_address == that._target_proxy_address)

// An OmniRouter is a router that can route a message to any Consumer in the
// system by using a target id.
trait val OmniRouter is Equatable[OmniRouter]
  fun route_with_target_id[D: Any val](target_id: U128,
    metric_name: String, pipeline_time_spent: U64, data: D,
    producer: Producer ref, msg_uid: MsgId, frac_ids: FractionalMessageId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64): (Bool, Bool, U64)

  fun val add_boundary(w: String, boundary: OutgoingBoundary): OmniRouter

  fun val update_route_to_proxy(id: U128,
    pa: ProxyAddress): OmniRouter

  fun val update_route_to_step(id: U128,
    step: Consumer): OmniRouter

  fun routes(): Array[Consumer] val

  fun routes_not_in(router: OmniRouter): Array[Consumer] val

class val EmptyOmniRouter is OmniRouter
  fun route_with_target_id[D: Any val](target_id: U128,
    metric_name: String, pipeline_time_spent: U64, data: D,
    producer: Producer ref, msg_uid: MsgId, frac_ids: FractionalMessageId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64): (Bool, Bool, U64)
  =>
    @printf[I32]("route_with_target_id() was called on an EmptyOmniRouter\n"
      .cstring())
    (true, true, latest_ts)

  fun val add_boundary(w: String,
    boundary: OutgoingBoundary): OmniRouter
  =>
    this

  fun val update_route_to_proxy(id: U128, pa: ProxyAddress):
    OmniRouter
  =>
    this

  fun val update_route_to_step(id: U128,
    step: Consumer): OmniRouter
  =>
    this

  fun routes(): Array[Consumer] val =>
    recover Array[Consumer] end

  fun routes_not_in(router: OmniRouter): Array[Consumer] val =>
    recover Array[Consumer] end

  fun eq(that: box->OmniRouter): Bool =>
    false

class val StepIdRouter is OmniRouter
  let _worker_name: String
  let _data_routes: Map[U128, Consumer] val
  let _step_map: Map[U128, (ProxyAddress | U128)] val
  let _outgoing_boundaries: Map[String, OutgoingBoundary] val
  let _stateless_partitions: Map[U128, StatelessPartitionRouter] val

  new val create(worker_name: String,
    data_routes: Map[U128, Consumer] val,
    step_map: Map[U128, (ProxyAddress | U128)] val,
    outgoing_boundaries: Map[String, OutgoingBoundary] val,
    stateless_partitions: Map[U128, StatelessPartitionRouter] val)
  =>
    _worker_name = worker_name
    _data_routes = data_routes
    _step_map = step_map
    _outgoing_boundaries = outgoing_boundaries
    _stateless_partitions = stateless_partitions

  fun route_with_target_id[D: Any val](target_id: U128,
    metric_name: String, pipeline_time_spent: U64, data: D,
    producer: Producer ref, msg_uid: MsgId, frac_ids: FractionalMessageId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64): (Bool, Bool, U64)
  =>
    ifdef "trace" then
      @printf[I32]("Rcvd msg at OmniRouter\n".cstring())
    end

    if _data_routes.contains(target_id) then
      try
        let target = _data_routes(target_id)?

        let might_be_route = producer.route_to(target)
        match might_be_route
        | let r: Route =>
          ifdef "trace" then
            @printf[I32]("OmniRouter found Route to Step\n".cstring())
          end
          let keep_sending = r.run[D](metric_name, pipeline_time_spent, data,
            producer, msg_uid, frac_ids,
            latest_ts, metrics_id, worker_ingress_ts)

          (false, keep_sending, latest_ts)
        else
          // No route for this target
          Fail()
          (true, true, latest_ts)
        end
      else
        Unreachable()
        (true, true, latest_ts)
      end
    else
      // This target_id step exists on another worker
      if _step_map.contains(target_id) then
        try
          match _step_map(target_id)?
          | let pa: ProxyAddress =>
            try
              // Try as though we have a reference to the right boundary
              let boundary = _outgoing_boundaries(pa.worker)?
              let might_be_route = producer.route_to(boundary)
              match might_be_route
              | let r: Route =>
                ifdef "trace" then
                  @printf[I32]("OmniRouter found Route to OutgoingBoundary\n"
                    .cstring())
                end
                let delivery_msg = ForwardMsg[D](pa.step_id,
                  _worker_name, data, metric_name,
                  pa, msg_uid, frac_ids)

                let keep_sending = r.forward(delivery_msg, pipeline_time_spent,
                  producer, latest_ts, metrics_id,
                  metric_name, worker_ingress_ts)
                (false, keep_sending, latest_ts)
              else
                // We don't have a route to this boundary
                ifdef debug then
                  @printf[I32]("OmniRouter had no Route\n".cstring())
                end
                Fail()
                (true, true, latest_ts)
              end
            else
              // We don't have a reference to the right outgoing boundary
              ifdef debug then
                @printf[I32](("OmniRouter has no reference to " +
                  " OutgoingBoundary\n").cstring())
              end
              Fail()
              (true, true, latest_ts)
            end
          | let sink_id: U128 =>
            (true, true, latest_ts)
          else
            Fail()
            (true, true, latest_ts)
          end
        else
          Fail()
          (true, true, latest_ts)
        end
      else
        try
          _stateless_partitions(target_id)?.route[D](metric_name,
            pipeline_time_spent, data, producer, msg_uid, frac_ids,
            latest_ts, metrics_id, worker_ingress_ts)
        else
          // Apparently this target_id does not refer to a valid step id
          ifdef debug then
            @printf[I32](("OmniRouter: target id does not refer to valid " +
              " step id\n").cstring())
          end
          Fail()
          (true, true, latest_ts)
        end
      end
    end

  fun val add_boundary(w: String, boundary: OutgoingBoundary): OmniRouter =>
    // TODO: Using persistent maps for our fields would make this more
    // efficient
    let new_outgoing_boundaries = recover trn Map[String, OutgoingBoundary] end
    for (k, v) in _outgoing_boundaries.pairs() do
      new_outgoing_boundaries(k) = v
    end
    new_outgoing_boundaries(w) = boundary
    StepIdRouter(_worker_name, _data_routes, _step_map,
      consume new_outgoing_boundaries, _stateless_partitions)

  fun val update_route_to_proxy(id: U128, pa: ProxyAddress): OmniRouter =>
    // TODO: Using persistent maps for our fields would make this more
    // efficient
    let new_data_routes = recover trn Map[U128, Consumer] end
    let new_step_map = recover trn Map[U128, (ProxyAddress | U128)] end
    for (k, v) in _data_routes.pairs() do
      if k != id then new_data_routes(k) = v end
    end
    for (k, v) in _step_map.pairs() do
      new_step_map(k) = v
    end
    new_step_map(id) = pa

    StepIdRouter(_worker_name, consume new_data_routes, consume new_step_map,
      _outgoing_boundaries, _stateless_partitions)

  fun val update_route_to_step(id: U128, step: Consumer): OmniRouter =>
    // TODO: Using persistent maps for our fields would make this more
    // efficient
    let new_data_routes = recover trn Map[U128, Consumer] end
    let new_step_map = recover trn Map[U128, (ProxyAddress | U128)] end
    for (k, v) in _data_routes.pairs() do
      if k != id then new_data_routes(k) = v end
    end
    new_data_routes(id) = step

    for (k, v) in _step_map.pairs() do
      new_step_map(k) = v
    end
    new_step_map(id) = ProxyAddress(_worker_name, id)

    StepIdRouter(_worker_name, consume new_data_routes, consume new_step_map,
      _outgoing_boundaries, _stateless_partitions)

  fun routes(): Array[Consumer] val =>
    let diff = recover trn Array[Consumer] end
    for r in _data_routes.values() do
      diff.push(r)
    end
    consume diff

  fun routes_not_in(router: OmniRouter): Array[Consumer] val =>
    let diff = recover trn Array[Consumer] end
    let other_routes = router.routes()
    for r in _data_routes.values() do
      if not other_routes.contains(r) then diff.push(r) end
    end
    consume diff

  fun eq(that: box->OmniRouter): Bool =>
    match that
    | let o: box->StepIdRouter =>
      (_worker_name == o._worker_name) and
        MapTagEquality[U128, Consumer](_data_routes,
          o._data_routes) and
        MapEquality2[U128, ProxyAddress, U128](_step_map, o._step_map) and
        MapTagEquality[String, OutgoingBoundary](_outgoing_boundaries,
          o._outgoing_boundaries) and
        MapEquality[U128, StatelessPartitionRouter](_stateless_partitions,
          o._stateless_partitions)
    else
      false
    end

class val DataRouter is Equatable[DataRouter]
  let _data_routes: Map[U128, Consumer] val
  let _target_ids_to_route_ids: Map[U128, RouteId] val
  let _route_ids_to_target_ids: Map[RouteId, U128] val

  new val create(data_routes: Map[U128, Consumer] val =
      recover Map[U128, Consumer] end)
  =>
    _data_routes = data_routes
    var route_id: RouteId = 0
    let keys: Array[U128] = keys.create()
    let tid_map = recover trn Map[U128, RouteId] end
    let rid_map = recover trn Map[RouteId, U128] end
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

  new val with_route_ids(data_routes: Map[U128, Consumer] val,
    target_ids_to_route_ids: Map[U128, RouteId] val,
    route_ids_to_target_ids: Map[RouteId, U128] val)
  =>
    _data_routes = data_routes
    _target_ids_to_route_ids = target_ids_to_route_ids
    _route_ids_to_target_ids = route_ids_to_target_ids

  fun step_for_id(id: U128): Consumer ? =>
    _data_routes(id)?

  fun route(d_msg: DeliveryMsg, pipeline_time_spent: U64,
    producer: DataReceiver ref, seq_id: SeqId, latest_ts: U64, metrics_id: U16,
    worker_ingress_ts: U64)
  =>
    ifdef "trace" then
      @printf[I32]("Rcvd msg at DataRouter\n".cstring())
    end
    let target_id = d_msg.target_id()
    try
      let target = _data_routes(target_id)?
      ifdef "trace" then
        @printf[I32]("DataRouter found Step\n".cstring())
      end
      try
        let route_id = _target_ids_to_route_ids(target_id)?
        d_msg.deliver(pipeline_time_spent, target, producer, seq_id, route_id,
          latest_ts, metrics_id, worker_ingress_ts)
        ifdef "resilience" then
          producer.bookkeeping(route_id, seq_id)
        end
      else
        // This shouldn't happen. If we have a route, we should have a route
        // id.
        Fail()
      end
    else
      Fail()
    end

  fun replay_route(r_msg: ReplayableDeliveryMsg, pipeline_time_spent: U64,
    producer: DataReceiver ref, seq_id: SeqId, latest_ts: U64, metrics_id: U16,
    worker_ingress_ts: U64)
  =>
    try
      let target_id = r_msg.target_id()
      let route_id = _target_ids_to_route_ids(target_id)?
      //TODO: create and deliver envelope
      r_msg.replay_deliver(pipeline_time_spent, _data_routes(target_id)?,
        producer, seq_id, route_id, latest_ts, metrics_id, worker_ingress_ts)
      ifdef "resilience" then
        producer.bookkeeping(route_id, seq_id)
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
        let t_id = _route_ids_to_target_ids(r_id)?
        _data_routes(t_id)?.request_ack()
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

  fun routes(): Array[Consumer] val =>
    let rs = recover trn Array[Consumer] end
    for step in _data_routes.values() do
      rs.push(step)
    end
    consume rs

  fun remove_route(id: U128): DataRouter =>
    // TODO: Using persistent maps for our fields would make this much more
    // efficient
    let new_data_routes = recover trn Map[U128, Consumer] end
    for (k, v) in _data_routes.pairs() do
      if k != id then new_data_routes(k) = v end
    end
    let new_tid_map = recover trn Map[U128, RouteId] end
    for (k, v) in _target_ids_to_route_ids.pairs() do
      if k != id then new_tid_map(k) = v end
    end
    let new_rid_map = recover trn Map[RouteId, U128] end
    for (k, v) in _route_ids_to_target_ids.pairs() do
      if v != id then new_rid_map(k) = v end
    end
    DataRouter.with_route_ids(consume new_data_routes,
      consume new_tid_map, consume new_rid_map)

  fun add_route(id: U128, target: Consumer): DataRouter =>
    // TODO: Using persistent maps for our fields would make this much more
    // efficient
    let new_data_routes = recover trn Map[U128, Consumer] end
    for (k, v) in _data_routes.pairs() do
      new_data_routes(k) = v
    end
    new_data_routes(id) = target

    let new_tid_map = recover trn Map[U128, RouteId] end
    var highest_route_id: RouteId = 0
    for (k, v) in _target_ids_to_route_ids.pairs() do
      new_tid_map(k) = v
      if v > highest_route_id then highest_route_id = v end
    end
    let new_route_id = highest_route_id + 1
    new_tid_map(id) = new_route_id

    let new_rid_map = recover trn Map[RouteId, U128] end
    for (k, v) in _route_ids_to_target_ids.pairs() do
      new_rid_map(k) = v
    end
    new_rid_map(new_route_id) = id

    DataRouter.with_route_ids(consume new_data_routes,
      consume new_tid_map, consume new_rid_map)

  fun eq(that: box->DataRouter): Bool =>
    MapTagEquality[U128, Consumer](_data_routes, that._data_routes) and
      MapEquality[U128, RouteId](_target_ids_to_route_ids,
        that._target_ids_to_route_ids) //and
      // MapEquality[RouteId, U128](_route_ids_to_target_ids,
      //   that._route_ids_to_target_ids)

  fun migrate_state(target_id: U128, s: ByteSeq val) =>
    try
      let target = _data_routes(target_id)?
      target.receive_state(s)
    else
      Fail()
    end

trait val PartitionRouter is (Router & Equatable[PartitionRouter])
  fun local_map(): Map[StepId, Step] val
  fun register_routes(router: Router, route_builder: RouteBuilder)
  fun update_route[K: (Hashable val & Equatable[K] val)](
    raw_k: K, target: (Step | ProxyRouter)): PartitionRouter ?
  fun rebalance_steps(boundary: OutgoingBoundary, target_worker: String,
    worker_count: USize, state_name: String, router_registry: RouterRegistry)
  fun size(): USize
  fun update_boundaries(ob: box->Map[String, OutgoingBoundary]):
    PartitionRouter
  fun blueprint(): PartitionRouterBlueprint

trait val AugmentablePartitionRouter[Key: (Hashable val & Equatable[Key] val)]
  is PartitionRouter
  fun clone_and_set_input_type[NewIn: Any val](
    new_p_function: PartitionFunction[NewIn, Key] val,
    new_default_router: (Router | None) = None): PartitionRouter

class val LocalPartitionRouter[In: Any val,
  Key: (Hashable val & Equatable[Key] val)] is AugmentablePartitionRouter[Key]
  let _worker_name: String
  let _local_map: Map[StepId, Step] val
  let _step_ids: Map[Key, StepId] val
  let _partition_routes: Map[Key, (Step | ProxyRouter)] val
  let _partition_function: PartitionFunction[In, Key] val
  let _default_router: (Router | None)

  new val create(worker_name: String,
    local_map': Map[StepId, Step] val,
    s_ids: Map[Key, StepId] val,
    partition_routes: Map[Key, (Step | ProxyRouter)] val,
    partition_function: PartitionFunction[In, Key] val,
    default_router: (Router | None) = None)
  =>
    _worker_name = worker_name
    _local_map = local_map'
    _step_ids = s_ids
    _partition_routes = partition_routes
    _partition_function = partition_function
    _default_router = default_router

  fun size(): USize =>
    _partition_routes.size()

  fun migrate_step[K: (Hashable val & Equatable[K] val)](
    boundary: OutgoingBoundary, state_name: String,  k: K)
  =>
    match k
    | let key: Key =>
      try
        match _partition_routes(key)?
        | let s: Step => s.send_state[Key](boundary, state_name, key)
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
    producer: Producer ref, i_msg_uid: MsgId, frac_ids: FractionalMessageId,
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
          match _partition_routes(key)?
          | let s: Step =>
            let might_be_route = producer.route_to(s)
            match might_be_route
            | let r: Route =>
              ifdef "trace" then
                @printf[I32]("PartitionRouter found Route\n".cstring())
              end
              let keep_sending = r.run[D](metric_name, pipeline_time_spent,
                data, producer, i_msg_uid, frac_ids,
                latest_ts, metrics_id, worker_ingress_ts)
              (false, keep_sending, latest_ts)
            else
              // TODO: What do we do if we get None?
              (true, true, latest_ts)
            end
          | let p: ProxyRouter =>
            p.route[D](metric_name, pipeline_time_spent, data, producer,
              i_msg_uid, frac_ids, latest_ts, metrics_id, worker_ingress_ts)
          else
            // No step or proxyrouter
            (true, true, latest_ts)
          end
        else
          // There is no entry for this key!
          // If there's a default, use that
          match _default_router
          | let r: Router =>
            ifdef "trace" then
              @printf[I32](("PartitionRouter sending to default step as " +
                "there was no entry for key\n").cstring())
            end
            r.route[In](metric_name, pipeline_time_spent, input, producer,
              i_msg_uid, frac_ids, latest_ts, metrics_id, worker_ingress_ts)
          else
            ifdef debug then
              match key
              | let k: Stringable val =>
                @printf[I32](("LocalPartitionRouter.route: No entry for " +
                "key %s and no default\n\n").cstring(), k.string().cstring())
              else
                @printf[I32](("LocalPartitionRouter.route: No entry for " +
                "this key and no default\n\n").cstring())
              end
            end
            (true, true, latest_ts)
          end
        end
      else
        // InputWrapper doesn't wrap In
        ifdef debug then
          @printf[I32](("LocalPartitionRouter.route: InputWrapper doesn't " +
            "contain data of type In\n").cstring())
        end
        (true, true, latest_ts)
      end
    else
      (true, true, latest_ts)
    end

  fun clone_and_set_input_type[NewIn: Any val](
    new_p_function: PartitionFunction[NewIn, Key] val,
    new_d_router: (Router | None) = None): PartitionRouter
  =>
    match new_d_router
    | let dr: Router =>
      LocalPartitionRouter[NewIn, Key](_worker_name, _local_map, _step_ids,
        _partition_routes, new_p_function, dr)
    else
      LocalPartitionRouter[NewIn, Key](_worker_name, _local_map, _step_ids,
        _partition_routes, new_p_function, _default_router)
    end

  fun register_routes(router: Router, route_builder: RouteBuilder) =>
    for r in _partition_routes.values() do
      match r
      | let step: Step =>
        step.register_routes(router, route_builder)
      end
    end

  fun routes(): Array[Consumer] val =>
    let cs = recover trn Array[Consumer] end

    for s in _partition_routes.values() do
      match s
      | let step: Step =>
        cs.push(step)
      end
    end

    consume cs

  fun routes_not_in(router: Router): Array[Consumer] val =>
    let diff = recover trn Array[Consumer] end
    let other_routes = router.routes()
    for r in routes().values() do
      if not other_routes.contains(r) then diff.push(r) end
    end
    consume diff

  fun local_map(): Map[StepId, Step] val => _local_map

  fun update_route[K: (Hashable val & Equatable[K] val)](
    raw_k: K, target: (Step | ProxyRouter)): PartitionRouter ?
  =>
    // TODO: Using persistent maps for our fields would make this much more
    // efficient
    match raw_k
    | let key: Key =>
      let target_id = _step_ids(key)?
      let new_local_map = recover trn Map[StepId, Step] end
      let new_partition_routes = recover trn Map[Key, (Step | ProxyRouter)] end
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
        LocalPartitionRouter[In, Key](_worker_name, consume new_local_map,
          _step_ids, consume new_partition_routes, _partition_function,
          _default_router)
      | let proxy_router: ProxyRouter =>
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
        LocalPartitionRouter[In, Key](_worker_name, consume new_local_map,
          _step_ids, consume new_partition_routes, _partition_function,
          _default_router)
      else
        error
      end
    else
      error
    end

  fun update_boundaries(ob: box->Map[String, OutgoingBoundary]):
    PartitionRouter
  =>
    let new_partition_routes = recover trn Map[Key, (Step | ProxyRouter)] end
    for (k, target) in _partition_routes.pairs() do
      match target
      | let pr: ProxyRouter =>
        new_partition_routes(k) = pr.update_boundary(ob)
      else
        new_partition_routes(k) = target
      end
    end
    LocalPartitionRouter[In, Key](_worker_name, _local_map, _step_ids,
      consume new_partition_routes, _partition_function, _default_router)

  fun rebalance_steps(boundary: OutgoingBoundary, target_worker: String,
    worker_count: USize, state_name: String, router_registry: RouterRegistry)
  =>
    try
      var left_to_send = PartitionRebalancer.step_count_to_send(size(),
        _local_map.size(), worker_count - 1)
      if left_to_send > 0 then
        let steps_to_migrate = Array[(Key, StepId, Step)]
        for (key, target) in _partition_routes.pairs() do
          if left_to_send == 0 then break end
          match target
          | let s: Step =>
            let step_id = _step_ids(key)?
            steps_to_migrate.push((key, step_id, s))
            left_to_send = left_to_send - 1
          end
        end
        if left_to_send > 0 then Fail() end
        @printf[I32]("^^Migrating %lu steps to %s\n".cstring(),
          steps_to_migrate.size(), target_worker.cstring())
        for (_, step_id, _) in steps_to_migrate.values() do
          router_registry.add_to_step_waiting_list(step_id)
        end
        for (key, step_id, step) in steps_to_migrate.values() do
          step.send_state[Key](boundary, state_name, key)
          router_registry.move_stateful_step_to_proxy[Key](step_id,
            ProxyAddress(target_worker, step_id), key, state_name)
        end
      else
        // There is nothing to send over. Can we immediately resume processing?
        router_registry.try_to_resume_processing_immediately()
      end
      ifdef debug then
        Invariant(left_to_send == 0)
      end
    else
      Fail()
    end

  fun blueprint(): PartitionRouterBlueprint =>
    let partition_addresses = recover trn Map[Key, ProxyAddress] end
    try
      for (k, v) in _partition_routes.pairs() do
        match v
        | let s: Step =>
          let pr = ProxyAddress(_worker_name, _step_ids(k)?)
          partition_addresses(k) = pr
        | let pr: ProxyRouter =>
          partition_addresses(k) = pr.proxy_address()
        end
      end
    else
      Fail()
    end

    LocalPartitionRouterBlueprint[In, Key](_step_ids,
      consume partition_addresses, _partition_function)

  fun eq(that: box->PartitionRouter): Bool =>
    match that
    | let o: box->LocalPartitionRouter[In, Key] =>
      MapTagEquality[StepId, Step](_local_map, o._local_map) and
        MapEquality[Key, StepId](_step_ids, o._step_ids) and
        _partition_routes_eq(o._partition_routes) and
        (_partition_function is o._partition_function) and
        (_default_router is o._default_router)
    else
      false
    end

  fun _partition_routes_eq(
    opr: Map[Key, (Step | ProxyRouter)] val): Bool
  =>
    try
      // These equality checks depend on the identity of Step or ProxyRouter
      // val which means we don't expect them to be created independently
      if _partition_routes.size() != opr.size() then return false end
      for (k, v) in _partition_routes.pairs() do
        match v
        | let s: Step =>
          if opr(k)? isnt v then return false end
        | let pr: ProxyRouter =>
          match opr(k)?
          | let pr2: ProxyRouter =>
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

trait val PartitionRouterBlueprint
  fun build_router(worker_name: String,
    outgoing_boundaries: Map[String, OutgoingBoundary] val,
    auth: AmbientAuth): PartitionRouter

class val LocalPartitionRouterBlueprint[In: Any val,
  Key: (Hashable val & Equatable[Key] val)] is PartitionRouterBlueprint
  let _step_ids: Map[Key, StepId] val
  let _partition_addresses: Map[Key, ProxyAddress] val
  let _partition_function: PartitionFunction[In, Key] val

  new val create(s_ids: Map[Key, StepId] val,
    partition_addresses: Map[Key, ProxyAddress] val,
    partition_function: PartitionFunction[In, Key] val)
  =>
    _step_ids = s_ids
    _partition_addresses = partition_addresses
    _partition_function = partition_function

  fun build_router(worker_name: String,
    outgoing_boundaries: Map[String, OutgoingBoundary] val,
    auth: AmbientAuth): PartitionRouter
  =>
    let partition_routes = recover trn Map[Key, (Step | ProxyRouter)] end
    try
      for (k, pa) in _partition_addresses.pairs() do
        let proxy_router = ProxyRouter(pa.worker,
          outgoing_boundaries(pa.worker)?, pa, auth)
        partition_routes(k) = proxy_router
      end
    else
      Fail()
    end
    // Since default routers are deprecated, this does not
    // support them (passing None in instead).
    LocalPartitionRouter[In, Key](worker_name,
      recover val Map[StepId, Step] end,
      _step_ids, consume partition_routes, _partition_function,
      None)

trait val StatelessPartitionRouter is (Router &
  Equatable[StatelessPartitionRouter])
  fun partition_id(): U128
  fun register_routes(router: Router, route_builder: RouteBuilder)
  fun update_route(partition_id': U64, target: (Step | ProxyRouter)):
    StatelessPartitionRouter ?
  fun size(): USize
  fun update_boundaries(ob: box->Map[String, OutgoingBoundary]):
    StatelessPartitionRouter
  fun blueprint(): StatelessPartitionRouterBlueprint

class val LocalStatelessPartitionRouter is StatelessPartitionRouter
  let _partition_id: U128
  let _worker_name: String
  // Maps stateless partition id to step id
  let _step_ids: Map[U64, StepId] val
  // Maps stateless partition id to step or proxy router
  let _partition_routes: Map[U64, (Step | ProxyRouter)] val
  let _partition_size: USize

  new val create(p_id: U128, worker_name: String, s_ids: Map[U64, StepId] val,
    partition_routes: Map[U64, (Step | ProxyRouter)] val)
  =>
    _partition_id = p_id
    _worker_name = worker_name
    _step_ids = s_ids
    _partition_routes = partition_routes
    _partition_size = _partition_routes.size()

  fun size(): USize =>
    _partition_size

  fun partition_id(): U128 =>
    _partition_id

  fun route[D: Any val](metric_name: String, pipeline_time_spent: U64, data: D,
    producer: Producer ref, i_msg_uid: MsgId, frac_ids: FractionalMessageId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64): (Bool, Bool, U64)
  =>
    ifdef "trace" then
      @printf[I32]("Rcvd msg at StatelessPartitionRouter\n".cstring())
    end
    let stateless_partition_id = producer.current_sequence_id() % size().u64()

    try
      match _partition_routes(stateless_partition_id)?
      | let s: Step =>
        let might_be_route = producer.route_to(s)
        match might_be_route
        | let r: Route =>
          ifdef "trace" then
            @printf[I32]("StatelessPartitionRouter found Route\n".cstring())
          end
          let keep_sending = r.run[D](metric_name, pipeline_time_spent, data,
            producer, i_msg_uid, frac_ids, latest_ts, metrics_id,
            worker_ingress_ts)
          (false, keep_sending, latest_ts)
        else
          // TODO: What do we do if we get None?
          (true, true, latest_ts)
        end
      | let p: ProxyRouter =>
        p.route[D](metric_name, pipeline_time_spent, data, producer,
          i_msg_uid, frac_ids, latest_ts, metrics_id, worker_ingress_ts)
      else
        // No step or proxyrouter
        (true, true, latest_ts)
      end
    else
      // Can't find route
      (true, true, latest_ts)
    end

  fun register_routes(router: Router, route_builder: RouteBuilder) =>
    for r in _partition_routes.values() do
      match r
      | let step: Step =>
        step.register_routes(router, route_builder)
      end
    end

  fun routes(): Array[Consumer] val =>
    let cs: SetIs[Consumer] = cs.create()

    for s in _partition_routes.values() do
      match s
      | let step: Step =>
        cs.set(step)
      | let pr: ProxyRouter =>
        for r in pr.routes().values() do
          cs.set(r)
        end
      end
    end

    let to_send = recover trn Array[Consumer] end
    for c in cs.values() do
      to_send.push(c)
    end

    consume to_send

  fun routes_not_in(router: Router): Array[Consumer] val =>
    let diff = recover trn Array[Consumer] end
    let other_routes = router.routes()
    for r in routes().values() do
      if not other_routes.contains(r) then diff.push(r) end
    end
    consume diff

  fun update_route(partition_id': U64, target: (Step | ProxyRouter)):
    StatelessPartitionRouter ?
  =>
    // TODO: Using persistent maps for our fields would make this much more
    // efficient
    let target_id = _step_ids(partition_id')?
    let new_partition_routes = recover trn Map[U64, (Step | ProxyRouter)] end
    match target
    | let step: Step =>
      for (p_id, t) in _partition_routes.pairs() do
        if p_id == partition_id' then
          new_partition_routes(p_id) = target
        else
          new_partition_routes(p_id) = t
        end
      end
      LocalStatelessPartitionRouter(_partition_id, _worker_name, _step_ids,
        consume new_partition_routes)
    | let proxy_router: ProxyRouter =>
      for (p_id, t) in _partition_routes.pairs() do
        if p_id == partition_id' then
          new_partition_routes(p_id) = target
        else
          new_partition_routes(p_id) = t
        end
      end
      LocalStatelessPartitionRouter(_partition_id, _worker_name, _step_ids,
        consume new_partition_routes)
    else
      error
    end

  fun update_boundaries(ob: box->Map[String, OutgoingBoundary]):
    StatelessPartitionRouter
  =>
    let new_partition_routes = recover trn Map[U64, (Step | ProxyRouter)] end
    for (p_id, target) in _partition_routes.pairs() do
      match target
      | let pr: ProxyRouter =>
        new_partition_routes(p_id) = pr.update_boundary(ob)
      else
        new_partition_routes(p_id) = target
      end
    end
    LocalStatelessPartitionRouter(_partition_id, _worker_name, _step_ids,
      consume new_partition_routes)

  fun blueprint(): StatelessPartitionRouterBlueprint =>
   let partition_addresses = recover trn Map[U64, ProxyAddress] end
    try
      for (k, v) in _partition_routes.pairs() do
        match v
        | let s: Step =>
          let pr = ProxyAddress(_worker_name, _step_ids(k)?)
          partition_addresses(k) = pr
        | let pr: ProxyRouter =>
          partition_addresses(k) = pr.proxy_address()
        end
      end
    else
      Fail()
    end

    LocalStatelessPartitionRouterBlueprint(_partition_id, _step_ids,
      consume partition_addresses)

  fun eq(that: box->StatelessPartitionRouter): Bool =>
    match that
    | let o: box->LocalStatelessPartitionRouter =>
        MapEquality[U64, U128](_step_ids, o._step_ids) and
        _partition_routes_eq(o._partition_routes)
    else
      false
    end

  fun _partition_routes_eq(opr: Map[U64, (Step | ProxyRouter)] val): Bool
  =>
    try
      // These equality checks depend on the identity of Step or ProxyRouter
      // val which means we don't expect them to be created independently
      if _partition_routes.size() != opr.size() then return false end
      for (p_id, v) in _partition_routes.pairs() do
        match v
        | let s: Step =>
          if opr(p_id)? isnt v then return false end
        | let pr: ProxyRouter =>
          match opr(p_id)?
          | let pr2: ProxyRouter =>
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

trait val StatelessPartitionRouterBlueprint
  fun build_router(worker_name: String,
    outgoing_boundaries: Map[String, OutgoingBoundary] val,
    auth: AmbientAuth): StatelessPartitionRouter

class val LocalStatelessPartitionRouterBlueprint
  is StatelessPartitionRouterBlueprint
  let _partition_id: U128
  let _step_ids: Map[U64, StepId] val
  let _partition_addresses: Map[U64, ProxyAddress] val

  new val create(p_id: U128, s_ids: Map[U64, StepId] val,
    partition_addresses: Map[U64, ProxyAddress] val)
  =>
    _partition_id = p_id
    _step_ids = s_ids
    _partition_addresses = partition_addresses

  fun build_router(worker_name: String,
    outgoing_boundaries: Map[String, OutgoingBoundary] val,
    auth: AmbientAuth): StatelessPartitionRouter
  =>
    let partition_routes = recover trn Map[U64, (Step | ProxyRouter)] end
    try
      for (k, pa) in _partition_addresses.pairs() do
        let proxy_router = ProxyRouter(pa.worker,
          outgoing_boundaries(pa.worker)?, pa, auth)
        partition_routes(k) = proxy_router
      end
    else
      Fail()
    end
    LocalStatelessPartitionRouter(_partition_id, worker_name, _step_ids,
      consume partition_routes)
