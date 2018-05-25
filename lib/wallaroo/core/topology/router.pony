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
use "crypto"
use "net"
use "wallaroo_labs/collection_helpers"
use "wallaroo_labs/equality"
use "wallaroo_labs/mort"
use "wallaroo/core/boundary"
use "wallaroo/core/common"
use "wallaroo/core/source"
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
    producer_id: StepId, producer: Producer ref, i_msg_uid: MsgId,
    frac_ids: FractionalMessageId, latest_ts: U64, metrics_id: U16,
    worker_ingress_ts: U64): (Bool, U64)
  fun routes(): Array[Consumer] val
  fun routes_not_in(router: Router): Array[Consumer] val

class val EmptyRouter is Router
  fun route[D: Any val](metric_name: String, pipeline_time_spent: U64, data: D,
    producer_id: StepId, producer: Producer ref, i_msg_uid: MsgId,
    frac_ids: FractionalMessageId, latest_ts: U64, metrics_id: U16,
    worker_ingress_ts: U64): (Bool, U64)
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
    producer_id: StepId, producer: Producer ref, i_msg_uid: MsgId,
    frac_ids: FractionalMessageId, latest_ts: U64, metrics_id: U16,
    worker_ingress_ts: U64): (Bool, U64)
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
        producer_id, producer,
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
  let _routers: Array[Router] val

  new val create(routers: Array[Router] val) =>
    ifdef debug then
      Invariant(routers.size() > 1)
    end
    _routers = routers

  fun route[D: Any val](metric_name: String, pipeline_time_spent: U64, data: D,
    producer_id: StepId, producer: Producer ref, i_msg_uid: MsgId,
    frac_ids: FractionalMessageId, latest_ts: U64, metrics_id: U16,
    worker_ingress_ts: U64): (Bool, U64)
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
      (let is_f, _) = router.route[D](metric_name, pipeline_time_spent, data,
        // hand down producer so we can call _next_sequence_id()
        producer_id, producer,
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
      for r in router.routes().values() do
        r_set.set(r)
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
    producer_id: StepId, producer: Producer ref, i_msg_uid: MsgId,
    frac_ids: FractionalMessageId, latest_ts: U64, metrics_id: U16,
    worker_ingress_ts: U64): (Bool, U64)
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
        i_msg_uid, frac_ids)

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
      Fail()
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
    producer_id: StepId, producer: Producer ref, msg_uid: MsgId,
    frac_ids: FractionalMessageId, latest_ts: U64, metrics_id: U16,
    worker_ingress_ts: U64): (Bool, U64)

  fun val add_boundary(w: String, boundary: OutgoingBoundary): OmniRouter
  fun val remove_boundary(w: String): OmniRouter
  fun val add_data_receiver(w: String, dr: DataReceiver): OmniRouter
  fun val remove_data_receiver(w: String): OmniRouter
  fun val add_source(source_id: StepId, s: (ProxyAddress | Source)): OmniRouter
  fun val remove_source(source_id: StepId): OmniRouter

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

  fun producer_for(step_id: StepId): Producer ?

  fun data_receiver_for(worker: String): DataReceiver ?

  fun blueprint(): OmniRouterBlueprint

