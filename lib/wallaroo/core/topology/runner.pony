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
use "wallaroo/core/common"
use "wallaroo/core/partitioning"
use "wallaroo/core/initialization"
use "wallaroo/core/invariant"
use "wallaroo/core/metrics"
use "wallaroo/core/routing"
use "wallaroo/core/state"
use "wallaroo/core/windows"
use "wallaroo/ent/recovery"
use "wallaroo_labs/guid"
use "wallaroo_labs/mort"
use "wallaroo_labs/time"


trait Runner
  // Return a Bool indicating whether the message is finished processing
  // and a U64 indicating the last timestamp for calculating the duration of
  // the computation
  fun ref run[D: Any val](metric_name: String, pipeline_time_spent: U64,
    data: D, key: Key, event_ts: U64, watermark_ts: U64,
    producer_id: RoutingId, producer: Producer ref, router: Router,
    i_msg_uid: MsgId, frac_ids: FractionalMessageId, latest_ts: U64,
    metrics_id: U16, worker_ingress_ts: U64,
    metrics_reporter: MetricsReporter ref): (Bool, U64)
  fun name(): String

trait SerializableStateRunner
  fun ref import_key_state(step: Step ref, s_group: RoutingId, key: Key,
    s: ByteSeq val)
  fun ref export_key_state(step: Step ref, key: Key): ByteSeq val
  fun ref serialize_state(): ByteSeq val
  fun ref replace_serialized_state(s: ByteSeq val)

trait RollbackableRunner
  fun ref rollback(payload: ByteSeq val)
  fun ref set_step_id(id: U128)

trait val RunnerBuilder
  fun apply(event_log: EventLog, auth: AmbientAuth,
    next_runner: (Runner iso | None) = None,
    router: (Router | None) = None,
    partitioner_builder: PartitionerBuilder = PassthroughPartitionerBuilder):
    Runner iso^

  fun name(): String
  fun routing_group(): RoutingId
  fun parallelism(): USize
  fun is_prestate(): Bool => false
  fun is_stateful(): Bool
  fun is_multi(): Bool => false

