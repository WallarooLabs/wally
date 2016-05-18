use "collections"
use "buffy/messages"
use "net"
use "buffy/metrics"
use "time"

interface TagBuilder
  fun apply(): Any tag

trait OutputStepBuilder[Out: OSCEncodable val]

trait ThroughStepBuilder[In: OSCEncodable val, Out: OSCEncodable val]
  is OutputStepBuilder[Out]
  fun apply(): ThroughStep[In, Out] tag

class SourceBuilder[Out: OSCEncodable val]
  is ThroughStepBuilder[String, Out]
  let _parser: Parser[Out] val

  new val create(p: Parser[Out] val) =>
    _parser = p

  fun apply(): ThroughStep[String, Out] tag =>
    Source[Out](_parser)

class StepBuilder[In: OSCEncodable val, Out: OSCEncodable val]
  is ThroughStepBuilder[In, Out]
  let _computation_builder: ComputationBuilder[In, Out] val

  new val create(c: ComputationBuilder[In, Out] val) =>
    _computation_builder = c

  fun apply(): ThroughStep[In, Out] tag =>
    Step[In, Out](_computation_builder())

class PartitionBuilder[In: OSCEncodable val, Out: OSCEncodable val]
  is ThroughStepBuilder[In, Out]
  let _step_builder: StepBuilder[In, Out] val
  let _partition_function: PartitionFunction[In] val

  new val create(c: ComputationBuilder[In, Out] val, pf: PartitionFunction[In] val) =>
    _step_builder = StepBuilder[In, Out](c)
    _partition_function = pf

  fun apply(): ThroughStep[In, Out] tag =>
    Partition[In, Out](_step_builder, _partition_function)

class StateStepBuilder[In: OSCEncodable val, Out: OSCEncodable val, State: Any #read]
  is ThroughStepBuilder[In, Out]
  let _state_computation_builder: StateComputationBuilder[In, Out, State] val
  let _state_initializer: {(): State} val

  new val create(s_builder: StateComputationBuilder[In, Out, State] val,
    s_initializer: {(): State} val) =>
    _state_computation_builder = s_builder
    _state_initializer = s_initializer

  fun apply(): ThroughStep[In, Out] tag =>
    StateStep[In, Out, State](_state_initializer, _state_computation_builder())

class ExternalConnectionBuilder[In: OSCEncodable val]
  let _stringify: Stringify[In] val

  new val create(stringify: Stringify[In] val) =>
    _stringify = stringify

  fun apply(conn: TCPConnection, metrics_collector: MetricsCollector)
    : ExternalConnection[In] =>
    ExternalConnection[In](_stringify, conn, metrics_collector)
