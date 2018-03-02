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
use "net"
use "wallaroo_labs/equality"
use "wallaroo/core/boundary"
use "wallaroo/core/common"
use "wallaroo/ent/data_receiver"
use "wallaroo/ent/network"
use "wallaroo/ent/recovery"
use "wallaroo_labs/mort"
use "wallaroo/core/initialization"
use "wallaroo/core/metrics"
use "wallaroo/core/routing"
use "wallaroo/core/state"

type WeightedKey[Key: (Hashable val & Equatable[Key])] is
  (Key, USize)

class val Partition[In: Any val, Key: (Hashable val & Equatable[Key])]
  let _function: PartitionFunction[In, Key] val
  let _keys: (Array[WeightedKey[Key]] val | Array[Key] val)

  new val create(f: PartitionFunction[In, Key] val,
    ks: (Array[WeightedKey[Key]] val | Array[Key] val))
  =>
    _function = f
    _keys = ks

  fun function(): PartitionFunction[In, Key] val => _function
  fun keys(): (Array[WeightedKey[Key]] val | Array[Key] val) => _keys

interface PartitionFunction[In: Any val, Key:
  (Hashable val & Equatable[Key] val)]
  fun apply(input: In): Key

primitive SingleStepPartitionFunction[In: Any val] is
  PartitionFunction[In, U8]
  fun apply(input: In): U8 => 0

interface val PartitionAddresses is Equatable[PartitionAddresses]
  fun apply(key: Any val): (ProxyAddress | None)
  fun update_key[Key: (Hashable val & Equatable[Key] val)](key: Key,
    pa: ProxyAddress): PartitionAddresses val ?

class val KeyedPartitionAddresses[Key: (Hashable val & Equatable[Key] val)]
  let _addresses: Map[Key, ProxyAddress] val

  new val create(a: Map[Key, ProxyAddress] val) =>
    _addresses = a

  fun apply(k: Any val): (ProxyAddress | None) =>
    match k
    | let key: Key =>
      try
        _addresses(key)?
      else
        None
      end
    else
      None
    end

  fun pairs(): Iterator[(Key, ProxyAddress)] => _addresses.pairs()

  fun update_key[K: (Hashable val & Equatable[K] val)](key: K,
    pa: ProxyAddress): PartitionAddresses val ?
  =>
    let new_addresses = recover trn Map[Key, ProxyAddress] end
    // TODO: This would be much more efficient with a persistent map, since
    // we wouldn't have to copy everything to make a small change.
    for (k, v) in _addresses.pairs() do
      new_addresses(k) = v
    end
    match key
    | let new_key: Key =>
      new_addresses(new_key) = pa
    else
      error
    end
    KeyedPartitionAddresses[Key](consume new_addresses)

  fun eq(that: box->PartitionAddresses): Bool =>
    match that
    | let that_keyed: box->KeyedPartitionAddresses[Key] =>
      MapEquality[Key, ProxyAddress](_addresses, that_keyed._addresses)
    else
      false
    end

  fun ne(that: box->PartitionAddresses): Bool => not eq(that)

interface StateAddresses
  fun apply(key: Any val): (Step tag | ProxyRouter | None)
  fun register_routes(router: Router, route_builder: RouteBuilder)
  fun steps(): Array[Consumer] val

class KeyedStateAddresses[Key: (Hashable val & Equatable[Key] val)]
  let _addresses: Map[Key, (Step | ProxyRouter)] val

  new val create(a: Map[Key, (Step | ProxyRouter)] val) =>
    _addresses = a

  fun apply(k: Any val): (Step | ProxyRouter | None) =>
    match k
    | let key: Key =>
      try
        _addresses(key)?
      else
        None
      end
    else
      None
    end

  fun register_routes(router: Router, route_builder: RouteBuilder) =>
    for s in _addresses.values() do
      match s
      | let step: Step =>
        step.register_routes(router, route_builder)
      end
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

trait val StateSubpartition is Equatable[StateSubpartition]
  fun build(app_name: String, worker_name: String,
    metrics_conn: MetricsSink,
    auth: AmbientAuth, event_log: EventLog,
    recovery_replayer: RecoveryReplayer,
    outgoing_boundaries: Map[String, OutgoingBoundary] val,
    initializables: SetIs[Initializable],
    data_routes: Map[U128, Consumer]): PartitionRouter
  fun update_key[Key: (Hashable val & Equatable[Key] val)](key: Key,
    pa: ProxyAddress): StateSubpartition ?
  fun runner_builder(): RunnerBuilder

