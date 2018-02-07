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
use "wallaroo/core/state"

trait val Router
  fun route[D: Any val](metric_name: String, pipeline_time_spent: U64, data: D,
    producer: Producer ref, i_msg_uid: MsgId, frac_ids: FractionalMessageId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64): (Bool, U64)
  fun routes(): Array[Consumer] val
  fun routes_not_in(router: Router): Array[Consumer] val

class val EmptyRouter is Router
  fun route[D: Any val](metric_name: String, pipeline_time_spent: U64, data: D,
    producer: Producer ref, i_msg_uid: MsgId, frac_ids: FractionalMessageId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64): (Bool, U64)
  =>
    (true, latest_ts)

  fun routes(): Array[Consumer] val =>
    recover Array[Consumer] end

  fun routes_not_in(router: Router): Array[Consumer] val =>
    recover Array[Consumer] end

class val DirectRouter is Router
  let _target: Consumer

  new val create(target: Consumer) =>
    _target = target

  fun route[D: Any val](metric_name: String, pipeline_time_spent: U64, data: D,
    producer: Producer ref, i_msg_uid: MsgId, frac_ids: FractionalMessageId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64): (Bool, U64)
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
      r.run[D](metric_name, pipeline_time_spent, data,
        // hand down producer so we can call _next_sequence_id()
        producer,
        // incoming envelope
        i_msg_uid, frac_ids,
        latest_ts, metrics_id, worker_ingress_ts)
      (false, latest_ts)
    else
      // TODO: What do we do if we get None?
      (true, latest_ts)
    end

  fun routes(): Array[Consumer] val =>
    recover [_target] end

  fun routes_not_in(router: Router): Array[Consumer] val =>
    if router.routes().contains(_target) then
      recover Array[Consumer] end
    else
      recover [_target] end
    end

class val MultiRouter is Router
  let _routers: Array[DirectRouter] val

  new val create(routers: Array[DirectRouter] val) =>
    ifdef debug then
      Invariant(routers.size() > 1)
    end
    _routers = routers

  fun route[D: Any val](metric_name: String, pipeline_time_spent: U64, data: D,
    producer: Producer ref, i_msg_uid: MsgId, frac_ids: FractionalMessageId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64): (Bool, U64)
  =>
    ifdef "trace" then
      @printf[I32]("Rcvd msg at MultiRouter\n".cstring())
    end
    var is_finished = true
    for (next_o_frac_id, router) in _routers.pairs() do
      let o_frac_ids =
        match frac_ids
        | None =>
          recover val Array[U32].init(next_o_frac_id.u32(), 1) end
        | let f_ids: Array[U32 val] val =>
          recover val
            let z = Array[U32](f_ids.size() + 1)
            for f_id in f_ids.values() do
              z.push(f_id)
            end
            z.push(next_o_frac_id.u32())
            z
          end
        end
      (let is_f, _) = r.route[D](metric_name, pipeline_time_spent, data,
        // hand down producer so we can call _next_sequence_id()
        producer,
        // incoming envelope
        i_msg_uid, o_frac_ids,
        latest_ts, metrics_id, worker_ingress_ts)
      // If any of the messages sent downstream are not finished, then
      // we report that this message is not finished yet.
      if not is_f then is_finished = false end
    end
    (is_finished, latest_ts)

  fun routes(): Array[Consumer] val =>
    let r_set = SetIs[Consumer]
    for router in _routers.values() do
      for r in router.routes() do
        r_set..set(r)
      end
    end
    let rs = recover iso Array[Consumer] end
    for r in r_set.values() do
      rs.push(r)
    end
    consume rs

  fun routes_not_in(router: Router): Array[Consumer] val =>
    let rs = recover iso Array[Consumer] end
    let those_routes = router.routes()
    for r in routes().values() do
      if not those_routes.contains(r) then
        rs.push(r)
      end
    end
    consume rs

