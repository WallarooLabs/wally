use "collections"
use "net"
use "sendence/guid"
use "wallaroo/backpressure"
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/network"
use "wallaroo/tcp-sink"
use "wallaroo/tcp-source"
use "wallaroo/resilience"
use "wallaroo/topology"

class Application
  let _name: String
  let pipelines: Array[BasicPipeline] = Array[BasicPipeline]
  // _state_builders maps from state_name to StateSubpartition
  let _state_builders: Map[String, StateSubpartition val] = 
    _state_builders.create()
  // Map from source id to filename
  let init_files: Map[USize, InitFile val] = init_files.create()
  // TODO: Replace this default strategy with a better one after POC
  var default_target: (RunnerBuilder val | None) = None

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
    s_comp: StateComputation[In, Out, State] val,
    s_initializer: StateBuilder[State] val,
    state_name: String): Application
  =>
    let guid_gen = GuidGenerator
    let single_step_partition = Partition[In, U8](
      SingleStepPartitionFunction[In], recover [0] end)
    let step_id_map: Map[U8, U128] trn = recover Map[U8, U128] end

    step_id_map(0) = guid_gen.u128()

    let next_builder = PartitionedPreStateRunnerBuilder[In, Out, In, 
      State, U8](pipeline_name, state_name, s_comp, consume step_id_map, 
        single_step_partition,
        TypedRouteBuilder[StateProcessor[State] val],
        TypedRouteBuilder[Out]
        where multi_worker = false)
    update_default_target(next_builder)

    let state_partition = KeyedStateSubpartition[U8](
      single_step_partition.keys(),
      StateRunnerBuilder[State](s_initializer, state_name, 
        s_comp.state_change_builders()) 
      where multi_worker = false)

    add_state_builder(state_name, state_partition)     
    this

  fun ref add_pipeline(p: BasicPipeline) =>
    pipelines.push(p)

  fun ref update_default_target(r: RunnerBuilder val) =>
    default_target = r

  fun ref add_init_file(source_id: USize, init_file: InitFile val) =>
    init_files(source_id) = init_file

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

  fun name(): String => _name

trait BasicPipeline
  fun name(): String
  fun source_id(): USize
  fun source_builder(): SourceBuilderBuilder val
  fun source_route_builder(): RouteBuilder val
  fun sink_builder(): (TCPSinkBuilder val | None)
  fun sink_target_ids(): Array[U64] val
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

    let next_builder = PartitionedPreStateRunnerBuilder[Last, Next, Last, 
      State, U8](_p.name(), state_name, s_comp, consume step_id_map, 
        single_step_partition,
        TypedRouteBuilder[StateProcessor[State] val],
        TypedRouteBuilder[Next]
        where multi_worker = false)
    _p.add_runner_builder(next_builder)

    let state_partition = KeyedStateSubpartition[U8](
      single_step_partition.keys(),
      StateRunnerBuilder[State](s_initializer, state_name, 
        s_comp.state_change_builders()) 
      where multi_worker = false)

    _a.add_state_builder(state_name, state_partition)

    PipelineBuilder[In, Out, Next](_a, _p)

    // let next_builder = PreStateRunnerBuilder[Last, Next, State](s_comp,
    //   TypedRouteBuilder[StateProcessor[State] val],
    //   TypedRouteBuilder[Next])
    // _p.add_runner_builder(next_builder)
    // let state_builder = StateRunnerBuilder[State](s_initializer, state_name, s_comp.state_change_builders())
    // _p.add_runner_builder(state_builder)
    // PipelineBuilder[In, Out, Next](_a, _p)

  fun ref to_state_partition[PIn: Any val,
    Key: (Hashable val & Equatable[Key]), Next: Any val = PIn, 
    State: Any #read](
      s_comp: StateComputation[Last, Next, State] val,
      s_initializer: StateBuilder[State] val,
      state_name: String, 
      partition: Partition[PIn, Key] val,
      multi_worker: Bool = false
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

    let next_builder = PartitionedPreStateRunnerBuilder[Last, Next, PIn, State,
      Key](_p.name(), state_name, s_comp, consume step_id_map, partition,
        TypedRouteBuilder[StateProcessor[State] val],
        TypedRouteBuilder[Next]
        where multi_worker = multi_worker)
    _p.add_runner_builder(next_builder)

    let state_partition = KeyedStateSubpartition[Key](partition.keys(),
      StateRunnerBuilder[State](s_initializer, state_name, s_comp.state_change_builders()) 
        where multi_worker = multi_worker)

    _a.add_state_builder(state_name, state_partition)

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
      //, initial_msgs), sink_ids)
    _a.add_pipeline(_p as BasicPipeline)
    _a
