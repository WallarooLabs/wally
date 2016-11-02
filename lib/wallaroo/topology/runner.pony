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
use "wallaroo/resilience"


// TODO: Eliminate producer None when we can
interface Runner
  // Return a Bool indicating whether the message is finished processing
  fun ref run[In: Any val](metric_name: String, source_ts: U64, input: In,
    incoming_envelope: MsgEnvelope box, outgoing_envelope: MsgEnvelope,
    producer: (CreditFlowProducer ref | None), router: (Router val | None) = None): Bool

trait ReplayableRunner
  fun ref replay_log_entry(uid: U128, frac_ids: (Array[U64] val | None), statechange_id: U64, payload: ByteSeq val, 
    origin: Origin tag)
  fun ref set_origin_id(id: U128)

interface RunnerBuilder
  fun apply(metrics_reporter: MetricsReporter iso, 
    alfred: Alfred tag,
    next_runner: (Runner iso | None) = None,
    router: (Router val | None) = None): Runner iso^

  fun name(): String
  fun is_stateful(): Bool
  fun id(): U128
  fun route_builder(): RouteBuilder val
  fun forward_route_builder(): RouteBuilder val

class RunnerSequenceBuilder
  let _runner_builders: Array[RunnerBuilder val] val
  let _id: U128
  var _forward_route_builder: RouteBuilder val = EmptyRouteBuilder

  new val create(bs: Array[RunnerBuilder val] val) =>
    _runner_builders = bs
    _id = 
      try
        bs(0).id()
      else
        GuidGenerator.u128()
      end
    try
      _forward_route_builder = 
        _runner_builders(_runner_builders.size() - 1).forward_route_builder()
    end

  fun apply(metrics_reporter: MetricsReporter iso, 
    alfred: Alfred tag,
    next_runner: (Runner iso | None) = None,
    router: (Router val | None) = None): Runner iso^
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
        latest_runner = rb(metrics_reporter.clone(), alfred,
          consume latest_runner, router)
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

  fun is_stateful(): Bool => false
  fun id(): U128 => _id
  fun route_builder(): RouteBuilder val => 
    try
      _runner_builders(_runner_builders.size() - 1).route_builder()
    else
      EmptyRouteBuilder
    end
  fun forward_route_builder(): RouteBuilder val => _forward_route_builder