class val EmptyOmniRouter is OmniRouter
  fun route_with_target_ids[D: Any val](target_ids: Array[StepId] val,
    metric_name: String, pipeline_time_spent: U64, data: D,
    producer_id: StepId, producer: Producer ref, msg_uid: MsgId,
    frac_ids: FractionalMessageId, latest_ts: U64, metrics_id: U16,
    worker_ingress_ts: U64): (Bool, U64)
  =>
    @printf[I32]("route_with_target_ids() was called on an EmptyOmniRouter\n"
      .cstring())
    (true, latest_ts)

  fun val add_boundary(w: String,
    boundary: OutgoingBoundary): OmniRouter
  =>
    this

  fun val remove_boundary(w: String): OmniRouter =>
    this

  fun val add_data_receiver(w: String, dr: DataReceiver): OmniRouter =>
    this

  fun val remove_data_receiver(w: String): OmniRouter =>
    this

  fun val add_source(source_id: StepId, s: (ProxyAddress | Source)): OmniRouter
  =>
    this

  fun val remove_source(source_id: StepId): OmniRouter =>
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

  fun producer_for(step_id: StepId): Producer ? =>
    error

  fun data_receiver_for(worker: String): DataReceiver ? =>
    error

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
  let _sources: Map[StepId, (ProxyAddress | Source)] val
  let _outgoing_boundaries: Map[String, OutgoingBoundary] val
  let _stateless_partitions: Map[U128, StatelessPartitionRouter] val
  let _data_receivers: Map[String, DataReceiver] val

  new val create(worker_name: String,
    data_routes: Map[StepId, Consumer] val,
    step_map: Map[StepId, (ProxyAddress | StepId)] val,
    outgoing_boundaries: Map[String, OutgoingBoundary] val,
    stateless_partitions: Map[U128, StatelessPartitionRouter] val,
    sources: Map[StepId, (ProxyAddress | Source)] val,
    data_receivers: Map[String, DataReceiver] val)
  =>
    _worker_name = worker_name
    _data_routes = data_routes
    _step_map = step_map
    _outgoing_boundaries = outgoing_boundaries
    _stateless_partitions = stateless_partitions
    _sources = sources
    _data_receivers = data_receivers

  fun route_with_target_ids[D: Any val](target_ids: Array[StepId] val,
    metric_name: String, pipeline_time_spent: U64, data: D,
    producer_id: StepId, producer: Producer ref, msg_uid: MsgId,
    frac_ids: FractionalMessageId, latest_ts: U64, metrics_id: U16,
    worker_ingress_ts: U64): (Bool, U64)
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
          metric_name, pipeline_time_spent, data, producer_id, producer,
          msg_uid, frac_ids, latest_ts, metrics_id, worker_ingress_ts)
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
          pipeline_time_spent, data, producer_id, producer, msg_uid,
          o_frac_ids, latest_ts, metrics_id, worker_ingress_ts)

        // If at least one downstream message is not finished, then this
        // message is not yet finished
        if not is_f then is_finished = false end
      end
    end
    (is_finished, latest_ts)

  fun _route_with_target_id[D: Any val](target_id: StepId,
    metric_name: String, pipeline_time_spent: U64, data: D,
    producer_id: StepId, producer: Producer ref, msg_uid: MsgId,
    frac_ids: FractionalMessageId, latest_ts: U64, metrics_id: U16,
    worker_ingress_ts: U64): (Bool, U64)
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
            producer_id, producer, msg_uid, frac_ids,
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
            pipeline_time_spent, data, producer_id, producer, msg_uid,
            frac_ids, latest_ts, metrics_id, worker_ingress_ts)
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
      consume new_outgoing_boundaries, _stateless_partitions, _sources,
      _data_receivers)

  fun val remove_boundary(w: String): OmniRouter =>
    // TODO: Using persistent maps for our fields would make this more
    // efficient
    let new_outgoing_boundaries = recover trn Map[String, OutgoingBoundary] end
    for (k, v) in _outgoing_boundaries.pairs() do
      if k != w then
        new_outgoing_boundaries(k) = v
      end
    end
    StepIdRouter(_worker_name, _data_routes, _step_map,
      consume new_outgoing_boundaries, _stateless_partitions, _sources,
      _data_receivers)

  fun val add_data_receiver(w: String, dr: DataReceiver): OmniRouter =>
    // TODO: Using persistent maps for our fields would make this more
    // efficient
    let new_data_receivers = recover trn Map[String, DataReceiver] end
    for (k, v) in _data_receivers.pairs() do
      new_data_receivers(k) = v
    end
    new_data_receivers(w) = dr
    StepIdRouter(_worker_name, _data_routes, _step_map,
      _outgoing_boundaries, _stateless_partitions, _sources,
      consume new_data_receivers)

  fun val remove_data_receiver(w: String): OmniRouter =>
    // TODO: Using persistent maps for our fields would make this more
    // efficient
    let new_data_receivers = recover trn Map[String, DataReceiver] end
    for (k, v) in _data_receivers.pairs() do
      if k != w then new_data_receivers(k) = v end
    end
    StepIdRouter(_worker_name, _data_routes, _step_map,
      _outgoing_boundaries, _stateless_partitions, _sources,
      consume new_data_receivers)

  fun val add_source(source_id: StepId, s: (ProxyAddress | Source)): OmniRouter
  =>
    // TODO: Using persistent maps for our fields would make this more
    // efficient
    let new_sources = recover trn Map[StepId, (ProxyAddress | Source)] end
    for (k, v) in _sources.pairs() do
      new_sources(k) = v
    end
    new_sources(source_id) = s
    StepIdRouter(_worker_name, _data_routes, _step_map,
      _outgoing_boundaries, _stateless_partitions, consume new_sources,
      _data_receivers)

  fun val remove_source(source_id: StepId): OmniRouter =>
    // TODO: Using persistent maps for our fields would make this more
    // efficient
    let new_sources = recover trn Map[StepId, (ProxyAddress | Source)] end
    for (k, v) in _sources.pairs() do
      if k != source_id then new_sources(k) = v end
    end
    StepIdRouter(_worker_name, _data_routes, _step_map,
      _outgoing_boundaries, _stateless_partitions, consume new_sources,
      _data_receivers)

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
      _outgoing_boundaries, _stateless_partitions, _sources, _data_receivers)

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
      _outgoing_boundaries, _stateless_partitions, _sources, _data_receivers)

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
      _outgoing_boundaries, consume new_stateless_partitions, _sources,
      _data_receivers)

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

  fun producer_for(step_id: StepId): Producer ? =>
    if _step_map.contains(step_id) then
      match _step_map(step_id)?
      | let s_id: StepId =>
        match _data_routes(s_id)?
        | let p: Producer =>
          p
        else
          error
        end
      | let pa: ProxyAddress =>
        let worker = pa.worker
        _data_receivers(worker)?
      end
    else
      match _sources(step_id)?
      | let p: Producer => p
      else
        error
      end
    end

  fun data_receiver_for(worker: String): DataReceiver ? =>
    _data_receivers(worker)?

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
    let new_source_map = recover trn Map[StepId, ProxyAddress] end
    for (s_id, v) in _sources.pairs() do
      match v
      | let pa: ProxyAddress =>
        new_source_map(s_id) = pa
      | let source: Source =>
        let proxy_address = ProxyAddress(_worker_name, s_id)
        new_source_map(s_id) = proxy_address
      end
    end
    StepIdRouterBlueprint(consume new_step_map, consume new_source_map)

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
  let _source_map: Map[StepId, ProxyAddress] val

  new val create(step_map: Map[StepId, ProxyAddress] val,
    source_map: Map[StepId, ProxyAddress] val)
  =>
    _step_map = step_map
    _source_map = source_map

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
    let new_source_map = recover trn Map[StepId, (ProxyAddress | Source)] end
    for (k, v) in _source_map.pairs() do
      new_source_map(k) = v
    end

    StepIdRouter(worker_name, consume data_routes,
      consume new_step_map, outgoing_boundaries,
      recover Map[U128, StatelessPartitionRouter] end,
      consume new_source_map, recover Map[String, DataReceiver] end)

