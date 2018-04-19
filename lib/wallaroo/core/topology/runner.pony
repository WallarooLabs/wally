/*

Copyright 2017 The Wallaroo Authors.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
 implied. See the License for the specific language governing
 permissions and limitations under the License.

*/

use "buffered"
use "collections"
use "crypto"
use "net"
use "time"
use "serialise"
use "wallaroo_labs/guid"
use "wallaroo_labs/time"
use "wallaroo_labs/weighted"
use "wallaroo/core/common"
use "wallaroo/ent/recovery"
use "wallaroo_labs/mort"
use "wallaroo/core/initialization"
use "wallaroo/core/invariant"
use "wallaroo/core/metrics"
use "wallaroo/core/routing"
use "wallaroo/core/state"


interface Runner
  // Return a Bool indicating whether the message is finished processing
  // and a U64 indicating the last timestamp for calculating the duration of
  // the computation
  fun ref run[D: Any val](metric_name: String, pipeline_time_spent: U64,
    data: D, producer_id: StepId, producer: Producer ref, router: Router,
    omni_router: OmniRouter,
    i_msg_uid: MsgId, frac_ids: FractionalMessageId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64,
    metrics_reporter: MetricsReporter ref): (Bool, U64)
  fun name(): String
  fun state_name(): String
  fun clone_router_and_set_input_type(r: Router): Router

interface SerializableStateRunner
  fun ref serialize_state(): ByteSeq val
  fun ref replace_serialized_state(s: ByteSeq val)

trait ReplayableRunner
  fun ref replay_log_entry(uid: U128, frac_ids: FractionalMessageId,
    statechange_id: U64, payload: ByteSeq val, producer: Producer)
  fun ref set_step_id(id: U128)

