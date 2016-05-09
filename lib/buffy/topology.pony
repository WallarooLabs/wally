use "collections"
use "net"
use "buffy/messages"

class Topology
  // A sequence of computation type ids representing
  // the computation pipeline
  let pipeline: Array[String] val

  fun from[Out: OSCEncodable val](parser: {(String): Out} val): Pipeline =>
    Pipeline[Out](this, Source[Out](parser))

class Pipeline[In: OSCEncodable val]
  let _t: Topology
  let _s: OutputStep[In]
  let _pipeline: Array[Connector]

  new create(t: Topology, last: OutputStep[In], pipeline: Array[Connector]
    = Array[Connector]) =>
    _t = t
    _s = s
    _pipeline = pipeline

  fun and_then[Out: OSCEncodable val]
    (comp_builder: ComputationBuilder[In, Out]): Pipeline =>
    this

  fun and_then_partition[Out: OSCEncodable val]
    (comp_builder: ComputationBuilder[], p_fun_builder): Pipeline =>
    this

  fun and_then_stateful[Out: OSCEncodable val](init_builder, state_comp_builder, id: I32 = 0): Pipeline =>
    this

  fun to[Out: OSCEncodable val](sink_builder): Topology =>
    _t

trait Connector

class ThroughConnector[In: OSCEncodable val, Out: OSCEncodable val, Next: OSCEncodable val]
  let input: {(): ThroughStep[In, Out]} val
  let output: {(): ThroughStep[Out, Next]} val

  new create()

trait StepBuilder
  fun val apply(computation_type: String): Any tag ?

trait OutputStepBuilder[C: OSCEncodable val]
  fun val apply(): OutputStep[C] tag ?

trait ComputeStepBuilder[C: OSCEncodable val]
  fun val apply(): ComputeStep[C] tag ?

//class Connector[C: OSCEncodable val]
//  let input: OutputStepBuilder[C] tag
//  let output: ComputeStepBuilder[C] tag
//
//  new create(i: OutputStepBuilder[C] val, o: ComputeStepBuilder[C]) =>
//    input = i
//    output = o
