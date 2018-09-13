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
    data: D, producer_id: RoutingId, producer: Producer ref, router: Router,
    target_id_router: TargetIdRouter,
    i_msg_uid: MsgId, frac_ids: FractionalMessageId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64,
    metrics_reporter: MetricsReporter ref): (Bool, U64)
  fun name(): String
  fun state_name(): StateName
  // TODO: We no longer need to set the input type, so this and related code
  // can be simplified.
  fun clone_router_and_set_input_type(r: Router): Router

interface SerializableStateRunner
  fun ref import_key_state(step: Step ref, s_name: StateName, key: Key,
    s: ByteSeq val)
  fun ref export_key_state(step: Step ref, key: Key): ByteSeq val
  fun ref serialize_state(): ByteSeq val
  fun ref replace_serialized_state(s: ByteSeq val)

trait RollbackableRunner
  fun ref rollback(payload: ByteSeq val)
  fun ref set_step_id(id: U128)

trait val RunnerBuilder
  fun apply(event_log: EventLog,
    auth: AmbientAuth,
    next_runner: (Runner iso | None) = None,
    router: (Router | None) = None,
    pre_state_target_ids': Array[RoutingId] val = recover Array[RoutingId] end):
      Runner iso^

  fun name(): String
  fun state_name(): StateName => ""
  fun is_prestate(): Bool => false
  fun is_stateful(): Bool
  fun is_stateless_parallel(): Bool => false
  fun is_multi(): Bool => false
  fun id(): RoutingId
  fun clone_router_and_set_input_type(r: Router): Router
  =>
    r

class val RunnerSequenceBuilder is RunnerBuilder
  let _runner_builders: Array[RunnerBuilder] val
  let _id: RoutingId
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
        RoutingIdGenerator()
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
    pre_state_target_ids': Array[RoutingId] val = recover Array[RoutingId] end):
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

  fun state_name(): StateName => _state_name
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
  fun id(): RoutingId => _id
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
  let _parallelized: Bool

  new val create(comp_builder: ComputationBuilder[In, Out], id': RoutingId = 0,
    parallelized': Bool = false)
  =>
    _comp_builder = comp_builder
    _id = if id' == 0 then GuidGenerator.u128() else id' end
    _parallelized = parallelized'

  fun apply(event_log: EventLog,
    auth: AmbientAuth,
    next_runner: (Runner iso | None) = None,
    router: (Router | None) = None,
    pre_state_target_ids': Array[RoutingId] val = recover Array[RoutingId] end):
      Runner iso^
  =>
    match (consume next_runner)
    | let r: Runner iso =>
      ComputationRunner[In, Out](_comp_builder(), consume r)
    else
      ComputationRunner[In, Out](_comp_builder(), RouterRunner)
    end

  fun name(): String => _comp_builder().name()
  fun state_name(): StateName => ""
  fun is_stateful(): Bool => false
  fun is_stateless_parallel(): Bool => _parallelized
  fun id(): RoutingId => _id

class val PreStateRunnerBuilder[In: Any val, Out: Any val,
  S: State ref] is RunnerBuilder
  let _state_comp: StateComputation[In, Out, S] val
  let _state_name: String
  let _partition_function: PartitionFunction[In] val
  let _id: RoutingId
  let _is_multi: Bool

  new val create(state_comp: StateComputation[In, Out, S] val,
    state_name': String, partition_function': PartitionFunction[In] val,
    multi_worker: Bool = false)
  =>
    _state_comp = state_comp
    _state_name = state_name'
    _partition_function = partition_function'
    _id = RoutingIdGenerator()
    _is_multi = multi_worker

  fun apply(event_log: EventLog,
    auth: AmbientAuth,
    next_runner: (Runner iso | None) = None,
    router: (Router | None) = None,
    pre_state_target_ids': Array[RoutingId] val = recover Array[RoutingId] end):
      Runner iso^
  =>
    PreStateRunner[In, Out, S](_state_comp, _state_name, _partition_function,
      pre_state_target_ids')

  fun name(): String => _state_comp.name()
  fun state_name(): StateName => _state_name
  fun is_prestate(): Bool => true
  fun is_stateful(): Bool => true
  fun is_multi(): Bool => _is_multi
  fun id(): RoutingId => _id
  fun clone_router_and_set_input_type(r: Router): Router
  =>
    r

class val StateRunnerBuilder[S: State ref] is RunnerBuilder
  // This is the id for the entire state collection. It's used, for example,
  // to route messages to a Key that exists on another worker where we don't
  // know the specific routing ids of the state steps.
  let _id: RoutingId
  let _state_builder: StateBuilder[S]
  let _state_name: String
  let _state_change_builders: Array[StateChangeBuilder[S]] val

  new val create(state_builder: StateBuilder[S],
    state_name': String,
    state_change_builders: Array[StateChangeBuilder[S]] val)
  =>
    _state_builder = state_builder
    _state_name = state_name'
    _state_change_builders = state_change_builders
    _id = RoutingIdGenerator()

  fun apply(event_log: EventLog,
    auth: AmbientAuth,
    next_runner: (Runner iso | None) = None,
    router: (Router | None) = None,
    pre_state_target_ids': Array[RoutingId] val = recover Array[RoutingId] end):
      Runner iso^
  =>
    let sr = StateRunner[S](_state_name, _state_builder, event_log, auth)
    for scb in _state_change_builders.values() do
      sr.register_state_change(scb)
    end
    sr

  fun name(): String => _state_name + " StateRunnerBuilder"
  fun state_name(): StateName => _state_name
  fun is_stateful(): Bool => true
  fun id(): RoutingId => _id

trait val PartitionsBuilder
  // These two methods need to be deterministic at the moment since they
  // are called at different times
  fun state_subpartition(workers: (String | Array[String] val)):
    StateSubpartitions
  fun key_distribution(workers: (String | Array[String] val)):
    KeyDistribution
  fun state_name(): StateName
  fun per_worker_parallelism(): USize
  fun is_multi(): Bool

class val PartitionedStateRunnerBuilder[In: Any val, S: State ref] is
  (PartitionsBuilder & RunnerBuilder)
  let _state_id: RoutingId
  let _pipeline_name: String
  let _state_name: String
  let _state_runner_builder: StateRunnerBuilder[S] val
  let _step_id_map: Map[Key, RoutingId] val
  let _partition: Partitions[In] val
  let _per_worker_parallelism: USize
  let _multi_worker: Bool

  new val create(pipeline_name: String, state_name': String,
    step_id_map': Map[Key, RoutingId] val, partition': Partitions[In] val,
    state_runner_builder: StateRunnerBuilder[S] val,
    per_worker_parallelism': USize, multi_worker: Bool = false)
  =>
    _state_id = RoutingIdGenerator()
    _state_name = state_name'
    _pipeline_name = pipeline_name
    _state_runner_builder = state_runner_builder
    _step_id_map = step_id_map'
    _partition = partition'
    _per_worker_parallelism = per_worker_parallelism'
    _multi_worker = multi_worker

  fun apply(event_log: EventLog,
    auth: AmbientAuth,
    next_runner: (Runner iso | None) = None,
    router: (Router | None) = None,
    pre_state_target_ids': Array[RoutingId] val = recover Array[RoutingId] end):
      Runner iso^
  =>
    _state_runner_builder(event_log, auth, consume next_runner, router)

  fun name(): String => _state_name
  fun state_name(): StateName => _state_name
  fun is_stateful(): Bool => true
  fun id(): RoutingId => _state_id
  fun step_id_map(): Map[Key, U128] val => _step_id_map
  fun per_worker_parallelism(): USize => _per_worker_parallelism
  fun is_multi(): Bool => _multi_worker

  fun state_subpartition(workers: (String | Array[String] val)):
    StateSubpartitions
  =>
    KeyedStateSubpartitions[S](_state_name, _per_worker_parallelism,
      key_distribution(workers), _step_id_map, _state_runner_builder,
      _pipeline_name)

  fun key_distribution(workers: (String | Array[String] val)):
    KeyDistribution
  =>
    let wtk = Map[String, Array[Key]]

    let hash_partitions = HashPartitions(match workers
      | let w: String =>
        wtk(w) = Array[Key]
        recover val [w] end
      | let ws: Array[String] val =>
        for w in ws.values() do
          wtk(w) = Array[Key]
        end
        ws
      end)
    let workers_to_keys = recover trn Map[String, Array[Key] val] end

    try
      for key in _partition.keys().values() do
        let w = hash_partitions.get_claimant_by_key(key)?
        wtk.upsert(w, recover trn [key] end,
          {(x, y) => x.>append(y)})?
      end

      for (w, ks') in wtk.pairs() do
        let a = recover trn Array[Key] end
        for k in ks'.values() do
          a.push(k)
        end
        workers_to_keys(w) = consume a
      end
    else
      Unreachable()
    end

    KeyDistribution(hash_partitions, consume workers_to_keys)

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
    data: D, producer_id: RoutingId, producer: Producer ref, router: Router,
    target_id_router: TargetIdRouter,
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
            producer, router, target_id_router,
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
              router, target_id_router,
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
        @printf[I32]("ComputationRunner: Input was not correct type!\n"
          .cstring())
        Fail()
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
  fun state_name(): StateName => ""
  fun clone_router_and_set_input_type(r: Router): Router
  =>
    _next.clone_router_and_set_input_type(r)

class PreStateRunner[In: Any val, Out: Any val, S: State ref]
  let _target_ids: Array[RoutingId] val
  let _state_comp: StateComputation[In, Out, S] val
  let _partition_function: PartitionFunction[In] val
  let _name: String
  let _prep_name: String
  let _state_name: StateName

  new iso create(state_comp: StateComputation[In, Out, S] val,
    state_name': String, partition_function: PartitionFunction[In] val,
    target_ids: Array[RoutingId] val)
  =>
    _target_ids = target_ids
    _state_comp = state_comp
    _name = _state_comp.name()
    _prep_name = _name + " prep"
    _state_name = state_name'
    _partition_function = partition_function

  fun ref run[D: Any val](metric_name: String, pipeline_time_spent: U64,
    data: D, producer_id: RoutingId, producer: Producer ref, router: Router,
    target_id_router: TargetIdRouter,
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
        let key = _partition_function(input)
        let processor: StateComputationWrapper[In, Out, S] =
          StateComputationWrapper[In, Out, S](input, _state_name, key,
            _state_comp, _target_ids)
        router.route[StateComputationWrapper[In, Out, S]](
          metric_name, pipeline_time_spent, processor, producer_id, producer,
          i_msg_uid, frac_ids, latest_ts, metrics_id + 1,
          worker_ingress_ts)
      else
        @printf[I32]("StateRunner: Input was not type In!\n"
          .cstring())
        Fail()
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
  fun state_name(): StateName => _state_name
  fun is_pre_state(): Bool => true
  fun clone_router_and_set_input_type(r: Router): Router
  =>
    r

class StateRunner[S: State ref] is (Runner & RollbackableRunner &
  SerializableStateRunner)
  let _canonical_state: S
  let _state_name: StateName
  var _state_map: Map[Key, S] = _state_map.create()
  let _state_builder: {(): S} val
  //TODO: this needs to be per-computation, rather than per-runner
  let _state_change_repository: StateChangeRepository[S] ref
  let _event_log: EventLog
  let _wb: Writer = Writer
  let _rb: Reader = Reader
  let _auth: AmbientAuth
  var _id: (U128 | None)

  new iso create(state_name': StateName, state_builder: {(): S} val,
    event_log: EventLog, auth: AmbientAuth)
  =>
    _state_name = state_name'
    _state_builder = state_builder
    _canonical_state = _state_builder()
    _state_change_repository = StateChangeRepository[S]
    _event_log = event_log
    _id = None
    _auth = auth

  fun ref set_step_id(id: U128) =>
    _id = id

  fun ref register_state_change(scb: StateChangeBuilder[S]) : U64 =>
    _state_change_repository.make_and_register(scb)

  fun ref rollback(payload: ByteSeq val) =>
    replace_serialized_state(payload)

  fun ref run[D: Any val](metric_name: String, pipeline_time_spent: U64,
    data: D, producer_id: RoutingId, producer: Producer ref, router: Router,
    target_id_router: TargetIdRouter,
    i_msg_uid: MsgId, frac_ids: FractionalMessageId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64,
    metrics_reporter: MetricsReporter ref): (Bool, U64)
  =>
    match data
    | let sp: StateProcessor[S] =>
      let key = sp.key()
      let state =
        try
          _state_map(key)?
        else
          match producer
          | let s: Step ref =>
            s.register_key(sp.state_name(), key)
          else
            Fail()
          end
          let new_state = _state_builder()
          _state_map(key) = new_state
          new_state
        end

      let new_metrics_id = ifdef "detailed-metrics" then
          // increment by 2 because we'll be reporting 2 step metrics below
          metrics_id + 2
        else
          // increment by 1 because we'll be reporting 1 step metrics below
          metrics_id + 1
        end

      let result = sp(state, _state_change_repository, target_id_router,
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

      // TODO: This applies the state change but doesn't write it to disk since
      // that's not currently supported with our new recovery protocol. Either
      // remove the StateChange from API or implement this feature.
      match state_change
      | let sc: StateChange[S] ref =>
        sc.apply(state)
      | let dsc: DirectStateChange =>
        None
      end

      (is_finished, last_ts)
    else
      @printf[I32]("StateRunner: Input was not a StateProcessor!\n".cstring())
      Fail()
      (true, latest_ts)
    end

  fun rotate_log() =>
    //we need to be able to conflate all the current logs to a checkpoint and
    //rotate
    None

  fun name(): String => "State runner"
  fun state_name(): StateName => _state_name
  fun clone_router_and_set_input_type(r: Router): Router =>
    r

  fun ref import_key_state(step: Step ref, s_name: StateName, key: Key,
    s: ByteSeq val)
  =>
    @printf[I32]("!@ Importing key state for <%s: %s>, size: %s\n".cstring(), s_name.cstring(), key.cstring(), s.size().string().cstring())
    ifdef debug then
      Invariant(s_name == _state_name)
    end
    if s.size() > 0 then
      try
        @printf[I32]("!@ _rb should be empty. Has %s bytes\n".cstring(), _rb.size().string().cstring())
        _rb.append(s as Array[U8] val)
        //!@
        // reader.append(_rb.block(s.size()))?
        match _canonical_state.read_log_entry(_rb, _auth)?
        | let state: S =>
          //!@
          match state
          | let st: Stringablike =>
            // try
              // match _state_map(s_name)?
              // | let st2: Stringablike =>
                (let sec', let ns') = Time.now()
                let us' = ns' / 1000
                let ts' = PosixDate(sec', ns').format("%Y-%m-%d %H:%M:%S." + us'.string())
                @printf[I32]("!@ DESERIALIZE (%s): loading new %s on step %s with tag %s\n".cstring(), ts'.cstring(), st.string().cstring(), _id.string().cstring(), (digestof this).string().cstring())
              // end
            // end
          end

          @printf[I32]("!@ Successfully imported key %s\n".cstring(), key.cstring())
          _state_map(key) = state
          step.register_key(s_name, key)
        else
          Fail()
        end
      else
        Fail()
      end
    else
      // We got the key but no accompanying state, so we initialize
      // ourselves.
      _state_map(key) = _state_builder()
      step.register_key(s_name, key)
    end

  fun ref export_key_state(step: Step ref, key: Key): ByteSeq val =>
    step.unregister_key(_state_name, key)
    try
      @printf[I32]("!@ exporting key %s\n".cstring(), key.cstring())
      let state =
        try
          _state_map.remove(key)?._2
        else
          _state_builder()
        end
      @printf[I32]("!@ removed state for %s\n".cstring(), key.cstring())
      Serialised(SerialiseAuth(_auth), state)?
        .output(OutputSerialisedAuth(_auth))
    else
      Fail()
      recover Array[U8] end
    end

  fun ref serialize_state(): ByteSeq val =>
    try
      let bytes = recover iso Array[U8] end
      @printf[I32]("!@ serialize_state: state_map is %s size\n".cstring(), _state_map.size().string().cstring())
      for (k, state) in _state_map.pairs() do
        //!@
        match state
        | let s: Stringablike =>
          (let sec', let ns') = Time.now()
          let us' = ns' / 1000
          let ts' = PosixDate(sec', ns').format("%Y-%m-%d %H:%M:%S." +
            us'.string())
          @printf[I32]("!@ SERIALIZE (%s): %s on step %s with tag %s\n".cstring(), ts'.cstring(), s.string().cstring(), _id.string().cstring(), (digestof this).string().cstring())
        end
        @printf[I32]("!@ SERIALIZING KEY %s\n".cstring(), k.cstring())

        let key_size = k.size()
        _wb.u32_be(key_size.u32())
        _wb.write(k)
        let s_bytes = Serialised(SerialiseAuth(_auth), state)?
          .output(OutputSerialisedAuth(_auth))
        _wb.u32_be(s_bytes.size().u32())
        _wb.write(s_bytes)
        @printf[I32]("!@ Wrote %s key bytes and %s state bytes\n".cstring(), key_size.string().cstring(), s_bytes.size().string().cstring())
      end
      for bs in _wb.done().values() do
        match bs
        | let s: String =>
          bytes.append(s)
        | let a: Array[U8] val =>
          for b in a.values() do
            bytes.push(b)
          end
        end
      end
      consume bytes
    else
      Fail()
      recover val Array[U8] end
    end

  fun ref replace_serialized_state(payload: ByteSeq val) =>
    _state_map.clear()
    try
      let reader: Reader ref = Reader
      var bytes_left: USize = payload.size()
      _rb.append(payload as Array[U8] val)
      @printf[I32]("!@ -- Preparing to read %s bytes for payload\n".cstring(), bytes_left.string().cstring())
      while bytes_left > 0 do
        let key_size = _rb.u32_be()?.usize()
        bytes_left = bytes_left - 4
        let key = String.from_array(_rb.block(key_size)?)
        bytes_left = bytes_left - key_size
        let state_size = _rb.u32_be()?.usize()
        bytes_left = bytes_left - 4
        reader.append(_rb.block(state_size)?)
        bytes_left = bytes_left - state_size
        match _canonical_state.read_log_entry(reader, _auth)?
        | let state: S =>
          //!@
          // try
            match state
            | let st: Stringablike =>
              (let sec', let ns') = Time.now()
              let us' = ns' / 1000
              let ts' = PosixDate(sec', ns').format("%Y-%m-%d %H:%M:%S." +
                us'.string())
              @printf[I32]("!@ DESERIALIZE (%s): loading new state %s on step %s with tag %s\n".cstring(), ts'.cstring(), st.string().cstring(), _id.string().cstring(), (digestof this).string().cstring())
            end
          // end

          @printf[I32]("!@ OVERWRITING STATE FOR KEY %s\n".cstring(), key.cstring())
          _state_map(key) = state
        else
          Fail()
        end
      end
    else
      Fail()
    end

//!@
interface Stringablike
  fun string(): String

class iso RouterRunner
  fun ref run[D: Any val](metric_name: String, pipeline_time_spent: U64,
    data: D, producer_id: RoutingId, producer: Producer ref, router: Router,
    target_id_router: TargetIdRouter,
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
  fun state_name(): StateName => ""
  fun clone_router_and_set_input_type(r: Router): Router =>
    r