trait val RunnerBuilder
  fun apply(event_log: EventLog,
    auth: AmbientAuth,
    next_runner: (Runner iso | None) = None,
    router: (Router | None) = None,
    pre_state_target_ids': Array[StepId] val = recover Array[StepId] end):
      Runner iso^

  fun name(): String
  fun state_name(): String => ""
  fun is_prestate(): Bool => false
  fun is_stateful(): Bool
  fun is_stateless_parallel(): Bool => false
  fun is_multi(): Bool => false
  fun id(): StepId
  fun route_builder(): RouteBuilder
  fun forward_route_builder(): RouteBuilder
  fun in_route_builder(): (RouteBuilder | None) => None
  fun clone_router_and_set_input_type(r: Router): Router
  =>
    r

class val RunnerSequenceBuilder is RunnerBuilder
  let _runner_builders: Array[RunnerBuilder] val
  let _id: StepId
  var _forward_route_builder: RouteBuilder
  var _in_route_builder: (RouteBuilder | None)
  var _state_name: String
  let _parallelized: Bool

  new val create(bs: Array[RunnerBuilder] val,
    parallelized': Bool = false)
  =>
    _runner_builders = bs
    _id =
      try
        bs(0)?.id()
      else
        StepIdGenerator()
      end
    _forward_route_builder =
      try
        _runner_builders(_runner_builders.size() - 1)?.forward_route_builder()
      else
        BoundaryOnlyRouteBuilder
      end

    _in_route_builder =
      try
        _runner_builders(_runner_builders.size() - 1)?.in_route_builder()
      else
        None
      end

    _state_name =
      try
        _runner_builders(_runner_builders.size() - 1)?.state_name()
      else
        ""
      end

    _parallelized = parallelized'

  fun apply(event_log: EventLog,
    auth: AmbientAuth,
    next_runner: (Runner iso | None) = None,
    router: (Router | None) = None,
    pre_state_target_ids': Array[StepId] val = recover Array[StepId] end):
      Runner iso^
  =>
    var remaining: USize = _runner_builders.size()
    var latest_runner: Runner iso = RouterRunner
    while remaining > 0 do
      let next_builder: (RunnerBuilder | None) =
        try
          _runner_builders(remaining - 1)?
        else
          None
        end
      match next_builder
      | let rb: RunnerBuilder =>
        latest_runner = rb(event_log, auth,
          consume latest_runner, router, pre_state_target_ids')
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
  fun is_prestate(): Bool =>
    try
      _runner_builders(_runner_builders.size() - 1)?.is_prestate()
    else
      false
    end
  fun is_stateful(): Bool => false
  fun is_stateless_parallel(): Bool => _parallelized
  fun is_multi(): Bool =>
    try
      _runner_builders(_runner_builders.size() - 1)?.is_multi()
    else
      false
    end
  fun id(): StepId => _id
  fun route_builder(): RouteBuilder =>
    try
      _runner_builders(_runner_builders.size() - 1)?.route_builder()
    else
      BoundaryOnlyRouteBuilder
    end
  fun forward_route_builder(): RouteBuilder => _forward_route_builder
  fun in_route_builder(): (RouteBuilder | None) => _in_route_builder
  fun clone_router_and_set_input_type(r: Router): Router
  =>
    try
      _runner_builders(_runner_builders.size() - 1)?
        .clone_router_and_set_input_type(r)
    else
      r
    end

class val ComputationRunnerBuilder[In: Any val, Out: Any val] is RunnerBuilder
  let _comp_builder: ComputationBuilder[In, Out]
  let _id: U128
  let _route_builder: RouteBuilder
  let _parallelized: Bool

  new val create(comp_builder: ComputationBuilder[In, Out],
    route_builder': RouteBuilder, id': U128 = 0,
    parallelized': Bool = false)
  =>
    _comp_builder = comp_builder
    _route_builder = route_builder'
    _id = if id' == 0 then GuidGenerator.u128() else id' end
    _parallelized = parallelized'

  fun apply(event_log: EventLog,
    auth: AmbientAuth,
    next_runner: (Runner iso | None) = None,
    router: (Router | None) = None,
    pre_state_target_ids': Array[StepId] val = recover Array[StepId] end):
      Runner iso^
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
  fun is_stateless_parallel(): Bool => _parallelized
  fun id(): StepId => _id
  fun route_builder(): RouteBuilder => _route_builder
  fun forward_route_builder(): RouteBuilder => BoundaryOnlyRouteBuilder

class val PreStateRunnerBuilder[In: Any val, Out: Any val,
  PIn: Any val, Key: (Hashable val & Equatable[Key] val), S: State ref] is
    RunnerBuilder
  let _state_comp: StateComputation[In, Out, S] val
  let _state_name: String
  let _route_builder: RouteBuilder
  let _partition_function: PartitionFunction[PIn, Key] val
  let _forward_route_builder: RouteBuilder
  let _in_route_builder: (RouteBuilder | None)
  let _id: U128
  let _is_multi: Bool

  new val create(state_comp: StateComputation[In, Out, S] val,
    state_name': String,
    partition_function': PartitionFunction[PIn, Key] val,
    route_builder': RouteBuilder,
    forward_route_builder': RouteBuilder,
    in_route_builder': (RouteBuilder | None) = None,
    multi_worker: Bool = false)
  =>
    _state_comp = state_comp
    _state_name = state_name'
    _route_builder = route_builder'
    _partition_function = partition_function'
    _id = StepIdGenerator()
    _is_multi = multi_worker
    _forward_route_builder = forward_route_builder'
    _in_route_builder = in_route_builder'

  fun apply(event_log: EventLog,
    auth: AmbientAuth,
    next_runner: (Runner iso | None) = None,
    router: (Router | None) = None,
    pre_state_target_ids': Array[StepId] val = recover Array[StepId] end):
      Runner iso^
  =>
    PreStateRunner[In, Out, S](_state_comp, _state_name, pre_state_target_ids')

  fun name(): String => _state_comp.name()
  fun state_name(): String => _state_name
  fun is_prestate(): Bool => true
  fun is_stateful(): Bool => true
  fun is_multi(): Bool => _is_multi
  fun id(): StepId => _id
  fun route_builder(): RouteBuilder => _route_builder
  fun forward_route_builder(): RouteBuilder => _forward_route_builder
  fun in_route_builder(): (RouteBuilder | None) =>
    _in_route_builder
  fun clone_router_and_set_input_type(r: Router): Router
  =>
    match r
    | let p: AugmentablePartitionRouter[Key] val =>
      p.clone_and_set_input_type[PIn](_partition_function)
    else
      r
    end

class val StateRunnerBuilder[S: State ref] is RunnerBuilder
  let _state_builder: StateBuilder[S]
  let _state_name: String
  let _state_change_builders: Array[StateChangeBuilder[S]] val
  let _route_builder: RouteBuilder
  let _id: U128

  new val create(state_builder: StateBuilder[S],
    state_name': String,
    state_change_builders: Array[StateChangeBuilder[S]] val,
    route_builder': RouteBuilder = BoundaryOnlyRouteBuilder)
  =>
    _state_builder = state_builder
    _state_name = state_name'
    _state_change_builders = state_change_builders
    _route_builder = route_builder'
    _id = StepIdGenerator()

  fun apply(event_log: EventLog,
    auth: AmbientAuth,
    next_runner: (Runner iso | None) = None,
    router: (Router | None) = None,
    pre_state_target_ids': Array[StepId] val = recover Array[StepId] end):
      Runner iso^
  =>
    let sr = StateRunner[S](_state_builder, event_log, auth)
    for scb in _state_change_builders.values() do
      sr.register_state_change(scb)
    end
    sr

  fun name(): String => _state_name + " StateRunnerBuilder"
  fun state_name(): String => _state_name
  fun is_stateful(): Bool => true
  fun id(): StepId => _id
  fun route_builder(): RouteBuilder => _route_builder
  fun forward_route_builder(): RouteBuilder => BoundaryOnlyRouteBuilder

trait val PartitionBuilder
  // These two methods need to be deterministic at the moment since they
  // are called at different times
  fun state_subpartition(workers: (String | Array[String] val)):
    StateSubpartition
  fun partition_addresses(workers: (String | Array[String] val)):
    PartitionAddresses val
  fun state_name(): String
  fun is_multi(): Bool

class val PartitionedStateRunnerBuilder[PIn: Any val, S: State ref,
  Key: (Hashable val & Equatable[Key])] is (PartitionBuilder & RunnerBuilder)
  let _pipeline_name: String
  let _state_name: String
  let _state_runner_builder: StateRunnerBuilder[S] val
  let _step_id_map: Map[Key, U128] val
  let _partition: Partition[PIn, Key] val
  let _route_builder: RouteBuilder
  let _forward_route_builder: RouteBuilder
  let _id: U128
  let _multi_worker: Bool

  new val create(pipeline_name: String, state_name': String,
    step_id_map': Map[Key, U128] val, partition': Partition[PIn, Key] val,
    state_runner_builder: StateRunnerBuilder[S] val,
    route_builder': RouteBuilder,
    forward_route_builder': RouteBuilder, id': U128 = 0,
    multi_worker: Bool = false)
  =>
    _id = if id' == 0 then StepIdGenerator() else id' end
    _state_name = state_name'
    _pipeline_name = pipeline_name
    _state_runner_builder = state_runner_builder
    _step_id_map = step_id_map'
    _partition = partition'
    _route_builder = route_builder'
    _forward_route_builder = forward_route_builder'
    _multi_worker = multi_worker

  fun apply(event_log: EventLog,
    auth: AmbientAuth,
    next_runner: (Runner iso | None) = None,
    router: (Router | None) = None,
    pre_state_target_ids': Array[StepId] val = recover Array[StepId] end):
      Runner iso^
  =>
    _state_runner_builder(event_log, auth, consume next_runner, router)

  fun name(): String => _state_name
  fun state_name(): String => _state_name
  fun is_stateful(): Bool => true
  fun id(): StepId => _id
  fun step_id_map(): Map[Key, U128] val => _step_id_map
  fun route_builder(): RouteBuilder => _route_builder
  fun forward_route_builder(): RouteBuilder => _forward_route_builder
  fun is_multi(): Bool => _multi_worker

  fun state_subpartition(workers: (String | Array[String] val)):
    StateSubpartition
  =>
    KeyedStateSubpartition[PIn, Key, S](_state_name,
      partition_addresses(workers), _step_id_map, _state_runner_builder,
      _partition.function(), _pipeline_name)

  fun partition_addresses(workers: (String | Array[String] val)):
    KeyedPartitionAddresses[Key] val
  =>
    let m = recover trn Map[Key, ProxyAddress] end
    let hash_partitions = HashPartitions(match workers
      | let w: String => recover val [w] end
      | let ws: Array[String] val => ws
      end)

    match workers
    | let w: String =>
      // With one worker, all the keys go on that worker
      match _partition.keys()
      | let wks: Array[WeightedKey[Key]] val =>
        for wkey in wks.values() do
          try
            m(wkey._1) = ProxyAddress(w, _step_id_map(wkey._1)?)
          end
        end
      | let ks: Array[Key] val =>
        for key in ks.values() do
          try
            m(key) = ProxyAddress(w, _step_id_map(key)?)
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
          let buckets = Weighted[Key](wks, ws.size())?
          for worker_idx in Range(0, buckets.size()) do
            for key in buckets(worker_idx)?.values() do
              m(key) = ProxyAddress(ws(worker_idx)?, _step_id_map(key)?)
            end
          end
        end
      | let ks: Array[Key] val =>
        // With unweighted keys, we simply distribute the keys equally across
        // the workers
        for key in ks.values() do
          try
            m(key) = ProxyAddress(ws(idx)?, _step_id_map(key)?)
          end
          idx = (idx + 1) % w_count
        end
      end
    end

    KeyedPartitionAddresses[Key](consume m, hash_partitions)

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
    data: D, producer_id: StepId, producer: Producer ref, router: Router,
    omni_router: OmniRouter,
    i_msg_uid: MsgId, frac_ids: FractionalMessageId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64,
    metrics_reporter: MetricsReporter ref): (Bool, U64)
  =>
    var computation_start: U64 = 0
    var computation_end: U64 = 0

    (let is_finished, let last_ts) =
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
        | None => (true, computation_end)
        | let output: Out =>
          _next.run[Out](metric_name, pipeline_time_spent, output, producer_id,
            producer, router, omni_router,
            i_msg_uid, frac_ids,
            computation_end, new_metrics_id, worker_ingress_ts,
            metrics_reporter)
        | let outputs: Array[Out] val =>
          var this_is_finished = true
          var this_last_ts = computation_end

          for (frac_id, output) in outputs.pairs() do
            let o_frac_ids = match frac_ids
            | None =>
              recover val
                Array[U32].init(frac_id.u32(), 1)
              end
            | let x: Array[U32 val] val =>
              recover val
                let z = Array[U32](x.size() + 1)
                for xi in x.values() do
                  z.push(xi)
                end
                z.push(frac_id.u32())
                z
              end
            end

            (let f, let ts) = _next.run[Out](metric_name,
              pipeline_time_spent, output, producer_id, producer,
              router, omni_router,
              i_msg_uid, o_frac_ids,
              computation_end, new_metrics_id, worker_ingress_ts,
              metrics_reporter)

            // we are sending multiple messages, only mark this message as
            // finished if all are finished
            if (f == false) then
              this_is_finished = false
            end

            this_last_ts = ts
          end
          (this_is_finished, this_last_ts)
        end
      else
        (true, latest_ts)
      end

    let latest_metrics_id = ifdef "detailed-metrics" then
        metrics_reporter.step_metric(metric_name, _computation_name,
          metrics_id, latest_ts, computation_start where prefix = "Before")
        metrics_id + 1
      else
        metrics_id
      end

    metrics_reporter.step_metric(metric_name, _computation_name,
      latest_metrics_id, computation_start, computation_end)

    (is_finished, last_ts)

  fun name(): String => _computation.name()
  fun state_name(): String => ""
  fun clone_router_and_set_input_type(r: Router): Router
  =>
    _next.clone_router_and_set_input_type(r)

class PreStateRunner[In: Any val, Out: Any val, S: State ref]
  let _target_ids: Array[StepId] val
  let _state_comp: StateComputation[In, Out, S] val
  let _name: String
  let _prep_name: String
  let _state_name: String

  new iso create(state_comp: StateComputation[In, Out, S] val,
    state_name': String, target_ids: Array[StepId] val)
  =>
    _target_ids = target_ids
    _state_comp = state_comp
    _name = _state_comp.name()
    _prep_name = _name + " prep"
    _state_name = state_name'

  fun ref run[D: Any val](metric_name: String, pipeline_time_spent: U64,
    data: D, producer_id: StepId, producer: Producer ref, router: Router,
    omni_router: OmniRouter,
    i_msg_uid: MsgId, frac_ids: FractionalMessageId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64,
    metrics_reporter: MetricsReporter ref): (Bool, U64)
  =>
    let wrapper_creation_start_ts =
      ifdef "detailed_metrics" then
        Time.nanos()
      else
        0
      end
    (let is_finished, let last_ts) =
      match data
      | let input: In =>
        match router
        | let shared_state_router: Router =>
          let processor: StateComputationWrapper[In, Out, S] =
            StateComputationWrapper[In, Out, S](input, _state_comp,
              _target_ids)
          shared_state_router.route[StateComputationWrapper[In, Out, S]](
            metric_name, pipeline_time_spent, processor, producer_id, producer,
            i_msg_uid, frac_ids, latest_ts, metrics_id + 1,
            worker_ingress_ts)
        end
      else
        @printf[I32]("StateRunner: Input was not a StateProcessor!\n"
          .cstring())
        (true, latest_ts)
      end
    ifdef "detailed-metrics" then
      ifdef debug then
        Invariant(wrapper_creation_start_ts != 0)
      end
      let wrapper_creation_end_ts = Time.nanos()
      metrics_reporter.step_metric(metric_name, _name, metrics_id,
        wrapper_creation_start_ts, wrapper_creation_end_ts
        where prefix = "Pre:")
    end
    (is_finished, last_ts)

  fun name(): String => _name
  fun state_name(): String => _state_name
  fun is_pre_state(): Bool => true
  fun clone_router_and_set_input_type(r: Router): Router
  =>
    r

class StateRunner[S: State ref] is (Runner & ReplayableRunner &
  SerializableStateRunner)
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

  fun ref register_state_change(scb: StateChangeBuilder[S]) : U64 =>
    _state_change_repository.make_and_register(scb)

  fun ref replay_log_entry(msg_uid: MsgId, frac_ids: FractionalMessageId,
    statechange_id: U64, payload: ByteSeq val, producer: Producer)
  =>
    if statechange_id == U64.max_value() then
      replace_serialized_state(payload)
    else
      try
        let sc = _state_change_repository(statechange_id)?
        _rb.append(payload as Array[U8] val)
        try
          sc.read_log_entry(_rb)?
          sc.apply(_state)
        end
      else
        @printf[I32]("FATAL: could not look up state_change with id %d"
          .cstring(), statechange_id)
      end
    end

  fun ref run[D: Any val](metric_name: String, pipeline_time_spent: U64,
    data: D, producer_id: StepId, producer: Producer ref, router: Router,
    omni_router: OmniRouter,
    i_msg_uid: MsgId, frac_ids: FractionalMessageId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64,
    metrics_reporter: MetricsReporter ref): (Bool, U64)
  =>
    match data
    | let sp: StateProcessor[S] =>
      let new_metrics_id = ifdef "detailed-metrics" then
          // increment by 2 because we'll be reporting 2 step metrics below
          metrics_id + 2
        else
          // increment by 1 because we'll be reporting 1 step metrics below
          metrics_id + 1
        end

      let result = sp(_state, _state_change_repository, omni_router,
        metric_name, pipeline_time_spent, producer_id, producer,
        i_msg_uid, frac_ids, latest_ts, new_metrics_id, worker_ingress_ts)
      let is_finished = result._1
      let state_change = result._2
      let sc_start_ts = result._3
      let sc_end_ts = result._4
      let last_ts = result._5

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
            _event_log.queue_log_entry(buffer_id, i_msg_uid, frac_ids,
              sc.id(), producer.current_sequence_id(), consume payload)
          else
            @printf[I32]("StateRunner with unassigned EventLogBuffer!"
              .cstring())
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
            _event_log.queue_log_entry(buffer_id, i_msg_uid, frac_ids,
              U64.max_value(), producer.current_sequence_id(), consume payload)
          end
        end
      end

      (is_finished, last_ts)
    else
      @printf[I32]("StateRunner: Input was not a StateProcessor!\n".cstring())
      (true, latest_ts)
    end

  fun rotate_log() =>
    //we need to be able to conflate all the current logs to a checkpoint and
    //rotate
    None

  fun name(): String => "State runner"
  fun state_name(): String => ""
  fun clone_router_and_set_input_type(r: Router): Router =>
    r

  fun ref serialize_state(): ByteSeq val =>
    try
      Serialised(SerialiseAuth(_auth), _state)?
        .output(OutputSerialisedAuth(_auth))
    else
      Fail()
      recover val Array[U8] end
    end

  fun ref replace_serialized_state(payload: ByteSeq val) =>
    try
      _rb.append(payload as Array[U8] val)
      match _state.read_log_entry(_rb, _auth)?
      | let s: S =>
        _state = s
      else
        Fail()
      end
    else
      Fail()
    end

class iso RouterRunner
  fun ref run[D: Any val](metric_name: String, pipeline_time_spent: U64,
    data: D, producer_id: StepId, producer: Producer ref, router: Router,
    omni_router: OmniRouter,
    i_msg_uid: MsgId, frac_ids: FractionalMessageId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64,
    metrics_reporter: MetricsReporter ref): (Bool, U64)
  =>
    match router
    | let r: Router =>
      r.route[D](metric_name, pipeline_time_spent, data, producer_id,
        producer, i_msg_uid, frac_ids, latest_ts, metrics_id,
        worker_ingress_ts)
    end

  fun name(): String => "Router runner"
  fun state_name(): String => ""
  fun clone_router_and_set_input_type(r: Router): Router =>
    r
