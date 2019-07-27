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
use "wallaroo/core/barrier"
use "wallaroo/core/boundary"
use "wallaroo/core/checkpoint"
use "wallaroo/core/common"
use "wallaroo/core/data_receiver"
use "wallaroo/core/invariant"
use "wallaroo/core/messages"
use "wallaroo/core/rebalancing"
use "wallaroo/core/registries"
use "wallaroo/core/routing"
use "wallaroo/core/sink"
use "wallaroo/core/source"
use "wallaroo/core/state"
use "wallaroo/core/step"
use "wallaroo_labs/collection_helpers"
use "wallaroo_labs/equality"
use "wallaroo_labs/mort"
use "wallaroo_labs/string_set"

trait val Router is (Hashable & Equatable[Router])
  fun route[D: Any val](metric_name: String, pipeline_time_spent: U64, data: D,
    key: Key, event_ts: U64, watermark_ts: U64,
    consumer_sender: TestableConsumerSender,
    i_msg_uid: MsgId, frac_ids: FractionalMessageId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64): (Bool, U64)
  fun routes(): Map[RoutingId, Consumer] val
  fun routes_not_in(router: Router): Map[RoutingId, Consumer] val

primitive EmptyRouter is Router
  fun route[D: Any val](metric_name: String, pipeline_time_spent: U64, data: D,
    key: Key, event_ts: U64, watermark_ts: U64,
    consumer_sender: TestableConsumerSender,
    i_msg_uid: MsgId, frac_ids: FractionalMessageId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64): (Bool, U64)
  =>
    (true, latest_ts)

  fun routes(): Map[RoutingId, Consumer] val =>
    recover Map[RoutingId, Consumer] end

  fun routes_not_in(router: Router): Map[RoutingId, Consumer] val =>
    recover Map[RoutingId, Consumer] end

  fun eq(that: box->Router): Bool =>
    that is EmptyRouter

  fun hash(): USize =>
    0

class val DirectRouter is Router
  let _target_id: RoutingId
  let _target: Consumer

  new val create(t_id: RoutingId, target: Consumer) =>
    _target_id = t_id
    _target = target

  fun route[D: Any val](metric_name: String, pipeline_time_spent: U64, data: D,
    key: Key, event_ts: U64, watermark_ts: U64,
    consumer_sender: TestableConsumerSender,
    i_msg_uid: MsgId, frac_ids: FractionalMessageId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64): (Bool, U64)
  =>
    ifdef "trace" then
      @printf[I32]("Rcvd msg at DirectRouter\n".cstring())
    end

    consumer_sender.send[D](metric_name, pipeline_time_spent, data, key,
      event_ts, watermark_ts, i_msg_uid, frac_ids, latest_ts, metrics_id,
      worker_ingress_ts, _target)
    (false, latest_ts)

  fun routes(): Map[RoutingId, Consumer] val =>
    let m = recover iso Map[RoutingId, Consumer] end
    m(_target_id) = _target
    consume m

  fun routes_not_in(router: Router): Map[RoutingId, Consumer] val =>
    let m = recover iso Map[RoutingId, Consumer] end
    for (id, c) in router.routes().pairs() do
      if _target_id == id then
        return consume m
      end
    end
    m(_target_id) = _target
    consume m

  fun eq(that: box->Router): Bool =>
    match that
    | let dr: DirectRouter =>
      (_target_id == dr._target_id) and (_target is dr._target)
    else
      false
    end

  fun hash(): USize =>
    _target_id.hash() xor (digestof _target).hash()

