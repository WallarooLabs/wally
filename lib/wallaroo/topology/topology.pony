use "collections"
use "net"
use "sendence/guid"
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/network"

class Topology
  let pipelines: Array[BasicPipeline] = Array[BasicPipeline]

  fun ref new_pipeline[In: Any val, Out: Any val] (
    decoder: SourceDecoder[In] val, pipeline_name: String): 
    PipelineBuilder[In, Out, In]
  =>
    let pipeline = Pipeline[In, Out](decoder, pipeline_name)
    PipelineBuilder[In, Out, In](this, pipeline)

  fun ref add_pipeline(p: BasicPipeline) =>
    pipelines.push(p)

trait BasicPipeline
  fun name(): String
  // fun initialize_source(source_id: U64, host: String, service: String, 
  //   env: Env, auth: AmbientAuth, coordinator: Coordinator, 
  //   output: BasicStep tag, 
  //   local_step_builder: (LocalStepBuilder val | None),
  //   shared_state_step: (BasicSharedStateStep tag | None) = None,
  //   metrics_collector: (MetricsCollector tag | None))
  fun sink_builder(): RunnerBuilder val
  fun sink_target_ids(): Array[U64] val
  fun apply(i: USize): RunnerBuilder val ?
  fun size(): USize

class Pipeline[In: Any val, Out: Any val] is BasicPipeline
  let _name: String
  let _decoder: SourceDecoder[In] val
  let _runner_builders: Array[RunnerBuilder val]
  var _sink_target_ids: Array[U64] val = recover Array[U64] end
  var _sink_builder: RunnerBuilder val

  new create(d: SourceDecoder[In] val, n: String) =>
    _decoder = d
    _runner_builders = Array[RunnerBuilder val]
    _name = n
    _sink_builder = SimpleSinkRunnerBuilder[Out](_name)

  fun ref add_runner_builder(p: RunnerBuilder val) =>
    _runner_builders.push(p)

  fun apply(i: USize): RunnerBuilder val ? => _runner_builders(i)

  // fun initialize_source(source_id: U64, host: String, service: String, 
  //   env: Env, auth: AmbientAuth, coordinator: Coordinator, 
  //   output: BasicStep tag, 
  //   local_step_builder: (LocalStepBuilder val | None),
  //   shared_state_step: (BasicSharedStateStep tag | None),
  //   metrics_collector: (MetricsCollector tag | None))
  // =>
  //   let source_notifier: TCPListenNotify iso = 
  //     match local_step_builder
  //     | let l: LocalStepBuilder val =>
  //       SourceNotifier[In](
  //         env, host, service, source_id, coordinator, _parser, output, 
  //         shared_state_step, l, metrics_collector)
  //     else
  //       SourceNotifier[In](
  //         env, host, service, source_id, coordinator, _parser, output,
  //         shared_state_step where metrics_collector = metrics_collector)
  //     end
  //   coordinator.add_listener(TCPListener(auth, consume source_notifier,
  //     host, service))

  fun ref update_sink(sink_builder': RunnerBuilder val, 
    sink_ids: Array[U64] val) 
  =>
    _sink_builder = sink_builder'
    _sink_target_ids = sink_ids

  fun sink_builder(): RunnerBuilder val => _sink_builder

  fun sink_target_ids(): Array[U64] val => _sink_target_ids

  fun size(): USize => _runner_builders.size()

  fun name(): String => _name

class PipelineBuilder[In: Any val, Out: Any val, Last: Any val]
  let _t: Topology
  let _p: Pipeline[In, Out]

  new create(t: Topology, p: Pipeline[In, Out]) =>
    _t = t
    _p = p

  fun ref to[Next: Any val](
    comp_builder: ComputationBuilder[Last, Next] val)
      : PipelineBuilder[In, Out, Next] =>
    let next_builder = ComputationRunnerBuilder[Last, Next](comp_builder)
    _p.add_runner_builder(next_builder)
    PipelineBuilder[In, Out, Next](_t, _p)

  fun ref to_empty_sink(): Topology ? =>
    _t.add_pipeline(_p as BasicPipeline)
    _t

  fun ref to_sink(encoder: SinkEncoder[Out] val, 
    sink_ids: Array[U64] val, initial_msgs: Array[Array[ByteSeq] val] val 
      = recover Array[Array[ByteSeq] val] end): Topology ? 
  =>
    _p.update_sink(EncoderSinkRunnerBuilder[Out](encoder, _p.name(),
      initial_msgs), sink_ids)
    _t.add_pipeline(_p as BasicPipeline)
    _t

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