class val ProxyRouter is (Router & Equatable[ProxyRouter])
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
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64): (Bool, U64)
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

      r.forward(delivery_msg, pipeline_time_spent, producer,
        latest_ts, metrics_id, metric_name, worker_ingress_ts)

      (false, latest_ts)
    else
      Fail()
      (true, latest_ts)
    end

  fun copy_with_new_target_id(target_id: StepId): ProxyRouter =>
    ProxyRouter(_worker_name, _target,
      ProxyAddress(_target_proxy_address.worker, target_id), _auth)

  fun routes(): Array[Consumer] val =>
    recover [_target] end

  fun routes_not_in(router: Router): Array[Consumer] val =>
    if router.routes().contains(_target) then
      recover Array[Consumer] end
    else
      recover [_target] end
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
  fun route_with_target_ids[D: Any val](target_ids: Array[StepId] val,
    metric_name: String, pipeline_time_spent: U64, data: D,
    producer: Producer ref, msg_uid: MsgId, frac_ids: FractionalMessageId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64): (Bool, U64)

  fun val add_boundary(w: String, boundary: OutgoingBoundary): OmniRouter

  fun val update_route_to_proxy(id: U128,
    pa: ProxyAddress): OmniRouter

  fun val update_route_to_step(id: U128,
    step: Consumer): OmniRouter

  fun val update_stateless_partition_router(id: U128,
    pr: StatelessPartitionRouter): OmniRouter

  fun routes(): Array[Consumer] val
  fun get_outgoing_boundaries_sorted(): Array[(String, OutgoingBoundary)] val

  fun routes_not_in(router: OmniRouter): Array[Consumer] val

  fun boundaries(): Map[String, OutgoingBoundary] val

  fun blueprint(): OmniRouterBlueprint

class val EmptyOmniRouter is OmniRouter
  fun route_with_target_ids[D: Any val](target_ids: Array[StepId] val,
    metric_name: String, pipeline_time_spent: U64, data: D,
    producer: Producer ref, msg_uid: MsgId, frac_ids: FractionalMessageId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64): (Bool, U64)
  =>
    @printf[I32]("route_with_target_ids() was called on an EmptyOmniRouter\n"
      .cstring())
    (true, latest_ts)

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

  fun val update_stateless_partition_router(id: U128,
    pr: StatelessPartitionRouter): OmniRouter
  =>
    this

  fun routes(): Array[Consumer] val =>
    recover Array[Consumer] end
  fun get_outgoing_boundaries_sorted(): Array[(String, OutgoingBoundary)] val
  =>
    recover val Array[(String, OutgoingBoundary)] end

  fun routes_not_in(router: OmniRouter): Array[Consumer] val =>
    recover Array[Consumer] end

  fun eq(that: box->OmniRouter): Bool =>
    false

  fun boundaries(): Map[String, OutgoingBoundary] val =>
    recover Map[String, OutgoingBoundary] end

  fun blueprint(): OmniRouterBlueprint =>
    EmptyOmniRouterBlueprint