class val DataRouter is Equatable[DataRouter]
  let _data_routes: Map[StepId, Consumer] val
  // _keyed_routes contains a subset of the routes in _data_routes.
  // _keyed_routes keeps track of state step routes, while
  // _data_routes keeps track of *all* routes.
  let _keyed_routes: Map[Key, Step] val
  let _keyed_step_ids: Map[Key, StepId] val
  let _target_ids_to_route_ids: Map[StepId, RouteId] val
  let _route_ids_to_target_ids: Map[RouteId, StepId] val
  let _keys_to_route_ids: Map[Key, RouteId] val

  new val create(data_routes: Map[StepId, Consumer] val,
    keyed_routes: Map[Key, Step] val, keyed_step_ids: Map[Key, StepId] val)
  =>
    _data_routes = data_routes
    _keyed_routes = keyed_routes
    _keyed_step_ids = keyed_step_ids

    var route_id: RouteId = 0
    let ids: Array[StepId] = ids.create()
    let tid_map = recover trn Map[StepId, RouteId] end
    let rid_map = recover trn Map[RouteId, StepId] end

    for step_id in _data_routes.keys() do
      ids.push(step_id)
    end
    for id in Sort[Array[StepId], StepId](ids).values() do
      route_id = route_id + 1
      tid_map(id) = route_id
    end
    for (t_id, r_id) in tid_map.pairs() do
      rid_map(r_id) = t_id
    end

    _target_ids_to_route_ids = consume tid_map
    _route_ids_to_target_ids = consume rid_map

    let kid_map = recover trn Map[Key, RouteId] end
    for (k, s_id) in _keyed_step_ids.pairs() do
      try
        let r_id = _target_ids_to_route_ids(s_id)?
        kid_map(k) = r_id
      else
        Fail()
      end
    end
    _keys_to_route_ids = consume kid_map

  new val with_route_ids(data_routes: Map[StepId, Consumer] val,
    keyed_routes: Map[Key, Step] val,
    keyed_step_ids: Map[Key, StepId] val,
    target_ids_to_route_ids: Map[StepId, RouteId] val,
    route_ids_to_target_ids: Map[RouteId, StepId] val,
    keys_to_route_ids: Map[Key, RouteId] val)
  =>
    _data_routes = data_routes
    _keyed_routes = keyed_routes
    _keyed_step_ids = keyed_step_ids
    _target_ids_to_route_ids = target_ids_to_route_ids
    _route_ids_to_target_ids = route_ids_to_target_ids
    _keys_to_route_ids = keys_to_route_ids

  fun size(): USize =>
    _data_routes.size()

  fun step_for_id(id: StepId): Consumer ? =>
    _data_routes(id)?

  fun route(d_msg: DeliveryMsg, pipeline_time_spent: U64, producer_id: StepId,
    producer: DataReceiver ref, seq_id: SeqId, latest_ts: U64, metrics_id: U16,
    worker_ingress_ts: U64)
  =>
    ifdef "trace" then
      @printf[I32]("Rcvd msg at DataRouter\n".cstring())
    end
    try
      ifdef "trace" then
        @printf[I32]("DataRouter found Step\n".cstring())
      end
      let route_id = d_msg.deliver(pipeline_time_spent, producer_id, producer,
        seq_id, latest_ts, metrics_id, worker_ingress_ts,
        _data_routes,
        _target_ids_to_route_ids,
        _route_ids_to_target_ids,
        _keyed_routes,
        _keys_to_route_ids
         )?
      ifdef "resilience" then
        producer.bookkeeping(route_id, seq_id)
      end
    else
      // !@ We used to fail here, but the only reason we should get here is
      // is because we couldn't find a route for the key. Maybe we should
      // handle this differently.
      ifdef "trace" then
        @printf[I32]("DataRouter could not find a step\n".cstring())
      end
    end

  fun replay_route(r_msg: ReplayableDeliveryMsg, pipeline_time_spent: U64,
    producer_id: StepId, producer: DataReceiver ref, seq_id: SeqId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    try
      let route_id = r_msg.replay_deliver(pipeline_time_spent,
        _data_routes, _target_ids_to_route_ids,
        producer_id, producer, seq_id, latest_ts, metrics_id,
        worker_ingress_ts, _keyed_routes, _keys_to_route_ids)?
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

  // !@ Get rid of id', we don't use it anymore
  fun remove_keyed_route(id': StepId, key: Key): DataRouter =>
    ifdef debug then
      Invariant(_keyed_routes.contains(key))
    end

    let id = try
      _keyed_step_ids(key)?
    else
      Fail()
      0
    end

    // TODO: Using persistent maps for our fields would make this much more
    // efficient
    let new_data_routes = recover trn Map[StepId, Consumer] end
    for (k, v) in _data_routes.pairs() do
      if k != id then new_data_routes(k) = v end
    end
    let new_keyed_routes = recover trn Map[Key, Step] end

    for (k, v) in _keyed_routes.pairs() do
      if k != key then new_keyed_routes(k) = v end
    end

    let new_keyed_step_ids = recover trn Map[Key, StepId] end
    for (k, v) in _keyed_step_ids.pairs() do
      if k != key then new_keyed_step_ids(k) = v end
    end

    let new_tid_map = recover trn Map[StepId, RouteId] end
    for (k, v) in _target_ids_to_route_ids.pairs() do
      if k != id then new_tid_map(k) = v end
    end
    let new_rid_map = recover trn Map[RouteId, StepId] end
    for (k, v) in _route_ids_to_target_ids.pairs() do
      if v != id then new_rid_map(k) = v end
    end
    let new_kid_map = recover trn Map[Key, RouteId] end
    for (k, v) in _keys_to_route_ids.pairs() do
      if k != key then new_kid_map(k) = v end
    end
    DataRouter.with_route_ids(consume new_data_routes,
      consume new_keyed_routes, consume new_keyed_step_ids,
      consume new_tid_map, consume new_rid_map, consume new_kid_map)

  fun add_keyed_route(id: StepId, key: Key, target: Step): DataRouter =>
    // TODO: Using persistent maps for our fields would make this much more
    // efficient
    let new_data_routes = recover trn Map[StepId, Consumer] end
    for (k, v) in _data_routes.pairs() do
      new_data_routes(k) = v
    end
    new_data_routes(id) = target

    let new_keyed_routes = recover trn Map[Key, Step] end

    for (k, v) in _keyed_routes.pairs() do
      new_keyed_routes(k) = v
    end
    new_keyed_routes(key) = target

    let new_keyed_step_ids = recover trn Map[Key, StepId] end
    for (k, v) in _keyed_step_ids.pairs() do
      new_keyed_step_ids(k) = v
    end
    new_keyed_step_ids(key) = id

    let new_tid_map = recover trn Map[StepId, RouteId] end
    var highest_route_id: RouteId = 0
    for (k, v) in _target_ids_to_route_ids.pairs() do
      new_tid_map(k) = v
      if v > highest_route_id then highest_route_id = v end
    end
    let new_route_id = highest_route_id + 1
    new_tid_map(id) = new_route_id

    let new_rid_map = recover trn Map[RouteId, StepId] end
    for (k, v) in _route_ids_to_target_ids.pairs() do
      new_rid_map(k) = v
    end
    new_rid_map(new_route_id) = id

    let new_kid_map = recover trn Map[Key, RouteId] end
    for (k, v) in _keys_to_route_ids.pairs() do
      new_kid_map(k) = v
    end
    new_kid_map(key) = new_route_id

    DataRouter.with_route_ids(consume new_data_routes,
      consume new_keyed_routes, consume new_keyed_step_ids,
      consume new_tid_map, consume new_rid_map, consume new_kid_map)

  fun remove_routes_to_consumer(c: Consumer) =>
    """
    For all consumers we have routes to, tell them to remove any route to
    the provided consumer.
    """
    for consumer in _data_routes.values() do
      match consumer
      | let p: Producer =>
        p.remove_route_to_consumer(c)
      end
    end

  fun eq(that: box->DataRouter): Bool =>
    MapTagEquality[U128, Consumer](_data_routes, that._data_routes) and
      MapEquality[U128, RouteId](_target_ids_to_route_ids,
        that._target_ids_to_route_ids) //and
      // MapEquality[RouteId, U128](_route_ids_to_target_ids,
      //   that._route_ids_to_target_ids)

  fun migrate_state(target_id: StepId, s: ByteSeq val) =>
    try
      let target = _data_routes(target_id)?
      target.receive_state(s)
    else
      Fail()
    end

  fun report_status(code: ReportStatusCode) =>
    for consumer in _data_routes.values() do
      consumer.report_status(code)
    end

  fun request_in_flight_ack(requester_id: StepId,
    requester: InFlightAckRequester, in_flight_ack_waiter: InFlightAckWaiter):
    Bool
  =>
    """
    Returns false if there were no data routes to request on.
    """
    ifdef "trace" then
      @printf[I32]("Finished ack requested at DataRouter\n".cstring())
    end
    if _data_routes.size() > 0 then
      for consumer in _data_routes.values() do
        let request_id = in_flight_ack_waiter.add_consumer_request(
          requester_id)
        consumer.request_in_flight_ack(request_id, requester_id, requester)
      end
      true
    else
      false
    end

  fun request_in_flight_resume_ack(
    in_flight_resume_ack_id: InFlightResumeAckId,
    requester_id: StepId, requester: InFlightAckRequester,
    in_flight_ack_waiter: InFlightAckWaiter,
    leaving_workers: Array[String] val)
  =>
    if _data_routes.size() > 0 then
      for consumer in _data_routes.values() do
        let request_id = in_flight_ack_waiter.add_consumer_resume_request()
        consumer.request_in_flight_resume_ack(in_flight_resume_ack_id,
          request_id, requester_id, requester, leaving_workers)
      end
    else
      in_flight_ack_waiter.try_finish_resume_request_early()
    end

trait val PartitionRouter is (Router & Equatable[PartitionRouter])
  fun state_name(): String
  fun register_routes(router: Router, route_builder': RouteBuilder)
  fun update_route(step_id: StepId, key: Key, step: Step): PartitionRouter ?
  fun rebalance_steps_grow(auth: AmbientAuth,
    target_workers: Array[(String, OutgoingBoundary)] val,
    router_registry: RouterRegistry ref): (PartitionRouter, Bool)
  fun rebalance_steps_shrink(
    target_workers: Array[(String, OutgoingBoundary)] val,
    leaving_workers: Array[String] val,
    router_registry: RouterRegistry ref): Bool
  fun recalculate_hash_partitions_for_join(auth: AmbientAuth,
    joining_workers: Array[String] val,
    outgoing_boundaries: Map[String, OutgoingBoundary]): PartitionRouter
  fun recalculate_hash_partitions_for_shrink(
    leaving_workers: Array[String] val): PartitionRouter
  fun hash_partitions(): HashPartitions
  fun update_hash_partitions(hp: HashPartitions): PartitionRouter
  // Number of local steps in partition
  fun local_size(): USize
  fun update_boundaries(auth: AmbientAuth,
    ob: box->Map[String, OutgoingBoundary]): PartitionRouter
  fun blueprint(): PartitionRouterBlueprint
  fun distribution_digest(): Map[String, Array[String] val] val
  fun state_entity_digest(): Array[String] val
  fun route_builder(): RouteBuilder

trait val AugmentablePartitionRouter is PartitionRouter
  fun clone_and_set_input_type[NewIn: Any val](
    new_p_function: PartitionFunction[NewIn] val): PartitionRouter

class val LocalPartitionRouter[In: Any val, S: State ref]
  is AugmentablePartitionRouter
  let _state_name: String
  let _worker_name: String
  let _local_routes: Map[Key, Step] val
  let _step_ids: Map[Key, StepId] val
  let _hashed_node_routes: Map[String, HashedProxyRouter] val
  let _hash_partitions: HashPartitions
  let _partition_function: PartitionFunction[In] val

  new val create(state_name': String, worker_name: String,
    local_routes': Map[Key, Step] val,
    s_ids: Map[Key, StepId] val,
    hashed_node_routes: Map[String, HashedProxyRouter] val,
    hash_partitions': HashPartitions,
    partition_function: PartitionFunction[In] val)
  =>
    _state_name = state_name'
    _worker_name = worker_name
    _local_routes = local_routes'
    _step_ids = s_ids
    _hashed_node_routes = hashed_node_routes
    _hash_partitions = hash_partitions'
    _partition_function = partition_function

  fun local_size(): USize =>
    _local_routes.size()

  fun state_name(): String =>
    _state_name

  fun route_builder(): RouteBuilder =>
    TypedRouteBuilder[StateProcessor[S]]

  fun route[D: Any val](metric_name: String, pipeline_time_spent: U64, data: D,
    producer_id: StepId, producer: Producer ref, i_msg_uid: MsgId,
    frac_ids: FractionalMessageId, latest_ts: U64, metrics_id: U16,
    worker_ingress_ts: U64): (Bool, U64)
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
        let worker =
          try
            _hash_partitions.get_claimant_by_key(key)?
          else
            @printf[I32](("Could not find claimant for key " +
              " '%s'\n\n").cstring(), key.string().cstring())
            Fail()
            return (true, latest_ts)
          end
        if worker == _worker_name then
          try
            let s = _local_routes(key)?
            let might_be_route = producer.route_to(s)
            match might_be_route
            | let r: Route =>
              ifdef "trace" then
                @printf[I32]("PartitionRouter found Route\n".cstring())
              end
              r.run[D](metric_name, pipeline_time_spent,
                data, producer_id, producer, i_msg_uid, frac_ids,
                latest_ts, metrics_id, worker_ingress_ts)
              (false, latest_ts)
            else
              // TODO: What do we do if we get None?
              Fail()
              (true, latest_ts)
            end
          else
            ifdef debug then
              @printf[I32](("LocalPartitionRouter.route: No entry for " +
                "key '%s'\n\n").cstring(), key.string().cstring())
            end
            producer.unknown_key(key)
            (true, latest_ts)
          end
        else
          try
            let r = _hashed_node_routes(worker)?
            let msg = r.build_msg[D](metric_name, pipeline_time_spent, data,
              key, producer_id, producer, i_msg_uid, frac_ids, latest_ts,
              metrics_id, worker_ingress_ts)
            r.route[ForwardHashedMsg[D]](metric_name, pipeline_time_spent, msg,
              producer_id, producer, i_msg_uid, frac_ids, latest_ts,
              metrics_id, worker_ingress_ts)
          else
            // We should have a route to any claimant we know about
            Fail()
            (true, latest_ts)
          end
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
    new_p_function: PartitionFunction[NewIn] val): PartitionRouter
  =>
    LocalPartitionRouter[NewIn, S](_state_name, _worker_name,
      _local_routes, _step_ids, _hashed_node_routes, _hash_partitions,
      new_p_function)

  fun register_routes(router: Router, route_builder': RouteBuilder) =>
    for step in _local_routes.values() do
      step.register_routes(router, route_builder')
    end

  fun routes(): Array[Consumer] val =>
    let cs = recover trn Array[Consumer] end

    for step in _local_routes.values() do
      cs.push(step)
    end

    consume cs

  fun routes_not_in(router: Router): Array[Consumer] val =>
    let diff = recover trn Array[Consumer] end
    let other_routes = router.routes()
    for r in routes().values() do
      if not other_routes.contains(r) then diff.push(r) end
    end
    consume diff

  fun update_route(step_id: StepId, key: Key, step: Step): PartitionRouter
  =>
    // TODO: Using persistent maps for our fields would make this much more
    // efficient
    let new_local_routes = recover trn Map[Key, Step] end
    let new_local_step_ids = recover trn Map[Key, StepId] end

    for (k, s) in _local_routes.pairs() do
      new_local_routes(k) = s
    end
    new_local_routes(key) = step

    for (k, s_id) in _step_ids.pairs() do
      new_local_step_ids(k) = s_id
    end
    new_local_step_ids(key) = step_id

    LocalPartitionRouter[In, S](_state_name, _worker_name,
      consume new_local_routes, consume new_local_step_ids,
      _hashed_node_routes, _hash_partitions, _partition_function)

  fun update_boundaries(auth: AmbientAuth,
    ob: box->Map[String, OutgoingBoundary]): PartitionRouter
  =>
    let new_hashed_node_routes = recover trn Map[String, HashedProxyRouter] end

    for (w, hpr) in _hashed_node_routes.pairs() do
      new_hashed_node_routes(w) = hpr
    end
    for (w, b) in ob.pairs() do
      new_hashed_node_routes(w) = HashedProxyRouter(w, b, _state_name, auth)
    end

    LocalPartitionRouter[In, S](_state_name, _worker_name, _local_routes,
      _step_ids, consume new_hashed_node_routes, _hash_partitions,
      _partition_function)

  fun recalculate_hash_partitions_for_join(auth: AmbientAuth,
    joining_workers: Array[String] val,
    outgoing_boundaries: Map[String, OutgoingBoundary]): PartitionRouter
  =>
    let new_hash_partitions =
      try
        _hash_partitions.add_claimants(joining_workers)?
      else
        Fail()
        _hash_partitions
      end
    let new_hashed_node_routes = recover trn Map[String, HashedProxyRouter] end
    for (w, pr) in _hashed_node_routes.pairs() do
      new_hashed_node_routes(w) = pr
    end
    for w in joining_workers.values() do
      try
        let b = outgoing_boundaries(w)?
        new_hashed_node_routes(w) = HashedProxyRouter(w, b, _state_name, auth)
      else
        Fail()
      end
    end

    LocalPartitionRouter[In, S](_state_name, _worker_name, _local_routes,
      _step_ids, consume new_hashed_node_routes, new_hash_partitions,
      _partition_function)

  fun recalculate_hash_partitions_for_shrink(
    leaving_workers: Array[String] val): PartitionRouter
  =>
    let new_hash_partitions =
      try
        _hash_partitions.remove_claimants(leaving_workers)?
      else
        Fail()
        _hash_partitions
      end
    let new_hashed_node_routes = recover trn Map[String, HashedProxyRouter] end
    for (w, pr) in _hashed_node_routes.pairs() do
      if not ArrayHelpers[String].contains[String](leaving_workers, w) then
        new_hashed_node_routes(w) = pr
      end
    end

    LocalPartitionRouter[In, S](_state_name, _worker_name, _local_routes,
      _step_ids, consume new_hashed_node_routes, new_hash_partitions,
      _partition_function)

  fun hash_partitions(): HashPartitions =>
    _hash_partitions

  fun update_hash_partitions(hp: HashPartitions): PartitionRouter =>
    LocalPartitionRouter[In, S](_state_name, _worker_name, _local_routes,
      _step_ids, _hashed_node_routes, hp, _partition_function)

  fun rebalance_steps_grow(auth: AmbientAuth,
    target_workers: Array[(String, OutgoingBoundary)] val,
    router_registry: RouterRegistry ref): (PartitionRouter, Bool)
  =>
    """
    Begin migration of state steps known to this router that we determine
    must be routed. Return the new router and a Bool indicating whether
    we migrated any steps.
    """
    let new_workers_trn = recover trn Array[String] end
    let new_boundaries = Map[String, OutgoingBoundary]
    let keys_to_move = Array[Key]
    let keys_to_move_by_worker = Map[String, Array[Key]]
    for (w, b) in target_workers.values() do
      new_workers_trn.push(w)
      new_boundaries(w) = b
      keys_to_move_by_worker(w) = Array[Key]
    end
    let new_workers = consume val new_workers_trn

    let new_hash_partitions =
      try
        _hash_partitions.add_claimants(new_workers)?
      else
        Fail()
        _hash_partitions
      end

    // Determine the steps we need to migrate
    try
      for k in _local_routes.keys() do
        let c = new_hash_partitions.get_claimant_by_key(k)?
        if ArrayHelpers[String].contains[String](new_workers, c) then
          try
            keys_to_move.push(k)
            keys_to_move_by_worker(c)?.push(k)
          else
            Fail()
          end
        end
      end
    else
      Fail()
    end
    let steps_to_migrate = Array[(String, OutgoingBoundary, Key, StepId, Step)]
    for (w, ks) in keys_to_move_by_worker.pairs() do
      for k in ks.values() do
        try
          let boundary = new_boundaries(w)?
          let step_id = _step_ids(k)?
          let step = _local_routes(k)?
          steps_to_migrate.push((w, boundary, k, step_id, step))
        else
          Fail()
        end
      end
    end

    // Update routes and step ids for the new PartitionRouter we will return
    let new_local_routes = recover trn Map[Key, Step] end
    let new_step_ids = recover trn Map[Key, StepId] end
    let new_hashed_node_routes = recover trn Map[String, HashedProxyRouter] end
    for (k, s) in _local_routes.pairs() do
      if not keys_to_move.contains(k) then
        new_local_routes(k) = s
      end
    end
    for (k, s_id) in _step_ids.pairs() do
      if not keys_to_move.contains(k) then
        new_step_ids(k) = s_id
      end
    end
    for (w, pr) in _hashed_node_routes.pairs() do
      new_hashed_node_routes(w) = pr
    end
    for (w, b) in new_boundaries.pairs() do
      new_hashed_node_routes(w) = HashedProxyRouter(w, b, _state_name, auth)
    end

    // Actually initiate migration of steps
    let had_steps_to_migrate = migrate_steps(router_registry,
      steps_to_migrate, target_workers.size())

    let new_router = LocalPartitionRouter[In, S](_state_name, _worker_name,
      consume new_local_routes, consume new_step_ids,
      consume new_hashed_node_routes, new_hash_partitions, _partition_function)
    (new_router, had_steps_to_migrate)

  fun rebalance_steps_shrink(
    target_workers: Array[(String, OutgoingBoundary)] val,
    leaving_workers: Array[String] val,
    router_registry: RouterRegistry ref): Bool
  =>
    let remaining_workers_trn = recover trn Array[String] end
    let remaining_boundaries = Map[String, OutgoingBoundary]
    let keys_to_move = Map[String, Array[Key]]
    for (w, b) in target_workers.values() do
      remaining_workers_trn.push(w)
      remaining_boundaries(w) = b
      keys_to_move(w) = Array[Key]
    end
    let remaining_workers = consume val remaining_workers_trn

    let new_hash_partitions =
      try
        _hash_partitions.remove_claimants(leaving_workers)?
      else
        Fail()
        _hash_partitions
      end

    try
      for k in _local_routes.keys() do
        let c = new_hash_partitions.get_claimant_by_key(k)?
        if ArrayHelpers[String].contains[String](remaining_workers, c) then
          try
            keys_to_move(c)?.push(k)
          else
            Fail()
          end
        end
      end
    else
      Fail()
    end
    let steps_to_migrate = Array[(String, OutgoingBoundary, Key, StepId, Step)]
    for (w, ks) in keys_to_move.pairs() do
      for k in ks.values() do
        try
          let boundary = remaining_boundaries(w)?
          let step_id = _step_ids(k)?
          let step = _local_routes(k)?
          steps_to_migrate.push((w, boundary, k, step_id, step))
        else
          Fail()
        end
      end
    end
    migrate_steps(router_registry, steps_to_migrate, target_workers.size())

  fun migrate_steps(router_registry: RouterRegistry ref,
    steps_to_migrate': Array[(String, OutgoingBoundary, Key, StepId, Step)],
    target_worker_count: USize): Bool
  =>
    """
    Actually initiate the migration of steps. Return false if none were
    migrated.
    """
    @printf[I32]("^^Migrating %lu steps to %d workers\n".cstring(),
      steps_to_migrate'.size(), target_worker_count)
    if steps_to_migrate'.size() > 0 then
      for (target_worker, boundary, key, step_id, step)
        in steps_to_migrate'.values()
      do
        router_registry.add_to_step_waiting_list(step_id)
        step.send_state(boundary, _state_name, key)
        router_registry.move_stateful_step_to_proxy(step_id, step,
          ProxyAddress(target_worker, step_id), key, _state_name)
        @printf[I32](
          "^^Migrating step %s for key %s to outgoing boundary %s/%lx\n"
            .cstring(), step_id.string().cstring(), key.cstring(),
            target_worker.cstring(), boundary)
      end
      true
    else
      false
    end

  fun blueprint(): PartitionRouterBlueprint =>
    LocalPartitionRouterBlueprint[In, S](_state_name, _step_ids,
      _hash_partitions, _partition_function)

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
    //!@ Others needs to be filled in another way. We don't know about
    // ProxyRouters anymore.  We need this distribution digest for partition
    // queries, which are used in autoscale tests.
    let others = Map[String, Array[String]]
    // try
    //   for target in _local_routes.values() do
    //     match target
    //     | let pr: ProxyRouter =>
    //       let pa = pr.proxy_address()
    //       if others.contains(pa.worker) then
    //         others(pa.worker)?.push(pa.step_id.string())
    //       else
    //         let next = Array[String]
    //         next.push(pa.step_id.string())
    //         others(pa.worker) = next
    //       end
    //     end
    //   end
    // else
    //   Fail()
    // end
    for (k, v) in others.pairs() do
      let next = recover iso Array[String] end
      for id in v.values() do
        next.push(id)
      end
      digest(k) = consume next
    end
    consume digest

  fun state_entity_digest(): Array[String] val =>
    // Return an array of keys
    let digest = recover trn Array[String] end

    for k in _local_routes.keys() do
      digest.push(k)
    end

    consume digest

  fun eq(that: box->PartitionRouter): Bool =>
    match that
    | let o: box->LocalPartitionRouter[In, S] =>
      MapTagEquality[Key, Step](_local_routes, o._local_routes) and
        MapEquality[Key, StepId](_step_ids, o._step_ids) and
        (_hash_partitions == o._hash_partitions) and
        (_partition_function is o._partition_function)
    else
      false
    end

trait val PartitionRouterBlueprint
  fun build_router(worker_name: String, workers: Array[String] val,
    outgoing_boundaries: Map[String, OutgoingBoundary] val,
    auth: AmbientAuth): PartitionRouter

class val LocalPartitionRouterBlueprint[In: Any val, S: State ref]
  is PartitionRouterBlueprint
  let _state_name: String
  let _step_ids: Map[Key, StepId] val
  let _hash_partitions: HashPartitions
  let _partition_function: PartitionFunction[In] val

  new val create(state_name: String,
    s_ids: Map[Key, StepId] val, hash_partitions: HashPartitions,
    partition_function: PartitionFunction[In] val)
  =>
    _state_name = state_name
    _step_ids = s_ids
    _hash_partitions = hash_partitions
    _partition_function = partition_function

  fun build_router(worker_name: String, workers: Array[String] val,
    outgoing_boundaries: Map[String, OutgoingBoundary] val,
    auth: AmbientAuth): PartitionRouter
  =>
    let hashed_node_routes = recover trn Map[String, HashedProxyRouter] end
    for (w, b) in outgoing_boundaries.pairs() do
      hashed_node_routes(w) = HashedProxyRouter(worker_name, b, _state_name,
        auth)
    end
    let current_workers = Array[String]
    let joining_workers = recover trn Array[String] end
    for c in _hash_partitions.claimants() do
      current_workers.push(c)
    end
    for w in workers.values() do
      if not ArrayHelpers[String].contains[String](current_workers, w) then
        joining_workers.push(w)
      end
    end
    let new_hash_partitions =
      try
        _hash_partitions.add_claimants(consume joining_workers)?
      else
        Fail()
        _hash_partitions
      end

    LocalPartitionRouter[In, S](_state_name, worker_name,
      recover val Map[Key, Step] end, _step_ids, consume hashed_node_routes,
      new_hash_partitions, _partition_function)

trait val StatelessPartitionRouter is (Router &
  Equatable[StatelessPartitionRouter])
  fun partition_id(): U128
  fun register_routes(router: Router, route_builder': RouteBuilder)
  fun update_route(partition_id': U64, target: (Step | ProxyRouter)):
    StatelessPartitionRouter ?
  // // Total number of steps in partition
  fun size(): USize
  // Number of local steps in partition
  fun local_size(): USize
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

  fun local_size(): USize =>
    _steps_per_worker

  fun partition_id(): U128 =>
    _partition_id

  fun route[D: Any val](metric_name: String, pipeline_time_spent: U64, data: D,
    producer_id: StepId, producer: Producer ref, i_msg_uid: MsgId,
    frac_ids: FractionalMessageId, latest_ts: U64, metrics_id: U16,
    worker_ingress_ts: U64): (Bool, U64)
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
            producer_id, producer, i_msg_uid, frac_ids, latest_ts, metrics_id,
            worker_ingress_ts)
          (false, latest_ts)
        else
          // TODO: What do we do if we get None?
          (true, latest_ts)
        end
      | let p: ProxyRouter =>
        p.route[D](metric_name, pipeline_time_spent, data, producer_id,
          producer, i_msg_uid, frac_ids, latest_ts, metrics_id,
          worker_ingress_ts)
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
    // Accumulate step_ids per worker
    let others = Map[String, Array[String]]
    others(_worker_name) = Array[String]
    try
      for (p_id, target) in _partition_routes.pairs() do
        match target
        | let s: Step =>
          let step_id = _step_ids(p_id)?
          others(_worker_name)?.push(step_id.string())
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

class val HashedProxyRouter is (Router & Equatable[HashedProxyRouter])
  let _worker_name: String
  let _target: OutgoingBoundary
  let _target_state_name: String
  let _auth: AmbientAuth

  new val create(worker_name: String, target: OutgoingBoundary,
    target_state_name: String, auth: AmbientAuth)
  =>
    _worker_name = worker_name
    _target = target
    _target_state_name = target_state_name
    _auth = auth

  fun build_msg[D: Any val](metric_name: String, pipeline_time_spent: U64,
    data: D, key: Key, producer_id: StepId, producer: Producer ref,
    i_msg_uid: MsgId, frac_ids: FractionalMessageId, latest_ts: U64,
    metrics_id: U16, worker_ingress_ts: U64): ForwardHashedMsg[D]
  =>
    ForwardHashedMsg[D](
      _target_state_name,
      key,
      _worker_name,
      data,
      metric_name,
      i_msg_uid,
      frac_ids)

  fun route[D: Any val](metric_name: String, pipeline_time_spent: U64, data: D,
    producer_id: StepId, producer: Producer ref, i_msg_uid: MsgId,
    frac_ids: FractionalMessageId, latest_ts: U64, metrics_id: U16,
    worker_ingress_ts: U64): (Bool, U64)
  =>
    ifdef "trace" then
      @printf[I32]("Rcvd msg at HashedProxyRouter\n".cstring())
    end

    let might_be_route = producer.route_to(_target)
    match might_be_route
    | let r: Route =>
      ifdef "trace" then
        @printf[I32]("HashedProxyRouter found Route\n".cstring())
      end

      match data
      | let m: ReplayableDeliveryMsg =>
        r.forward(m, pipeline_time_spent, producer,
          latest_ts, metrics_id, metric_name, worker_ingress_ts)
      else
        Fail()
      end

      (false, latest_ts)
    else
      Fail()
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

  fun val update_boundary(ob: box->Map[String, OutgoingBoundary]):
    HashedProxyRouter
  =>
    try
      let new_target = ob(_worker_name)?
      if new_target isnt _target then
        HashedProxyRouter(_worker_name, new_target, _target_state_name, _auth)
      else
        this
      end
    else
      Fail()
      this
    end

  fun eq(that: box->HashedProxyRouter): Bool =>
    (_worker_name == that._worker_name) and
      (_target is that._target)