//TODO: Using the MultiRouter with sub-MultiRouters causes compilation to
//freeze on Reachability, so for now it's banned.
class val MultiRouter is Router
  let _routers: Array[Router] val

  new val create(routers: Array[Router] val) =>
    _routers = routers
    ifdef debug then
      for r in _routers.values() do
        Invariant(
          match r
          | let mr: MultiRouter => false
          else true end
        )
      end
    end

  fun route[D: Any val](metric_name: String, pipeline_time_spent: U64, data: D,
    key: Key, event_ts: U64, watermark_ts: U64,
    consumer_sender: TestableConsumerSender,
    i_msg_uid: MsgId, frac_ids: FractionalMessageId,
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
      (let is_f, _) =
        match router
        | let dr: DirectRouter =>
          dr.route[D](metric_name, pipeline_time_spent, data,
            key, event_ts, watermark_ts, consumer_sender, i_msg_uid,
            o_frac_ids, latest_ts, metrics_id, worker_ingress_ts)
        else
          Fail()
          (true, 0)
        end

      // // If any of the messages sent downstream are not finished, then
      // // we report that this message is not finished yet.
      if not is_f then is_finished = false end
    end
    (is_finished, latest_ts)

  fun routes(): Map[RoutingId, Consumer] val =>
    let m = recover iso Map[RoutingId, Consumer] end
    for router in _routers.values() do
      for (id, r) in router.routes().pairs() do
        m(id) = r
      end
    end
    consume m

  fun routes_not_in(router: Router): Map[RoutingId, Consumer] val =>
    let rs = recover iso Map[RoutingId, Consumer] end
    let those_routes = router.routes()
    for (id, r) in routes().pairs() do
      if not those_routes.contains(id) then
        rs(id) = r
      end
    end
    consume rs

  fun eq(that: box->Router): Bool =>
    match that
    | let mr: MultiRouter =>
      try
        let theirs = mr._routers
        if _routers.size() != theirs.size() then return false end
        var is_equal = true
        for i in Range(0, _routers.size()) do
          if _routers(i)? != theirs(i)? then is_equal = false end
        end
        is_equal
      else
        false
      end
    else
      false
    end

  fun hash(): USize =>
    try
      var h = _routers(0)?.hash()
      if _routers.size() > 1 then
        for i in Range(1, _routers.size()) do
          h = h xor _routers(i)?.hash()
        end
      end
      h
    else
      0
    end

class val ProxyRouter is Router
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
    key: Key, event_ts: U64, watermark_ts: U64,
    consumer_sender: TestableConsumerSender,
    i_msg_uid: MsgId, frac_ids: FractionalMessageId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64): (Bool, U64)
  =>
    ifdef "trace" then
      @printf[I32]("Rcvd msg at ProxyRouter\n".cstring())
    end

    let delivery_msg = ForwardMsg[D](
      _target_proxy_address.routing_id, _worker_name, data, key, event_ts,
      watermark_ts, metric_name, _target_proxy_address, i_msg_uid, frac_ids)

    consumer_sender.forward(delivery_msg, pipeline_time_spent,
      latest_ts, metrics_id, metric_name, worker_ingress_ts, _target)

    (false, latest_ts)

  fun copy_with_new_target_id(target_id: RoutingId): ProxyRouter =>
    ProxyRouter(_worker_name, _target,
      ProxyAddress(_target_proxy_address.worker, target_id), _auth)

  fun routes(): Map[RoutingId, Consumer] val =>
    let m = recover iso Map[RoutingId, Consumer] end
    m(_target_proxy_address.routing_id) = _target
    consume m

  fun routes_not_in(router: Router): Map[RoutingId, Consumer] val =>
    let m = recover iso Map[RoutingId, Consumer] end
    if router.routes().contains(_target_proxy_address.routing_id) then
      consume m
    else
      m(_target_proxy_address.routing_id) = _target
      consume m
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

  fun target_boundary(): OutgoingBoundary =>
    _target

  fun eq(that: box->Router): Bool =>
    match that
    | let pr: ProxyRouter =>
      (_worker_name == pr._worker_name) and
        (_target is pr._target) and
        (_target_proxy_address == pr._target_proxy_address)
    else
      false
    end

  fun hash(): USize =>
    _target_proxy_address.hash()

