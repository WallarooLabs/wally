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
use "files"
use "itertools"
use "net"
use "wallaroo_labs/collection_helpers"
use "wallaroo_labs/equality"
use "wallaroo/core/boundary"
use "wallaroo/core/common"
use "wallaroo/core/initialization"
use "wallaroo/core/invariant"
use "wallaroo/core/metrics"
use "wallaroo/core/routing"
use "wallaroo/core/state"
use "wallaroo/ent/barrier"
use "wallaroo/ent/data_receiver"
use "wallaroo/ent/network"
use "wallaroo/ent/recovery"
use "wallaroo/ent/router_registry"
use "wallaroo_labs/mort"

class val Partitions[In: Any val]
  let _function: PartitionFunction[In] val
  let _keys: Array[Key] val

  new val create(f: PartitionFunction[In] val,
    ks: Array[Key] val)
  =>
    _function = f
    _keys = ks

  fun function(): PartitionFunction[In] val => _function
  fun keys(): Array[Key] val => _keys

interface val PartitionFunction[In: Any val]
  fun apply(input: In): Key

primitive SingleStepPartitionFunction[In: Any val] is
  PartitionFunction[In]
  fun apply(input: In): String => "key"

class val KeyDistribution is Equatable[KeyDistribution]
  let _hash_partitions: HashPartitions
  let _workers_to_keys: Map[WorkerName, Array[Key] val] val

  new val create(hp: HashPartitions,
    wtk: Map[WorkerName, Array[Key] val] val)
  =>
    _hash_partitions = hp
    _workers_to_keys = wtk

  fun claimants(): Iterator[WorkerName] =>
    _hash_partitions.claimants()

  fun hash_partitions(): HashPartitions =>
    _hash_partitions

  fun workers_to_keys(): Map[WorkerName, Array[Key] val] val =>
    _workers_to_keys

  fun local_keys(w: WorkerName): Array[Key] val =>
    try
      _workers_to_keys(w)?
    else
      Fail()
      recover val Array[Key] end
    end

  fun update_key(key: Key, pa: ProxyAddress): KeyDistribution val =>
    let new_workers_to_keys = recover trn Map[String, Array[Key] val] end

    var old_key_target = ""
    for (w, ks) in _workers_to_keys.pairs() do
      new_workers_to_keys(w) = ks
      if ArrayHelpers[Key].contains[Key](ks, key) then
        old_key_target = w
      end
    end

    try
      if old_key_target != "" then
        let old_target_keys = _workers_to_keys(old_key_target)?
        let new_keys = recover trn Array[Key] end
        for k in old_target_keys.values() do
          if k != key then new_keys.push(k) end
        end
        new_workers_to_keys(old_key_target) = consume new_keys
      end

      let new_key_target = pa.worker
      let new_keys_for_new_target = recover trn Array[Key] end
      for k in _workers_to_keys(new_key_target)?.values() do
        new_keys_for_new_target.push(k)
      end
      new_keys_for_new_target.push(key)
      new_workers_to_keys(new_key_target) = consume new_keys_for_new_target
    else
      Fail()
    end

    KeyDistribution(_hash_partitions, consume new_workers_to_keys)

  fun add_worker_name(worker: String): KeyDistribution =>
    let workers = recover iso
      Array[String].>concat(_hash_partitions.claimants()).>push(worker)
    end

    let new_hash_partitions = HashPartitions(consume workers)

    KeyDistribution(consume new_hash_partitions, _workers_to_keys)

  fun eq(that: box->KeyDistribution): Bool =>
    _hash_partitions == that._hash_partitions

  fun ne(that: box->KeyDistribution): Bool => not eq(that)

interface StateAddresses
  fun apply(key: Key): (Step tag | ProxyRouter | None)
  fun steps(): Array[Consumer] val