class val StepIdRouter is OmniRouter
  let _worker_name: String
  let _data_routes: Map[StepId, Consumer] val
  let _step_map: Map[StepId, (ProxyAddress | StepId)] val
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

  fun route_with_target_ids[D: Any val](target_ids: Array[StepId] val,
    metric_name: String, pipeline_time_spent: U64, data: D,
    producer: Producer ref, msg_uid: MsgId, frac_ids: FractionalMessageId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64): (Bool, U64)
  =>
    ifdef "trace" then
      @printf[I32]("Rcvd msg at OmniRouter\n".cstring())
    end
    ifdef debug then
      Invariant(target_ids.size() > 0)
    end
    var is_finished = true
    if target_ids.size() == 1 then
      try
        (is_finished, _) = _route_with_target_id[D](target_ids(0)?,
          metric_name, pipeline_time_spent, data, producer, msg_uid, frac_ids,
          latest_ts, metrics_id, worker_ingress_ts)
      else
        Fail()
      end
    else
      for (next_o_frac_id, next_target_id) in target_ids.pairs() do
        let o_frac_ids =
          match frac_ids
          | None =>
            recover val Array[U32].init(next_o_frac_id.u32(), 1) end
          | let f_ids: Array[U32 val] val =>
            recover val
              let z = Array[U32](f_ids.size() + 1)
              for f_id in f_ids.values() do
                z.push(f_id)
              end
              z.push(next_o_frac_id.u32())
              z
            end
          end

        (let is_f, _) = _route_with_target_id[D](next_target_id, metric_name,
          pipeline_time_spent, data, producer, msg_uid, o_frac_ids, latest_ts,
          metrics_id, worker_ingress_ts)

        // If at least one downstream message is not finished, then this
        // message is not yet finished
        if not is_f then is_finished = false end
      end
    end
    (is_finished, latest_ts)

  fun _route_with_target_id[D: Any val](target_id: StepId,
    metric_name: String, pipeline_time_spent: U64, data: D,
    producer: Producer ref, msg_uid: MsgId, frac_ids: FractionalMessageId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64): (Bool, U64)
  =>
    if _data_routes.contains(target_id) then
      try
        let target = _data_routes(target_id)?

        let might_be_route = producer.route_to(target)
        match might_be_route
        | let r: Route =>
          ifdef "trace" then
            @printf[I32]("OmniRouter found Route to Step\n".cstring())
          end
          r.run[D](metric_name, pipeline_time_spent, data,
            producer, msg_uid, frac_ids,
            latest_ts, metrics_id, worker_ingress_ts)

          (false, latest_ts)
        else
          // No route for this target
          Fail()
          (true, latest_ts)
        end
      else
        Unreachable()
        (true, latest_ts)
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

                r.forward(delivery_msg, pipeline_time_spent,
                  producer, latest_ts, metrics_id,
                  metric_name, worker_ingress_ts)
                (false, latest_ts)
              else
                // We don't have a route to this boundary
                ifdef debug then
                  @printf[I32]("OmniRouter had no Route\n".cstring())
                end
                Fail()
                (true, latest_ts)
              end
            else
              // We don't have a reference to the right outgoing boundary
              ifdef debug then
                @printf[I32](("OmniRouter has no reference to " +
                  " OutgoingBoundary\n").cstring())
              end
              Fail()
              (true, latest_ts)
            end
          | let sink_id: StepId =>
            (true, latest_ts)
          end
        else
          Fail()
          (true, latest_ts)
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
          (true, latest_ts)
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
    let new_data_routes = recover trn Map[StepId, Consumer] end
    let new_step_map = recover trn Map[StepId, (ProxyAddress | StepId)] end
    for (k, v) in _data_routes.pairs() do
      if k != id then new_data_routes(k) = v end
    end
    for (k, v) in _step_map.pairs() do
      new_step_map(k) = v
    end
    new_step_map(id) = pa

    StepIdRouter(_worker_name, consume new_data_routes, consume new_step_map,
      _outgoing_boundaries, _stateless_partitions)

  fun val update_route_to_step(id: StepId, step: Consumer): OmniRouter =>
    // TODO: Using persistent maps for our fields would make this more
    // efficient
    let new_data_routes = recover trn Map[StepId, Consumer] end
    let new_step_map = recover trn Map[StepId, (ProxyAddress | StepId)] end
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

  fun val update_stateless_partition_router(p_id: U128,
    pr: StatelessPartitionRouter): OmniRouter
  =>
    let new_stateless_partitions = recover trn
      Map[U128, StatelessPartitionRouter] end

    for (k, v) in _stateless_partitions.pairs() do
      new_stateless_partitions(k) = v
    end
    new_stateless_partitions(p_id) = pr

    StepIdRouter(_worker_name, _data_routes, _step_map,
      _outgoing_boundaries, consume new_stateless_partitions)

  fun routes(): Array[Consumer] val =>
    let diff = recover trn Array[Consumer] end
    for r in _data_routes.values() do
      diff.push(r)
    end
    consume diff

  fun get_outgoing_boundaries_sorted(): Array[(String, OutgoingBoundary)] val
  =>
    let keys = Array[String]
    for k in _outgoing_boundaries.keys() do
      keys.push(k)
    end

    let sorted_keys = Sort[Array[String], String](keys)

    let diff = recover trn Array[(String, OutgoingBoundary)] end
    for sorted_key in sorted_keys.values() do
      try
        diff.push((sorted_key, _outgoing_boundaries(sorted_key)?))
      else
        Fail()
      end
    end
    consume diff

  fun routes_not_in(router: OmniRouter): Array[Consumer] val =>
    let diff = recover trn Array[Consumer] end
    let other_routes = router.routes()
    for r in _data_routes.values() do
      if not other_routes.contains(r) then diff.push(r) end
    end
    consume diff

  fun boundaries(): Map[String, OutgoingBoundary] val =>
    _outgoing_boundaries

  fun blueprint(): OmniRouterBlueprint =>
    let new_step_map = recover trn Map[StepId, ProxyAddress] end
    for (k, v) in _step_map.pairs() do
      match v
      | let pa: ProxyAddress =>
        new_step_map(k) = pa
      | let step_id: StepId =>
        let proxy_address = ProxyAddress(_worker_name, step_id)
        new_step_map(k) = proxy_address
      end
    end
    StepIdRouterBlueprint(consume new_step_map)

  fun eq(that: box->OmniRouter): Bool =>
    match that
    | let o: box->StepIdRouter =>
      (_worker_name == o._worker_name) and
        MapTagEquality[StepId, Consumer](_data_routes,
          o._data_routes) and
        MapEquality2[StepId, ProxyAddress, StepId](_step_map, o._step_map) and
        MapTagEquality[String, OutgoingBoundary](_outgoing_boundaries,
          o._outgoing_boundaries) and
        MapEquality[U128, StatelessPartitionRouter](_stateless_partitions,
          o._stateless_partitions)
    else
      false
    end

