use "collections"
use "net"
use "buffy/messages"
use "buffy/metrics"

class Topology
  let pipelines: Array[PipelineSteps] = Array[PipelineSteps]

  fun ref new_pipeline[In: Any val, Out: Any val] (parser: Parser[In] val,
    stringify: Stringify[Out] val, sink_target_ids: Array[U64] val)
    : PipelineBuilder[In, Out, In] =>
    let pipeline = Pipeline[In, Out](parser, stringify, sink_target_ids)
    PipelineBuilder[In, Out, In](this, pipeline)

  fun ref add_pipeline(p: PipelineSteps) =>
    pipelines.push(p)

trait PipelineSteps
  fun sink_builder(): SinkBuilder val
  fun sink_target_ids(): Array[U64] val
  fun apply(i: USize): PipelineStep box ?
  fun size(): USize

class Pipeline[In: Any val, Out: Any val] is PipelineSteps
  let _steps: Array[PipelineStep]
  let _sink_target_ids: Array[U64] val
  let _sink_builder: SinkBuilder val

  new create(p: Parser[In] val, s: Stringify[Out] val,
    s_target_ids: Array[U64] val) =>
    let source_builder = SourceBuilder[In](p)
    _steps = Array[PipelineStep]
    _sink_target_ids = s_target_ids
    _steps.push(PipelineThroughStep[String, In](source_builder))
    _sink_builder = ExternalConnectionBuilder[Out](s)

  fun ref add_step(p: PipelineStep) =>
    _steps.push(p)

  fun apply(i: USize): PipelineStep box ? => _steps(i)

  fun sink_builder(): SinkBuilder val => _sink_builder

  fun sink_target_ids(): Array[U64] val => _sink_target_ids

  fun size(): USize => _steps.size()

trait PipelineStep
  fun id(): U64
  fun step_builder(): BasicStepBuilder val

class PipelineThroughStep[In: Any val, Out: Any val] is PipelineStep
  let _id: U64
  let _step_builder: BasicStepBuilder val

  new create(s_builder: ThroughStepBuilder[In, Out] val,
    pipeline_id: U64 = 0) =>
    _step_builder = s_builder
    _id = pipeline_id

  fun id(): U64 => _id
  fun step_builder(): BasicStepBuilder val => _step_builder

class PipelineBuilder[In: Any val, Out: Any val, Last: Any val]
  let _t: Topology
  let _p: Pipeline[In, Out]

  new create(t: Topology, p: Pipeline[In, Out]) =>
    _t = t
    _p = p

  fun ref to[Next: Any val](
    comp_builder: ComputationBuilder[Last, Next] val, id: U64 = 0)
      : PipelineBuilder[In, Out, Next] =>
    let next_builder = StepBuilder[Last, Next](comp_builder)
    let next_step = PipelineThroughStep[Last, Next](next_builder, id)
    _p.add_step(next_step)
    PipelineBuilder[In, Out, Next](_t, _p)

  fun ref to_map[Next: Any val](
    comp_builder: MapComputationBuilder[Last, Next] val, id: U64 = 0)
      : PipelineBuilder[In, Out, Next] =>
    let next_builder = MapStepBuilder[Last, Next](comp_builder)
    let next_step = PipelineThroughStep[Last, Next](next_builder, id)
    _p.add_step(next_step)
    PipelineBuilder[In, Out, Next](_t, _p)

  fun ref to_partition[Next: Any val](
    comp_builder: ComputationBuilder[Last, Next] val,
    p_fun: PartitionFunction[Last] val, id: U64 = 0)
      : PipelineBuilder[In, Out, Next] =>
    let next_builder = PartitionBuilder[Last, Next](comp_builder, p_fun)
    let next_step = PipelineThroughStep[Last, Next](next_builder, id)
    _p.add_step(next_step)
    PipelineBuilder[In, Out, Next](_t, _p)

  fun ref to_stateful_partition[Next: Any val, State: Any iso](
    comp_builder: StateComputationBuilder[Last, Next, State] val,
    state_initializer: {(): State} val,
    p_fun: PartitionFunction[Last] val, id: U64 = 0)
      : PipelineBuilder[In, Out, Next] =>
    let next_builder = StatePartitionBuilder[Last, Next, State](comp_builder,
      state_initializer, p_fun)
    let next_step = PipelineThroughStep[Last, Next](next_builder, id)
    _p.add_step(next_step)
    PipelineBuilder[In, Out, Next](_t, _p)

  fun ref to_stateful[Next: Any val, State: Any iso](
    comp_builder: StateComputationBuilder[Last, Next, State] val,
    state_initializer: {(): State} val, id: U64 = 0)
      : PipelineBuilder[In, Out, Next] =>
    let next_builder = StateStepBuilder[Last, Next, State](comp_builder,
      state_initializer)
    let next_step = PipelineThroughStep[Last, Next](next_builder, id)
    _p.add_step(next_step)
    PipelineBuilder[In, Out, Next](_t, _p)

  fun ref build(): Topology ? =>
    _t.add_pipeline(_p as PipelineSteps)
    _t
