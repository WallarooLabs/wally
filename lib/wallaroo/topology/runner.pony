use "buffered"
use "collections"
use "net"
use "time"
use "serialise"
use "sendence/guid"
use "sendence/time"
use "sendence/weighted"
use "wallaroo/"
use "wallaroo/fail"
use "wallaroo/initialization"
use "wallaroo/invariant"
use "wallaroo/metrics"
use "wallaroo/recovery"
use "wallaroo/routing"
use "wallaroo/state"
use "wallaroo/w_actor"


interface Runner
  // Return a Bool indicating whether the message is finished processing
  // and a Bool indicating whether the Route has filled its queue
  fun ref run[D: Any val](metric_name: String, pipeline_time_spent: U64,
    data: D, producer: Producer ref, router: Router val,
    omni_router: OmniRouter val, i_origin: Producer, i_msg_uid: U128,
    i_frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64,
    metrics_reporter: MetricsReporter ref): (Bool, Bool, U64)
  fun name(): String
  fun state_name(): String
  fun clone_router_and_set_input_type(r: Router val,
    default_r: (Router val | None) = None): Router val

interface SerializableStateRunner
  fun ref serialize_state(): ByteSeq val
  fun ref replace_serialized_state(s: ByteSeq val)

trait ReplayableRunner
  fun ref replay_log_entry(uid: U128, frac_ids: None, statechange_id: U64,
    payload: ByteSeq val, origin: Producer)
  fun ref set_step_id(id: U128)

