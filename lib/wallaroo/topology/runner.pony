use "buffered"
use "collections"
use "time"
use "net"
use "sendence/epoch"
use "sendence/guid"
use "wallaroo/backpressure"
use "wallaroo/initialization"
use "wallaroo/metrics"
use "wallaroo/messages"

// TODO: Eliminate producer None when we can
interface Runner
  // Return a Bool indicating whether the message is finished processing
  fun ref run[In: Any val](metric_name: String, source_ts: U64, input: In,
    producer: (CreditFlowProducer ref | None), router: (Router val | None) = None): Bool

interface RunnerBuilder
  fun apply(metrics_reporter: MetricsReporter iso, 
    next_runner: (Runner iso | None) = None,
    router: (Router val | None) = None): Runner iso^

  fun name(): String
  fun is_stateful(): Bool
  fun id(): U128

primitive RouterRunnerBuilder
  fun apply(metrics_reporter: MetricsReporter iso, 
    next_runner: (Runner iso | None) = None,
    router: (Router val | None) = None): Runner iso^
  => 
    RouterRunner

  fun name(): String => "router"
  fun is_stateful(): Bool => false
  fun id(): U128 => 0

class RunnerSequenceBuilder
  let _runner_builders: Array[RunnerBuilder val] val

  new val create(bs: Array[RunnerBuilder val] val) =>
    _runner_builders = bs

  fun apply(metrics_reporter: MetricsReporter iso, router: Router val): 
    Runner iso^ 
  =>
    var remaining: USize = _runner_builders.size()
    var latest_runner: Runner iso = RouterRunner
    while remaining > 0 do
      let next_builder: (RunnerBuilder val | None) = 
        try
          _runner_builders(remaining - 1)
        else
          None
        end
      match next_builder
      | let rb: RunnerBuilder val =>
        latest_runner = rb(metrics_reporter.clone(), consume latest_runner,
          router)
      end
      remaining = remaining - 1
    end
    consume latest_runner

  fun name(): String =>
    var n = ""
    for r in _runner_builders.values() do
      n = n + "|" + r.name()
    end
    n + "|"

