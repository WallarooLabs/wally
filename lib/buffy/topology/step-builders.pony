use "collections"
use "buffy/messages"
use "net"
use "buffy/metrics"
use "time"

interface TagBuilder
  fun apply(): Any tag

trait BasicStepBuilder
  fun apply(): BasicStep tag

trait SinkBuilder
  fun apply(conns: Array[TCPConnection] iso, metrics_collector: MetricsCollector)
    : BasicStep tag

trait OutputStepBuilder[Out: Any val] is BasicStepBuilder

trait ThroughStepBuilder[In: Any val, Out: Any val]
  is OutputStepBuilder[Out]
//  fun apply(): ThroughStep[In, Out] tag

class SourceBuilder[Out: Any val]
  is ThroughStepBuilder[String, Out]
  let _parser: Parser[Out] val

  new val create(p: Parser[Out] val) =>
    _parser = p

  fun apply(): BasicStep tag =>
    Source[Out](_parser)

class StepBuilder[In: Any val, Out: Any val]
  is ThroughStepBuilder[In, Out]
  let _computation_builder: ComputationBuilder[In, Out] val

  new val create(c: ComputationBuilder[In, Out] val) =>
    _computation_builder = c

  fun apply(): BasicStep tag =>
    Step[In, Out](_computation_builder())

class MapStepBuilder[In: Any val, Out: Any val]
  is ThroughStepBuilder[In, Out]
  let _computation_builder: MapComputationBuilder[In, Out] val

  new val create(c: MapComputationBuilder[In, Out] val) =>
    _computation_builder = c

  fun apply(): BasicStep tag =>
    MapStep[In, Out](_computation_builder())

class PartitionBuilder[In: Any val, Out: Any val]
  is ThroughStepBuilder[In, Out]
  let _step_builder: StepBuilder[In, Out] val
  let _partition_function: PartitionFunction[In] val

  new val create(c: ComputationBuilder[In, Out] val, pf: PartitionFunction[In] val) =>
    _step_builder = StepBuilder[In, Out](c)
    _partition_function = pf

  fun apply(): BasicStep tag =>
    Partition[In, Out](_step_builder, _partition_function)

class StatePartitionBuilder[In: Any val, Out: Any val, State: Any iso]
  is ThroughStepBuilder[In, Out]
  let _state_computation_builder: StateComputationBuilder[In, Out, State] val
  let _state_initializer: {(): State} val
  let _partition_function: PartitionFunction[In] val

  new val create(scb: StateComputationBuilder[In, Out, State] val,
    init: {(): State} val, pf: PartitionFunction[In] val) =>
    _state_computation_builder = scb
    _state_initializer = init
    _partition_function = pf

  fun apply(): BasicStep tag =>
    Partition[In, Out](StateStepBuilder[In, Out, State](_state_computation_builder,
      _state_initializer), _partition_function)

class StateStepBuilder[In: Any val, Out: Any val, State: Any iso]
  is ThroughStepBuilder[In, Out]
  let _state_computation_builder: StateComputationBuilder[In, Out, State] val
  let _state_initializer: {(): State} val

  new val create(s_builder: StateComputationBuilder[In, Out, State] val,
    s_initializer: {(): State} val) =>
    _state_computation_builder = s_builder
    _state_initializer = s_initializer

  fun apply(): BasicStep tag =>
    StateStep[In, Out, State](_state_initializer)

class ExternalConnectionBuilder[In: Any val] is SinkBuilder
  let _stringify: Stringify[In] val

  new val create(stringify: Stringify[In] val) =>
    _stringify = stringify

  fun apply(conns: Array[TCPConnection] iso, metrics_collector: MetricsCollector)
    : BasicStep tag =>
    ExternalConnection[In](_stringify, consume conns, metrics_collector)