class val RunnerSequenceBuilder is RunnerBuilder
  let _runner_builders: Array[RunnerBuilder] val
  let _routing_group: RoutingId
  let _parallelism: USize

  new val create(bs: Array[RunnerBuilder] val, parallelism': USize) =>
    _runner_builders = bs
    _routing_group =
      try
        _runner_builders(0)?.routing_group()
      else
        0
      end
    _parallelism = parallelism'

  fun apply(event_log: EventLog,
    auth: AmbientAuth,
    next_runner: (Runner iso | None) = None,
    router: (Router | None) = None,
    partitioner_builder: PartitionerBuilder = PassthroughPartitionerBuilder):
    Runner iso^
  =>
    var remaining: USize = _runner_builders.size()
    var latest_runner: Runner iso = RouterRunner(partitioner_builder)
    while remaining > 0 do
      let next_builder: (RunnerBuilder | None) =
        try
          _runner_builders(remaining - 1)?
        else
          None
        end
      match next_builder
      | let rb: RunnerBuilder =>
        latest_runner = rb(event_log, auth, consume latest_runner, router)
      end
      remaining = remaining - 1
    end
    consume latest_runner

  fun name(): String =>
    if _runner_builders.size() == 1 then
      try _runner_builders(0)?.name() else Unreachable(); "" end
    else
      var n = ""
      for r in _runner_builders.values() do
        n = n + "|" + r.name()
      end
      n + "|"
    end

  fun routing_group(): RoutingId =>
    _routing_group
  fun parallelism(): USize => _parallelism
  fun is_prestate(): Bool =>
    try
      _runner_builders(_runner_builders.size() - 1)?.is_prestate()
    else
      false
    end
  fun is_stateful(): Bool => false
  fun is_multi(): Bool =>
    try
      _runner_builders(_runner_builders.size() - 1)?.is_multi()
    else
      false
    end

class val StatelessComputationRunnerBuilder[In: Any val, Out: Any val] is
  RunnerBuilder
  let _comp: StatelessComputation[In, Out]
  let _routing_group: RoutingId
  let _parallelism: USize

  new val create(comp: StatelessComputation[In, Out],
    routing_group': RoutingId, parallelism': USize)
  =>
    _comp = comp
    _routing_group = routing_group'
    _parallelism = parallelism'

  fun apply(event_log: EventLog,
    auth: AmbientAuth,
    next_runner: (Runner iso | None) = None,
    router: (Router | None) = None,
    partitioner_builder: PartitionerBuilder = PassthroughPartitionerBuilder):
    Runner iso^
  =>
    match (consume next_runner)
    | let r: Runner iso =>
      StatelessComputationRunner[In, Out](_comp, consume r)
    else
      StatelessComputationRunner[In, Out](_comp, RouterRunner(partitioner_builder))
    end

  fun name(): String => _comp.name()
  fun routing_group(): RoutingId => _routing_group
  fun parallelism(): USize => _parallelism
  fun is_stateful(): Bool => false

class val StateRunnerBuilder[In: Any val, Out: Any val, S: State ref] is
  RunnerBuilder
  let _state_init: StateInitializer[In, Out, S] val
  let _step_group: RoutingId
  let _parallelism: USize

  new val create(state_init: StateInitializer[In, Out, S] val,
    step_group: RoutingId, parallelism': USize)
  =>
    _state_init = state_init
    _step_group = step_group
    _parallelism = parallelism'

  fun apply(event_log: EventLog,
    auth: AmbientAuth,
    next_runner: (Runner iso | None) = None,
    router: (Router | None) = None,
    partitioner_builder: PartitionerBuilder = PassthroughPartitionerBuilder):
    Runner iso^
  =>
    match (consume next_runner)
    | let r: Runner iso =>
      StateRunner[In, Out, S](_step_group, _state_init, event_log, auth,
        consume r)
    else
      StateRunner[In, Out, S](_step_group, _state_init, event_log, auth,
        RouterRunner(partitioner_builder))
    end

  fun name(): String => _state_init.name()
  fun routing_group(): RoutingId => _step_group
  fun parallelism(): USize => _parallelism
  fun is_stateful(): Bool => true

class StatelessComputationRunner[In: Any val, Out: Any val] is Runner
  let _next: Runner
  let _computation: StatelessComputation[In, Out] val
  let _computation_name: String

  new iso create(computation: StatelessComputation[In, Out] val,
    next: Runner iso)
  =>
    _computation = computation
    _computation_name = _computation.name()
    _next = consume next

  fun ref run[D: Any val](metric_name: String, pipeline_time_spent: U64,
    data: D, key: Key, event_ts: U64, watermark_ts: U64,
    producer_id: RoutingId, producer: Producer ref, router: Router,
    i_msg_uid: MsgId, frac_ids: FractionalMessageId, latest_ts: U64,
    metrics_id: U16, worker_ingress_ts: U64,
    metrics_reporter: MetricsReporter ref): (Bool, U64)
  =>
    match data
    | let input: In =>
      let computation_start = Time.nanos()
      let result = _computation(input)
      let computation_end = Time.nanos()

      let new_metrics_id = ifdef "detailed-metrics" then
          // increment by 2 because we'll be reporting 2 step metrics below
          metrics_id + 2
        else
          // increment by 1 because we'll be reporting 1 step metric below
          metrics_id + 1
        end

      //!@ This is unnecessary work since we only ever pass along the
      // input watermark
      (let new_watermark_ts, let old_watermark_ts) =
        producer.update_output_watermark(watermark_ts)

      (let is_finished, let last_ts) =
        match result
        | None => (true, computation_end)
        | let o: Out =>
          OutputProcessor[Out](_next, metric_name, pipeline_time_spent, o,
            key, event_ts, new_watermark_ts, old_watermark_ts, producer_id,
            producer, router, i_msg_uid, frac_ids, computation_end,
            new_metrics_id, worker_ingress_ts, metrics_reporter)
        | let os: Array[Out] val =>
          OutputProcessor[Out](_next, metric_name, pipeline_time_spent, os,
            key, event_ts, new_watermark_ts, old_watermark_ts, producer_id,
            producer, router, i_msg_uid, frac_ids, computation_end,
            new_metrics_id, worker_ingress_ts, metrics_reporter)
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
    else
      @printf[I32]("StatelessComputationRunner: Input was not correct type!\n"
        .cstring())
      Fail()
      (true, latest_ts)
    end

  fun name(): String => _computation.name()

class StateRunner[In: Any val, Out: Any val, S: State ref] is (Runner &
  RollbackableRunner & SerializableStateRunner & TimeoutTriggeringRunner)
  let _step_group: RoutingId
  let _state_initializer: StateInitializer[In, Out, S] val
  let _next_runner: Runner

  var _state_map: Map[Key, StateWrapper[In, Out, S]] = _state_map.create()
  let _event_log: EventLog
  let _wb: Writer = Writer
  let _rb: Reader = Reader
  let _auth: AmbientAuth
  var _step_id: (RoutingId | None)

  // Timeouts
  var _step_timeout_trigger: (StepTimeoutTrigger | None) = None
  let _msg_id_gen: MsgIdGenerator = MsgIdGenerator

  new iso create(step_group': RoutingId,
    state_initializer: StateInitializer[In, Out, S] val, event_log: EventLog,
    auth: AmbientAuth, next_runner: Runner iso)
  =>
    _step_group = step_group'
    _state_initializer = state_initializer
    _next_runner = consume next_runner
    _event_log = event_log
    _step_id = None
    _auth = auth

  fun ref set_step_id(id: RoutingId) =>
    _step_id = id

  fun ref rollback(payload: ByteSeq val) =>
    replace_serialized_state(payload)

  fun ref set_triggers(stt: StepTimeoutTrigger, watermarks: StageWatermarks) =>
    _step_timeout_trigger = stt
    let ti = _state_initializer.timeout_interval()
    if ti > 0 then
      stt.set_timeout(ti)
      watermarks.update_last_heard_threshold(ti * 2)
    end

  fun ref on_timeout(producer_id: RoutingId, producer: Producer ref,
    router: Router, metrics_reporter: MetricsReporter ref)
  =>
    @printf[I32]("!@ on_timeout called on StateRunner\n".cstring())
    let on_timeout_ts = Time.nanos()
    for (key, sw) in _state_map.pairs() do
      let watermark_ts = producer.check_effective_input_watermark(
        on_timeout_ts)

      (let out, let output_watermark_ts) = sw.on_timeout(watermark_ts)
      (let new_watermark_ts, let old_watermark_ts) =
        producer.update_output_watermark(output_watermark_ts)

      // TODO: Is this sufficient for assigning msg ids to window outputs?
      let new_i_msg_uid = _msg_id_gen()

      let latest_ts = Time.nanos()

      // !@ TODO: For metrics info, we need to pass along a worker_ingress_ts,
      // metrics_name, metrics_id, and pipeline_time_spent value per window
      // output. We could save this metadata per window.  It seems onerous
      // but also the clearest option.
      match out
      | let o: Out =>
        OutputProcessor[Out](
          _next_runner,
          //!@ metric_name, pipeline_time_spent
          "", latest_ts - on_timeout_ts,
          //!@ real
          o, key, on_timeout_ts, new_watermark_ts, old_watermark_ts,
          producer_id, producer, router, new_i_msg_uid, None, latest_ts,
          //!@ metrics_id, worker_ingress_ts
          0, on_timeout_ts,
          //!@ real
          metrics_reporter)
      | let os: Array[Out] val =>
        OutputProcessor[Out](
          _next_runner,
          //!@ metric_name, pipeline_time_spent
          "", latest_ts - on_timeout_ts,
          //!@ real
          os, key, on_timeout_ts, new_watermark_ts, old_watermark_ts,
          producer_id,  producer, router, new_i_msg_uid, None, latest_ts,
          //!@ metrics_id, worker_ingress_ts
          0, on_timeout_ts,
          //!@ real
          metrics_reporter)
      end
    end
    //!@ How do we configure this timeout and where does this go?
    match _step_timeout_trigger
    | let stt: StepTimeoutTrigger =>
      let ti = _state_initializer.timeout_interval()
      if ti > 0 then
        stt.set_timeout(ti)
      end
    else
      ifdef debug then
        @printf[I32](("StateRunner: on_timeout was called but we have no " +
          "StepTimeoutTrigger\n").cstring())
      end
    end

  fun ref run[D: Any val](metric_name: String, pipeline_time_spent: U64,
    data: D, key: Key, event_ts: U64, watermark_ts: U64,
    producer_id: RoutingId, producer: Producer ref, router: Router,
    i_msg_uid: MsgId, frac_ids: FractionalMessageId, latest_ts: U64,
    metrics_id: U16, worker_ingress_ts: U64,
    metrics_reporter: MetricsReporter ref): (Bool, U64)
  =>
    match data
    | let input: In =>
      let state_wrapper =
        try
          _state_map(key)?
        else
          match producer
          | let s: Step ref =>
            s.register_key(_step_group, key)
          else
            Fail()
          end
          let new_state = _state_initializer.state_wrapper(key)
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

      let computation_start = Time.nanos()
      (let result, let output_watermark_ts) =
        state_wrapper(input, event_ts, watermark_ts)
      let computation_end = Time.nanos()

      (let new_watermark_ts, let old_watermark_ts) =
        producer.update_output_watermark(output_watermark_ts)

      (let is_finished, let last_ts) =
        match result
        | None => (true, computation_end)
        | let o: Out =>
          OutputProcessor[Out](_next_runner, metric_name,
            pipeline_time_spent, o, key, event_ts, new_watermark_ts,
            old_watermark_ts, producer_id, producer, router, i_msg_uid,
            frac_ids, computation_end, new_metrics_id, worker_ingress_ts,
            metrics_reporter)
        | let os: Array[Out] val =>
          OutputProcessor[Out](_next_runner, metric_name,
            pipeline_time_spent, os, key, event_ts, new_watermark_ts,
            old_watermark_ts, producer_id, producer, router, i_msg_uid,
            frac_ids, computation_end, new_metrics_id, worker_ingress_ts,
            metrics_reporter)
        end

      let latest_metrics_id = ifdef "detailed-metrics" then
          metrics_reporter.step_metric(metric_name, _state_initializer.name(),
            metrics_id, latest_ts, computation_start where prefix = "Before")
          metrics_id + 1
        else
          metrics_id
        end

      metrics_reporter.step_metric(metric_name, _state_initializer.name(),
        latest_metrics_id, computation_start, computation_end)

      (is_finished, last_ts)
    else
      @printf[I32](("StateStatelessComputationRunner: Input was not correct " +
        "type!\n").cstring())
      Fail()
      (true, latest_ts)
    end

  fun rotate_log() =>
    //we need to be able to conflate all the current logs to a checkpoint and
    //rotate
    None

  fun name(): String => _state_initializer.name()

  fun ref import_key_state(step: Step ref, s_group: RoutingId, key: Key,
    s: ByteSeq val)
  =>
    ifdef debug then
      Invariant(s_group == _step_group)
    end
    if s.size() > 0 then
      try
        _rb.append(s as Array[U8] val)
        let state_wrapper = _state_initializer.decode(_rb, _auth)?
        ifdef "checkpoint_trace" then
          //!@
          // match state
          // | let st: Stringablike =>
          //   (let sec', let ns') = Time.now()
          //   let us' = ns' / 1000
          //   let ts' = PosixDate(sec', ns').format("%Y-%m-%d %H:%M:%S." + us'
          //     .string())
          //   @printf[I32]("DESERIALIZE (%s): loading new %s on step %s with tag %s\n".cstring(), ts'.cstring(), st.string().cstring(), _step_id.string().cstring(), (digestof this).string().cstring())
          // end
          @printf[I32]("Successfully imported key %s\n".cstring(),
            key.cstring())
        end
        _state_map(key) = state_wrapper
        step.register_key(s_group, key)
      else
        Fail()
      end
    else
      // We got the key but no accompanying state, so we initialize
      // ourselves.
      _state_map(key) = _state_initializer.state_wrapper(key)
      step.register_key(s_group, key)
    end

  fun ref export_key_state(step: Step ref, key: Key): ByteSeq val =>
    step.unregister_key(_step_group, key)
    let state_wrapper =
      try
        _state_map.remove(key)?._2
      else
        _state_initializer.state_wrapper(key)
      end
    state_wrapper.encode(_auth)

  fun ref serialize_state(): ByteSeq val =>
    let bytes = recover iso Array[U8] end
    for (k, state_wrapper) in _state_map.pairs() do
      ifdef "checkpoint_trace" then
        match state_wrapper
        | let s: Stringablike =>
          (let sec', let ns') = Time.now()
          let us' = ns' / 1000
          let ts' = PosixDate(sec', ns').format("%Y-%m-%d %H:%M:%S." +
            us'.string())
          @printf[I32]("SERIALIZE (%s): %s on step %s with tag %s\n"
            .cstring(), ts'.cstring(), s.string().cstring(),
            _step_id.string().cstring(), (digestof this).string().cstring())
        end
        @printf[I32]("SERIALIZING KEY %s\n".cstring(), k.cstring())
      end

      let key_size = k.size()
      _wb.u32_be(key_size.u32())
      _wb.write(k)
      let state_bytes = state_wrapper.encode(_auth)
      _wb.u32_be(state_bytes.size().u32())
      _wb.write(state_bytes)
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

  fun ref replace_serialized_state(payload: ByteSeq val) =>
    _state_map.clear()
    try
      let reader: Reader ref = Reader
      var bytes_left: USize = payload.size()
      _rb.append(payload as Array[U8] val)
      while bytes_left > 0 do
        let key_size = _rb.u32_be()?.usize()
        bytes_left = bytes_left - 4
        let key = String.from_array(_rb.block(key_size)?)
        bytes_left = bytes_left - key_size
        let state_size = _rb.u32_be()?.usize()
        bytes_left = bytes_left - 4
        reader.append(_rb.block(state_size)?)
        bytes_left = bytes_left - state_size
        let state_wrapper = _state_initializer.decode(reader, _auth)?
        ifdef "checkpoint_trace" then
          //!@
          // match state
          // | let st: Stringablike =>
          //   (let sec', let ns') = Time.now()
          //   let us' = ns' / 1000
          //   let ts' = PosixDate(sec', ns').format("%Y-%m-%d %H:%M:%S." +
          //     us'.string())
          //   @printf[I32]("DESERIALIZE (%s): loading new state %s on step %s with tag %s\n".cstring(), ts'.cstring(), st.string().cstring(), _step_id.string().cstring(), (digestof this).string().cstring())
          // end
          @printf[I32]("OVERWRITING STATE FOR KEY %s\n".cstring(),
            key.cstring())
        end
        _state_map(key) = state_wrapper
      end
    else
      Fail()
    end

interface Stringablike
  fun string(): String

class iso RouterRunner is Runner
  let _partitioner: Partitioner

  new iso create(pb: PartitionerBuilder) =>
    _partitioner = pb()

  fun ref run[D: Any val](metric_name: String, pipeline_time_spent: U64,
    data: D, key: Key, event_ts: U64, watermark_ts: U64,
    producer_id: RoutingId, producer: Producer ref, router: Router,
    i_msg_uid: MsgId, frac_ids: FractionalMessageId, latest_ts: U64,
    metrics_id: U16, worker_ingress_ts: U64,
    metrics_reporter: MetricsReporter ref): (Bool, U64)
  =>
    let new_key = _partitioner[D](data, key)
    router.route[D](metric_name, pipeline_time_spent, data, new_key, event_ts,
      watermark_ts, producer_id, producer, i_msg_uid, frac_ids, latest_ts,
      metrics_id, worker_ingress_ts)

  fun name(): String => "Router runner"