class ComputationRunnerBuilder[In: Any val, Out: Any val]
  let _comp_builder: ComputationBuilder[In, Out] val
  let _id: U128

  new val create(comp_builder: ComputationBuilder[In, Out] val,
    id': U128 = 0) 
  =>
    _comp_builder = comp_builder
    _id = id'

  fun apply(metrics_reporter: MetricsReporter iso, 
    next_runner: (Runner iso | None) = None,
    router: (Router val | None) = None): Runner iso^
  =>
    match (consume next_runner)
    | let r: Runner iso =>
      ComputationRunner[In, Out](_comp_builder(), consume r, 
        consume metrics_reporter)
    else
      ComputationRunner[In, Out](_comp_builder(), RouterRunner, 
        consume metrics_reporter)      
    end

  fun name(): String => _comp_builder().name()
  fun is_stateful(): Bool => false
  fun id(): U128 => _id

class PreStateRunnerBuilder[In: Any val, Out: Any val, State: Any #read]
  let _state_comp: StateComputation[In, Out, State] val

  new val create(state_comp: StateComputation[In, Out, State] val) 
  =>
    _state_comp = state_comp

  fun apply(metrics_reporter: MetricsReporter iso, 
    next_runner: (Runner iso | None) = None,
    router: (Router val | None) = None): Runner iso^
  =>
    match router
    | let r: Router val =>
      PreStateRunner[In, Out, State](_state_comp, r, consume metrics_reporter)
    else
      @printf[I32]("PreStateRunner should take a Router on build!\n".cstring())
      PreStateRunner[In, Out, State](_state_comp, EmptyRouter, 
        consume metrics_reporter)
    end

  fun name(): String => _state_comp.name()
  fun is_stateful(): Bool => true
  fun id(): U128 => 0

class StateRunnerBuilder[State: Any #read]
  let _state_builder: StateBuilder[State] val
  let _name: String

  new val create(state_builder: StateBuilder[State] val, 
    name': String) =>
    _state_builder = state_builder
    _name = name'

  fun apply(metrics_reporter: MetricsReporter iso, 
    next_runner: (Runner iso | None) = None,
    router: (Router val | None) = None): Runner iso^
  =>
    StateRunner[State](_state_builder, consume metrics_reporter)

  fun name(): String => _state_builder.name()
  fun is_stateful(): Bool => true
  fun id(): U128 => 0

trait PartitionBuilder
  fun pre_state_subpartition(worker: String): PreStateSubpartition val
  fun partition_addresses(worker: String): PartitionAddresses val
  fun state_name(): String

class PartitionedPreStateRunnerBuilder[In: Any val, Out: Any val, 
  PIn: Any val, State: Any #read, Key: (Hashable val & Equatable[Key])] is PartitionBuilder
  let _pipeline_name: String
  let _state_name: String
  let _state_comp: StateComputation[In, Out, State] val
  let _step_id_map: Map[Key, U128] val
  let _partition: Partition[PIn, Key] val

  new val create(pipeline_name: String, state_name': String,
    state_comp: StateComputation[In, Out, State] val,
    step_id_map': Map[Key, U128] val, partition': Partition[PIn, Key] val) 
  =>
    _state_name = state_name'
    _pipeline_name = pipeline_name
    _state_comp = state_comp
    _step_id_map = step_id_map'
    _partition = partition'

  fun apply(metrics_reporter: MetricsReporter iso, 
    next_runner: (Runner iso | None) = None,
    router: (Router val | None) = None): Runner iso^
  =>
    match router
    | let r: Router val =>
      PreStateRunner[In, Out, State](_state_comp, r, consume metrics_reporter)
    else
      @printf[I32]("PreStateRunner should take a Router on build!\n".cstring())
      PreStateRunner[In, Out, State](_state_comp, EmptyRouter, 
        consume metrics_reporter)
    end

  fun name(): String => _state_comp.name()
  fun state_name(): String => _state_name
  fun is_stateful(): Bool => true
  fun id(): U128 => 0
  fun step_id_map(): Map[Key, U128] val => _step_id_map
  
  fun pre_state_subpartition(worker: String): PreStateSubpartition val =>
    KeyedPreStateSubpartition[PIn, Key](partition_addresses(worker),
      _step_id_map, _partition.function(), _pipeline_name)

  fun partition_addresses(worker: String): KeyedPartitionAddresses[Key] val =>
    let m: Map[Key, ProxyAddress val] trn = 
      recover Map[Key, ProxyAddress val] end
    for key in _partition.keys().values() do
      m(key) = ProxyAddress(worker, GuidGenerator.u128())
    end
    KeyedPartitionAddresses[Key](consume m)

class ComputationRunner[In: Any val, Out: Any val]
  let _next: Runner
  let _computation: Computation[In, Out] val
  let _computation_name: String
  let _metrics_reporter: MetricsReporter

  new iso create(computation: Computation[In, Out] val, 
    next: Runner iso,
    metrics_reporter: MetricsReporter iso) 
  =>
    _computation = computation
    _computation_name = _computation.name()
    _next = consume next
    _metrics_reporter = consume metrics_reporter

  fun ref run[D: Any val](metric_name: String val, source_ts: U64, data: D,
    producer: (CreditFlowProducer ref | None), router: (Router val | None)): Bool
  =>
    let computation_start = Time.nanos()

    let is_finished = 
      match data
      | let input: In =>
        let result = _computation(input)
        match result
        | None => true
        | let output: Out =>
          _next.run[Out](metric_name, source_ts, output, producer, router)
        else
          true
        end
      else
        true
      end
    let computation_end = Time.nanos()   
    _metrics_reporter.step_metric(_computation_name,
      computation_start, computation_end)
    is_finished

class PreStateRunner[In: Any val, Out: Any val, State: Any #read]
  let _metrics_reporter: MetricsReporter
  let _output_router: Router val
  let _state_comp: StateComputation[In, Out, State] val
  let _name: String
  let _prep_name: String

  new iso create(state_comp: StateComputation[In, Out, State] val,
    router: Router val, metrics_reporter: MetricsReporter iso) 
  =>
    _metrics_reporter = consume metrics_reporter
    _output_router = router
    _state_comp = state_comp
    _name = _state_comp.name()
    _prep_name = _name + " prep"

  fun ref run[D: Any val](metric_name: String val, source_ts: U64, data: D,
    producer: (CreditFlowProducer ref | None), router: (Router val | None)): Bool
  =>
    @printf[I32]("prestate runner received!\n".cstring())
    let computation_start = Time.nanos()
    let is_finished = 
      match data
      | let input: In =>
        match router
        | let shared_state_router: Router val =>
          let processor: StateProcessor[State] val = 
            StateComputationWrapper[In, Out, State](input, _state_comp, 
              _output_router)
          shared_state_router.route[StateProcessor[State] val](metric_name,
            source_ts, processor, producer)
        else
          true
        end
      else
        @printf[I32]("StateRunner: Input was not a StateProcessor!\n".cstring())
        true
      end
    let computation_end = Time.nanos()

    _metrics_reporter.step_metric(_prep_name, computation_start, 
      computation_end)

    is_finished

class StateRunner[State: Any #read]
  let _state: State
  let _metrics_reporter: MetricsReporter

  new iso create(state_builder: {(): State} val, 
    metrics_reporter: MetricsReporter iso) 
  =>
    _state = state_builder()
    _metrics_reporter = consume metrics_reporter

  fun ref run[In: Any val](metric_name: String val, source_ts: U64, input: In,
    producer: (CreditFlowProducer ref | None), router: (Router val | None)): Bool
  =>
    @printf[I32]("state runner received!\n".cstring())
    match input
    | let sp: StateProcessor[State] val =>
      let computation_start = Time.nanos()
      let is_finished = sp(_state, metric_name, source_ts, producer)
      let computation_end = Time.nanos()

      _metrics_reporter.step_metric(sp.name(),
        computation_start, computation_end)
      is_finished
    else
      @printf[I32]("StateRunner: Input was not a StateProcessor!\n".cstring())
      true
    end

class iso RouterRunner
  fun ref run[In: Any val](metric_name: String val, source_ts: U64, input: In,
    producer: (CreditFlowProducer ref | None), router: (Router val | None)): Bool
  =>
    match router
    | let r: Router val =>
      r.route[In](metric_name, source_ts, input, producer)
      false
    else
      true
    end

class Proxy
  let _worker_name: String
  let _target_step_id: U128
  let _metrics_reporter: MetricsReporter
  let _auth: AmbientAuth

  new iso create(worker_name: String, target_step_id: U128, 
    metrics_reporter: MetricsReporter iso, auth: AmbientAuth) 
  =>
    _worker_name = worker_name
    _target_step_id = target_step_id
    _metrics_reporter = consume metrics_reporter
    _auth = auth

  fun ref run[In: Any val](metric_name: String, source_ts: U64, input: In,
    producer: (CreditFlowProducer ref | None), router: (Router val | None)): Bool
  =>
    match router
    | let r: Router val =>
      try
        let forward_msg = ChannelMsgEncoder.data_channel[In](_target_step_id, 
          0, _worker_name, source_ts, input, metric_name, _auth)
        r.route[Array[ByteSeq] val](metric_name, source_ts, forward_msg, 
          producer)
        false
      else
        @printf[I32]("Problem encoding forwarded message\n".cstring())
        true
      end
    else
      true
    end

    // _metrics_reporter.worker_metric(metric_name, source_ts)  