class ComputationRunnerBuilder[In: Any val, Out: Any val]
  let _comp_builder: ComputationBuilder[In, Out] val
  let _id: U128
  let _route_builder: RouteBuilder val

  new val create(comp_builder: ComputationBuilder[In, Out] val,
    route_builder': RouteBuilder val, id': U128 = 0) 
  =>
    _comp_builder = comp_builder
    _route_builder = route_builder'
    _id = if id' == 0 then GuidGenerator.u128() else id' end

  fun apply(metrics_reporter: MetricsReporter iso, 
    alfred: Alfred tag,
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
  fun route_builder(): RouteBuilder val => _route_builder
  fun forward_route_builder(): RouteBuilder val => EmptyRouteBuilder

class PreStateRunnerBuilder[In: Any val, Out: Any val, State: Any #read]
  let _state_comp: StateComputation[In, Out, State] val
  let _route_builder: RouteBuilder val
  let _forward_route_builder: RouteBuilder val
  let _id: U128

  new val create(state_comp: StateComputation[In, Out, State] val,
    route_builder': RouteBuilder val, 
    forward_route_builder': RouteBuilder val) 
  =>
    _state_comp = state_comp
    _route_builder = route_builder'
    _id = GuidGenerator.u128()
    _forward_route_builder = forward_route_builder'

  fun apply(metrics_reporter: MetricsReporter iso, 
    alfred: Alfred tag,
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
  fun id(): U128 => _id
  fun route_builder(): RouteBuilder val => _route_builder
  fun forward_route_builder(): RouteBuilder val => _forward_route_builder

class StateRunnerBuilder[State: Any #read]
  let _state_builder: StateBuilder[State] val
  let _name: String
  let _state_change_builders: Array[StateChangeBuilder[State] val] val
  let _id: U128

  new val create(state_builder: StateBuilder[State] val, 
    name': String, 
    state_change_builders: Array[StateChangeBuilder[State] val] val) 
  =>
    _state_builder = state_builder
    _name = name'
    _state_change_builders = state_change_builders
    _id = GuidGenerator.u128()

  fun apply(metrics_reporter: MetricsReporter iso, 
    alfred: Alfred tag,
    next_runner: (Runner iso | None) = None,
    router: (Router val | None) = None): Runner iso^
  =>
    let sr = StateRunner[State](_state_builder, consume metrics_reporter, alfred)
    for scb in _state_change_builders.values() do
      sr.register_state_change(scb)
    end
    sr

  fun name(): String => _state_builder.name()
  fun is_stateful(): Bool => true
  fun id(): U128 => _id
  fun route_builder(): RouteBuilder val => EmptyRouteBuilder
  fun forward_route_builder(): RouteBuilder val => EmptyRouteBuilder

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
  let _route_builder: RouteBuilder val
  let _forward_route_builder: RouteBuilder val
  let _id: U128

  new val create(pipeline_name: String, state_name': String,
    state_comp: StateComputation[In, Out, State] val,
    step_id_map': Map[Key, U128] val, partition': Partition[PIn, Key] val,
    route_builder': RouteBuilder val, 
    forward_route_builder': RouteBuilder val, id': U128 = 0) 
  =>
    _id = if id' == 0 then GuidGenerator.u128() else id' end
    _state_name = state_name'
    _pipeline_name = pipeline_name
    _state_comp = state_comp
    _step_id_map = step_id_map'
    _partition = partition'
    _route_builder = route_builder'
    _forward_route_builder = forward_route_builder'

  fun apply(metrics_reporter: MetricsReporter iso, 
    alfred: Alfred tag,
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
  fun id(): U128 => _id
  fun step_id_map(): Map[Key, U128] val => _step_id_map
  fun route_builder(): RouteBuilder val => _route_builder
  fun forward_route_builder(): RouteBuilder val => _forward_route_builder
  
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
    next: Runner iso, metrics_reporter: MetricsReporter iso) 
  =>
    _computation = computation
    _computation_name = _computation.name()
    _next = consume next
    _metrics_reporter = consume metrics_reporter

  fun ref run[D: Any val](metric_name: String val, source_ts: U64, data: D,
    incoming_envelope: MsgEnvelope box, outgoing_envelope: MsgEnvelope,
    producer: (CreditFlowProducer ref | None), router: (Router val | None)): 
      Bool
  =>
    let computation_start = Time.nanos()

    let is_finished = 
      match data
      | let input: In =>
        let result = _computation(input)
        match result
        | None => true
        | let output: Out =>
          _next.run[Out](metric_name, source_ts, output, 
            incoming_envelope, outgoing_envelope, producer, router)
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
    incoming_envelope: MsgEnvelope box, outgoing_envelope: MsgEnvelope,
    producer: (CreditFlowProducer ref | None), router: (Router val | None)): Bool
  =>
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
            source_ts, processor, incoming_envelope, outgoing_envelope,
            producer)
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

class StateRunner[State: Any #read] is (Runner & ReplayableRunner)
  let _state: State
  let _metrics_reporter: MetricsReporter
  let _state_change_repository: StateChangeRepository[State] ref
  let _alfred: Alfred
  let _wb: Writer = Writer
  let _rb: Reader = Reader
  var _id: (U128 | None)

  new iso create(state_builder: {(): State} val, 
      metrics_reporter: MetricsReporter iso, alfred: Alfred)
  =>
    _state = state_builder()
    _metrics_reporter = consume metrics_reporter
    _state_change_repository = StateChangeRepository[State]
    _alfred = alfred
    _id = None

  fun ref set_origin_id(id: U128) => _id = id

  fun ref register_state_change(scb: StateChangeBuilder[State] val) : U64 =>
    _state_change_repository.make_and_register(scb)

  fun ref replay_log_entry(msg_uid: U128, frac_ids: (Array[U64] val | None), statechange_id: U64, payload: ByteSeq val, 
    origin: (Origin tag | None))
  =>
    try
      let sc = _state_change_repository(statechange_id)
      _rb.append(payload as Array[U8] val)
      try
        sc.read_log_entry(_rb)
        sc.apply(_state)
      end
    else
      @printf[I32]("FATAL: could not look up state_change with id %d".cstring(), statechange_id)
    end

  fun ref run[In: Any val](metric_name: String val, source_ts: U64, input: In,
    incoming_envelope: MsgEnvelope box, outgoing_envelope: MsgEnvelope,
    producer: (CreditFlowProducer ref | None), router: (Router val | None)): Bool
  =>
    // @printf[I32]("state runner received!\n".cstring())
    match input
    | let sp: StateProcessor[State] val =>
      let computation_start = Time.nanos()
      let result = sp(_state, _state_change_repository, metric_name, source_ts,
          incoming_envelope, outgoing_envelope, producer)
      let is_finished = result._1
      let state_change = result._2

      match state_change
      | let sc: StateChange[State] ref =>
        ifdef "resilience" then
          sc.write_log_entry(_wb)
          //TODO: batching? race between queueing and watermark?
          let payload = _wb.done()
          //TODO: deal with creating fractional message ids here
          match _id
          | let buffer_id: U128 =>
            _alfred.queue_log_entry(buffer_id, incoming_envelope.msg_uid, None,
              sc.id(), outgoing_envelope.seq_id, consume payload)
          else
            @printf[I32]("StateRunner with unassigned EventLogBuffer!".cstring())
          end
        end
        sc.apply(_state)
        let computation_end = Time.nanos()
        _metrics_reporter.step_metric(sp.name(), computation_start, 
          computation_end)
        is_finished
      else
        let computation_end = Time.nanos()
        _metrics_reporter.step_metric(sp.name(), computation_start, 
          computation_end)
        is_finished
      end
    else
      @printf[I32]("StateRunner: Input was not a StateProcessor!\n".cstring())
      true
    end

  fun rotate_log() =>
    //we need to be able to conflate all the current logs to a checkpoint and
    //rotate
    None

class iso RouterRunner
  fun ref run[In: Any val](metric_name: String val, source_ts: U64, input: In,
    incoming_envelope: MsgEnvelope box, outgoing_envelope: MsgEnvelope,
    producer: (CreditFlowProducer ref | None), router: (Router val | None)): Bool
  =>
    match router
    | let r: Router val =>
      r.route[In](metric_name, source_ts, input, incoming_envelope,
        outgoing_envelope, producer)
      false
    else
      true
    end
