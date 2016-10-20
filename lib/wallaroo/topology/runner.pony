use "buffered"
use "time"
use "net"
use "collections"
use "sendence/epoch"
use "wallaroo/metrics"
use "wallaroo/messages"
use "wallaroo/resilience"

trait Runner
  // Return a Bool indicating whether the message is finished processing
  fun ref run[D: Any val](metric_name: String val, source_ts: U64, data: D,
    origin: Origin tag, msg_uid: U64, frac_ids: (Array[U64] val | None), seq_id: U64, incoming_envelope: MsgEnvelope val,
    router: (Router val | None) = None): Bool
  fun ref recovery_run[D: Any val](metric_name: String val, source_ts: U64, data: D,
    origin: Origin tag, msg_uid: U64, frac_ids: (Array[U64] val | None), seq_id: U64, incoming_envelope: MsgEnvelope val,
    router: (Router val | None) = None): Bool
  fun ref replay_log_entry(uid: U64, frac_ids: (Array[U64] val | None), statechange_id: U64, payload: Array[ByteSeq] val, origin: Origin tag) => None
  fun ref set_buffer_target(target: ResilientOrigin tag) => None
  fun ref replay_finished() => None

interface RunnerBuilder
  fun apply(metrics_reporter: MetricsReporter iso, next: (Runner iso | None) = 
    None): Runner iso^

  fun name(): String
  fun is_stateful(): Bool

primitive RouterRunnerBuilder
  fun apply(metrics_reporter: MetricsReporter iso, next: (Runner iso | None) = 
    None): Runner iso^ 
  => 
    RouterRunner

  fun name(): String => "router"
  fun is_stateful(): Bool => false

class RunnerSequenceBuilder
  let _runner_builders: Array[RunnerBuilder val] val

  new val create(bs: Array[RunnerBuilder val] val) =>
    _runner_builders = bs

  fun apply(metrics_reporter: MetricsReporter iso): Runner iso^ =>
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
        latest_runner = rb(metrics_reporter.clone(), consume latest_runner)
      end
      remaining = remaining - 1
    end
    consume latest_runner

class ComputationRunnerBuilder[In: Any val, Out: Any val]
  let _comp_builder: ComputationBuilder[In, Out] val

  new val create(comp_builder: ComputationBuilder[In, Out] val) =>
    _comp_builder = comp_builder

  fun apply(metrics_reporter: MetricsReporter iso, next: (Runner iso | None)): 
    Runner iso^
  =>
    match (consume next)
    | let r: Runner iso =>
      ComputationRunner[In, Out](_comp_builder(), consume r, 
        consume metrics_reporter)
    else
      ComputationRunner[In, Out](_comp_builder(), RouterRunner, 
        consume metrics_reporter)      
    end

  fun name(): String => _comp_builder().name()
  fun is_stateful(): Bool => false

