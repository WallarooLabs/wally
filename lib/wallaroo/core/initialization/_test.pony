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
use "ponytest"
use "wallaroo_labs/dag"
use "wallaroo/core/common"
use "wallaroo/core/routing"
use "wallaroo/core/topology"
use "wallaroo/core/state"

actor Main is TestList
  new make() =>
    None

  fun tag tests(test: PonyTest) =>
    None
    // test(_TestLocalTopologyEquality)


// !TODO!: WHAT IS THIS TESTING?

// class iso _TestLocalTopologyEquality is UnitTest
//   """
//   Test that updating LocalTopology creates the expected changes
//   """
//   fun name(): String =>
//     "initialization/LocalTopologyEquality"

//   fun ref apply(h: TestHelper) ? =>
//     // These five are currently tested using identity checks (e.g. "x is y")
//     // since they cannot be changed. Thus, we need a reference to the same
//     // object in the base topology and target topology in order for our
//     // equality check to pass in this test. Once they become dynamic, this test
//     // will need to be updated.
//     let dag = _DagGenerator()
//     let partition_function = _PartitionFunctionGenerator()
//     let runner_builder = _RunnerBuilderGenerator()
//     let pre_state_data = _PreStateDataArrayGenerator(runner_builder)

//     var base_topology = _BaseLocalTopologyGenerator(dag, pre_state_data,
//       partition_function, runner_builder)
//     let target_topology = _TargetLocalTopologyGenerator(dag, pre_state_data,
//       partition_function, runner_builder)
//     h.assert_eq[Bool](false, base_topology == target_topology)
//     base_topology = base_topology.update_proxy_address_for_state_key(
//       "state", "k1", ProxyAddress("w2", 10))?
//     base_topology = base_topology.add_worker_name("w4")
//     h.assert_eq[Bool](true, base_topology == target_topology)

// primitive _BaseLocalTopologyGenerator
//   fun apply(dag: Dag[StepInitializer] val,
//     psd: Array[PreStateData] val,
//     pf: PartitionFunction[String] val,
//     rb: RunnerBuilder): LocalTopology
//   =>
//     LocalTopology("test", "w1", dag, _StepMapGenerator(),
//       _BaseStateBuildersGenerator(rb, pf), psd, _ProxyIdsGenerator(),
//       recover val Map[StateName, Array[RoutingId] val] end,
//       _BaseWorkerNamesGenerator(), recover val SetIs[String] end,
//       recover val Map[StateName, Map[WorkerName, RoutingId] val] end,
//       recover val Map[RoutingId, Map[WorkerName, RoutingId] val] end,
//       0)

// primitive _TargetLocalTopologyGenerator
//   fun apply(dag: Dag[StepInitializer] val,
//     psd: Array[PreStateData] val,
//     pf: PartitionFunction[String] val,
//     rb: RunnerBuilder): LocalTopology
//   =>
//     LocalTopology("test", "w1", dag, _StepMapGenerator(),
//       _TargetStateBuildersGenerator(rb, pf), psd, _ProxyIdsGenerator(),
//       recover val Map[StateName, Array[RoutingId] val] end,
//       _TargetWorkerNamesGenerator(), recover val SetIs[String] end,
//       recover val Map[StateName, Map[WorkerName, RoutingId] val] end,
//       recover val Map[RoutingId, Map[WorkerName, RoutingId] val] end,
//       0)

// primitive _DagGenerator
//   fun apply(): Dag[StepInitializer] val =>
//     Dag[StepInitializer]

// primitive _StepMapGenerator
//   fun apply(): Map[U128, (ProxyAddress | U128)] val =>
//     let m = recover trn Map[U128, (ProxyAddress | U128)] end
//     m(1) = ProxyAddress("w1", 10)
//     m(2) = ProxyAddress("w2", 20)
//     m(3) = ProxyAddress("w3", 30)
//     consume m

// primitive _BaseStateBuildersGenerator
//   fun apply(rb: RunnerBuilder, pf: PartitionFunction[String] val):
//     Map[String, StateSubpartitions] val
//   =>
//     let m = recover trn Map[String, StateSubpartitions] end
//     m("state") = _BaseStateSubpartitionsGenerator(rb)
//     consume m