trait RunnerBuilder
  fun apply(event_log: EventLog,
    auth: AmbientAuth,
    next_runner: (Runner iso | None) = None,
    router: (Router val | None) = None,
    pre_state_target_id': (U128 | None) = None): Runner iso^

  fun name(): String
  fun state_name(): String => ""
  fun is_prestate(): Bool => false
  fun is_stateful(): Bool
  fun is_multi(): Bool => false
  fun id(): U128
  fun route_builder(): RouteBuilder val
  fun forward_route_builder(): RouteBuilder val
  fun in_route_builder(): (RouteBuilder val | None) => None
  fun clone_router_and_set_input_type(r: Router val,
    default_r: (Router val | None) = None): Router val
  =>
    r

class RunnerSequenceBuilder is RunnerBuilder
  let _runner_builders: Array[RunnerBuilder val] val
  let _id: U128
  var _forward_route_builder: RouteBuilder val
  var _in_route_builder: (RouteBuilder val | None)
  var _state_name: String

  new val create(bs: Array[RunnerBuilder val] val) =>
    _runner_builders = bs
    _id =
      try
        bs(0).id()
      else
        GuidGenerator.u128()
      end
    _forward_route_builder =
      try
        _runner_builders(_runner_builders.size() - 1).forward_route_builder()
      else
        EmptyRouteBuilder
      end

    _in_route_builder =
      try
        _runner_builders(_runner_builders.size() - 1).in_route_builder()
      else
        None
      end

    _state_name =
      try
        _runner_builders(_runner_builders.size() - 1).state_name()
      else
        ""
      end

  fun apply(event_log: EventLog,
    auth: AmbientAuth,
    next_runner: (Runner iso | None) = None,
    router: (Router val | None) = None,
    pre_state_target_id': (U128 | None) = None): Runner iso^
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
        latest_runner = rb(event_log, auth,
          consume latest_runner, router, pre_state_target_id')
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

  fun state_name(): String => _state_name
  fun default_state_name(): String =>
    try
      match _runner_builders(_runner_builders.size() - 1)
      | let ds: DefaultStateable val =>
        ds.default_state_name()
      else
        ""
      end
    else
      ""
    end
  fun is_prestate(): Bool =>
    try
      _runner_builders(_runner_builders.size() - 1).is_prestate()
    else
      false
    end
  fun is_stateful(): Bool => false
  fun is_multi(): Bool =>
    try
      _runner_builders(_runner_builders.size() - 1).is_multi()
    else
      false
    end
  fun id(): U128 => _id
  fun route_builder(): RouteBuilder val =>
    try
      _runner_builders(_runner_builders.size() - 1).route_builder()
    else
      EmptyRouteBuilder
    end
  fun forward_route_builder(): RouteBuilder val => _forward_route_builder
  fun in_route_builder(): (RouteBuilder val | None) => _in_route_builder
  fun clone_router_and_set_input_type(r: Router val,
    default_r: (Router val | None) = None): Router val
  =>
    try
      _runner_builders(_runner_builders.size() - 1).clone_router_and_set_input_type(r, default_r)
    else
      r
    end

class ComputationRunnerBuilder[In: Any val, Out: Any val] is RunnerBuilder
  let _comp_builder: ComputationBuilder[In, Out] val
  let _id: U128
  let _route_builder: RouteBuilder val

  new val create(comp_builder: ComputationBuilder[In, Out] val,
    route_builder': RouteBuilder val, id': U128 = 0)
  =>
    _comp_builder = comp_builder
    _route_builder = route_builder'
    _id = if id' == 0 then GuidGenerator.u128() else id' end

  fun apply(event_log: EventLog,
    auth: AmbientAuth,
    next_runner: (Runner iso | None) = None,
    router: (Router val | None) = None,
    pre_state_target_id': (U128 | None) = None): Runner iso^
  =>
    match (consume next_runner)
    | let r: Runner iso =>
      ComputationRunner[In, Out](_comp_builder(), consume r)
    else
      ComputationRunner[In, Out](_comp_builder(), RouterRunner)
    end

  fun name(): String => _comp_builder().name()
  fun state_name(): String => ""
  fun is_stateful(): Bool => false
  fun id(): U128 => _id
  fun route_builder(): RouteBuilder val => _route_builder
  fun forward_route_builder(): RouteBuilder val => EmptyRouteBuilder

interface DefaultStateable
  fun default_state_name(): String

class PreStateRunnerBuilder[In: Any val, Out: Any val,
  PIn: Any val, Key: (Hashable val & Equatable[Key] val), S: State ref] is
    RunnerBuilder
  let _state_comp: StateComputation[In, Out, S] val
  let _state_name: String
  let _default_state_name: String
  let _route_builder: RouteBuilder val
  let _partition_function: PartitionFunction[PIn, Key] val
  let _forward_route_builder: RouteBuilder val
  let _in_route_builder: (RouteBuilder val | None)
  let _id: U128
  let _is_multi: Bool

  new val create(state_comp: StateComputation[In, Out, S] val,
    state_name': String,
    partition_function': PartitionFunction[PIn, Key] val,
    route_builder': RouteBuilder val,
    forward_route_builder': RouteBuilder val,
    in_route_builder': (RouteBuilder val | None) = None,
    default_state_name': String = "",
    multi_worker: Bool = false)
  =>
    _state_comp = state_comp
    _state_name = state_name'
    _default_state_name = default_state_name'
    _route_builder = route_builder'
    _partition_function = partition_function'
    _id = GuidGenerator.u128()
    _is_multi = multi_worker
    _forward_route_builder = forward_route_builder'
    _in_route_builder = in_route_builder'

  fun apply(event_log: EventLog,
    auth: AmbientAuth,
    next_runner: (Runner iso | None) = None,
    router: (Router val | None) = None,
    pre_state_target_id': (U128 | None) = None): Runner iso^
  =>
    match pre_state_target_id'
    | let t_id: U128 =>
      PreStateRunner[In, Out, S](_state_comp, _state_name, t_id)
    else
      PreStateRunner[In, Out, S](_state_comp, _state_name, 0)
    end

  fun name(): String => _state_comp.name()
  fun state_name(): String => _state_name
  fun default_state_name(): String => _default_state_name
  fun is_prestate(): Bool => true
  fun is_stateful(): Bool => true
  fun is_multi(): Bool => _is_multi
  fun id(): U128 => _id
  fun route_builder(): RouteBuilder val => _route_builder
  fun forward_route_builder(): RouteBuilder val => _forward_route_builder
  fun in_route_builder(): (RouteBuilder val | None) =>
    _in_route_builder
  fun clone_router_and_set_input_type(r: Router val,
    default_r: (Router val | None) = None): Router val
  =>
    match r
    | let p: AugmentablePartitionRouter[Key] val =>
      p.clone_and_set_input_type[PIn](_partition_function, default_r)
    else
      r
    end

class StateRunnerBuilder[S: State ref] is RunnerBuilder
  let _state_builder: StateBuilder[S] val
  let _state_name: String
  let _state_change_builders: Array[StateChangeBuilder[S] val] val
  let _route_builder: RouteBuilder val
  let _id: U128

  new val create(state_builder: StateBuilder[S] val,
    state_name': String,
    state_change_builders: Array[StateChangeBuilder[S] val] val,
    route_builder': RouteBuilder val = EmptyRouteBuilder)
  =>
    _state_builder = state_builder
    _state_name = state_name'
    _state_change_builders = state_change_builders
    _route_builder = route_builder'
    _id = GuidGenerator.u128()

  fun apply(event_log: EventLog,
    auth: AmbientAuth,
    next_runner: (Runner iso | None) = None,
    router: (Router val | None) = None,
    pre_state_target_id': (U128 | None) = None): Runner iso^
  =>
    let sr = StateRunner[S](_state_builder, event_log, auth)
    for scb in _state_change_builders.values() do
      sr.register_state_change(scb)
    end
    sr

  fun name(): String => _state_builder.name()
  fun state_name(): String => _state_name
  fun is_stateful(): Bool => true
  fun id(): U128 => _id
  fun route_builder(): RouteBuilder val => _route_builder
  fun forward_route_builder(): RouteBuilder val => EmptyRouteBuilder

trait PartitionBuilder
  // These two methods need to be deterministic at the moment since they
  // are called at different times
  fun state_subpartition(workers: (String | Array[String] val)):
    StateSubpartition val
  fun partition_addresses(workers: (String | Array[String] val)):
    PartitionAddresses val
  fun state_name(): String
  fun is_multi(): Bool
  fun default_state_name(): String

class PartitionedStateRunnerBuilder[PIn: Any val, S: State ref,
  Key: (Hashable val & Equatable[Key])] is (PartitionBuilder & RunnerBuilder)
  let _pipeline_name: String
  let _state_name: String
  let _state_runner_builder: StateRunnerBuilder[S] val
  let _step_id_map: Map[Key, U128] val
  let _partition: Partition[PIn, Key] val
  let _route_builder: RouteBuilder val
  let _forward_route_builder: RouteBuilder val
  let _id: U128
  let _multi_worker: Bool
  let _default_state_name: String

  new val create(pipeline_name: String, state_name': String,
    step_id_map': Map[Key, U128] val, partition': Partition[PIn, Key] val,
    state_runner_builder: StateRunnerBuilder[S] val,
    route_builder': RouteBuilder val,
    forward_route_builder': RouteBuilder val, id': U128 = 0,
    multi_worker: Bool = false, default_state_name': String = "")
  =>
    _id = if id' == 0 then GuidGenerator.u128() else id' end
    _state_name = state_name'
    _pipeline_name = pipeline_name
    _state_runner_builder = state_runner_builder
    _step_id_map = step_id_map'
    _partition = partition'
    _route_builder = route_builder'
    _forward_route_builder = forward_route_builder'
    _multi_worker = multi_worker
    _default_state_name = default_state_name'

  fun apply(event_log: EventLog,
    auth: AmbientAuth,
    next_runner: (Runner iso | None) = None,
    router: (Router val | None) = None,
    pre_state_target_id': (U128 | None) = None): Runner iso^
  =>
    _state_runner_builder(event_log, auth,
      consume next_runner, router)

  fun name(): String => _state_name
  fun state_name(): String => _state_name
  fun is_stateful(): Bool => true
  fun id(): U128 => _id
  fun step_id_map(): Map[Key, U128] val => _step_id_map
  fun route_builder(): RouteBuilder val => _route_builder
  fun forward_route_builder(): RouteBuilder val => _forward_route_builder
  fun is_multi(): Bool => _multi_worker
  fun default_state_name(): String => _default_state_name

  fun state_subpartition(workers: (String | Array[String] val)):
    StateSubpartition val
  =>
    KeyedStateSubpartition[PIn, Key](partition_addresses(workers),
      _step_id_map, _state_runner_builder, _partition.function(),
      _pipeline_name)

  fun partition_addresses(workers: (String | Array[String] val)):
    KeyedPartitionAddresses[Key] val
  =>
    let m: Map[Key, ProxyAddress val] trn =
      recover Map[Key, ProxyAddress val] end

    match workers
    | let w: String =>
      // With one worker, all the keys go on that worker
      match _partition.keys()
      | let wks: Array[WeightedKey[Key]] val =>
        for wkey in wks.values() do
          try
            m(wkey._1) = ProxyAddress(w, _step_id_map(wkey._1))
          end
        end
      | let ks: Array[Key] val =>
        for key in ks.values() do
          try
            m(key) = ProxyAddress(w, _step_id_map(key))
          end
        end
      end
    | let ws: Array[String] val =>
      // With multiple workers, we need to determine our distribution of keys
      let w_count = ws.size()
      var idx: USize = 0

      match _partition.keys()
      | let wks: Array[WeightedKey[Key]] val =>
        // Using weighted keys, we need to create a distribution that
        // balances the weight across workers
        try
          let buckets = Weighted[Key](wks, ws.size())
          for worker_idx in Range(0, buckets.size()) do
            for key in buckets(worker_idx).values() do
              m(key) = ProxyAddress(ws(worker_idx), _step_id_map(key))
            end
          end
        end
      | let ks: Array[Key] val =>
        // With unweighted keys, we simply distribute the keys equally across
        // the workers
        for key in ks.values() do
          try
            m(key) = ProxyAddress(ws(idx), _step_id_map(key))
          end
          idx = (idx + 1) % w_count
        end
      end
    end

    KeyedPartitionAddresses[Key](consume m)

class ComputationRunner[In: Any val, Out: Any val]
  let _next: Runner
  let _computation: Computation[In, Out] val
  let _computation_name: String

  new iso create(computation: Computation[In, Out] val,
    next: Runner iso)
  =>
    _computation = computation
    _computation_name = _computation.name()
    _next = consume next

  fun ref run[D: Any val](metric_name: String, pipeline_time_spent: U64,
    data: D, producer: Producer ref, router: Router val,
    omni_router: OmniRouter val, i_origin: Producer, i_msg_uid: U128,
    i_frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId, latest_ts: U64,
    metrics_id: U16, worker_ingress_ts: U64,
    metrics_reporter: MetricsReporter ref): (Bool, Bool, U64)
  =>
    var computation_start: U64 = 0
    var computation_end: U64 = 0

    (let is_finished, let keep_sending, let last_ts) =
      match data
      | let input: In =>
        computation_start = Time.nanos()
        let result = _computation(input)
        computation_end = Time.nanos()
        let new_metrics_id = ifdef "detailed-metrics" then
            // increment by 2 because we'll be reporting 2 step metrics below
            metrics_id + 2
          else
            // increment by 1 because we'll be reporting 1 step metric below
            metrics_id + 1
          end

        match result
        | None => (true, true, computation_end)
        | let output: Out =>
          _next.run[Out](metric_name, pipeline_time_spent, output, producer,
            router, omni_router,
            i_origin, i_msg_uid, i_frac_ids, i_seq_id, i_route_id,
            computation_end, new_metrics_id, worker_ingress_ts, metrics_reporter)
        else
          (true, true, computation_end)
        end
      else
        (true, true, latest_ts)
      end

    let latest_metrics_id = ifdef "detailed-metrics" then
        metrics_reporter.step_metric(metric_name, _computation_name, metrics_id,
          latest_ts, computation_start where prefix = "Before")
        metrics_id + 1
      else
        metrics_id
      end

    metrics_reporter.step_metric(metric_name, _computation_name, latest_metrics_id,
      computation_start, computation_end)
    (is_finished, keep_sending, last_ts)

  fun name(): String => _computation.name()
  fun state_name(): String => ""
  fun clone_router_and_set_input_type(r: Router val,
    default_r: (Router val | None) = None): Router val
  =>
    _next.clone_router_and_set_input_type(r)

class PreStateRunner[In: Any val, Out: Any val, S: State ref]
  let _target_id: U128
  let _state_comp: StateComputation[In, Out, S] val
  let _name: String
  let _prep_name: String
  let _state_name: String

  new iso create(state_comp: StateComputation[In, Out, S] val,
    state_name': String, target_id: U128)
  =>
    _target_id = target_id
    _state_comp = state_comp
    _name = _state_comp.name()
    _prep_name = _name + " prep"
    _state_name = state_name'
    //TODO: Fix the types on this so we can check something like this.
    // We want to prove that target_id is 0 iff the output type is None
    // and not just a subtype of (X | None)
    // ifdef debug then
    //   Invariant(
    //     match None
    //     | let o: Out =>
    //       _target_id == 0
    //     else
    //       _target_id != 0
    //     end
    //   )
    // end

  fun ref run[D: Any val](metric_name: String, pipeline_time_spent: U64,
    data: D, producer: Producer ref, router: Router val,
    omni_router: OmniRouter val, i_origin: Producer, i_msg_uid: U128,
    i_frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64,
    metrics_reporter: MetricsReporter ref): (Bool, Bool, U64)
  =>
    let wrapper_creation_start_ts = Time.nanos()
    (let is_finished, let keep_sending, let last_ts) =
      match data
      | let input: In =>
        match router
        | let shared_state_router: Router val =>
          let processor: StateComputationWrapper[In, Out, S] val =
            StateComputationWrapper[In, Out, S](input, _state_comp,
              _target_id)
          shared_state_router.route[
            StateComputationWrapper[In, Out, S] val](
            metric_name, pipeline_time_spent, processor, producer,
            i_origin, i_msg_uid, i_frac_ids, i_seq_id, i_route_id,
            latest_ts, metrics_id + 1, worker_ingress_ts)
        else
          (true, true, latest_ts)
        end
      else
        @printf[I32]("StateRunner: Input was not a StateProcessor!\n".cstring())
        (true, true, latest_ts)
      end
    let wrapper_creation_end_ts = Time.nanos()
    metrics_reporter.step_metric(metric_name, _name, metrics_id,
      wrapper_creation_start_ts, wrapper_creation_end_ts
      where prefix = "Pre:")
    (is_finished, keep_sending, last_ts)

  fun name(): String => _name
  fun state_name(): String => _state_name
  fun is_pre_state(): Bool => true
  fun clone_router_and_set_input_type(r: Router val,
    default_r: (Router val | None) = None): Router val
  =>
    r

class StateRunner[S: State ref] is (Runner & ReplayableRunner & SerializableStateRunner)
  var _state: S
  //TODO: this needs to be per-computation, rather than per-runner
  let _state_change_repository: StateChangeRepository[S] ref
  let _event_log: EventLog
  let _wb: Writer = Writer
  let _rb: Reader = Reader
  let _auth: AmbientAuth
  var _id: (U128 | None)

  new iso create(state_builder: {(): S} val,
      event_log: EventLog, auth: AmbientAuth)
  =>
    _state = state_builder()
    _state_change_repository = StateChangeRepository[S]
    _event_log = event_log
    _id = None
    _auth = auth

  fun ref set_step_id(id: U128) =>
    _id = id

  fun ref register_state_change(scb: StateChangeBuilder[S] val) : U64 =>
    _state_change_repository.make_and_register(scb)

  fun ref replay_log_entry(msg_uid: U128, frac_ids: None, statechange_id: U64,
    payload: ByteSeq val, origin: Producer)
  =>
    if statechange_id == U64.max_value() then
      replace_serialized_state(payload)
    else
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
    end

  fun ref run[D: Any val](metric_name: String, pipeline_time_spent: U64,
    data: D, producer: Producer ref, router: Router val,
    omni_router: OmniRouter val, i_origin: Producer, i_msg_uid: U128,
    i_frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64,
    metrics_reporter: MetricsReporter ref): (Bool, Bool, U64)
  =>
    match data
    | let sp: StateProcessor[S] val =>
      let new_metrics_id = ifdef "detailed-metrics" then
          // increment by 2 because we'll be reporting 2 step metrics below
          metrics_id + 2
        else
          // increment by 1 because we'll be reporting 1 step metrics below
          metrics_id + 1
        end

      let result = sp(_state, _state_change_repository, omni_router,
        metric_name, pipeline_time_spent, producer,
        i_origin, i_msg_uid, i_frac_ids, i_seq_id, i_route_id,
        latest_ts, new_metrics_id, worker_ingress_ts)
      let is_finished = result._1
      let keep_sending = result._2
      let state_change = result._3
      let sc_start_ts = result._4
      let sc_end_ts = result._5
      let last_ts = result._6

      let latest_metrics_id = ifdef "detailed-metrics" then
          metrics_reporter.step_metric(metric_name, sp.name(), metrics_id,
            latest_ts, sc_start_ts where prefix = "Before")
          metrics_id + 1
        else
          metrics_id
        end

      metrics_reporter.step_metric(metric_name, sp.name(), latest_metrics_id,
        sc_start_ts, sc_end_ts)

      match state_change
      | let sc: StateChange[S] ref =>
        ifdef "resilience" then
          sc.write_log_entry(_wb)
          let payload = _wb.done()
          match _id
          | let buffer_id: U128 =>

            _event_log.queue_log_entry(buffer_id, i_msg_uid, None,
              sc.id(), producer.current_sequence_id(), consume payload)
          else
            @printf[I32]("StateRunner with unassigned EventLogBuffer!".cstring())
          end
        end
        sc.apply(_state)
      | let dsc: DirectStateChange =>
        ifdef "resilience" then
          // TODO: Replace this with calling provided serialization method
          match _id
          | let buffer_id: U128 =>
            _state.write_log_entry(_wb, _auth)
            let payload = _wb.done()
            _event_log.queue_log_entry(buffer_id, i_msg_uid, None,
              U64.max_value(), producer.current_sequence_id(), consume payload)
          end
        end
      end

      (is_finished, keep_sending, last_ts)
    else
      @printf[I32]("StateRunner: Input was not a StateProcessor!\n".cstring())
      (true, true, latest_ts)
    end

  fun rotate_log() =>
    //we need to be able to conflate all the current logs to a checkpoint and
    //rotate
    None

  fun name(): String => "State runner"
  fun state_name(): String => ""
  fun clone_router_and_set_input_type(r: Router val,
    default_r: (Router val | None) = None): Router val
  =>
    r

  fun ref serialize_state(): ByteSeq val =>
    try
      Serialised(SerialiseAuth(_auth), _state).output(OutputSerialisedAuth(_auth))
    else
      Fail()
      recover val Array[U8] end
    end

  fun ref replace_serialized_state(payload: ByteSeq val) =>
    try
      _rb.append(payload as Array[U8] val)
      match _state.read_log_entry(_rb, _auth)
      | let s: S =>
        _state = s
      else
        Fail()
      end
    else
      Fail()
    end

class iso RouterRunner
  fun ref run[Out: Any val](metric_name: String, pipeline_time_spent: U64,
    output: Out, producer: Producer ref, router: Router val,
    omni_router: OmniRouter val, i_origin: Producer, i_msg_uid: U128,
    i_frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64,
    metrics_reporter: MetricsReporter ref): (Bool, Bool, U64)
  =>
    match router
    | let r: Router val =>
      r.route[Out](metric_name, pipeline_time_spent, output, producer,
        i_origin, i_msg_uid, i_frac_ids, i_seq_id, i_route_id,
        latest_ts, metrics_id, worker_ingress_ts)
    else
      (true, true, latest_ts)
    end

  fun name(): String => "Router runner"
  fun state_name(): String => ""
  fun clone_router_and_set_input_type(r: Router val,
    default_r: (Router val | None) = None): Router val
  =>
    r
