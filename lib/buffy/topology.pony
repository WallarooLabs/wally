use "collections"
use "net"
use "buffy/messages"

class Topology
  let pipelines: Array[PipelineSteps] = Array[PipelineSteps]

  fun ref new_pipeline[In: OSCEncodable val, Out: OSCEncodable val]
    (parser: Parser[In] val, stringify: Stringify[Out] val): PipelineBuilder[In, Out, In] =>
    let pipeline = Pipeline[In, Out](parser, stringify)
    PipelineBuilder[In, Out, In](this, pipeline)

  fun ref add_pipeline(p: PipelineSteps) =>
    pipelines.push(p)

interface StepLookup
  fun val apply(computation_type: String): BasicStep tag ?
  fun sink(conn: TCPConnection): BasicStep tag

trait PipelineSteps
  fun sink(conn: TCPConnection): Any tag
  fun apply(i: USize): PipelineStep box ?
  fun size(): USize

class Pipeline[In: OSCEncodable val, Out: OSCEncodable val] is PipelineSteps
  let _steps: Array[PipelineStep]
  let sink_builder: ExternalConnectionBuilder[Out] val

  new create(p: Parser[In] val, s: Stringify[Out] val) =>
    let source_builder = SourceBuilder[In](p)
    _steps = Array[PipelineStep]
    _steps.push(PipelineThroughStep[String, In]("source", source_builder))
    sink_builder = ExternalConnectionBuilder[Out](s)

  fun ref add_step(p: PipelineStep) =>
    _steps.push(p)

  fun sink(conn: TCPConnection): Any tag =>
    sink_builder(conn)

  fun apply(i: USize): PipelineStep box ? => _steps(i)

  fun size(): USize => _steps.size()

trait PipelineStep
  fun computation_type(): String
  fun id(): I32

class PipelineThroughStep[In: OSCEncodable, Out: OSCEncodable] is PipelineStep
  let _computation_type: String
  let _id: I32
  let _step_builder: ThroughStepBuilder[In, Out] val

  new create(c_type: String, s_builder: ThroughStepBuilder[In, Out] val,
    pipeline_id: I32 = 0) =>
    _computation_type = c_type
    _step_builder = s_builder
    _id = pipeline_id

  fun computation_type(): String => _computation_type

  fun id(): I32 => _id

class PipelineBuilder[In: OSCEncodable val, Out: OSCEncodable val, Last: OSCEncodable val]
  let _t: Topology
  let _p: Pipeline[In, Out]

  new create(t: Topology, p: Pipeline[In, Out]) =>
    _t = t
    _p = p

  fun ref and_then[Next: OSCEncodable val](comp_type: String,
    comp_builder: ComputationBuilder[Last, Next] val, id: I32 = 0)
      : PipelineBuilder[In, Out, Next] =>
    let next_builder = StepBuilder[Last, Next](comp_builder)
    let next_step = PipelineThroughStep[Last, Next](comp_type, next_builder, id)
    _p.add_step(next_step)
    PipelineBuilder[In, Out, Next](_t, _p)

  fun ref and_then_partition[Next: OSCEncodable](comp_type: String,
    comp_builder: ComputationBuilder[Last, Next] val,
    p_fun: PartitionFunction[Last] val, id: I32 = 0)
      : PipelineBuilder[In, Out, Next] =>
    let next_builder = PartitionBuilder[Last, Next](comp_builder, p_fun)
    let next_step = PipelineThroughStep[Last, Next](comp_type, next_builder, id)
    _p.add_step(next_step)
    PipelineBuilder[In, Out, Next](_t, _p)

  fun ref and_then_stateful[Next: OSCEncodable, State: Any #read](comp_type: String,
    comp_builder: StateComputationBuilder[Last, Next, State] val,
    state_initializer: {(): State} val, id: I32 = 0)
      : PipelineBuilder[In, Out, Next] =>
    let next_builder = StateStepBuilder[Last, Next, State](comp_builder,
      state_initializer)
    let next_step = PipelineThroughStep[Last, Next](comp_type, next_builder, id)
    _p.add_step(next_step)
    PipelineBuilder[In, Out, Next](_t, _p)

  fun ref build(): Topology ? =>
    _t.add_pipeline(_p as PipelineSteps)
    _t
