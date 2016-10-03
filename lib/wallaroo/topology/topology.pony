use "collections"
use "net"
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/network"

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
    metrics_collector: (MetricsCollector tag | None))
  fun sink_builder(): SinkBuilder val
  fun sink_target_ids(): Array[U64] val
  fun apply(i: USize): PipelineStep val ?
  fun size(): USize

class Pipeline[In: Any val, Out: Any val] is PipelineSteps
  let _name: String
  let _parser: Parser[In] val
  let _steps: Array[PipelineStep val]
  var _sink_target_ids: Array[U64] val = recover Array[U64] end
  var _sink_builder: SinkBuilder val

  new create(p: Parser[In] val, n: String) =>
    _parser = p
    _steps = Array[PipelineStep val]
    _name = n
    _sink_builder = EmptySinkBuilder(_name)

  fun ref add_step(p: PipelineStep val) =>
    _steps.push(p)

  fun apply(i: USize): PipelineStep val ? => _steps(i)

  fun initialize_source(source_id: U64, host: String, service: String, 
    env: Env, auth: AmbientAuth, coordinator: Coordinator, 
    output: BasicStep tag, 
    local_step_builder: (LocalStepBuilder val | None),
    shared_state_step: (BasicSharedStateStep tag | None),
    metrics_collector: (MetricsCollector tag | None))
  =>
    let source_notifier: TCPListenNotify iso = 
      match local_step_builder
      | let l: LocalStepBuilder val =>
        SourceNotifier[In](
          env, host, service, source_id, coordinator, _parser, output, 
          shared_state_step, l, metrics_collector)
      else
        SourceNotifier[In](
          env, host, service, source_id, coordinator, _parser, output,
          shared_state_step where metrics_collector = metrics_collector)
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
  fun step_builder(): StepBuilder val
  fun name(): String => step_builder().name()

class PipelineThroughStep[In: Any val, Out: Any val] is PipelineStep
  let _id: U64
  let _step_builder: StepBuilder val

  new val create(s_builder: ThroughStepBuilder[In, Out] val,
    pipeline_id: U64 = 0) =>
    _step_builder = s_builder
    _id = pipeline_id

  fun id(): U64 => _id
  fun step_builder(): StepBuilder val => _step_builder

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

  // fun ref to_partition[Next: Any val](
  //   comp_builder: ComputationBuilder[Last, Next] val,
  //   p_fun: PartitionFunction[Last] val, id: U64 = 0)
  //     : PipelineBuilder[In, Out, Next] =>
  //   let next_builder = PartitionBuilder[Last, Next](comp_builder, p_fun)
  //   let next_step = PipelineThroughStep[Last, Next](next_builder, id)
  //   _p.add_step(next_step)
  //   PipelineBuilder[In, Out, Next](_t, _p)

  // fun ref to_stateful[Next: Any val, State: Any ref](
  //   state_comp: StateComputation[Last, Next, State] val,
  //   state_initializer: {(): State} val, state_id: U64, id: U64 = 0)
  //     : PipelineBuilder[In, Out, Next] =>
  //   let next_builder = StateStepBuilder[Last, Next, State](state_comp, state_initializer, state_id)
  //   let next_step = PipelineThroughStep[Last, Next](next_builder, id)
  //   _p.add_step(next_step)
  //   PipelineBuilder[In, Out, Next](_t, _p)

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

