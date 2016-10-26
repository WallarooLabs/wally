use "collections"
use "buffy/messages"
use "buffy/topology/external"
use "net"
use "buffy/metrics"
use "time"
use "process"

trait BasicStepBuilder
  fun apply(): BasicStep tag
  fun shared_state_step_builder(): BasicSharedStateStepBuilder val
    => EmptySharedStateStepBuilder
  fun name(): String

trait BasicSharedStateStepBuilder
  fun apply(): BasicSharedStateStep tag
  fun name(): String

trait LocalStepBuilder is BasicStepBuilder
  fun local(): BasicOutputLocalStep
  fun state_id(): (U64 | None) => None

trait BasicStateStepBuilder is BasicStepBuilder
  fun state_id(): (U64 | None)

trait SinkBuilder
  fun apply(conns: Array[TCPConnection] iso, metrics_collector:
    (MetricsCollector | None))
    : BasicStep tag
  fun is_state_builder(): Bool => false
  fun name(): String => "Sink"

class EmptySinkBuilder is SinkBuilder
  let _pipeline_name: String

  new val create(pipeline_name: String) =>
    _pipeline_name = pipeline_name

  fun apply(conns: Array[TCPConnection] iso,
    metrics_collector: (MetricsCollector | None)): BasicStep tag
  =>
    EmptySink(metrics_collector, _pipeline_name)

  fun name(): String => "Empty Sink"

trait BasicOutputStepBuilder[Out: Any val] is BasicStepBuilder

trait ThroughStepBuilder[In: Any val, Out: Any val]
  is BasicOutputStepBuilder[Out]

trait BasicOutputComputationStepBuilder
  fun apply(): BasicOutputComputationStep
  fun name(): String

class ComputationStepBuilder[In: Any val, Out: Any val] is
  BasicOutputComputationStepBuilder
  let _comp_builder: ComputationBuilder[In, Out] val
  let _name: String

  new val create(c: ComputationBuilder[In, Out] val) =>
    _comp_builder = c
    _name = c().name()

  fun apply(): BasicOutputComputationStep =>
    ComputationStep[In, Out](_comp_builder())

  fun name(): String => _name

class MapComputationStepBuilder[In: Any val, Out: Any val] is
  BasicOutputComputationStepBuilder
  let _comp_builder: MapComputationBuilder[In, Out] val
  let _name: String

  new val create(c: MapComputationBuilder[In, Out] val) =>
    _comp_builder = c
    _name = c().name()

  fun apply(): BasicOutputComputationStep =>
    MapComputationStep[In, Out](_comp_builder())

  fun name(): String => _name