class KeyedStateAddresses
  let _addresses: Map[Key, (Step | ProxyRouter)] val

  new val create(a: Map[Key, (Step | ProxyRouter)] val) =>
    _addresses = a

  fun apply(key: Key): (Step | ProxyRouter | None) =>
    try
      _addresses(key)?
    else
      None
    end

  fun steps(): Array[Consumer] val =>
    let ss = recover trn Array[Consumer] end
    for s in _addresses.values() do
      match s
      | let cfcs: Consumer =>
        ss.push(cfcs)
      end
    end

    consume ss

trait val StateSubpartitions is Equatable[StateSubpartitions]
  fun per_worker_parallelism(): USize
  fun build(app_name: String, worker_name: WorkerName,
    worker_names: Array[WorkerName] val, metrics_conn: MetricsSink,
    auth: AmbientAuth, event_log: EventLog,
    all_local_keys: Map[StateName, SetIs[Key] val] val,
    recovery_replayer: RecoveryReconnecter,
    outgoing_boundaries: Map[WorkerName, OutgoingBoundary] val,
    initializables: Initializables,
    data_routes: Map[RoutingId, Consumer],
    state_step_assigned_ids: Map[StateName, Array[RoutingId] val] val,
    state_steps: Map[StateName, Array[Step] val],
    state_step_ids: Map[StateName, Map[RoutingId, Step] val],
    state_routing_ids: Map[WorkerName, RoutingId] val,
    router_registery: RouterRegistry): PartitionRouter
  fun update_key(key: Key, pa: ProxyAddress): StateSubpartitions ?
  fun add_worker_name(worker: String): StateSubpartitions
  fun initial_local_keys(w: WorkerName): SetIs[Key] val
  fun runner_builder(): RunnerBuilder