class val DataRouter is Equatable[DataRouter]
  let _worker_name: String
  let _data_routes: Map[RoutingId, Consumer] val
  let _step_group_steps: Map[RoutingId, Array[Step] val] val
  let _consumer_ids: MapIs[Consumer, RoutingId] val

  // Special RoutingIds that indicates that a barrier or un/register_producer
  // request needs to be forwarded to all known steps on this worker for a
  // particular step group.
  let _step_group_routing_ids: Map[RoutingId, RoutingId] val

  new val create(worker: String, data_routes: Map[RoutingId, Consumer] val,
    step_group_steps: Map[RoutingId, Array[Step] val] val,
    step_group_routing_ids': Map[RoutingId, RoutingId] val)
  =>
    _worker_name = worker
    _data_routes = data_routes
    _step_group_steps = step_group_steps
    _step_group_routing_ids = step_group_routing_ids'

    let ids: Array[RoutingId] = ids.create()
    let cid_map = recover trn MapIs[Consumer, RoutingId] end

    for step_id in _data_routes.keys() do
      ids.push(step_id)
    end
    for (r_id, c) in data_routes.pairs() do
      cid_map(c) = r_id
    end
     _consumer_ids = consume cid_map

  fun size(): USize =>
    _data_routes.size()

  fun step_for_id(id: RoutingId): Consumer ? =>
    _data_routes(id)?

  fun route(d_msg: DeliveryMsg, pipeline_time_spent: U64,
    producer_id: RoutingId, producer: DataReceiver ref, seq_id: SeqId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    ifdef "trace" then
      @printf[I32]("Rcvd msg at DataRouter\n".cstring())
    end
    try
      d_msg.deliver(pipeline_time_spent, producer_id, producer,
        seq_id, latest_ts, metrics_id, worker_ingress_ts,
        _data_routes, _step_group_steps, _consumer_ids)?
    else
      Fail()
    end

  fun register_producer(input_id: RoutingId, output_id: RoutingId,
    producer: DataReceiver ref)
  =>
    if _data_routes.contains(output_id) then
      try
        _data_routes(output_id)?.register_producer(input_id, producer)
      else
        Unreachable()
      end
    elseif _step_group_routing_ids.contains(output_id) then
      try
        let routing_id = _step_group_routing_ids(output_id)?
        let steps = _step_group_steps(routing_id)?
        for step in steps.values() do
          step.register_producer(input_id, producer)
        end
      else
        Fail()
      end
    else
      producer.queue_register_producer(input_id, output_id)
    end

  fun unregister_producer(input_id: RoutingId, output_id: RoutingId,
    producer: DataReceiver ref)
  =>
    if _data_routes.contains(output_id) then
      try
        _data_routes(output_id)?.unregister_producer(input_id, producer)
      else
        Unreachable()
      end
    elseif _step_group_routing_ids.contains(output_id) then
      try
        let routing_id = _step_group_routing_ids(output_id)?
        let steps = _step_group_steps(routing_id)?
        for step in steps.values() do
          step.unregister_producer(input_id, producer)
        end
      else
        Fail()
      end
    else
      producer.queue_unregister_producer(input_id, output_id)
    end

  fun routes(): Map[RoutingId, Consumer] val =>
    let m = recover iso Map[RoutingId, Consumer] end
    for (r_id, c) in _data_routes.pairs() do
      m(r_id) = c
    end
    consume m

  fun remove_routes_to_consumer(id: RoutingId, c: Consumer) =>
    """
    For all consumers we have routes to, tell them to remove any route to
    the provided consumer.
    """
    for consumer in _data_routes.values() do
      match consumer
      | let p: Producer =>
        p.remove_route_to_consumer(id, c)
      end
    end

  fun forward_barrier(target_step_id: RoutingId, origin_step_id: RoutingId,
    producer: Producer, barrier_token: BarrierToken)
  =>
    if _data_routes.contains(target_step_id) then
      try
        _data_routes(target_step_id)?.receive_barrier(origin_step_id,
          producer, barrier_token)
      else
        Unreachable()
      end
    elseif _step_group_routing_ids.contains(target_step_id) then
      try
        let routing_id = _step_group_routing_ids(target_step_id)?
        let steps = _step_group_steps(routing_id)?
        for step in steps.values() do
          step.receive_barrier(origin_step_id, producer, barrier_token)
        end
      else
        Fail()
      end
    else
      Fail()
    end

  fun eq(that: box->DataRouter): Bool =>
    MapTagEquality[U128, Consumer](_data_routes, that._data_routes)

  fun report_status(code: ReportStatusCode) =>
    for consumer in _data_routes.values() do
      consumer.report_status(code)
    end

class val StatePartitionRouter is Router
  let _step_group: RoutingId
  let _worker_name: WorkerName
  let _state_steps: Array[Step] val
  let _step_ids: Map[RoutingId, Step] val
  let _consumer_ids: MapIs[Step, RoutingId] val
  let _hashed_node_routes: Map[String, HashedProxyRouter] val
  let _hash_partitions: HashPartitions
  // These routing ids are used to route messages to this step group on
  // another worker.
  let _worker_routing_ids: Map[WorkerName, RoutingId] val
  // If this router is in the scope of a local_key_by, then it will only
  // route messages to local Steps on this worker.
  let _local_routing: Bool

  new val create(step_group': RoutingId,
    worker_name: WorkerName,
    state_steps: Array[Step] val,
    step_ids: Map[RoutingId, Step] val,
    hashed_node_routes: Map[WorkerName, HashedProxyRouter] val,
    hash_partitions': HashPartitions,
    worker_routing_ids: Map[WorkerName, RoutingId] val,
    local_routing: Bool)
  =>
    _step_group = step_group'
    _worker_name = worker_name
    _state_steps = state_steps
    _step_ids = step_ids
    _hashed_node_routes = hashed_node_routes
    _hash_partitions = hash_partitions'
    _worker_routing_ids = worker_routing_ids
    let consumer_ids = recover iso MapIs[Step, RoutingId] end
    for (k, v) in _step_ids.pairs() do
      consumer_ids(v) = k
    end
    _consumer_ids = consume consumer_ids
    _local_routing = local_routing

  fun local_size(): USize =>
    _state_steps.size()

  fun step_group(): RoutingId =>
    _step_group

  fun route[D: Any val](metric_name: String, pipeline_time_spent: U64, data: D,
    key: Key, event_ts: U64, watermark_ts: U64,
    consumer_sender: TestableConsumerSender,
    i_msg_uid: MsgId, frac_ids: FractionalMessageId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64): (Bool, U64)
  =>
    ifdef "trace" then
      @printf[I32]("Rcvd msg at StatePartitionRouter\n".cstring())
    end

    let worker =
      try
        _hash_partitions.get_claimant_by_key(key)?
      else
        @printf[I32](("Could not find claimant for key " +
          " '%s'\n\n").cstring(), HashableKey.string(key).cstring())
        Fail()
        return (true, latest_ts)
      end
    if worker == _worker_name then
      try
        let idx = (HashKey(key) % _state_steps.size().u128()).usize()

        let s = _state_steps(idx)?
        ifdef "trace" then
          @printf[I32]("PartitionRouter found Route\n".cstring())
        end
        consumer_sender.send[D](metric_name, pipeline_time_spent,
          data, key, event_ts, watermark_ts, i_msg_uid, frac_ids, latest_ts,
          metrics_id, worker_ingress_ts, s)
        (false, latest_ts)
      else
        ifdef debug then
          @printf[I32](("StatePartitionRouter.route: No state step for " +
            "key '%s'\n\n").cstring(), HashableKey.string(key).cstring())
        end
        Fail()
        (false, latest_ts)
      end
    else
      try
        let r = _hashed_node_routes(worker)?
        let msg = r.build_msg[D](_worker_name, metric_name,
          pipeline_time_spent, data, key, event_ts, watermark_ts, i_msg_uid,
          frac_ids, latest_ts, metrics_id, worker_ingress_ts)
        r.route[ForwardStatePartitionMsg[D]](metric_name,
          pipeline_time_spent, msg, key, event_ts, watermark_ts,
          consumer_sender, i_msg_uid, frac_ids, latest_ts, metrics_id,
          worker_ingress_ts)
      else
        // We should have a route to any claimant we know about
        Fail()
        (true, latest_ts)
      end
    end

  fun routes(): Map[RoutingId, Consumer] val =>
    let m = recover iso Map[RoutingId, Consumer] end
    for (id, step) in _step_ids.pairs() do
      m(id) = step
    end
    for (w, hpr) in _hashed_node_routes.pairs() do
      try
        m(_worker_routing_ids(w)?) = hpr.target_boundary()
      else
        @printf[I32](("StatePartitionRouter: Failed to find state routing " +
          "id for %s\n").cstring(), w.cstring())
        Fail()
      end
    end
    consume m

  fun routes_not_in(router: Router): Map[RoutingId, Consumer] val =>
    let diff = recover iso Map[RoutingId, Consumer] end
    let other_routes = router.routes()
    for (id, r) in routes().pairs() do
      if not other_routes.contains(id) then diff(id) = r end
    end
    consume diff

  fun update_boundaries(auth: AmbientAuth,
    ob: box->Map[String, OutgoingBoundary]): StatePartitionRouter
  =>
    let new_hashed_node_routes = recover trn Map[String, HashedProxyRouter] end

    for (w, hpr) in _hashed_node_routes.pairs() do
      new_hashed_node_routes(w) = hpr
    end
    for (w, b) in ob.pairs() do
      new_hashed_node_routes(w) = HashedProxyRouter(w, b, _step_group, auth)
    end

    StatePartitionRouter(_step_group, _worker_name,
      _state_steps, _step_ids, consume new_hashed_node_routes,
      _hash_partitions, _worker_routing_ids, _local_routing)

  fun receive_key_state(key: Key, state: ByteSeq val) =>
    let idx = (HashKey(key) % _state_steps.size().u128()).usize()
    try
      let step = _state_steps(idx)?
      step.receive_key_state(_step_group, key, state)
    else
      Fail()
    end

  fun val recalculate_hash_partitions_for_join(auth: AmbientAuth,
    joining_workers: Array[String] val,
    outgoing_boundaries: Map[String, OutgoingBoundary]): StatePartitionRouter
  =>
    // If we're using local routing, then a join is irrelevant.
    if _local_routing then
      return this
    end

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
        new_hashed_node_routes(w) = HashedProxyRouter(w, b, _step_group, auth)
      else
        Fail()
      end
    end

    StatePartitionRouter(_step_group, _worker_name,
      _state_steps, _step_ids, consume new_hashed_node_routes,
      new_hash_partitions, _worker_routing_ids, _local_routing)

  fun val recalculate_hash_partitions_for_shrink(
    leaving_workers: Array[String] val): StatePartitionRouter
  =>
    // If we're using local routing, then a shrink is irrelevant.
    if _local_routing then
      return this
    end

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

    StatePartitionRouter(_step_group, _worker_name,
      _state_steps, _step_ids, consume new_hashed_node_routes,
      new_hash_partitions, _worker_routing_ids, _local_routing)

  fun hash_partitions(): HashPartitions =>
    _hash_partitions

  fun update_hash_partitions(hp: HashPartitions): StatePartitionRouter =>
    StatePartitionRouter(_step_group, _worker_name,
      _state_steps, _step_ids, _hashed_node_routes, hp,
      _worker_routing_ids, _local_routing)

  fun val rebalance_steps_grow(auth: AmbientAuth,
    target_workers: Array[(String, OutgoingBoundary)] val,
    router_registry: RouterRegistry ref,
    local_keys: KeySet,
    checkpoint_id: CheckpointId): (StatePartitionRouter, Bool)
  =>
    """
    Begin migration of state steps known to this router that we determine
    must be routed. Return the new router and a Bool indicating whether
    we migrated any steps.
    """
    // If we're using local routing, then there is nothing to migrate.
    if _local_routing then
      return (this, false)
    end

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
      for k in local_keys.values() do
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
    let steps_to_migrate =
      Array[(String, OutgoingBoundary, Key, RoutingId, Step)]
    for (w, ks) in keys_to_move_by_worker.pairs() do
      for k in ks.values() do
        try
          let boundary = new_boundaries(w)?
          let step_idx = (HashKey(k) % _state_steps.size().u128()).usize()
          let step = _state_steps(step_idx)?
          let step_id = _consumer_ids(step)?
          steps_to_migrate.push((w, boundary, k, step_id, step))
        else
          Fail()
        end
      end
    end

    // Update routes for the new StatePartitionRouter we will return
    let new_hashed_node_routes = recover trn Map[String, HashedProxyRouter] end

    for (w, pr) in _hashed_node_routes.pairs() do
      new_hashed_node_routes(w) = pr
    end
    for (w, b) in new_boundaries.pairs() do
      new_hashed_node_routes(w) = HashedProxyRouter(w, b, _step_group, auth)
    end

    // Actually initiate migration of steps
    let had_keys_to_migrate = migrate_keys(router_registry,
      steps_to_migrate, target_workers.size(), checkpoint_id)

    let new_router = StatePartitionRouter(_step_group,
      _worker_name, _state_steps, _step_ids, consume new_hashed_node_routes,
      new_hash_partitions, _worker_routing_ids, _local_routing)
    (new_router, had_keys_to_migrate)

  fun val rebalance_steps_shrink(
    target_workers: Array[(String, OutgoingBoundary)] val,
    leaving_workers: Array[String] val,
    router_registry: RouterRegistry ref,
    local_keys: KeySet,
    checkpoint_id: CheckpointId): Bool
  =>
    // If we're using local routing, then there is nothing to migrate.
    if _local_routing then
      return false
    end

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
      for k in local_keys.values() do
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
    let steps_to_migrate = Array[(WorkerName, OutgoingBoundary, Key, RoutingId,
      Step)]
    for (w, ks) in keys_to_move.pairs() do
      for k in ks.values() do
        try
          let boundary = remaining_boundaries(w)?
          let step_idx = (HashKey(k) % _state_steps.size().u128()).usize()
          let step = _state_steps(step_idx)?
          let step_id = _consumer_ids(step)?
          steps_to_migrate.push((w, boundary, k, step_id, step))
        else
          Fail()
        end
      end
    end
    migrate_keys(router_registry, steps_to_migrate, target_workers.size(),
      checkpoint_id)

  fun migrate_keys(router_registry: RouterRegistry ref,
    keys_to_migrate': Array[(WorkerName, OutgoingBoundary, Key, RoutingId,
    Step)], target_worker_count: USize, checkpoint_id: CheckpointId): Bool
  =>
    """
    Actually initiate the migration of steps. Return false if none were
    migrated.
    """
    @printf[I32]("^^Migrating %lu keys to %d workers\n".cstring(),
      keys_to_migrate'.size(), target_worker_count)
    if keys_to_migrate'.size() > 0 then
      for (target_worker, boundary, key, step_id, step)
        in keys_to_migrate'.values()
      do
        router_registry.add_to_key_waiting_list(key)
        step.send_state(boundary, _step_group, key, checkpoint_id)
        @printf[I32](
          "^^Migrating key %s to outgoing boundary %s/%lx\n"
            .cstring(), HashableKey.string(key).cstring(),
            target_worker.cstring(), boundary)
      end
      true
    else
      false
    end

  fun add_worker_routing_id(worker: WorkerName, routing_id: RoutingId):
    StatePartitionRouter
  =>
    let new_worker_routing_ids = recover iso Map[WorkerName, RoutingId] end
    for (w, r_id) in _worker_routing_ids.pairs() do
      new_worker_routing_ids(w) = r_id
    end
    new_worker_routing_ids(worker) = routing_id
    StatePartitionRouter(_step_group, _worker_name, _state_steps,
      _step_ids, _hashed_node_routes, _hash_partitions,
      consume new_worker_routing_ids, _local_routing)

  fun distribution_digest(): Map[WorkerName, Array[String] val] val =>
    // Return a map of form {worker_name: routing_ids_as_strings}
    let digest = recover iso Map[WorkerName, Array[String] val] end
    // First for this worker
    let a = recover iso Array[String] end
    for id in _step_ids.keys() do
      a.push(id.string())
    end
    digest(_worker_name) = consume a
    let others = Map[WorkerName, Array[String]]
    for (k, v) in others.pairs() do
      let next = recover iso Array[String] end
      for id in v.values() do
        next.push(id)
      end
      digest(k) = consume next
    end
    consume digest

  fun eq(that: box->Router): Bool =>
    match that
    | let o: box->StatePartitionRouter =>
        MapTagEquality[RoutingId, Step](_step_ids, o._step_ids) and
        (_hash_partitions == o._hash_partitions)
    else
      false
    end

  fun hash(): USize =>
    _step_group.hash()

class val StatelessPartitionRouter is Router
  let _partition_id: RoutingId
  let _worker_name: String
  let _workers: Array[WorkerName] val

  let _local_partitions: Array[Step] val
  let _local_partition_ids: MapIs[Step, RoutingId] val
  let _proxies: Map[WorkerName, ProxyRouter] val

  let _steps_per_worker: USize
  let _partition_size: USize

  // Special routing ids assigned to each worker that are used to route
  // messages to the portion of this collection of stateless partitions
  // found on that worker.
  let _worker_routing_ids: Map[WorkerName, RoutingId] val

  new val create(p_id: RoutingId, worker_name: String,
    workers: Array[WorkerName] val, local_partitions: Array[Step] val,
    local_partition_ids: MapIs[Step, RoutingId] val,
    worker_routing_ids: Map[WorkerName, RoutingId] val,
    proxies: Map[WorkerName, ProxyRouter] val,
    steps_per_worker: USize)
  =>
    _partition_id = p_id
    _worker_name = worker_name
    _workers = workers
    _local_partitions = local_partitions
    _local_partition_ids = local_partition_ids
    _worker_routing_ids = worker_routing_ids
    _proxies = proxies
    _steps_per_worker = steps_per_worker
    _partition_size = _workers.size() * _steps_per_worker

  fun size(): USize =>
    _partition_size

  fun local_size(): USize =>
    _steps_per_worker

  fun partition_routing_id(): RoutingId =>
    _partition_id

  fun route[D: Any val](metric_name: String, pipeline_time_spent: U64, data: D,
    key: Key, event_ts: U64, watermark_ts: U64,
    consumer_sender: TestableConsumerSender,
    i_msg_uid: MsgId, frac_ids: FractionalMessageId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64): (Bool, U64)
  =>
    ifdef "trace" then
      @printf[I32]("Rcvd msg at StatelessPartitionRouter\n".cstring())
    end
    try
      let hashed_key = HashKey(key)
      let w_idx = (hashed_key % _workers.size().u128()).usize()
      let target_worker = _workers(w_idx)?

      if target_worker == _worker_name then
        let s_idx = (hashed_key % _local_partitions.size().u128()).usize()
        let step = _local_partitions(s_idx)?
        @printf[I32]("SLF: StatelessPartitionRouter.route: send: i_msg_uid = %lu\n".cstring(), i_msg_uid)
        consumer_sender.send[D](metric_name, pipeline_time_spent, data, key,
          event_ts, watermark_ts, i_msg_uid, frac_ids,
          latest_ts, metrics_id, worker_ingress_ts, step)
        (false, latest_ts)
      else
        let msg = ForwardStatelessPartitionMsg[D](_partition_id, _worker_name,
          data, key, event_ts, watermark_ts, metric_name, i_msg_uid, frac_ids)
        let proxy = _proxies(target_worker)?
        let ob = proxy.target_boundary()
        @printf[I32]("SLF: StatelessPartitionRouter.route: forward: proxy = 0x%lx ob = 0x%lx target_worker %s w_idx %lu this 0x%lx\n".cstring(), proxy, ob, target_worker.cstring(), w_idx, this)
        consumer_sender.forward(msg, pipeline_time_spent, latest_ts,
          metrics_id, metric_name, worker_ingress_ts, ob)
        (false, latest_ts)
      end
    else
      @printf[I32]("Can't find route!\n".cstring())
      Fail()
      (true, latest_ts)
    end

  fun routes(): Map[RoutingId, Consumer] val =>
    let m = recover iso Map[RoutingId, Consumer] end

    for step in _local_partitions.values() do
      try
        let id = _local_partition_ids(step)?
        m(id) = step
      else
        Fail()
      end
    end
    for pr in _proxies.values() do
      for (r_id, r) in pr.routes().pairs() do
        m(r_id) = r
      end
    end
    consume m

  fun routes_not_in(router: Router): Map[RoutingId, Consumer] val =>
    let diff = recover iso Map[RoutingId, Consumer] end
    let other_routes = router.routes()
    for (id, r) in routes().pairs() do
      if not other_routes.contains(id) then diff(id) = r end
    end
    consume diff

  fun update_boundaries(ob: box->Map[String, OutgoingBoundary]):
    StatelessPartitionRouter
  =>
    @printf[I32]("SLF: StatelessPartitionRouter proxies update line %d\n".cstring(), __loc.line())
    let new_proxies = recover iso Map[WorkerName, ProxyRouter] end
    for (w, pr) in _proxies.pairs() do
      new_proxies(w) = pr.update_boundary(ob)
    end
    StatelessPartitionRouter(_partition_id, _worker_name, _workers,
      _local_partitions, _local_partition_ids,
      _worker_routing_ids, consume new_proxies,
      _steps_per_worker)

  fun add_worker(joining_worker: WorkerName, group_routing_id: RoutingId,
    proxy_router: ProxyRouter): StatelessPartitionRouter
  =>
    let new_workers = recover iso Array[WorkerName] end
    for w in _workers.values() do
      new_workers.push(w)
    end
    new_workers.push(joining_worker)

    let new_r_ids = recover iso Map[WorkerName, RoutingId] end
    for (w, r_id) in _worker_routing_ids.pairs() do
      new_r_ids(w) = r_id
    end
    new_r_ids(joining_worker) = group_routing_id

    @printf[I32]("SLF: StatelessPartitionRouter proxies update line %d\n".cstring(), __loc.line())
    let new_proxies = recover iso Map[WorkerName, ProxyRouter] end
    for (w, pr) in _proxies.pairs() do
      new_proxies(w) = pr
    end
    new_proxies(joining_worker) = proxy_router

    StatelessPartitionRouter(_partition_id, _worker_name, consume new_workers,
      _local_partitions, _local_partition_ids, consume new_r_ids,
      consume new_proxies, _steps_per_worker)

  fun remove_workers(leaving_workers: Array[WorkerName] val):
    StatelessPartitionRouter
  =>
    let new_workers = recover iso Array[WorkerName] end
    let new_proxies = recover iso Map[WorkerName, ProxyRouter] end
    let new_r_ids = recover iso Map[WorkerName, RoutingId] end

    for w in _workers.values() do
      if not ArrayHelpers[WorkerName].contains[WorkerName](leaving_workers,
        w)
      then
        new_workers.push(w)
      end
    end
    @printf[I32]("SLF: StatelessPartitionRouter proxies update line %d\n".cstring(), __loc.line())
    for (w, pr) in _proxies.pairs() do
      if not ArrayHelpers[WorkerName].contains[WorkerName](leaving_workers,
        w)
      then
        new_proxies(w) = pr
      end
    end
    for (w, r_id) in _worker_routing_ids.pairs() do
      if not ArrayHelpers[WorkerName].contains[WorkerName](leaving_workers,
        w)
      then
        new_r_ids(w) = r_id
      end
    end

    StatelessPartitionRouter(_partition_id, _worker_name,
      consume new_workers, _local_partitions, _local_partition_ids,
      consume new_r_ids, consume new_proxies, _steps_per_worker)

  fun distribution_digest(): Map[String, Array[String] val] val =>
    // Return a map of form {worker_name: step_ids_as_strings}
    let digest = recover iso Map[String, Array[String] val] end
    // Accumulate step_ids per worker
    let local_step_ids = recover iso Array[String] end
    try
      for step in _local_partitions.values() do
        let step_id = _local_partition_ids(step)?
        local_step_ids.push(step_id.string())
      end
    else
      Fail()
    end
    digest(_worker_name) = consume local_step_ids
    consume digest

  fun eq(that: box->Router): Bool =>
    match that
    | let o: box->StatelessPartitionRouter =>
      // !TODO!: We need to figure this out:
      true
    else
      false
    end

  fun hash(): USize =>
    _partition_id.hash()

class val HashedProxyRouter is Router
  let _target_worker_name: WorkerName
  let _target: OutgoingBoundary
  let _target_step_group: RoutingId
  let _auth: AmbientAuth

  new val create(target_worker: String, target: OutgoingBoundary,
    target_step_group: RoutingId, auth: AmbientAuth)
  =>
    _target_worker_name = target_worker
    _target = target
    _target_step_group = target_step_group
    _auth = auth

  fun build_msg[D: Any val](worker_name: WorkerName, metric_name: String,
    pipeline_time_spent: U64, data: D, key: Key, event_ts: U64,
    watermark_ts: U64, i_msg_uid: MsgId, frac_ids: FractionalMessageId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64):
    ForwardStatePartitionMsg[D]
  =>
    ForwardStatePartitionMsg[D](_target_step_group, _target_worker_name,
      data, key, event_ts, watermark_ts, metric_name, i_msg_uid, frac_ids)

  fun route[D: Any val](metric_name: String, pipeline_time_spent: U64, data: D,
    key: Key, event_ts: U64, watermark_ts: U64,
    consumer_sender: TestableConsumerSender,
    i_msg_uid: MsgId, frac_ids: FractionalMessageId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64): (Bool, U64)
  =>
    ifdef "trace" then
      @printf[I32]("Rcvd msg at HashedProxyRouter\n".cstring())
    end

    match data
    | let m: DeliveryMsg =>
      consumer_sender.forward(m, pipeline_time_spent, latest_ts, metrics_id,
        metric_name, worker_ingress_ts, _target)
    else
      Fail()
    end

    (false, latest_ts)

  fun routes(): Map[RoutingId, Consumer] val =>
    recover val Map[RoutingId, Consumer] end

  fun routes_not_in(router: Router): Map[RoutingId, Consumer] val =>
    recover val Map[RoutingId, Consumer] end

  fun val update_boundary(ob: box->Map[String, OutgoingBoundary]):
    HashedProxyRouter
  =>
    try
      let new_target = ob(_target_worker_name)?
      if new_target isnt _target then
        HashedProxyRouter(_target_worker_name, new_target,
          _target_step_group, _auth)
      else
        this
      end
    else
      Fail()
      this
    end

  fun target_boundary(): OutgoingBoundary =>
    _target

  fun eq(that: box->Router): Bool =>
    match that
    | let hpr: HashedProxyRouter =>
      (_target_worker_name == hpr._target_worker_name) and
        (_target is hpr._target)
    else
      false
    end

  fun hash(): USize =>
    _target_step_group.hash() xor (digestof _target).hash()
