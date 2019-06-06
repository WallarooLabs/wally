/*

Copyright 2019 The Wallaroo Authors.

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

use "collections"
use "ponytest"
use "promises"
use "random"
use "time"
use "wallaroo/core/aggregations"
use "wallaroo/core/common"
use "wallaroo/core/state"
use "wallaroo_labs/time"


/*
StateRunner interface:
  //!@ This can't be passed into Builder?
  fun ref set_step_id(id: RoutingId)

  fun ref rollback(payload: ByteSeq val)

  fun ref set_triggers(stt: StepTimeoutTrigger, watermarks: StageWatermarks)

  fun ref run[D: Any val](metric_name: String, pipeline_time_spent: U64,
    data: D, key: Key, event_ts: U64, watermark_ts: U64,
    producer_id: RoutingId, producer: Producer ref, router: Router,
    i_msg_uid: MsgId, frac_ids: FractionalMessageId, latest_ts: U64,
    metrics_id: U16, worker_ingress_ts: U64,
    metrics_reporter: MetricsReporter ref): (Bool, U64)

  //!@ Why is this here?
  fun rotate_log()

  fun ref on_timeout(producer_id: RoutingId, producer: Producer ref,
    router: Router, metrics_reporter: MetricsReporter ref,
    watermarks: StageWatermarks)

  fun ref flush_local_state(producer_id: RoutingId, producer: Producer ref,
    router: Router, metrics_reporter: MetricsReporter ref,
    watermarks: StageWatermarks)

  fun name(): String

  fun ref import_key_state(step: Step ref, s_group: RoutingId, key: Key,
    s: ByteSeq val)

  fun ref export_key_state(step: Step ref, key: Key): ByteSeq val

  fun ref serialize_state(): ByteSeq val

  fun ref replace_serialized_state(payload: ByteSeq val)

  PRIVATE
  fun ref _send_flushed_outputs(key: Key, out: ComputationResult[Out],
    output_watermark_ts: U64, producer_id: RoutingId, producer: Producer ref,
    router: Router, metrics_reporter: MetricsReporter ref,
    watermarks: StageWatermarks, artificial_ingress_ts: U64)

StateRunner fields:
  let _step_group: RoutingId
  let _state_initializer: StateInitializer[In, Out, S] val
  let _next_runner: Runner

  var _state_map: HashMap[Key, StateWrapper[In, Out, S], HashableKey] = _state_map.create()
  let _event_log: EventLog
  let _wb: Writer = Writer
  let _rb: Reader = Reader
  let _auth: AmbientAuth
  var _step_id: (RoutingId | None)

  // !TODO! This is for creating unaligned windows with random starting
  // points. We should refactor so that we can control the seed for testing.
  let _rand: Rand = Rand

  let _local_routing: Bool

  // Timeouts
  var _step_timeout_trigger: (StepTimeoutTrigger | None) = None
  let _msg_id_gen: MsgIdGenerator = MsgIdGenerator
*/


/*
!@ We can use next_runner to check outputs
*/

// actor _StateRunnerTests is TestList
//   new create(env: Env) => PonyTest(env, this)
//   new make() => None
//   fun tag tests(test: PonyTest) =>
//     test(_KeyIsAddedWhenFirstMessageForKeyIsReceived)
//     test(_KeyIsRemovedWhenStateIsRemoved)
//     test(_KeyIsAddedWhenMessageForKeyIsReceivedAfterStateWasRemoved)

// class iso _KeyIsAddedWhenFirstMessageForKeyIsReceived is UnitTest
//   //!@ Can we statically access the class name with something like __loc()?
//   fun name(): String =>
//     "topology/state_runner/_KeyIsAddedWhenFirstMessageForKeyIsReceived"

//   fun apply(h: TestHelper) ? =>

//     // given
//     let key = "key"
//     let mock_state_init = ...
//     let state_runner = StateRunner[In, Out, State](step_group': RoutingId,
//       state_initializer: StateInitializer[In, Out, S] val,
//       key_registry: KeyRegistry, event_log: EventLog,
//       auth: AmbientAuth, next_runner: Runner iso, local_routing: Bool)

//     // when
//     state_runner.run[](...)

//     // then
//     mock_key_registry.has_registered_key(key)

// class iso _KeyIsRemovedWhenStateIsRemoved is UnitTest
//   //!@ Can we statically access the class name with something like __loc()?
//   fun name(): String =>
//     "topology/state_runner/_KeyIsRemovedWhenStateIsRemoved"

//   fun apply(h: TestHelper) ? =>

//     // given
//     let key = "key"
//     let mock_state_init = ...(n_messages_before_remove)
//     let state_runner = StateRunner[In, Out, State](step_group': RoutingId,
//       state_initializer: StateInitializer[In, Out, S] val,
//       key_registry: KeyRegistry, event_log: EventLog,
//       auth: AmbientAuth, next_runner: Runner iso, local_routing: Bool)
//     state_runner.run[](...)

//     // when
//     // DELETE STATE!
//     state_runner.run[](...)

//     // then
//     mock_key_registry.does_not_have_registered_key(key)

// class iso _KeyIsAddedWhenMessageForKeyIsReceivedAfterStateWasRemoved
//   is UnitTest
//   //!@ Can we statically access the class name with something like __loc()?
//   fun name(): String =>
//     "topology/state_runner/" +
//       "_KeyIsAddedWhenMessageForKeyIsReceivedAfterStateWasRemoved"

//   fun apply(h: TestHelper) ? =>

//     // given
//     let key = "key"
//     let mock_state_init = ...(n_messages_before_remove)
//     let state_runner = StateRunner[In, Out, State](step_group': RoutingId,
//       state_initializer: StateInitializer[In, Out, S] val,
//       key_registry: KeyRegistry, event_log: EventLog,
//       auth: AmbientAuth, next_runner: Runner iso, local_routing: Bool)
//     state_runner.run[](...)
//     // DELETE STATE!
//     state_runner.run[](...)

//     // when
//     // NEW MESSAGE FOR DELETED KEY
//     state_runner.run[](...)

//     // then
//     mock_key_registry.has_registered_key(key)