class val KeyedStateSubpartition[PIn: Any val,
  Key: (Hashable val & Equatable[Key] val), S: State ref] is StateSubpartition
  let _state_name: String
  let _partition_addresses: KeyedPartitionAddresses[Key] val
  let _id_map: Map[Key, U128] val
  let _partition_function: PartitionFunction[PIn, Key] val
  let _pipeline_name: String
  let _runner_builder: RunnerBuilder

  new val create(state_name': String,
    partition_addresses': KeyedPartitionAddresses[Key] val,
    id_map': Map[Key, U128] val, runner_builder': RunnerBuilder,
    partition_function': PartitionFunction[PIn, Key] val,
    pipeline_name': String)
  =>
    _state_name = state_name'
    _partition_addresses = partition_addresses'
    _id_map = id_map'
    _partition_function = partition_function'
    _pipeline_name = pipeline_name'
    _runner_builder = runner_builder'

  fun runner_builder(): RunnerBuilder =>
    _runner_builder

  fun build(app_name: String, worker_name: String,
    metrics_conn: MetricsSink,
    auth: AmbientAuth, event_log: EventLog,
    recovery_replayer: RecoveryReplayer,
    outgoing_boundaries: Map[String, OutgoingBoundary] val,
    initializables: SetIs[Initializable],
    data_routes: Map[U128, Consumer]):
    LocalPartitionRouter[PIn, Key, S] val
  =>
    let routes = recover trn Map[Key, (Step | ProxyRouter)] end

    let m = recover trn Map[U128, Step] end

    var partition_count: USize = 0

    for (key, id) in _id_map.pairs() do
      let proxy_address = _partition_addresses(key)
      match proxy_address
      | let pa: ProxyAddress =>
        if pa.worker == worker_name then
          let reporter = MetricsReporter(app_name, worker_name, metrics_conn)
          let next_state_step = Step(_runner_builder(where event_log =
            event_log, auth=auth),
            consume reporter, id, _runner_builder.route_builder(),
              event_log, recovery_replayer, outgoing_boundaries)

          initializables.set(next_state_step)
          data_routes(id) = next_state_step
          m(id) = next_state_step
          routes(key) = next_state_step
          partition_count = partition_count + 1
        else
          try
            let boundary = outgoing_boundaries(pa.worker)?

            routes(key) = ProxyRouter(worker_name, boundary,
              pa, auth)
          else
            @printf[I32](("Missing proxy for " + pa.worker + "!\n").cstring())
          end
        end
      else
        @printf[I32]("Missing proxy address!\n".cstring())
      end
    end

    @printf[I32](("Spinning up " + partition_count.string() +
      " state partitions for " + _pipeline_name + " pipeline\n").cstring())

    LocalPartitionRouter[PIn, Key, S](_state_name, worker_name, consume m,
      _id_map, consume routes, _partition_function)

  fun update_key[K: (Hashable val & Equatable[K] val)](k: K,
    pa: ProxyAddress): StateSubpartition ?
  =>
    match k
    | let key: Key =>
      match _partition_addresses.update_key[Key](key, pa)?
      | let kpa: KeyedPartitionAddresses[Key] val =>
        KeyedStateSubpartition[PIn, Key, S](_state_name, kpa, _id_map,
          _runner_builder, _partition_function, _pipeline_name)
      else
        error
      end
    else
      error
    end

  fun eq(that: box->StateSubpartition): Bool =>
    match that
    | let kss: box->KeyedStateSubpartition[PIn, Key, S] =>
      // ASSUMPTION: Add RunnerBuilder equality check assumes that
      // runner builder would not change over time, which currently
      // is true.
      (_partition_addresses == kss._partition_addresses) and
        (MapEquality[Key, U128](_id_map, kss._id_map)) and
        (_partition_function is kss._partition_function) and
        (_pipeline_name == kss._pipeline_name) and
        (_runner_builder is kss._runner_builder)
    else
      false
    end

  fun ne(that: box->StateSubpartition): Bool => not eq(that)

primitive PartitionFileReader
  fun apply(filename: String, auth: AmbientAuth):
    Array[WeightedKey[String]] val
  =>
    let keys = recover trn Array[WeightedKey[String]] end

    try
      let file = File(FilePath(auth, filename)?)
      for line in file.lines() do
        let els = line.split(",")
        match els.size()
        | 0 => None
        | 1 => keys.push((els(0)?, 1))
        | 2 => keys.push((els(0)?, els(1)?.usize()?))
        else
          error
        end
      end
      file.dispose()
    else
      @printf[I32](("ERROR: Problem reading partition file. Each line must " +
        "have a key string and, optionally, a weight (separated by a " +
        "comma)\n").cstring())
    end

    consume keys
