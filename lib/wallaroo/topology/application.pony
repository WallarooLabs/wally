use "collections"
use "net"
use "sendence/guid"
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/network"

class Application
  let _name: String
  let pipelines: Array[BasicPipeline] = Array[BasicPipeline]

  new create(name': String) =>
    _name = name'

  fun ref new_pipeline[In: Any val, Out: Any val] (
    pipeline_name: String, decoder: SourceDecoder[In] val, 
    coalescing: Bool = true): PipelineBuilder[In, Out, In]
  =>
    let pipeline = Pipeline[In, Out](pipeline_name, decoder, coalescing)
    PipelineBuilder[In, Out, In](this, pipeline)

  fun ref add_pipeline(p: BasicPipeline) =>
    pipelines.push(p)

  fun name(): String => _name

trait BasicPipeline
  fun name(): String
  fun source_builder(): BytesProcessorBuilder val
  fun sink_runner_builder(): SinkRunnerBuilder val
  fun sink_target_ids(): Array[U64] val
  fun state_builder(state_name: String): StateSubpartition val ?
  fun state_builders(): Map[String, StateSubpartition val] val
  fun is_coalesced(): Bool
  fun apply(i: USize): RunnerBuilder val ?
  fun size(): USize

class Pipeline[In: Any val, Out: Any val] is BasicPipeline
  let _name: String
  let _decoder: SourceDecoder[In] val
  let _runner_builders: Array[RunnerBuilder val]
  var _sink_target_ids: Array[U64] val = recover Array[U64] end
  let _source_builder: BytesProcessorBuilder val
  var _sink_builder: SinkRunnerBuilder val
  // _state_builders maps from state_name to StateSubpartition
  let _state_builders: Map[String, StateSubpartition val] = 
    _state_builders.create()
  let _is_coalesced: Bool

  new create(n: String, d: SourceDecoder[In] val, coalescing: Bool) 
  =>
    _decoder = d
    _runner_builders = Array[RunnerBuilder val]
    _name = n
    _source_builder = SourceBuilder[In](_name, _decoder)
    _sink_builder = SimpleSinkRunnerBuilder[Out](_name)
    _is_coalesced = coalescing

  fun ref add_runner_builder(p: RunnerBuilder val) =>
    _runner_builders.push(p)

  fun apply(i: USize): RunnerBuilder val ? => _runner_builders(i)

  fun ref update_sink(sink_builder': SinkRunnerBuilder val, 
    sink_ids: Array[U64] val) 
  =>
    _sink_builder = sink_builder'
    _sink_target_ids = sink_ids

  fun source_builder(): BytesProcessorBuilder val => _source_builder

  fun sink_runner_builder(): SinkRunnerBuilder val => _sink_builder

  fun sink_target_ids(): Array[U64] val => _sink_target_ids

  fun ref add_state_builder(state_name: String, 
    state_partition: StateSubpartition val) 
  =>
    _state_builders(state_name) = state_partition

  fun state_builder(state_name: String): StateSubpartition val ? =>
    _state_builders(state_name)

  fun state_builders(): Map[String, StateSubpartition val] val =>
    let builders: Map[String, StateSubpartition val] trn =
      recover Map[String, StateSubpartition val] end
    for (k, v) in _state_builders.pairs() do
      builders(k) = v
    end
    consume builders

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
    comp_builder: ComputationBuilder[Last, Next] val,
    id: U128 = 0)
      : PipelineBuilder[In, Out, Next] =>
    let next_builder = ComputationRunnerBuilder[Last, Next](comp_builder)
    _p.add_runner_builder(next_builder)
    PipelineBuilder[In, Out, Next](_a, _p)

  fun ref to_stateful[Next: Any val, State: Any #read](
    s_comp: StateComputation[Last, Next, State] val,
    s_initializer: StateBuilder[State] val,
    state_name: String) 
      : PipelineBuilder[In, Out, Next] =>

    let next_builder = PreStateRunnerBuilder[Last, Next, State](s_comp)
    _p.add_runner_builder(next_builder)
    let state_builder = StateRunnerBuilder[State](s_initializer, state_name)
    _p.add_runner_builder(state_builder)
    PipelineBuilder[In, Out, Next](_a, _p)

  fun ref to_state_partition[PIn: Any val,
    Key: (Hashable val & Equatable[Key]), Next: Any val = PIn, 
    State: Any #read](
      s_comp: StateComputation[Last, Next, State] val,
      s_initializer: StateBuilder[State] val,
      state_name: String, 
      partition: Partition[PIn, Key] val
    ): PipelineBuilder[In, Out, Next] 
  =>
    let guid_gen = GuidGenerator
    let step_id_map: Map[Key, U128] trn = recover Map[Key, U128] end

    for key in partition.keys().values() do
      step_id_map(key) = guid_gen.u128()
    end

    let next_builder = PartitionedPreStateRunnerBuilder[Last, Next, PIn, State,
      Key](_p.name(), state_name, s_comp, consume step_id_map, partition)
    _p.add_runner_builder(next_builder)

    let state_partition = KeyedStateSubpartition[Key](partition.keys(),
      StateRunnerBuilder[State](s_initializer, state_name))

    _p.add_state_builder(state_name, state_partition)

    PipelineBuilder[In, Out, Next](_a, _p)

  fun ref done(): Application ? =>
    _a.add_pipeline(_p as BasicPipeline)
    _a

  fun ref to_sink(encoder: SinkEncoder[Out] val, 
    sink_ids: Array[U64] val, initial_msgs: Array[Array[ByteSeq] val] val 
      = recover Array[Array[ByteSeq] val] end): Application ? 
  =>
    _p.update_sink(EncoderSinkRunnerBuilder[Out](_p.name(), encoder,
      initial_msgs), sink_ids)
    _a.add_pipeline(_p as BasicPipeline)
    _a
