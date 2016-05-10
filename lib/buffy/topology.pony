use "collections"
use "net"
use "buffy/messages"

class Topology
  let pipelines: Array[PipelineSteps] = Array[PipelineSteps]

  fun ref new_pipeline[In: OSCEncodable val, Out: OSCEncodable val]
    (parser: Parser[In] val, stringify: Stringify[Out] val): PipelineBuilder[In, Out, In] =>
    let pipeline = Pipeline[In, Out](parser, stringify)
    PipelineBuilder[In, Out, In](this, pipeline)

//  fun ref from[Out: OSCEncodable val](parser: Parser[Out] val): PipelineBuilder[Out] =>
//    let source_builder = SourceBuilder[Out](parser)
//    pipeline.push(PipelineThroughStep[String, Out]("source", source_builder))
//    PipelineBuilder[Out](this, source_builder)

  fun ref add_pipeline(p: PipelineSteps) =>
    pipelines.push(p)

interface StepLookup
  fun val apply(computation_type: String): Any tag ?

trait PipelineSteps
  fun steps(): Array[PipelineStep]
  fun sink(conn: TCPConnection): Any tag

class Pipeline[In: OSCEncodable val, Out: OSCEncodable val]
  let _steps: Array[PipelineStep]
  let sink_builder: ExternalConnectionBuilder[Out] val

  new create(p: Parser[In] val, s: Stringify[Out] val) =>
    let source_builder = SourceBuilder[In](p)
    _steps.push(PipelineThroughStep[String, In]("source", source_builder))
    sink_builder = ExternalConnectionBuilder[Out](s)

  fun steps(): Array[PipelineStep] =>
    _steps

  fun sink(conn: TCPConnection): Any tag =>
    sink_builder(conn)

trait PipelineStep
  fun computation_type(): String

class PipelineThroughStep[In: OSCEncodable, Out: OSCEncodable] is PipelineStep
  let _computation_type: String
  let step_builder: ThroughStepBuilder[In, Out] val

  new create(c_type: String, s_builder: ThroughStepBuilder[In, Out] val) =>
    _computation_type = c_type
    step_builder = s_builder

  fun computation_type(): String => _computation_type

class PipelineBuilder[In: OSCEncodable val, Out: OSCEncodable val, Last: OSCEncodable val]
  let _t: Topology
  let _p: Pipeline[In, Out]

  new create(t: Topology, p: Pipeline[In, Out]) =>
    _t = t
    _p = p

  fun ref and_then[Next: OSCEncodable val](comp_type: String,
    comp_builder: ComputationBuilder[Last, Next] val): PipelineBuilder[In, Out, Next] =>
    let next_builder = StepBuilder[In, Out](comp_builder)
    let next_step = PipelineThroughStep[In, Out](comp_type, next_builder)
    _t.add_step(next_step)
    PipelineBuilder[Out](_t, _p)

//  fun ref and_then_partition[Next: OSCEncodable]
//    (comp_builder: ComputationBuilder[Out, Next] val,
//      p_fun: PartitionFunction[Out] val): PipelineBuilder[Out] =>
//    let next_builder = PartitionBuilder[Out, Next](comp_builder, p_fun)
//    let next_connector = ThroughConnector[In, Out, Next](_last, next_builder)
//    _t.add_step(next_connector)
//    PipelineBuilder[Out](_t, next_builder)

//  fun and_then_stateful[Out: OSCEncodable val](init_builder, state_comp_builder, id: I32 = 0): Pipeline =>
//    this

//  fun ref to(stringify: Stringify[In] val): Topology =>
//    let external_connector = ExternalConnector[In](_last, stringify)
//    _t.add_step(external_connector)
//    _t

trait Connector

class SourceConnector[Out: OSCEncodable, Next: OSCEncodable]
  let input: {(): Source[Out]} val
  let output: StepBuilder[Out, Next] val

  new create(p: {(String): Out} val, o: ComputationBuilder[Out, Next] val) =>
    input = recover val
      object
        let parser: {(String): Out} val = p
        fun apply(): Source[Out] => Source[Out](parser)
      end
    end
    output = StepBuilder[Out, Next](o)

class ThroughConnector[In: OSCEncodable, Out: OSCEncodable,
  Next: OSCEncodable] is Connector
  let input: ThroughStepBuilder[In, Out] val
  let output: ThroughStepBuilder[Out, Next] val

  new create(i: ThroughStepBuilder[In, Out] val, o: ThroughStepBuilder[Out, Next] val) =>
    input = i
    output = o

//class PartitionConnector[In: OSCEncodable, Out: OSCEncodable,
//  Next: OSCEncodable] is Connector
//  let input: ThroughStepBuilder[In, Out]
//  let output: PartitionBuilder[Out, Next]
//
//  new create(i: ThroughStepBuilder[In, Out], o: PartitionBuilder[Out, Next],
//    pf: PartitionFunction[Out]) =>
//    input = i
//    output = o

//class ExternalConnector[In: OSCEncodable, Out: OSCEncodable] is Connector
//  let input: ThroughStepBuilder[In, Out] val
//  let output: {(TCPConnection): ExternalConnection[Out] tag} val
//
//  new create(i: ThroughStepBuilder[In, Out] val, s: {(Out): String} val) =>
//    input = i
//    output = recover val
//      object
//        let stringify: {(Out): String} val = s
//        fun apply(conn: TCPConnection): ExternalConnection[Out] =>
//          ExternalConnection[Out](stringify, conn)
//      end
//    end

//trait OutputStepBuilder[C: OSCEncodable val]
//  fun val apply(): OutputStep[C] tag ?
//
//trait ComputeStepBuilder[C: OSCEncodable val]
//  fun val apply(): ComputeStep[C] tag ?

//class Connector[C: OSCEncodable val]
//  let input: OutputStepBuilder[C] tag
//  let output: ComputeStepBuilder[C] tag
//
//  new create(i: OutputStepBuilder[C] val, o: ComputeStepBuilder[C]) =>
//    input = i
//    output = o