class PreStateRunnerBuilder[In: Any val, Out: Any val, State: Any #read]
  let _state_comp: StateComputation[In, Out, State] val
  let _router: Router val

  new val create(state_comp: StateComputation[In, Out, State] val,
    router: Router val) =>
    _state_comp = state_comp
    _router = router

  fun apply(metrics_reporter: MetricsReporter iso, next: (Runner iso | None)): 
    Runner iso^
  =>
    PreStateRunner[In, Out, State](_state_comp, _router, consume metrics_reporter)

  fun name(): String => _state_comp.name()
  fun is_stateful(): Bool => true

class StateRunnerBuilder[State: Any #read]
  let _state_builder: StateBuilder[State] val

  new val create(state_builder: StateBuilder[State] val) =>
    _state_builder = state_builder

  fun apply(metrics_reporter: MetricsReporter iso, next: (Runner iso | None),
    alfred: Alfred):
    Runner iso
  =>
    StateRunner[State](_state_builder, consume metrics_reporter, alfred)

  fun name(): String => _state_builder.name()
  fun is_stateful(): Bool => true

class ComputationRunner[In: Any val, Out: Any val] is Runner
  let _next: Runner
  let _computation: Computation[In, Out] val
  let _computation_name: String
  let _metrics_reporter: MetricsReporter
  let _deduplication_list: Array[MsgEnvelope val]

  new iso create(computation: Computation[In, Out] val, 
    next: Runner iso,
    metrics_reporter: MetricsReporter iso) 
  =>
    _computation = computation
    _computation_name = _computation.name()
    _next = consume next
    _metrics_reporter = consume metrics_reporter
    _deduplication_list = Array[MsgEnvelope val]

  fun ref run[D: Any val](metric_name: String val, source_ts: U64, data: D,
    origin: Origin tag, msg_uid: U64, frac_ids: (Array[U64] val | None), seq_id: U64, incoming_envelope: MsgEnvelope val,
    router: (Router val | None) = None): Bool
  =>
    let computation_start = Time.nanos()

    let is_finished = 
      match data
      | let input: In =>
        let result = _computation(input)
        match result
        | None => true
        | let output: Out =>
          _next.run[Out](metric_name, source_ts, output, origin, msg_uid, frac_ids, seq_id,
          incoming_envelope, router)
        else
          true
        end
      else
        true
      end
    let computation_end = Time.nanos()   
    //_metrics_reporter.step_metric(_computation_name,
    //  computation_start, computation_end)
    is_finished

  fun ref recovery_run[D: Any val](metric_name: String val, source_ts: U64, data: D,
    origin: Origin tag, msg_uid: U64, frac_ids: (Array[U64] val | None), seq_id: U64, incoming_envelope: MsgEnvelope val,
    router: (Router val | None) = None): Bool
  =>
    run[D](metric_name, source_ts, data, origin, msg_uid, frac_ids, seq_id, incoming_envelope,
      router)

class PreStateRunner[In: Any val, Out: Any val, State: Any #read] is Runner
  let _metrics_reporter: MetricsReporter
  let _output_router: Router val
  let _state_comp: StateComputation[In, Out, State] val
  let _name: String
  let _prep_name: String
  let _deduplication_list: Array[MsgEnvelope val]

  new iso create(state_comp: StateComputation[In, Out, State] val,
    router: Router val, metrics_reporter: MetricsReporter iso) 
  =>
    _metrics_reporter = consume metrics_reporter
    _output_router = router
    _state_comp = state_comp
    _name = _state_comp.name()
    _prep_name = _name + " prep"
    _deduplication_list = Array[MsgEnvelope val]

  fun ref run[D: Any val](metric_name: String val, source_ts: U64, data: D,
    origin: Origin tag, msg_uid: U64, frac_ids: (Array[U64] val | None), seq_id: U64, incoming_envelope: MsgEnvelope val,
    router: (Router val | None) = None): Bool
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
            source_ts, processor, origin, msg_uid, frac_ids, seq_id, incoming_envelope)
        else
          true
        end
      else
        @printf[I32]("PreStateRunner: Input was not a StateProcessor!\n".cstring())
        true
      end
    let computation_end = Time.nanos()
    //_metrics_reporter.step_metric(_prep_name, computation_start, 
    //  computation_end)
    is_finished

  fun ref recovery_run[D: Any val](metric_name: String val, source_ts: U64, data: D,
    origin: Origin tag, msg_uid: U64, frac_ids: (Array[U64] val | None), seq_id: U64, incoming_envelope: MsgEnvelope val,
    router: (Router val | None) = None): Bool
  =>
    if not is_duplicate_message(incoming_envelope) then
      _deduplication_list.push(incoming_envelope)
      run[D](metric_name, source_ts, data, origin, msg_uid, frac_ids, seq_id, incoming_envelope,
        router)
    else
      //we can pretend it stopped here because everything downstream know about
      //this
      true
    end

  fun is_duplicate_message(env: MsgEnvelope val): Bool =>
    for e in _deduplication_list.values() do
      //TODO: Bloom filter maybe?
      if e.msg_uid != env.msg_uid then
        continue
      else
        match (e.frac_ids, env.frac_ids)
        | (let efa: Array[U64] val, let efb: Array[U64] val) => 
          if efa.size() == efb.size() then
            var found = false
            for i in Range(0,efa.size()) do
              try
                if efa(i) != efb(i) then
                  found = false
                  break
                end
              else
                found = false
                break
              end
            end
            if found then
              return true
            end
          end
        | (None,None) => return true
        else
          continue
        end
      end
    end
    false

class StateRunner[State: Any #read] is Runner
  let _state: State
  let _metrics_reporter: MetricsReporter
  let _state_change_repository: StateChangeRepository[State] ref
  let _event_log_buffer: EventLogBuffer tag
  let _alfred: Alfred
  let _deduplication_list: Array[MsgEnvelope val]
  let _wb : Writer
  let _rb : Reader

  new iso create(state_builder: {(): State} val, 
      metrics_reporter: MetricsReporter iso, alfred: Alfred) 
  =>
    _state = state_builder()
    _metrics_reporter = consume metrics_reporter
    _state_change_repository = StateChangeRepository[State]
    _alfred = alfred
    _event_log_buffer =
      ifdef "resilience" then
        StandardEventLogBuffer(alfred)
      else
        DeactivatedEventLogBuffer
      end
    _deduplication_list = Array[MsgEnvelope val]
    _wb = Writer
    _rb = Reader

  fun ref register_state_change(scb: StateChangeBuilder[State] ref) : U64 =>
    _state_change_repository.make_and_register(scb)

  fun ref set_buffer_target(target: ResilientOrigin tag) =>
    _event_log_buffer.set_target(target)

  fun ref recovery_run[D: Any val](metric_name: String val, source_ts: U64, data: D,
    origin: Origin tag, msg_uid: U64, frac_ids: (Array[U64] val | None), seq_id: U64, incoming_envelope: MsgEnvelope val,
    router: (Router val | None) = None): Bool
  =>
    if not is_duplicate_message(incoming_envelope) then
      _deduplication_list.push(incoming_envelope)
      run[D](metric_name, source_ts, data, origin, msg_uid, frac_ids, seq_id, incoming_envelope,
        router)
    else
      //we can pretend it stopped here because everything downstream know about
      //this
      true
    end

  fun is_duplicate_message(env: MsgEnvelope val): Bool =>
    for e in _deduplication_list.values() do
      //TODO: Bloom filter maybe?
      if e.msg_uid != env.msg_uid then
        continue
      else
        match (e.frac_ids, env.frac_ids)
        | (let efa: Array[U64] val, let efb: Array[U64] val) => 
          if efa.size() == efb.size() then
            var found = false
            for i in Range(0,efa.size()) do
              try
                if efa(i) != efb(i) then
                  found = false
                  break
                end
              else
                found = false
                break
              end
            end
            if found then
              return true
            end
          end
        | (None,None) => return true
        else
          continue
        end
      end
    end
    false

  fun ref replay_log_entry(uid: U64, frac_ids: (Array[U64] val | None), statechange_id: U64, payload: Array[ByteSeq] val, origin: Origin tag) =>
    let me = recover val MsgEnvelope(origin, uid, frac_ids,0,0) end
    if not is_duplicate_message(me) then 
      _deduplication_list.push(me)
      try
        let sc = _state_change_repository(statechange_id)
        for e in payload.values() do
          _rb.append(e as Array[U8] val)
        end
        try
          sc.read_log_entry(_rb)
          sc.apply(_state)
        end
      else
        @printf[I32]("FATAL: could not look up state_change with id %d".cstring(),
          statechange_id)
      end
    end

  fun ref replay_finished() =>
    _deduplication_list.clear()
    None

  fun ref run[D: Any val](metric_name: String val, source_ts: U64, data: D,
    origin: Origin tag, msg_uid: U64, frac_ids: (Array[U64] val | None), seq_id: U64, incoming_envelope: MsgEnvelope val,
    router: (Router val | None) = None): Bool
  =>
    match data
    | let sp: StateProcessor[State] val =>
      let computation_start = Time.nanos()
      match sp(_state, _state_change_repository, metric_name, source_ts,
          origin, msg_uid, frac_ids, seq_id, incoming_envelope)
      | (let sc: StateChange[State] val, let is_finished: Bool) =>
        ifdef "resilience" then
          let payload = sc.to_log_entry(_wb)
          //TODO: deal with fractional message ids here
          _event_log_buffer.queue(msg_uid, None, sc.id(), payload)
        end
        sc.apply(_state)
        let computation_end = Time.nanos()
        //_metrics_reporter.step_metric(sp.name(), computation_start, computation_end)
        is_finished
      | let is_finished: Bool =>
        let computation_end = Time.nanos()
        //_metrics_reporter.step_metric(sp.name(), computation_start, computation_end)
        is_finished
      else
        @printf[I32]("StateRunner: StateProcessor did not return ((StateChange[State], Bool) | Bool)\n".cstring())
        true
      end
    else
      @printf[I32]("StateRunner: Input was not a StateProcessor!\n".cstring())
      true
    end

  fun rotate_log() =>
    //we need to be able to conflate all the current logs to a checkpoint and
    //rotate
    None

class iso RouterRunner is Runner

  fun ref run[D: Any val](metric_name: String val, source_ts: U64, data: D,
    origin: Origin tag, msg_uid: U64, frac_ids: (Array[U64] val | None), seq_id: U64, incoming_envelope: MsgEnvelope val,
    router: (Router val | None) = None): Bool
  =>
    match router
    | let r: Router val =>
      r.route[D](metric_name, source_ts, data, origin, msg_uid, frac_ids, seq_id,
      incoming_envelope)
      false
    else
      true
    end

  fun ref recovery_run[D: Any val](metric_name: String val, source_ts: U64, data: D,
    origin: Origin tag, msg_uid: U64, frac_ids: (Array[U64] val | None), seq_id: U64, incoming_envelope: MsgEnvelope val,
    router: (Router val | None) = None): Bool
  =>
    run[D](metric_name, source_ts, data, origin, msg_uid, frac_ids, seq_id, incoming_envelope,
      router)

class Proxy is Runner
  let _worker_name: String
  let _target_step_id: U128
  let _metrics_reporter: MetricsReporter
  let _auth: AmbientAuth
  let _deduplication_list: Array[MsgEnvelope val]

  new iso create(worker_name: String, target_step_id: U128, 
    metrics_reporter: MetricsReporter iso, auth: AmbientAuth) 
  =>
    _worker_name = worker_name
    _target_step_id = target_step_id
    _metrics_reporter = consume metrics_reporter
    _auth = auth
    _deduplication_list = Array[MsgEnvelope val]

  fun ref run[D: Any val](metric_name: String val, source_ts: U64, data: D,
    origin: Origin tag, msg_uid: U64, frac_ids: (Array[U64] val | None), seq_id: U64, incoming_envelope: MsgEnvelope val,
    router: (Router val | None) = None): Bool
  =>
    match router
    | let r: Router val =>
      try
        let forward_msg = ChannelMsgEncoder.data_channel[D](_target_step_id, 
          0, _worker_name, source_ts, data, metric_name, _auth)
        r.route[Array[ByteSeq] val](metric_name, source_ts, forward_msg,
        origin, msg_uid, frac_ids, seq_id, incoming_envelope)
        false
      else
        @printf[I32]("Problem encoding forwarded message\n".cstring())
        true
      end
    else
      true
    end
    // _metrics_reporter.worker_metric(metric_name, source_ts)  

  fun ref recovery_run[D: Any val](metric_name: String val, source_ts: U64, data: D,
    origin: Origin tag, msg_uid: U64, frac_ids: (Array[U64] val | None), seq_id: U64, incoming_envelope: MsgEnvelope val,
    router: (Router val | None) = None): Bool
  =>
    run[D](metric_name, source_ts, data, origin, msg_uid, frac_ids, seq_id, incoming_envelope,
      router)