class val KeyedStateSubpartitions[S: State ref] is
  StateSubpartitions
  let _state_name: StateName
  let _per_worker_parallelism: USize
  let _key_distribution: KeyDistribution
  let _id_map: Map[Key, RoutingId] val
  let _pipeline_name: String
  let _runner_builder: RunnerBuilder

  new val create(state_name': StateName, per_worker_parallelism': USize,
    key_distribution': KeyDistribution,
    id_map': Map[Key, RoutingId] val, runner_builder': RunnerBuilder,
    pipeline_name': String)
  =>
    _state_name = state_name'
    _per_worker_parallelism = per_worker_parallelism'
    _key_distribution = key_distribution'
    _id_map = id_map'
    _pipeline_name = pipeline_name'
    _runner_builder = runner_builder'

  fun per_worker_parallelism(): USize =>
    _per_worker_parallelism

  fun runner_builder(): RunnerBuilder =>
    _runner_builder

  fun build(app_name: String, worker_name: WorkerName,
    worker_names: Array[WorkerName] val, metrics_conn: MetricsSink,
    auth: AmbientAuth, event_log: EventLog,
    all_local_keys: Map[StateName, SetIs[Key] val] val,
    recovery_replayer: RecoveryReconnecter,
    outgoing_boundaries: Map[WorkerName, OutgoingBoundary] val,
    initializables: Initializables,
    data_routes: Map[RoutingId, Consumer],
    state_step_assigned_ids: Map[StateName, Array[RoutingId] val] val,
    state_steps: Map[StateName, Array[Step] val],
    state_step_ids: Map[StateName, Map[RoutingId, Step] val],
    state_routing_ids: Map[WorkerName, RoutingId] val,
    router_registry: RouterRegistry): LocalPartitionRouter[S]
  =>
    let hashed_node_routes = recover trn Map[WorkerName, HashedProxyRouter] end
    let new_state_steps = recover iso Array[Step] end
    let new_state_step_ids = recover iso Map[RoutingId, Step] end

    try
      let local_keys =
        try
          all_local_keys(_state_name)?
        else
          SetIs[Key]
        end
      let step_ids = state_step_assigned_ids(_state_name)?

      ifdef debug then
        Invariant(_per_worker_parallelism == step_ids.size())
      end

      @printf[I32](("Spinning up " + _per_worker_parallelism.string() +
        " state partitions for " + _pipeline_name + " pipeline\n").cstring())

      for next_step_id in step_ids.values() do
        let reporter = MetricsReporter(app_name, worker_name,
          metrics_conn)
        let next_state_step = Step(auth, _runner_builder(
          where event_log = event_log, auth = auth),
          consume reporter, next_step_id, event_log, recovery_replayer,
          outgoing_boundaries, router_registry)
        new_state_steps.push(next_state_step)
        initializables.set(next_state_step)
        data_routes(next_step_id) = next_state_step
        new_state_step_ids(next_step_id) = next_state_step
        router_registry.register_producer(next_step_id, next_state_step)
      end
    else
      @printf[I32]("No step ids for state %s\n".cstring(),
        _state_name.cstring())
    end

    for w in worker_names.values() do
      if w != worker_name then
        try
          let boundary = outgoing_boundaries(w)?
          hashed_node_routes(w) = HashedProxyRouter(w, boundary,
            _state_name, auth)
        else
          @printf[I32](("Missing proxy for %s!\n").cstring(), w.cstring())
        end
      end
    end

    let new_state_steps_val = consume val new_state_steps
    let new_state_step_ids_val = consume val new_state_step_ids
    state_steps(_state_name) = new_state_steps_val
    state_step_ids(_state_name) = new_state_step_ids_val

    LocalPartitionRouter[S](_state_name, worker_name,
      new_state_steps_val, new_state_step_ids_val,
      consume hashed_node_routes, _key_distribution.hash_partitions(),
      state_routing_ids)

  fun update_key(key: Key, pa: ProxyAddress): StateSubpartitions =>
    let kpa = _key_distribution.update_key(key, pa)
    KeyedStateSubpartitions[S](_state_name, _per_worker_parallelism, kpa,
      _id_map, _runner_builder, _pipeline_name)

  fun add_worker_name(worker: String): StateSubpartitions =>
    let kd = _key_distribution.add_worker_name(worker)
    KeyedStateSubpartitions[S](_state_name, _per_worker_parallelism, kd,
      _id_map, _runner_builder, _pipeline_name)

  fun initial_local_keys(w: WorkerName): SetIs[Key] val =>
    """
    The keys local to worker w when the application first started up.
    """
    let ks = _key_distribution.local_keys(w)
    let lks = recover iso SetIs[Key] end
    for k in ks.values() do
      lks.set(k)
    end
    consume lks

  fun eq(that: box->StateSubpartitions): Bool =>
    match that
    | let kss: box->KeyedStateSubpartitions[S] =>
      // ASSUMPTION: Add RunnerBuilder equality check assumes that
      // runner builder would not change over time, which currently
      // is true.
      (_key_distribution == kss._key_distribution) and
        (MapEquality[Key, U128](_id_map, kss._id_map)) and
        (_pipeline_name == kss._pipeline_name) and
        (_runner_builder is kss._runner_builder)
    else
      false
    end

  fun ne(that: box->StateSubpartitions): Bool => not eq(that)

primitive PartitionsFileReader
  fun apply(filename: String, auth: AmbientAuth): Array[Key] val =>
    let keys = recover trn Array[Key] end

    try
      let file = File(FilePath(auth, filename)?)
      for line in file.lines() do
        let els = line.split(",")
        match els.size()
        | 0 => None
        | 1 => keys.push(els(0)?)
        // TODO: Remove this, since we no longer support weighted keys
        | 2 => keys.push(els(0)?)
        else
          error
        end
      end
      file.dispose()
    else
      @printf[I32](("ERROR: Problem reading partition file. Each line must " +
        "have a key string\n").cstring())
    end

    consume keys

primitive _Contains
  fun apply[T: (Step | RoutingId | RouteId)](map: Map[String, Map[Key, T]] box,
    state_name: String, key: Key): Bool
  =>
    if map.contains(state_name) then
      try
        let inner_m = map(state_name)?
        inner_m.contains(key)
      else
        Unreachable()
        false
      end
    else
      false
    end