trait val OmniRouterBlueprint
  fun build_router(worker_name: String,
    outgoing_boundaries: Map[String, OutgoingBoundary] val,
    local_sinks: Map[StepId, Consumer] val): OmniRouter

class val EmptyOmniRouterBlueprint is OmniRouterBlueprint
  fun build_router(worker_name: String,
    outgoing_boundaries: Map[String, OutgoingBoundary] val,
    local_sinks: Map[StepId, Consumer] val): OmniRouter
  =>
    EmptyOmniRouter

class val StepIdRouterBlueprint is OmniRouterBlueprint
  let _step_map: Map[StepId, ProxyAddress] val

  new val create(step_map: Map[StepId, ProxyAddress] val) =>
    _step_map = step_map

  fun build_router(worker_name: String,
    outgoing_boundaries: Map[String, OutgoingBoundary] val,
    local_sinks: Map[StepId, Consumer] val): OmniRouter
  =>
    let data_routes = recover trn Map[StepId, Consumer] end
    let new_step_map = recover trn Map[StepId, (ProxyAddress | StepId)] end
    for (k, v) in _step_map.pairs() do
      if local_sinks.contains(k) then
        try
          data_routes(k) = local_sinks(k)?
        else
          Fail()
        end
        new_step_map(k) = k
      else
        new_step_map(k) = v
      end
    end

    StepIdRouter(worker_name, consume data_routes,
      consume new_step_map, outgoing_boundaries,
      recover Map[U128, StatelessPartitionRouter] end)

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
  fun state_name(): String
  fun local_map(): Map[StepId, Step] val
  fun register_routes(router: Router, route_builder': RouteBuilder)
  fun update_route[K: (Hashable val & Equatable[K] val)](
    raw_k: K, target: (Step | ProxyRouter)): PartitionRouter ?
  fun rebalance_steps_grow(
    target_workers: Array[(String, OutgoingBoundary)] val,
    worker_count: USize, state_name': String,
    router_registry: RouterRegistry ref)
  fun rebalance_steps_shrink(
    target_workers: Array[(String, OutgoingBoundary)] val,
    state_name': String, router_registry: RouterRegistry ref)
  fun size(): USize
  fun update_boundaries(ob: box->Map[String, OutgoingBoundary]):
    PartitionRouter
  fun blueprint(): PartitionRouterBlueprint
  fun distribution_digest(): Map[String, Array[String] val] val
  fun route_builder(): RouteBuilder

trait val AugmentablePartitionRouter[Key: (Hashable val & Equatable[Key] val)]
  is PartitionRouter
  fun clone_and_set_input_type[NewIn: Any val](
    new_p_function: PartitionFunction[NewIn, Key] val): PartitionRouter

class val LocalPartitionRouter[In: Any val,
  Key: (Hashable val & Equatable[Key] val), S: State ref]
  is AugmentablePartitionRouter[Key]
  let _state_name: String
  let _worker_name: String
  let _local_map: Map[StepId, Step] val
  let _step_ids: Map[Key, StepId] val
  let _partition_routes: Map[Key, (Step | ProxyRouter)] val
  let _partition_function: PartitionFunction[In, Key] val

  new val create(state_name': String, worker_name: String,
    local_map': Map[StepId, Step] val,
    s_ids: Map[Key, StepId] val,
    partition_routes: Map[Key, (Step | ProxyRouter)] val,
    partition_function: PartitionFunction[In, Key] val)
  =>
    _state_name = state_name'
    _worker_name = worker_name
    _local_map = local_map'
    _step_ids = s_ids
    _partition_routes = partition_routes
    _partition_function = partition_function

  fun size(): USize =>
    _partition_routes.size()

  fun state_name(): String =>
    _state_name

  fun route_builder(): RouteBuilder =>
    TypedRouteBuilder[StateProcessor[S]]

  // fun migrate_step[K: (Hashable val & Equatable[K] val)](
  //   boundary: OutgoingBoundary, k: K)
  // =>
  //   match k
  //   | let key: Key =>
  //     try
  //       match _partition_routes(key)?
  //       | let s: Step => s.send_state[Key](boundary, _state_name, key)
  //       else
  //         Fail()
  //       end
  //     else
  //       Fail()
  //     end
  //   else
  //     Fail()
  //   end

  fun route[D: Any val](metric_name: String, pipeline_time_spent: U64, data: D,
    producer: Producer ref, i_msg_uid: MsgId, frac_ids: FractionalMessageId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64): (Bool, U64)
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
              r.run[D](metric_name, pipeline_time_spent,
                data, producer, i_msg_uid, frac_ids,
                latest_ts, metrics_id, worker_ingress_ts)
              (false, latest_ts)
            else
              // TODO: What do we do if we get None?
              Fail()
              (true, latest_ts)
            end
          | let p: ProxyRouter =>
            p.route[D](metric_name, pipeline_time_spent, data, producer,
              i_msg_uid, frac_ids, latest_ts, metrics_id, worker_ingress_ts)
          end
        else
          ifdef debug then
            match key
            | let k: Stringable val =>
              @printf[I32](("LocalPartitionRouter.route: No entry for " +
              "key %s\n\n").cstring(), k.string().cstring())
            else
              @printf[I32](("LocalPartitionRouter.route: No entry for " +
              "this key\n\n").cstring())
            end
          end
          (true, latest_ts)
        end
      else
        // InputWrapper doesn't wrap In
        ifdef debug then
          @printf[I32](("LocalPartitionRouter.route: InputWrapper doesn't " +
            "contain data of type In\n").cstring())
        end
        Fail()
        (true, latest_ts)
      end
    else
      Fail()
      (true, latest_ts)
    end

  fun clone_and_set_input_type[NewIn: Any val](
    new_p_function: PartitionFunction[NewIn, Key] val): PartitionRouter
  =>
    LocalPartitionRouter[NewIn, Key, S](_state_name, _worker_name,
      _local_map, _step_ids, _partition_routes, new_p_function)

  fun register_routes(router: Router, route_builder': RouteBuilder) =>
    for r in _partition_routes.values() do
      match r
      | let step: Step =>
        step.register_routes(router, route_builder')
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
        LocalPartitionRouter[In, Key, S](_state_name, _worker_name,
          consume new_local_map, _step_ids, consume new_partition_routes,
          _partition_function)
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
        LocalPartitionRouter[In, Key, S](_state_name, _worker_name,
          consume new_local_map, _step_ids, consume new_partition_routes,
          _partition_function)
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
    LocalPartitionRouter[In, Key, S](_state_name, _worker_name, _local_map,
      _step_ids, consume new_partition_routes, _partition_function)

  fun rebalance_steps_grow(
    target_workers: Array[(String, OutgoingBoundary)] val,
    worker_count: USize, state_name': String,
    router_registry: RouterRegistry ref)
  =>
    let joining_worker_count = target_workers.size()
    let former_worker_count = worker_count - joining_worker_count
    (let total_to_send, let to_send_counts) =
      PartitionRebalancer.step_counts_to_send(size(), _local_map.size(),
        former_worker_count, joining_worker_count)

    let steps_to_migrate' = steps_to_migrate(total_to_send, to_send_counts,
      target_workers)

    migrate_steps(state_name', router_registry, steps_to_migrate',
      target_workers.size())

  fun rebalance_steps_shrink(
    target_workers: Array[(String, OutgoingBoundary)] val,
    state_name': String,
    router_registry: RouterRegistry ref)
  =>
    let total_to_send = _local_map.size()
    let to_send_counts =
      PartitionRebalancer.step_counts_to_send_on_leaving(total_to_send,
        target_workers.size())

    let steps_to_migrate' = steps_to_migrate(total_to_send, to_send_counts,
      target_workers)

    migrate_steps(state_name', router_registry, steps_to_migrate',
      target_workers.size())

  fun steps_to_migrate(total_to_send: USize, to_send_counts: Array[USize] val,
    target_workers: Array[(String, OutgoingBoundary)] val):
    Array[(String, OutgoingBoundary, Key, U128, Step)]
  =>
    let steps_to_migrate' = Array[(String, OutgoingBoundary, Key, U128, Step)]
    var left_to_send = total_to_send

    try
      var worker_idx: USize = 0
      var left_to_send_to_worker: USize =
        try to_send_counts(worker_idx)? else Fail(); 0 end
      if left_to_send > 0 then
        for (key, target) in _partition_routes.pairs() do
          if left_to_send == 0 then break end
          if left_to_send_to_worker == 0 then
            worker_idx = worker_idx + 1
            left_to_send_to_worker =
              try to_send_counts(worker_idx)? else Fail(); 0 end
          end
          match target
          | let s: Step =>
            let step_id = _step_ids(key)?
            (let next_worker, let next_boundary) = target_workers(worker_idx)?
            steps_to_migrate'.push((next_worker, next_boundary, key, step_id,
              s))
            left_to_send = left_to_send - 1
            left_to_send_to_worker = left_to_send_to_worker - 1
          end
        end
        if left_to_send > 0 then Fail() end
      else
        // There is nothing to send over.
        None
      end
      ifdef debug then
        Invariant(left_to_send == 0)
      end
    else
      Fail()
    end
    steps_to_migrate'

  fun migrate_steps(state_name': String,
    router_registry: RouterRegistry ref,
    steps_to_migrate': Array[(String, OutgoingBoundary, Key, U128, Step)],
    target_worker_count: USize)
  =>
    if (steps_to_migrate'.size() == 0) then
      // There is nothing to send over. Can we immediately resume processing?
      router_registry.try_to_resume_processing_immediately()
      return
    end
    @printf[I32]("^^Migrating %lu steps to %d workers\n".cstring(),
      steps_to_migrate'.size(), target_worker_count)
    for (target_worker, boundary, key, step_id, step)
      in steps_to_migrate'.values()
    do
      router_registry.add_to_step_waiting_list(step_id)
      step.send_state[Key](boundary, state_name', key)
      router_registry.move_stateful_step_to_proxy[Key](step_id,
        ProxyAddress(target_worker, step_id), key, state_name')
      @printf[I32](
        "^^Migrating step %s to outgoing boundary %s/%lx\n".cstring(),
        step_id.string().cstring(), target_worker.cstring(), boundary)
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

    LocalPartitionRouterBlueprint[In, Key, S](_state_name, _step_ids,
      consume partition_addresses, _partition_function)

  fun distribution_digest(): Map[String, Array[String] val] val =>
    // Return a map of form {worker_name: step_ids_as_strings}
    let digest = recover iso Map[String, Array[String] val] end
    // First for this worker
    let a = recover iso Array[String] end
    for id in _local_map.keys() do
      a.push(id.string())
    end
    digest(_worker_name) = consume a
    // Now the other workers
    let others = Map[String, Array[String]]
    try
      for target in _partition_routes.values() do
        match target
        | let pr: ProxyRouter =>
          let pa = pr.proxy_address()
          if others.contains(pa.worker) then
            others(pa.worker)?.push(pa.step_id.string())
          else
            let next = Array[String]
            next.push(pa.step_id.string())
            others(pa.worker) = next
          end
        end
      end
    else
      Fail()
    end
    for (k, v) in others.pairs() do
      let next = recover iso Array[String] end
      for id in v.values() do
        next.push(id)
      end
      digest(k) = consume next
    end
    consume digest

  fun eq(that: box->PartitionRouter): Bool =>
    match that
    | let o: box->LocalPartitionRouter[In, Key, S] =>
      MapTagEquality[StepId, Step](_local_map, o._local_map) and
        MapEquality[Key, StepId](_step_ids, o._step_ids) and
        _partition_routes_eq(o._partition_routes) and
        (_partition_function is o._partition_function)
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
  Key: (Hashable val & Equatable[Key] val), S: State ref]
  is PartitionRouterBlueprint
  let _state_name: String
  let _step_ids: Map[Key, StepId] val
  let _partition_addresses: Map[Key, ProxyAddress] val
  let _partition_function: PartitionFunction[In, Key] val

  new val create(state_name: String,
    s_ids: Map[Key, StepId] val,
    partition_addresses: Map[Key, ProxyAddress] val,
    partition_function: PartitionFunction[In, Key] val)
  =>
    _state_name = state_name
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
    LocalPartitionRouter[In, Key, S](_state_name, worker_name,
      recover val Map[StepId, Step] end,
      _step_ids, consume partition_routes, _partition_function)

trait val StatelessPartitionRouter is (Router &
  Equatable[StatelessPartitionRouter])
  fun partition_id(): U128
  fun register_routes(router: Router, route_builder': RouteBuilder)
  fun update_route(partition_id': U64, target: (Step | ProxyRouter)):
    StatelessPartitionRouter ?
  fun size(): USize
  fun update_boundaries(ob: box->Map[String, OutgoingBoundary]):
    StatelessPartitionRouter
  fun calculate_shrink(remaining_workers: Array[String] val):
    StatelessPartitionRouter
  fun blueprint(): StatelessPartitionRouterBlueprint
  fun distribution_digest(): Map[String, Array[String] val] val

class val LocalStatelessPartitionRouter is StatelessPartitionRouter
  let _partition_id: U128
  let _worker_name: String
  // Maps stateless partition id to step id
  let _step_ids: Map[U64, StepId] val
  // Maps stateless partition id to step or proxy router
  let _partition_routes: Map[U64, (Step | ProxyRouter)] val
  let _steps_per_worker: USize
  let _partition_size: USize

  new val create(p_id: U128, worker_name: String, s_ids: Map[U64, StepId] val,
    partition_routes: Map[U64, (Step | ProxyRouter)] val,
    steps_per_worker: USize)
  =>
    _partition_id = p_id
    _worker_name = worker_name
    _step_ids = s_ids
    _partition_routes = partition_routes
    _steps_per_worker = steps_per_worker
    _partition_size = _partition_routes.size()

  fun size(): USize =>
    _partition_size

  fun partition_id(): U128 =>
    _partition_id

  fun route[D: Any val](metric_name: String, pipeline_time_spent: U64, data: D,
    producer: Producer ref, i_msg_uid: MsgId, frac_ids: FractionalMessageId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64): (Bool, U64)
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
          r.run[D](metric_name, pipeline_time_spent, data,
            producer, i_msg_uid, frac_ids, latest_ts, metrics_id,
            worker_ingress_ts)
          (false, latest_ts)
        else
          // TODO: What do we do if we get None?
          (true, latest_ts)
        end
      | let p: ProxyRouter =>
        p.route[D](metric_name, pipeline_time_spent, data, producer,
          i_msg_uid, frac_ids, latest_ts, metrics_id, worker_ingress_ts)
      end
    else
      // Can't find route
      (true, latest_ts)
    end

  fun register_routes(router: Router, route_builder': RouteBuilder) =>
    for r in _partition_routes.values() do
      match r
      | let step: Step =>
        step.register_routes(router, route_builder')
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
        consume new_partition_routes, _steps_per_worker)
    | let proxy_router: ProxyRouter =>
      for (p_id, t) in _partition_routes.pairs() do
        if p_id == partition_id' then
          new_partition_routes(p_id) = target
        else
          new_partition_routes(p_id) = t
        end
      end
      LocalStatelessPartitionRouter(_partition_id, _worker_name, _step_ids,
        consume new_partition_routes, _steps_per_worker)
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
      consume new_partition_routes, _steps_per_worker)

  fun calculate_shrink(remaining_workers: Array[String] val):
    StatelessPartitionRouter
  =>
    // We need to remove any non-remaining workers from our partition
    // routes and then reassign partition ids accordingly. Partition ids
    // range sequentially from 0 to the partition count - 1.  They are
    // assigned to StepIds in the partition. When we remove non-remaining
    // workers, we are also removing all StepIds for partition steps that
    // existed on those workers. This means the partition count is reduced
    // and we create holes in the remaining valid partition ids. For example,
    // if we're removing worker 3 and worker 3 had a step corresponding to
    // partition ids 2 and 5 in a sequence from 0 to 5, then we are left
    // with partition id sequence [0, 1, 3, 4]. Since we route messages by
    // modding message seq ids over partition count, this gap means we'd
    // lose messages. We need to reassign the partition ids from 0 to
    // the new partition count - 1.
    let new_partition_count = remaining_workers.size() * _steps_per_worker

    // Filter out non-remaining workers, creating a map of only the
    // remaining partition routes.
    let reduced_partition_routes =
      recover trn Map[U64, (Step | ProxyRouter)] end
    for (p_id, s) in _partition_routes.pairs() do
      match s
      | let step: Step =>
        reduced_partition_routes(p_id) = step
      | let pr: ProxyRouter =>
        if remaining_workers.contains(pr.proxy_address().worker) then
          reduced_partition_routes(p_id) = pr
        end
      end
    end
    let partition_count = reduced_partition_routes.size()

    // Collect and sort the remaining old partition ids.
    let unsorted_old_p_ids = Array[U64]
    for id in reduced_partition_routes.keys() do
      unsorted_old_p_ids.push(id)
    end
    let old_p_ids = Sort[Array[U64], U64](unsorted_old_p_ids)

    // Reassign StepIds and (Step | ProxyRouter) values to the new partition
    // ids by placing them in new maps.
    let new_step_ids = recover trn Map[U64, StepId] end
    let new_partition_routes = recover trn Map[U64, (Step | ProxyRouter)] end
    for i in Range[U64](0, old_p_ids.size().u64()) do
      try
        let old_p_id = old_p_ids(i.usize())?
        new_step_ids(i) = _step_ids(old_p_id)?
        new_partition_routes(i) = reduced_partition_routes(old_p_id)?
      else
        Fail()
      end
    end

    LocalStatelessPartitionRouter(_partition_id, _worker_name,
      consume new_step_ids, consume new_partition_routes,
      _steps_per_worker)

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
      consume partition_addresses, _steps_per_worker)

  fun distribution_digest(): Map[String, Array[String] val] val =>
    // Return a map of form {worker_name: step_ids_as_strings}
    let digest = recover iso Map[String, Array[String] val] end
    // First for this worker
    let a = recover iso Array[String] end
    for id in _step_ids.values() do
      a.push(id.string())
    end
    digest(_worker_name) = consume a
    // Now the other workers
    let others = Map[String, Array[String]]
    try
      for target in _partition_routes.values() do
        match target
        | let pr: ProxyRouter =>
          let pa = pr.proxy_address()
          if others.contains(pa.worker) then
            others(pa.worker)?.push(pa.step_id.string())
          else
            let next = Array[String]
            next.push(pa.step_id.string())
            others(pa.worker) = next
          end
        end
      end
    else
      Fail()
    end
    for (k, v) in others.pairs() do
      let next = recover iso Array[String] end
      for id in v.values() do
        next.push(id)
      end
      digest(k) = consume next
    end
    consume digest

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
  let _steps_per_worker: USize

  new val create(p_id: U128, s_ids: Map[U64, StepId] val,
    partition_addresses: Map[U64, ProxyAddress] val,
    steps_per_worker: USize)
  =>
    _partition_id = p_id
    _step_ids = s_ids
    _partition_addresses = partition_addresses
    _steps_per_worker = steps_per_worker

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
      consume partition_routes, _steps_per_worker)
