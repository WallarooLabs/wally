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
use "wallaroo/core/common"
use "wallaroo/ent/network"
use "wallaroo/ent/recovery"
use "wallaroo_labs/mort"
use "wallaroo/core/messages"
use "wallaroo/core/metrics"
use "wallaroo/core/sink"
use "wallaroo/core/sink/tcp_sink"
use "wallaroo/core/source"
use "wallaroo/core/source/tcp_source"
use "wallaroo/core/state"
use "wallaroo/core/routing"
use "wallaroo/core/topology"

class Application
  let _name: String
  let pipelines: Array[BasicPipeline] = Array[BasicPipeline]
  // _state_builders maps from state_name to StateSubpartition
  let _state_builders: Map[String, PartitionBuilder] = _state_builders.create()
  var sink_count: USize = 0

  new create(name': String) =>
    _name = name'

  fun ref new_pipeline[In: Any val, Out: Any val] (pipeline_name: String,
    source_config: SourceConfig[In]): PipelineBuilder[In, Out, In]
  =>
    // We have removed the ability to turn coalescing off at the command line.
    let coalescing = true
    let pipeline_id = pipelines.size()
    let pipeline = Pipeline[In, Out](_name, pipeline_id, pipeline_name,
      source_config, coalescing)
    PipelineBuilder[In, Out, In](this, pipeline)

  fun ref add_pipeline(p: BasicPipeline) =>
    pipelines.push(p)

  fun ref add_state_builder(state_name: String,
    state_partition: PartitionBuilder)
  =>
    _state_builders(state_name) = state_partition

  fun ref increment_sink_count() =>
    sink_count = sink_count + 1

  fun state_builder(state_name: String): PartitionBuilder ? =>
    _state_builders(state_name)?

  fun state_builders(): Map[String, PartitionBuilder] val =>
    let builders = recover trn Map[String, PartitionBuilder] end
    for (k, v) in _state_builders.pairs() do
      builders(k) = v
    end
    consume builders

  fun name(): String => _name

trait BasicPipeline
  fun name(): String
  fun source_id(): USize
  fun source_builder(): SourceBuilderBuilder ?
  fun source_route_builder(): RouteBuilder
  fun source_listener_builder_builder(): SourceListenerBuilderBuilder
  fun sink_builder(): (SinkBuilder | None)
  // TODO: Change this when we need more sinks per pipeline
  // ASSUMPTION: There is at most one sink per pipeline
  fun sink_id(): (U128 | None)
  // The index into the list of provided sink addresses
  fun is_coalesced(): Bool
  fun apply(i: USize): RunnerBuilder ?
  fun size(): USize

class Pipeline[In: Any val, Out: Any val] is BasicPipeline
  let _pipeline_id: USize
  let _name: String
  let _app_name: String
  let _runner_builders: Array[RunnerBuilder]
  var _source_builder: (SourceBuilderBuilder | None) = None
  let _source_route_builder: RouteBuilder
  let _source_listener_builder_builder: SourceListenerBuilderBuilder
  var _sink_builder: (SinkBuilder | None) = None

  var _sink_id: (U128 | None) = None
  let _is_coalesced: Bool

  new create(app_name: String, p_id: USize, n: String,
    sc: SourceConfig[In], coalescing: Bool)
  =>
    _pipeline_id = p_id
    _runner_builders = Array[RunnerBuilder]
    _name = n
    _app_name = app_name
    _source_route_builder = TypedRouteBuilder[In]
    _is_coalesced = coalescing
    _source_listener_builder_builder = sc.source_listener_builder_builder()
    _source_builder = sc.source_builder(_app_name, _name)

  fun ref add_runner_builder(p: RunnerBuilder) =>
    _runner_builders.push(p)

  fun apply(i: USize): RunnerBuilder ? => _runner_builders(i)?

  fun ref update_sink(sink_builder': SinkBuilder) =>
    _sink_builder = sink_builder'

  fun source_id(): USize => _pipeline_id

  fun source_builder(): SourceBuilderBuilder ? =>
    _source_builder as SourceBuilderBuilder

  fun source_route_builder(): RouteBuilder => _source_route_builder

  fun source_listener_builder_builder(): SourceListenerBuilderBuilder =>
    _source_listener_builder_builder

  fun sink_builder(): (SinkBuilder | None) => _sink_builder

  // TODO: Change this when we need more sinks per pipeline
  // ASSUMPTION: There is at most one sink per pipeline
  fun sink_id(): (U128 | None) => _sink_id

  fun ref update_sink_id() =>
    _sink_id = StepIdGenerator()

  fun is_coalesced(): Bool => _is_coalesced

  fun size(): USize => _runner_builders.size()

  fun name(): String => _name

class PipelineBuilder[In: Any val, Out: Any val, Last: Any val]
  let _a: Application
  let _p: Pipeline[In, Out]

  new create(a: Application, p: Pipeline[In, Out]) =>
    _a = a
    _p = p

  fun ref to[Next: Any val](
    comp_builder: ComputationBuilder[Last, Next],
    id: U128 = 0): PipelineBuilder[In, Out, Next]
  =>
    let next_builder = ComputationRunnerBuilder[Last, Next](comp_builder,
      TypedRouteBuilder[Next])
    _p.add_runner_builder(next_builder)
    PipelineBuilder[In, Out, Next](_a, _p)

  fun ref to_parallel[Next: Any val](
    comp_builder: ComputationBuilder[Last, Next],
    id: U128 = 0): PipelineBuilder[In, Out, Next]
  =>
    let next_builder = ComputationRunnerBuilder[Last, Next](
      comp_builder, TypedRouteBuilder[Next] where parallelized' = true)
    _p.add_runner_builder(next_builder)
    PipelineBuilder[In, Out, Next](_a, _p)

  fun ref to_stateful[Next: Any val, S: State ref](
    s_comp: StateComputation[Last, Next, S] val,
    s_initializer: StateBuilder[S],
    state_name: String): PipelineBuilder[In, Out, Next]
  =>
    // TODO: This is a shortcut. Non-partitioned state is being treated as a
    // special case of partitioned state with one partition. This works but is
    // a bit confusing when reading the code.
    let step_id_gen = StepIdGenerator
    let single_step_partition = Partition[Last, U8](
      SingleStepPartitionFunction[Last], recover [0] end)
    let step_id_map = recover trn Map[U8, StepId] end

    step_id_map(0) = step_id_gen()


    let next_builder = PreStateRunnerBuilder[Last, Next, Last, U8, S](
      s_comp, state_name, SingleStepPartitionFunction[Last],
      TypedRouteBuilder[StateProcessor[S]],
      TypedRouteBuilder[Next])

    _p.add_runner_builder(next_builder)

    let state_builder = PartitionedStateRunnerBuilder[Last, S, U8](_p.name(),
      state_name, consume step_id_map, single_step_partition,
      StateRunnerBuilder[S](s_initializer, state_name,
        s_comp.state_change_builders()),
      TypedRouteBuilder[StateProcessor[S]],
      TypedRouteBuilder[Next])

    _a.add_state_builder(state_name, state_builder)

    PipelineBuilder[In, Out, Next](_a, _p)

  fun ref to_state_partition[PIn: Any val,
    Key: (Hashable val & Equatable[Key]), Next: Any val = PIn,
    S: State ref](
      s_comp: StateComputation[Last, Next, S] val,
      s_initializer: StateBuilder[S],
      state_name: String,
      partition: Partition[PIn, Key],
      multi_worker: Bool = false): PipelineBuilder[In, Out, Next]
  =>
    let step_id_gen = StepIdGenerator
    let step_id_map = recover trn Map[Key, U128] end

    match partition.keys()
    | let wks: Array[WeightedKey[Key]] val =>
      for wkey in wks.values() do
        step_id_map(wkey._1) = step_id_gen()
      end
    | let ks: Array[Key] val =>
      for key in ks.values() do
        step_id_map(key) = step_id_gen()
      end
    end

    let next_builder = PreStateRunnerBuilder[Last, Next, PIn, Key, S](
      s_comp, state_name, partition.function(),
      TypedRouteBuilder[StateProcessor[S]],
      TypedRouteBuilder[Next] where multi_worker = multi_worker)

    _p.add_runner_builder(next_builder)

    let state_builder = PartitionedStateRunnerBuilder[PIn, S,
      Key](_p.name(), state_name, consume step_id_map, partition,
        StateRunnerBuilder[S](s_initializer, state_name,
          s_comp.state_change_builders()),
        TypedRouteBuilder[StateProcessor[S]],
        TypedRouteBuilder[Next]
        where multi_worker = multi_worker)

    _a.add_state_builder(state_name, state_builder)

    PipelineBuilder[In, Out, Next](_a, _p)

  fun ref done(): Application =>
    _a.add_pipeline(_p)
    _a

  fun ref to_sink(sink_information: SinkConfig[Out]): Application =>
    let sink_builder = sink_information()
    _a.increment_sink_count()
    _p.update_sink(sink_builder)
    _p.update_sink_id()
    _a.add_pipeline(_p)
    _a
