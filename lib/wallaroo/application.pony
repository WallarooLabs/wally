use "collections"
use "net"
use "sendence/guid"
use "wallaroo/fail"
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/network"
use "wallaroo/tcp_sink"
use "wallaroo/tcp_source"
use "wallaroo/resilience"
use "wallaroo/routing"
use "wallaroo/topology"

class Application
  let _name: String
  let pipelines: Array[BasicPipeline] = Array[BasicPipeline]
  // _state_builders maps from state_name to StateSubpartition
  let _state_builders: Map[String, PartitionBuilder val] =
    _state_builders.create()
  // Map from source id to filename
  let init_files: Map[USize, InitFile val] = init_files.create()
  // TODO: Replace this default strategy with a better one after POC
  var default_target: (Array[RunnerBuilder val] val | None) = None
  var default_state_name: String = ""
  var default_target_id: U128 = 0

  new create(name': String) =>
    _name = name'

  fun ref new_pipeline[In: Any val, Out: Any val] (
    pipeline_name: String, decoder: FramedSourceHandler[In] val,
    init_file: (InitFile val | None) = None, coalescing: Bool = true):
      PipelineBuilder[In, Out, In]
  =>
    let pipeline_id = pipelines.size()
    match init_file
    | let f: InitFile val =>
      add_init_file(pipeline_id, f)
    end
    let pipeline = Pipeline[In, Out](_name, pipeline_id, pipeline_name,
      decoder, coalescing)
    PipelineBuilder[In, Out, In](this, pipeline)

  // TODO: Replace this with a better approach.  This is a shortcut to get
  // the POC working and handle unknown bucket in the partition.
  fun ref partition_default_target[In: Any val, Out: Any val,
    State: Any #read](
    pipeline_name: String,
    default_name: String,
    s_comp: StateComputation[In, Out, State] val,
    s_initializer: StateBuilder[State] val): Application
  =>
    default_state_name = default_name

    let builders: Array[RunnerBuilder val] trn =
      recover Array[RunnerBuilder val] end

    let pre_state_builder = PreStateRunnerBuilder[In, Out, In, U8, State](
      s_comp, default_name, SingleStepPartitionFunction[In],
      TypedRouteBuilder[StateProcessor[State] val],
      TypedRouteBuilder[Out], TypedRouteBuilder[In])
    builders.push(pre_state_builder)

    let state_builder' = StateRunnerBuilder[State](s_initializer, default_name, s_comp.state_change_builders(),
      TypedRouteBuilder[Out])
    builders.push(state_builder')

    default_target = consume builders
    default_target_id = pre_state_builder.id()

    this

  fun ref add_pipeline(p: BasicPipeline) =>
    pipelines.push(p)

  fun ref add_init_file(source_id: USize, init_file: InitFile val) =>
    init_files(source_id) = init_file

  fun ref add_state_builder(state_name: String,
    state_partition: PartitionBuilder val)
  =>
    _state_builders(state_name) = state_partition

  fun state_builder(state_name: String): PartitionBuilder val ? =>
    _state_builders(state_name)
  fun state_builders(): Map[String, PartitionBuilder val] val =>
    let builders: Map[String, PartitionBuilder val] trn =
      recover Map[String, PartitionBuilder val] end
    for (k, v) in _state_builders.pairs() do
      builders(k) = v
    end
    consume builders

  fun name(): String => _name

trait BasicPipeline
  fun name(): String
  fun source_id(): USize
  fun source_builder(): SourceBuilderBuilder val
  fun source_route_builder(): RouteBuilder val
  fun sink_builder(): (TCPSinkBuilder val | None)
  fun sink_target_ids(): Array[U64] val
  // TODO: Change this when we need more sinks per pipeline
  // ASSUMPTION: There is at most one sink per pipeline
  fun sink_id(): (U128 | None)
  fun is_coalesced(): Bool
  fun apply(i: USize): RunnerBuilder val ?
  fun size(): USize

class Pipeline[In: Any val, Out: Any val] is BasicPipeline
  let _pipeline_id: USize
  let _name: String
  let _decoder: FramedSourceHandler[In] val
  let _runner_builders: Array[RunnerBuilder val]
  var _sink_target_ids: Array[U64] val = recover Array[U64] end
  let _source_builder: SourceBuilderBuilder val
  let _source_route_builder: RouteBuilder val
  var _sink_builder: (TCPSinkBuilder val | None) = None
  var _sink_id: (U128 | None) = None
  let _is_coalesced: Bool

  new create(app_name: String, p_id: USize, n: String,
    d: FramedSourceHandler[In] val, coalescing: Bool)
  =>
    _pipeline_id = p_id
    _decoder = d
    _runner_builders = Array[RunnerBuilder val]
    _name = n
    _source_builder = TypedSourceBuilderBuilder[In](app_name, _name, _decoder)
    _source_route_builder = TypedRouteBuilder[In]
    _is_coalesced = coalescing

  fun ref add_runner_builder(p: RunnerBuilder val) =>
    _runner_builders.push(p)

  fun apply(i: USize): RunnerBuilder val ? => _runner_builders(i)

  fun ref update_sink(sink_builder': TCPSinkBuilder val,
    sink_ids: Array[U64] val)
  =>
    _sink_builder = sink_builder'
    _sink_target_ids = sink_ids

  fun source_id(): USize => _pipeline_id

  fun source_builder(): SourceBuilderBuilder val => _source_builder

  fun source_route_builder(): RouteBuilder val => _source_route_builder

  fun sink_builder(): (TCPSinkBuilder val | None) => _sink_builder

  fun sink_target_ids(): Array[U64] val => _sink_target_ids

  // TODO: Change this when we need more sinks per pipeline
  // ASSUMPTION: There is at most one sink per pipeline
  fun sink_id(): (U128 | None) => _sink_id

  fun ref update_sink_id() =>
    _sink_id = GuidGenerator.u128()

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
    id: U128 = 0): PipelineBuilder[In, Out, Next]
  =>
    let next_builder = ComputationRunnerBuilder[Last, Next](comp_builder,
      TypedRouteBuilder[Next])
    _p.add_runner_builder(next_builder)
    PipelineBuilder[In, Out, Next](_a, _p)

  fun ref to_stateful[Next: Any val, State: Any #read](
    s_comp: StateComputation[Last, Next, State] val,
    s_initializer: StateBuilder[State] val,
    state_name: String): PipelineBuilder[In, Out, Next]
  =>
    // TODO: This is a shortcut. Non-partitioned state is being treated as a
    // special case of partitioned state with one partition. This works but is
    // a bit confusing when reading the code.
    let guid_gen = GuidGenerator
    let single_step_partition = Partition[Last, U8](
      SingleStepPartitionFunction[Last], recover [0] end)
    let step_id_map: Map[U8, U128] trn = recover Map[U8, U128] end

    step_id_map(0) = guid_gen.u128()


    let next_builder = PreStateRunnerBuilder[Last, Next, Last, U8, State](
      s_comp, state_name, SingleStepPartitionFunction[Last],
      TypedRouteBuilder[StateProcessor[State] val],
      TypedRouteBuilder[Next])

    _p.add_runner_builder(next_builder)

    let state_builder = PartitionedStateRunnerBuilder[Last, State,
      U8](_p.name(), state_name, consume step_id_map,
        single_step_partition,
        StateRunnerBuilder[State](s_initializer, state_name,
          s_comp.state_change_builders()),
        TypedRouteBuilder[StateProcessor[State] val],
        TypedRouteBuilder[Next])

    _a.add_state_builder(state_name, state_builder)

    PipelineBuilder[In, Out, Next](_a, _p)

  fun ref to_state_partition[PIn: Any val,
    Key: (Hashable val & Equatable[Key]), Next: Any val = PIn,
    State: Any #read](
      s_comp: StateComputation[Last, Next, State] val,
      s_initializer: StateBuilder[State] val,
      state_name: String,
      partition: Partition[PIn, Key] val,
      multi_worker: Bool = false,
      default_state_name: String = ""
    ): PipelineBuilder[In, Out, Next]
  =>
    let guid_gen = GuidGenerator
    let step_id_map: Map[Key, U128] trn = recover Map[Key, U128] end

    match partition.keys()
    | let wks: Array[WeightedKey[Key]] val =>
      for wkey in wks.values() do
        step_id_map(wkey._1) = guid_gen.u128()
      end
    | let ks: Array[Key] val =>
      for key in ks.values() do
        step_id_map(key) = guid_gen.u128()
      end
    end

    let next_builder = PreStateRunnerBuilder[Last, Next, PIn, Key, State](
      s_comp, state_name, partition.function(),
      TypedRouteBuilder[StateProcessor[State] val],
      TypedRouteBuilder[Next] where multi_worker = multi_worker,
      default_state_name' = default_state_name)

    _p.add_runner_builder(next_builder)

    let state_builder = PartitionedStateRunnerBuilder[PIn, State,
      Key](_p.name(), state_name, consume step_id_map, partition,
        StateRunnerBuilder[State](s_initializer, state_name,
          s_comp.state_change_builders()),
        TypedRouteBuilder[StateProcessor[State] val],
        TypedRouteBuilder[Next]
        where multi_worker = multi_worker, default_state_name' =
        default_state_name)

    _a.add_state_builder(state_name, state_builder)

    PipelineBuilder[In, Out, Next](_a, _p)

  fun ref done(): Application ? =>
    _a.add_pipeline(_p as BasicPipeline)
    _a

  fun ref to_sink(encoder: SinkEncoder[Out] val,
    sink_ids: Array[U64] val, initial_msgs: Array[Array[ByteSeq] val] val
      = recover Array[Array[ByteSeq] val] end): Application ?
  =>
    let sink_builder: TCPSinkBuilder val =
      TCPSinkBuilder(TypedEncoderWrapper[Out](encoder), initial_msgs)
    _p.update_sink(sink_builder, sink_ids)
    _p.update_sink_id()
    _a.add_pipeline(_p as BasicPipeline)
    _a