class StateLocalStepBuilder[In: Any val, Out: Any val, State: Any #read]
  is BasicOutputComputationStepBuilder
  let _s_comp: StateComputation[In, Out, State] val
  let _shared_state_step_builder: SharedStateStepBuilder[State] val
  let _state_id: U64
  let _name: String

  new val create(s_comp: StateComputation[In, Out, State] val,
    state_initializer: StateInitializer[State] val, s_id: U64) =>
    _s_comp = s_comp
    _shared_state_step_builder =
      SharedStateStepBuilder[State](state_initializer)
    _state_id = s_id
    _name = _s_comp.name()

  fun apply(): BasicOutputComputationStep =>
    StateLocalStep[In, Out, State](_s_comp, _state_id)

  fun state_id(): (U64 | None) => _state_id
  fun shared_state_step_builder(): BasicSharedStateStepBuilder val =>
    _shared_state_step_builder

  fun name(): String => _name

class ComputationStepsBuilder[In: Any val, Out: Any val]
  let _first_step: BasicOutputComputationStep
  var _last_step: BasicOutputComputationStep

  new iso create(f: BasicOutputComputationStepBuilder val) =>
    let first = f()
    _first_step = first
    _last_step = first

  fun ref add(f: BasicOutputComputationStepBuilder val) =>
    let next_step = f()
    _last_step.add_local_output(next_step)
    _last_step = next_step

  fun ref apply(): ComputationSteps[In, Out] =>
    ComputationSteps[In, Out](_first_step, _last_step)

class CoalesceStepBuilder[In: Any val, Out: Any val]
  is (ThroughStepBuilder[In, Out] & LocalStepBuilder & BasicStateStepBuilder)
  let _comp_step_builders: Array[BasicOutputComputationStepBuilder val] val
  let _shared_state_step_builder: BasicSharedStateStepBuilder val
  let _state_id: (U64 | None)
  var _name: String = ""

  new val create(cs: Array[BasicOutputComputationStepBuilder val] iso,
    s_id: (U64 | None) = None,
    sssb: BasicSharedStateStepBuilder val = EmptySharedStateStepBuilder)
  =>
    _comp_step_builders = consume cs
    for builder in _comp_step_builders.values() do
      _name = if _name == "" then
        builder.name()
      else
        _name + "->" + builder.name()
      end
    end
    _state_id = s_id
    _shared_state_step_builder = sssb

  fun apply(): BasicStep tag =>
    try
      let first_step_builder = _comp_step_builders(0)
      let c_steps_builder: ComputationStepsBuilder[In, Out] iso =
        ComputationStepsBuilder[In, Out](first_step_builder)
      for (idx, builder) in _comp_step_builders.pairs() do
        if idx > 0 then
          c_steps_builder.add(builder)
        end
      end

      CoalesceStep[In, Out](consume c_steps_builder)
    else
      EmptyStep
    end

  fun local(): BasicOutputLocalStep =>
    try
      let first_step_builder = _comp_step_builders(0)
      let c_steps_builder: ComputationStepsBuilder[In, Out] iso =
        ComputationStepsBuilder[In, Out](first_step_builder)
      for (idx, builder) in _comp_step_builders.pairs() do
        if idx > 0 then
          c_steps_builder.add(builder)
        end
      end

      CoalesceLocalStep[In, Out](consume c_steps_builder)
    else
      EmptyLocalStep
    end

  fun shared_state_step_builder(): BasicSharedStateStepBuilder val =>
    _shared_state_step_builder

  fun name(): String => _name
  fun state_id(): (U64 | None) => _state_id

// class CoalesceStateStepBuilder[In: Any val, Out: Any val, State: Any #read]
//   is (ThroughStepBuilder[In, Out] & LocalStepBuilder & BasicStateStepBuilder)
//   let _comp_step_builders: Array[BasicOutputComputationStepBuilder val] val
//   let _state_comp: StateComputation[In, Out, State] val
//   let _name: String
//   let _state_id: U64

//   new val create(cs: Array[BasicOutputComputationStepBuilder val] iso,
//     state_comp: StateComputation[In, Out, State] val, s_id: U64) =>
//     _comp_step_builders = consume cs
//     _state_comp = state_comp
//     _state_id = s_id
//     for builder in _comp_step_builders.values() do
//       _name = _name + builder.name()
//     end

//   fun apply(): BasicStep tag =>
//     try
//       let first_step_builder = _comp_step_builders(0)
//       let c_steps_builder: ComputationStepsBuilder[In, Out] iso =
//         ComputationStepsBuilder[In, Out](first_step_builder)
//       for (idx, builder) in _comp_step_builders.pairs() do
//         if idx > 0 then
//           c_steps_builder.add(builder)
//         end
//       end

//       CoalesceStateStep[In, Out](consume c_steps_builder, _state_comp,
//         _state_id)
//     else
//       EmptyStep
//     end

//   fun local(): BasicOutputLocalStep =>
//     try
//       let first_step_builder = _comp_step_builders(0)
//       let c_steps_builder: ComputationStepsBuilder[In, Out] iso =
//         ComputationStepsBuilder[In, Out](first_step_builder)
//       for (idx, builder) in _comp_step_builders.pairs() do
//         if idx > 0 then
//           c_steps_builder.add(builder)
//         end
//       end

//       CoalesceLocalStateStep[In, Out](consume c_steps_builder, _state_comp,
//         _state_id)
//     else
//       EmptyLocalStep
//     end

//   fun name(): String => _name
//   fun state_id(): U64 => _state_id

class StepBuilder[In: Any val, Out: Any val]
  is (ThroughStepBuilder[In, Out] & LocalStepBuilder)
  let _computation_builder: ComputationBuilder[In, Out] val
  let _name: String

  new val create(c: ComputationBuilder[In, Out] val) =>
    _computation_builder = c
    _name = _computation_builder().name()

  fun apply(): BasicStep tag =>
    Step[In, Out](_computation_builder())

  fun local(): BasicOutputLocalStep =>
    LocalStep[In, Out](_computation_builder())

  fun name(): String => _name

class MapStepBuilder[In: Any val, Out: Any val]
  is (ThroughStepBuilder[In, Out] & LocalStepBuilder)
  let _computation_builder: MapComputationBuilder[In, Out] val
  let _name: String

  new val create(c: MapComputationBuilder[In, Out] val) =>
    _computation_builder = c
    _name = _computation_builder().name()

  fun apply(): BasicStep tag =>
    MapStep[In, Out](_computation_builder())

  fun local(): BasicOutputLocalStep =>
    MapLocalStep[In, Out](_computation_builder())

  fun name(): String => _name

class PassThroughStepBuilder[In: Any val, Out: Any val] is LocalStepBuilder
  fun apply(): BasicStep tag => EmptyStep

  fun local(): BasicOutputLocalStep =>
    PassThroughLocalStep

  fun name(): String => "Passthrough"

class PartitionBuilder[In: Any val, Out: Any val]
  is ThroughStepBuilder[In, Out]
  let _step_builder: BasicStepBuilder val
  let _partition_function: PartitionFunction[In] val
  let _name: String

  new val create(c: ComputationBuilder[In, Out] val, pf: PartitionFunction[In] val) =>
    _step_builder = StepBuilder[In, Out](c)
    _partition_function = pf
    _name = _step_builder.name()

  new val with_step_builder(sb: BasicStepBuilder val, pf: PartitionFunction[In] val) =>
    _step_builder = sb
    _partition_function = pf
    _name = sb.name()

  fun apply(): BasicStep tag =>
    Partition[In, Out](_step_builder, _partition_function)

  fun name(): String => _name

// class SharedStatePartitionBuilder[State: Any #read]
//   is BasicStepBuilder
//   let _step_builder: BasicStepBuilder val
//   let _initialization_map: Map[U64, {(): State} val] val
//   let _initialize_at_start: Bool
//   let _name: String

//   new val create(sb: BasicStepBuilder val,
//     init_map: Map[U64, {(): State} val] val, init_at_start: Bool) =>
//     _step_builder = sb
//     _initialization_map = init_map
//     _initialize_at_start = init_at_start
//     _name = _step_builder.name()

//   fun apply(): BasicStep tag =>
//     StatePartition[State](_step_builder, _initialization_map,
//       _initialize_at_start)

//   fun name(): String => _name

class StateStepBuilder[In: Any val, Out: Any val, State: Any #read]
  is (ThroughStepBuilder[In, Out] & BasicStateStepBuilder & LocalStepBuilder)
  let _s_comp: StateComputation[In, Out, State] val
  let _shared_state_step_builder: SharedStateStepBuilder[State] val
  let _state_id: U64
  let _state_initializer: StateInitializer[State] val
  let _name: String

  new val create(s_comp: StateComputation[In, Out, State] val,
    state_initializer: StateInitializer[State] val, s_id: U64) =>
    _s_comp = s_comp
    _shared_state_step_builder =
      SharedStateStepBuilder[State](state_initializer)
    _state_id = s_id
    _state_initializer = state_initializer
    _name = _s_comp.name()

  fun apply(): BasicStateStep tag =>
    StateStep[In, Out, State](_s_comp, _state_id)

  fun local(): BasicOutputLocalStep =>
    StateLocalStep[In, Out, State](_s_comp, _state_id)

  fun state_id(): U64 => _state_id
  fun shared_state_step_builder(): BasicSharedStateStepBuilder val =>
    _shared_state_step_builder

  fun name(): String => _name

class SharedStateStepBuilder[State: Any #read]
  is BasicSharedStateStepBuilder
  let _state_initializer: StateInitializer[State] val

  new val create(state_initializer: StateInitializer[State] val) =>
    _state_initializer = state_initializer

  fun apply(): BasicSharedStateStep tag =>
    SharedStateStep[State](_state_initializer)

  fun name(): String => "Shared State Step"

// class StatePartitionBuilder[In: Any val, Out: Any val, State: Any #read]
//   is (ThroughStepBuilder[In, Out] & BasicStateStepBuilder)
//   let _partition_function: PartitionFunction[In] val
//   let _s_comp: StateComputation[In, Out, State] val
//   let _shared_state_step_builder: BasicStepBuilder val
//   let _state_id: U64
//   let _name: String

//   new val create(s_comp: StateComputation[In, Out, State] val,
//     state_initializer: StateInitializer[State] val,
//     pf: PartitionFunction[In] val, s_id: U64,
//     init_map: Map[U64, {(): State} val] val, init_at_start: Bool)
//     =>
//     _s_comp = s_comp
//     _partition_function = pf
//     _shared_state_step_builder =
//       SharedStatePartitionBuilder[State](
//         SharedStateStepBuilder[State](state_initializer), init_map, init_at_start)
//     _state_id = s_id
//     _name = _comp_builder().name()

//   fun apply(): BasicStep tag =>
//     StateStep[In, Out, State](_comp_builder, _state_id, _partition_function)

//   fun state_id(): U64 => _state_id
//   fun shared_state_step_builder(): BasicStepBuilder val =>
//     _shared_state_step_builder

//   fun name(): String => _name

primitive EmptyStepBuilder is BasicStepBuilder
  fun apply(): BasicStep tag => EmptyStep
  fun name(): String => "Empty Step"

primitive EmptySharedStateStepBuilder is BasicSharedStateStepBuilder
  fun apply(): BasicSharedStateStep tag => EmptySharedStateStep
  fun name(): String => "Empty Step"

class ExternalConnectionBuilder[In: Any val] is SinkBuilder
  let _array_stringify: ArrayStringify[In] val
  let _pipeline_name: String
  let _initial_msgs: Array[Array[ByteSeq] val] val

  new val create(array_stringify: ArrayStringify[In] val,
    pipeline_name: String, initial_msgs: Array[Array[ByteSeq] val] val
      = recover Array[Array[ByteSeq] val] end)
  =>
    _array_stringify = array_stringify
    _pipeline_name = pipeline_name
    _initial_msgs = initial_msgs

  fun apply(conns: Array[TCPConnection] iso, metrics_collector:
    (MetricsCollector | None))
    : BasicStep tag =>
    ExternalConnection[In](_array_stringify, consume conns, metrics_collector,
      _pipeline_name, _initial_msgs)

  fun name(): String => _pipeline_name + " Sink"

class CollectorSinkStepBuilder[In: Any val, Diff: Any #read] is SinkBuilder
  let _array_byteseqify: ArrayByteSeqify[Diff] val
  let _pipeline_name: String
  let _collector_builder: {(): SinkCollector[In, Diff]} val
  let _initial_msgs: Array[Array[ByteSeq] val] val

  new val create(collector_builder: {(): SinkCollector[In, Diff]} val,
    array_byteseqify: ArrayByteSeqify[Diff] val,
    pipeline_name: String, initial_msgs: Array[Array[ByteSeq] val] val =
      recover Array[Array[ByteSeq] val] end)
  =>
    _collector_builder = collector_builder
    _array_byteseqify = array_byteseqify
    _pipeline_name = pipeline_name
    _initial_msgs = initial_msgs

  fun apply(conns: Array[TCPConnection] iso, metrics_collector:
    (MetricsCollector | None))
    : BasicStep tag =>
    CollectorSinkStep[In, Diff](_collector_builder, _array_byteseqify,
      consume conns, metrics_collector, _pipeline_name, _initial_msgs)

  fun name(): String => _pipeline_name + " Sink"

class ExternalProcessStepBuilder[In: Any val, Out: Any val]
  is ThroughStepBuilder[In, Out]
  let _auth: ProcessMonitorAuth
  let _config: ExternalProcessConfig val
  let _codec: ExternalProcessCodec[In, Out] val
  let _length_encoder: ByteLengthEncoder val
  let _name: String val

  new val create(builder: ExternalProcessBuilder[In, Out] val) =>
    _auth = builder.auth()
    _config = builder.config()
    _codec = builder.codec()
    _length_encoder = builder.length_encoder()
    _name = builder.name()

  fun apply(): BasicStep tag =>
    ExternalProcessStep[In, Out](_auth, _config, _codec, _length_encoder)

  fun name(): String => _name
