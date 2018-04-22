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
    test(_TestLocalTopologyEquality)

class iso _TestLocalTopologyEquality is UnitTest
  """
  Test that updating LocalTopology creates the expected changes
  """
  fun name(): String =>
    "initialization/LocalTopologyEquality"

  fun ref apply(h: TestHelper) ? =>
    // These five are currently tested using identity checks (e.g. "x is y")
    // since they cannot be changed. Thus, we need a reference to the same
    // object in the base topology and target topology in order for our
    // equality check to pass in this test. Once they become dynamic, this test
    // will need to be updated.
    let dag = _DagGenerator()
    let partition_function = _PartitionFunctionGenerator()
    let runner_builder = _RunnerBuilderGenerator()
    let pre_state_data = _PreStateDataArrayGenerator(runner_builder)

    var base_topology = _BaseLocalTopologyGenerator(dag, pre_state_data,
      partition_function, runner_builder)
    let target_topology = _TargetLocalTopologyGenerator(dag, pre_state_data,
      partition_function, runner_builder)
    h.assert_eq[Bool](false, base_topology == target_topology)
    base_topology = base_topology.update_proxy_address_for_state_key[String](
      "state", "k1", ProxyAddress("w2", 10))?
    base_topology = base_topology.add_worker_name("w4")
    h.assert_eq[Bool](true, base_topology == target_topology)

primitive _BaseLocalTopologyGenerator
  fun apply(dag: Dag[StepInitializer] val,
    psd: Array[PreStateData] val,
    pf: PartitionFunction[String, String] val,
    rb: RunnerBuilder): LocalTopology
  =>
    LocalTopology("test", "w1", dag, _StepMapGenerator(),
      _BaseStateBuildersGenerator(rb, pf), psd, _ProxyIdsGenerator(),
      _BaseWorkerNamesGenerator(), recover val SetIs[String] end)

primitive _TargetLocalTopologyGenerator
  fun apply(dag: Dag[StepInitializer] val,
    psd: Array[PreStateData] val,
    pf: PartitionFunction[String, String] val,
    rb: RunnerBuilder): LocalTopology
  =>
    LocalTopology("test", "w1", dag, _StepMapGenerator(),
      _TargetStateBuildersGenerator(rb, pf), psd, _ProxyIdsGenerator(),
      _TargetWorkerNamesGenerator(), recover val SetIs[String] end)

primitive _DagGenerator
  fun apply(): Dag[StepInitializer] val =>
    Dag[StepInitializer]

primitive _StepMapGenerator
  fun apply(): Map[U128, (ProxyAddress | U128)] val =>
    let m = recover trn Map[U128, (ProxyAddress | U128)] end
    m(1) = ProxyAddress("w1", 10)
    m(2) = ProxyAddress("w2", 20)
    m(3) = ProxyAddress("w3", 30)
    consume m

primitive _BaseStateBuildersGenerator
  fun apply(rb: RunnerBuilder, pf: PartitionFunction[String, String] val):
    Map[String, StateSubpartition] val
  =>
    let m = recover trn Map[String, StateSubpartition] end
    m("state") = _BaseStateSubpartitionGenerator(rb, pf)
    consume m

primitive _TargetStateBuildersGenerator
  fun apply(rb: RunnerBuilder, pf: PartitionFunction[String, String] val):
    Map[String, StateSubpartition] val
  =>
    let m = recover trn Map[String, StateSubpartition] end
    m("state") = _TargetStateSubpartitionGenerator(rb, pf)
    consume m

primitive _BaseStateSubpartitionGenerator
  fun apply(rb: RunnerBuilder, pf: PartitionFunction[String, String] val):
    StateSubpartition
  =>
    KeyedStateSubpartition[String, String, EmptyState]("s",
      _BaseKeyedPartitionAddressesGenerator(), _IdMapGenerator(),
      rb, pf, "pipeline")

primitive _TargetStateSubpartitionGenerator
  fun apply(rb: RunnerBuilder, pf: PartitionFunction[String, String] val):
    StateSubpartition
  =>
    KeyedStateSubpartition[String, String, EmptyState]("s",
      _TargetKeyedPartitionAddressesGenerator(), _IdMapGenerator(),
      rb, pf, "pipeline")

primitive _BaseKeyedPartitionAddressesGenerator
  fun apply(): KeyedPartitionAddresses[String] val =>
    let m = recover trn Map[String, ProxyAddress] end
    m("k1") = ProxyAddress("w1", 10)
    m("k2") = ProxyAddress("w2", 20)
    m("k3") = ProxyAddress("w3", 30)
    let m': Map[String, ProxyAddress] val = consume m
    KeyedPartitionAddresses[String](m', HashPartitions(recover [] end),
      recover Map[String, Array[String] val] end)

primitive _TargetKeyedPartitionAddressesGenerator
  fun apply(): KeyedPartitionAddresses[String] val =>
    let m = recover trn Map[String, ProxyAddress] end
    m("k1") = ProxyAddress("w2", 10)
    m("k2") = ProxyAddress("w2", 20)
    m("k3") = ProxyAddress("w3", 30)
    let m': Map[String, ProxyAddress] val = consume m
    KeyedPartitionAddresses[String](m', HashPartitions(recover [] end),
      recover Map[String, Array[String] val] end)

primitive _IdMapGenerator
  fun apply(): Map[String, U128] val =>
    let m = recover trn Map[String, U128] end
    m("k1") = 10
    m("k2") = 20
    m("k3") = 30
    consume m

primitive _PartitionFunctionGenerator
  fun apply(): PartitionFunction[String, String] val =>
    {(s: String): String => s}

primitive _PreStateDataArrayGenerator
  fun apply(rb: RunnerBuilder): Array[PreStateData] val =>
    recover [
      _PreStateDataGenerator(rb)
      _PreStateDataGenerator(rb)
      _PreStateDataGenerator(rb)
    ] end

primitive _PreStateDataGenerator
  fun apply(rb: RunnerBuilder): PreStateData =>
    PreStateData(rb, recover Array[StepId] end)

primitive _RunnerBuilderGenerator
  fun apply(): RunnerBuilder =>
    ComputationRunnerBuilder[U8, U8](_ComputationBuilderGenerator(),
      BoundaryOnlyRouteBuilder)

primitive _ComputationBuilderGenerator
  fun apply(): ComputationBuilder[U8, U8] val =>
    {(): Computation[U8, U8] val => _IdentityComputation[U8]}

class val _IdentityComputation[V]
  fun name(): String => "id"
  fun apply(v: V): V =>
    v

primitive _ProxyIdsGenerator
  fun apply(): Map[String, U128] val =>
    recover Map[String, U128] end

primitive _BaseWorkerNamesGenerator
  fun apply(): Array[String] val =>
    recover ["w1"; "w2"; "w3"] end

primitive _TargetWorkerNamesGenerator
  fun apply(): Array[String] val =>
    recover ["w1"; "w2"; "w3"; "w4"] end