// primitive _TargetStateBuildersGenerator
//   fun apply(rb: RunnerBuilder, pf: PartitionFunction[String] val):
//     Map[String, StateSubpartitions] val
//   =>
//     let m = recover trn Map[String, StateSubpartitions] end
//     m("state") = _TargetStateSubpartitionsGenerator(rb)
//     consume m

// primitive _BaseStateSubpartitionsGenerator
//   fun apply(rb: RunnerBuilder):
//     StateSubpartitions
//   =>
//     KeyedStateSubpartitions[EmptyState]("s", 1,
//       _BaseKeyDistributionGenerator(), _IdMapGenerator(),
//       rb, "pipeline")

// primitive _TargetStateSubpartitionsGenerator
//   fun apply(rb: RunnerBuilder):
//     StateSubpartitions
//   =>
//     KeyedStateSubpartitions[EmptyState]("s", 1,
//       _TargetKeyDistributionGenerator(), _IdMapGenerator(),
//       rb, "pipeline")

// primitive _HashPartitionsAndWorkersToKeys
//   fun apply(workers: Array[String] val, keys: Array[String] val)
//     : (HashPartitions, Map[String, Array[String] val] val)
//   =>
//     let hash_partitions = HashPartitions(workers)

//     let wtk = recover val

//       let wtk' = Map[String, Array[String]]

//       for w in workers.values() do
//         wtk'(w) = Array[String]
//       end

//       for k in keys.values() do
//         try
//           wtk'(hash_partitions.get_claimant_by_key(k)?)?.push(k)
//         end
//       end

//       let wtk'' = Map[String, Array[String] val]

//       for (w, w_keys) in wtk'.pairs() do
//         let new_keys = recover iso Array[String] end
//         for k in w_keys.values() do
//           new_keys.push(k)
//         end
//         wtk''(w) = consume new_keys
//       end

//       wtk''
//     end

//     (hash_partitions, wtk)

// primitive _BaseKeyDistributionGenerator
//   fun apply(): KeyDistribution val =>
//     let workers = _BaseWorkerNamesGenerator()
//     let keys = recover val ["k1"; "k2"; "k3"] end

//     (let hp, let wtk) =
//       _HashPartitionsAndWorkersToKeys(workers, keys)

//     KeyDistribution(hp, wtk)

// primitive _TargetKeyDistributionGenerator
//   fun apply(): KeyDistribution val =>
//     let workers = _TargetWorkerNamesGenerator()
//     let keys = recover val ["k1"; "k2"; "k3"] end

//     (let hp, let wtk) =
//       _HashPartitionsAndWorkersToKeys(workers, keys)

//     KeyDistribution(hp, wtk)

// primitive _IdMapGenerator
//   fun apply(): Map[String, U128] val =>
//     let m = recover trn Map[String, U128] end
//     m("k1") = 10
//     m("k2") = 20
//     m("k3") = 30
//     consume m

// primitive _PartitionFunctionGenerator
//   fun apply(): PartitionFunction[String] val =>
//     {(s: String): String => s}

// primitive _PreStateDataArrayGenerator
//   fun apply(rb: RunnerBuilder): Array[PreStateData] val =>
//     recover [
//       _PreStateDataGenerator(rb)
//       _PreStateDataGenerator(rb)
//       _PreStateDataGenerator(rb)
//     ] end

// primitive _PreStateDataGenerator
//   fun apply(rb: RunnerBuilder): PreStateData =>
//     PreStateData(rb, recover Array[RoutingId] end)

// primitive _RunnerBuilderGenerator
//   fun apply(): RunnerBuilder =>
//     ComputationRunnerBuilder[U8, U8](_ComputationBuilderGenerator())

// primitive _ComputationBuilderGenerator
//   fun apply(): ComputationBuilder[U8, U8] val =>
//     {(): Computation[U8, U8] val => _IdentityComputation[U8]}

// class val _IdentityComputation[V]
//   fun name(): String => "id"
//   fun apply(v: V): V =>
//     v

// primitive _ProxyIdsGenerator
//   fun apply(): Map[String, U128] val =>
//     recover Map[String, U128] end

// primitive _BaseWorkerNamesGenerator
//   fun apply(): Array[String] val =>
//     recover ["w1"; "w2"; "w3"] end

// primitive _TargetWorkerNamesGenerator
//   fun apply(): Array[String] val =>
//     recover ["w1"; "w2"; "w3"; "w4"] end
