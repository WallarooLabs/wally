use "collections"
use "net"
use "buffy/messages"
use "buffy/metrics"
use "buffy/network"
use "logger"

class Topology
  let pipelines: Array[PipelineSteps] = Array[PipelineSteps]

  fun ref new_pipeline[In: Any val, Out: Any val] (parser: Parser[In] val,
    pipeline_name: String): PipelineBuilder[In, Out, In]
  =>
    let pipeline = Pipeline[In, Out](parser, pipeline_name)
    PipelineBuilder[In, Out, In](this, pipeline)

  fun ref add_pipeline(p: PipelineSteps) =>
    pipelines.push(p)

trait PipelineSteps
  fun name(): String
  fun initialize_source(source_id: U64, host: String, service: String, 
    env: Env, auth: AmbientAuth, coordinator: Coordinator, 
    output: BasicStep tag, 
    local_step_builder: (LocalStepBuilder val | None),
    shared_state_step: (BasicSharedStateStep tag | None) = None,
    metrics_collector: (MetricsCollector tag | None), logger: Logger[String])
  fun sink_builder(): SinkBuilder val
  fun sink_target_ids(): Array[U64] val
  fun apply(i: USize): PipelineStep box ?
  fun size(): USize

class Pipeline[In: Any val, Out: Any val] is PipelineSteps
  let _name: String
  let _parser: Parser[In] val
  let _steps: Array[PipelineStep]
  var _sink_target_ids: Array[U64] val = recover Array[U64] end
  var _sink_builder: SinkBuilder val

  new create(p: Parser[In] val, n: String) =>
    _parser = p
    _steps = Array[PipelineStep]
    _name = n
    _sink_builder = EmptySinkBuilder(_name)

  fun ref add_step(p: PipelineStep) =>
    _steps.push(p)

  fun apply(i: USize): PipelineStep box ? => _steps(i)

  fun initialize_source(source_id: U64, host: String, service: String, 
    env: Env, auth: AmbientAuth, coordinator: Coordinator, 
    output: BasicStep tag, 
    local_step_builder: (LocalStepBuilder val | None),
    shared_state_step: (BasicSharedStateStep tag | None),
    metrics_collector: (MetricsCollector tag | None), logger: Logger[String])
  =>
    let source_notifier: TCPListenNotify iso = 
      match local_step_builder
      | let l: LocalStepBuilder val =>
        SourceNotifier[In](
          env, host, service, source_id, coordinator, _parser, output, 
          shared_state_step, l, metrics_collector, logger)
      else
        SourceNotifier[In](
          env, host, service, source_id, coordinator, _parser, output,
          shared_state_step where metrics_collector = metrics_collector, logger' = logger)
      end
    coordinator.add_listener(TCPListener(auth, consume source_notifier,
      host, service))

  fun ref update_sink(sink_builder': SinkBuilder val, 
    sink_ids: Array[U64] val) 
  =>
    _sink_builder = sink_builder'
    _sink_target_ids = sink_ids

  fun sink_builder(): SinkBuilder val => _sink_builder

  fun sink_target_ids(): Array[U64] val => _sink_target_ids

  fun size(): USize => _steps.size()

  fun name(): String => _name

trait PipelineStep
  fun id(): U64
  fun step_builder(): BasicStepBuilder val
  fun name(): String => step_builder().name()

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

  fun ref coalesce[COut: Any val](id: U64 = 0): 
    CoalesceBuilder[Last, COut, In, Out, Last] 
  =>
    CoalesceBuilder[Last, COut, In, Out, Last](_t, _p where id = id)

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

  fun ref to_stateful[Next: Any val, State: Any ref](
    state_comp: StateComputation[Last, Next, State] val,
    state_initializer: {(): State} val, state_id: U64, id: U64 = 0)
      : PipelineBuilder[In, Out, Next] =>
    let next_builder = StateStepBuilder[Last, Next, State](state_comp, state_initializer, state_id)
    let next_step = PipelineThroughStep[Last, Next](next_builder, id)
    _p.add_step(next_step)
    PipelineBuilder[In, Out, Next](_t, _p)

  fun ref to_empty_sink(): Topology ? =>
    _t.add_pipeline(_p as PipelineSteps)
    _t

  fun ref to_simple_sink(o: ArrayStringify[Out] val, 
    sink_ids: Array[U64] val, initial_msgs: Array[Array[ByteSeq] val] val 
      = recover Array[Array[ByteSeq] val] end): Topology ? 
  =>
    _p.update_sink(ExternalConnectionBuilder[Out](o, _p.name(),
      initial_msgs), sink_ids)
    _t.add_pipeline(_p as PipelineSteps)
    _t

  fun ref to_collector_sink[Diff: Any #read](
    collector_builder: {(): SinkCollector[Out, Diff]} val,
    array_byteseqify: ArrayByteSeqify[Diff] val,
    sink_ids: Array[U64] val, initial_msgs: Array[Array[ByteSeq] val] val 
      = recover Array[Array[ByteSeq] val] end): Topology ?
  =>
    let collector_sink_builder = CollectorSinkStepBuilder[Out, Diff](
      collector_builder, array_byteseqify, _p.name(), initial_msgs)
    _p.update_sink(collector_sink_builder, sink_ids)
    _t.add_pipeline(_p as PipelineSteps)
    _t

  // fun ref to_stateful_partition[Next: Any val, State: Any ref](
  //   config: StatePartitionConfig[Last, Next, State] iso)
  //     : PipelineBuilder[In, Out, Next] =>
  //   let c: StatePartitionConfig[Last, Next, State] val = consume config
  //   let next_builder = StatePartitionBuilder[Last, Next, State](
  //     c.state_computation, c.state_initializer,
  //     c.partition_function, c.state_id, c.initialization_map,
  //     c.initialize_at_start)
  //   let next_step = PipelineThroughStep[Last, Next](next_builder, c.id)
  //   _p.add_step(next_step)
  //   PipelineBuilder[In, Out, Next](_t, _p)

  fun ref to_external[Next: Any val](
    ext_builder: ExternalProcessBuilder[Last, Next] val, id: U64 = 0)
      : PipelineBuilder[In, Out, Next] =>
    let next_builder = ExternalProcessStepBuilder[Last, Next](ext_builder)
    let next_step = PipelineThroughStep[Last, Next](next_builder, id)
    _p.add_step(next_step)
    PipelineBuilder[In, Out, Next](_t, _p)

  // fun ref build(): Topology ? =>
  //   _t.add_pipeline(_p as PipelineSteps)
  //   _t

class CoalesceBuilder[CIn: Any val, COut: Any val, PIn: Any val, 
  POut: Any val, Last: Any val] 
  let _t: Topology
  let _p: Pipeline[PIn, POut]
  let _builders: Array[BasicOutputComputationStepBuilder val]
  let _id: U64

  new create(t: Topology, p: Pipeline[PIn, POut],
    builders: Array[BasicOutputComputationStepBuilder val] = 
    Array[BasicOutputComputationStepBuilder val], id: U64) 
  =>
    _t = t
    _p = p
    _builders = builders
    _id = id

  fun ref to[Next: Any val](
    comp_builder: ComputationBuilder[Last, Next] val, id: U64 = 0)
    : CoalesceBuilder[CIn, COut, PIn, POut, Next] 
  =>
    _builders.push(
      ComputationStepBuilder[Last, Next](comp_builder)
    )
    CoalesceBuilder[CIn, COut, PIn, POut, Next](_t, _p, _builders, _id)    

  fun ref to_map[Next: Any val](
    comp_builder: MapComputationBuilder[Last, Next] val, id: U64 = 0)
    : CoalesceBuilder[CIn, COut, PIn, POut, Next] 
  =>
    _builders.push(
      MapComputationStepBuilder[Last, Next](comp_builder)
    )
    CoalesceBuilder[CIn, COut, PIn, POut, Next](_t, _p, _builders, _id)    

  fun ref to_stateful[Next: Any val, State: Any ref](
    state_comp: StateComputation[Last, Next, State] val,
    state_initializer: {(): State} val, state_id: U64, id: U64 = 0)
      : CoalesceStateBuilder[CIn, COut, PIn, POut, Last, Next, State] =>
    CoalesceStateBuilder[CIn, COut, PIn, POut, Last, Next, State](
      _t, _p, state_comp, state_initializer, state_id, _builders, id
    )

  fun ref close(): PipelineBuilder[PIn, POut, COut] =>
    let builders: Array[BasicOutputComputationStepBuilder val] iso = 
      recover Array[BasicOutputComputationStepBuilder val] end
    for b in _builders.values() do
      builders.push(b)
    end
    let coalesce_step_builder: CoalesceStepBuilder[CIn, COut] val =
      CoalesceStepBuilder[CIn, COut](consume builders)
    let next_step = PipelineThroughStep[CIn, COut](coalesce_step_builder, _id)
    _p.add_step(next_step)
    PipelineBuilder[PIn, POut, COut](_t, _p)

class CoalesceStateBuilder[CIn: Any val, COut: Any val, PIn: Any val, 
  POut: Any val, Last: Any val, Next: Any val, State: Any #read] 
  let _t: Topology
  let _p: Pipeline[PIn, POut]
  let _builders: Array[BasicOutputComputationStepBuilder val]
  let _id: U64
  let _state_id: U64
  let _shared_state_step_builder: SharedStateStepBuilder[State] val

  new create(t: Topology, p: Pipeline[PIn, POut],
    s_comp: StateComputation[Last, Next, State] val,
    state_initializer: {(): State} val,
    state_id: U64,
    builders: Array[BasicOutputComputationStepBuilder val], id: U64) 
  =>
    _t = t
    _p = p
    _builders = builders
    _id = id
    _state_id = state_id
    _builders.push(
      StateLocalStepBuilder[Last, Next, State](s_comp, state_initializer,
        state_id)
    )
    _shared_state_step_builder = 
      SharedStateStepBuilder[State](state_initializer)

  fun ref close(): PipelineBuilder[PIn, POut, COut] =>
    let builders: Array[BasicOutputComputationStepBuilder val] iso = 
      recover Array[BasicOutputComputationStepBuilder val] end
    for b in _builders.values() do
      builders.push(b)
    end
    let coalesce_step_builder: CoalesceStepBuilder[CIn, COut] val =
      CoalesceStepBuilder[CIn, COut](consume builders, _state_id, 
        _shared_state_step_builder)
    let next_step = PipelineThroughStep[CIn, COut](coalesce_step_builder, _id)
    _p.add_step(next_step)
    PipelineBuilder[PIn, POut, COut](_t, _p)

// class StatePartitionConfig[In: Any val, Out: Any val, State: Any ref]
//   let state_computation: StateComputation[In, Out, State] val
//   let state_initializer: {(): State} val
//   let partition_function: PartitionFunction[In] val
//   let state_id: U64
//   var id: U64 = 0
//   var initialization_map: Map[U64, {(): State} val] val =
//     recover val Map[U64, {(): State} val] end
//   var initialize_at_start: Bool = false

//   new create(
//     s_comp: StateComputation[In, Out, State] val,
//     s_initializer: {(): State} val,
//     p_fun: PartitionFunction[In] val,
//     s_id: U64
//     )
//   =>
//     state_computation = s_comp
//     state_initializer = s_initializer
//     partition_function = p_fun
//     state_id = s_id

//   fun ref with_id(i: U64): StatePartitionConfig[In, Out, State]^ =>
//     id = i
//     this

//   fun ref with_initialization_map(im: Map[U64, {(): State} val] iso)
//     : StatePartitionConfig[In, Out, State]^ =>
//     initialization_map = consume im
//     this

//   fun ref with_initialize_at_start(): StatePartitionConfig[In, Out, State]^ =>
//     initialize_at_start = true
//     this
