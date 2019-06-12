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
use "wallaroo/core/barrier"
use "wallaroo/core/boundary"
use "wallaroo/core/checkpoint"
use "wallaroo/core/common"
use "wallaroo/core/initialization"
use "wallaroo/core/partitioning"
use "wallaroo/core/recovery"
use "wallaroo/core/step"
use "wallaroo/core/topology"


actor TestOutputCollector[V: (Hashable & Equatable[V] & Stringable val)]
  is Consumer
  var _outputs: Array[String] = Array[String]
  let _h: TestHelper
  let _expected: (Array[String] | None)
  var _test_finished_msg: (V | None)
  // How many upstreams do we expect to register as producers with this Step?
  let _expected_registered_count: (USize | None)
  let _registered: Set[RoutingId] = _registered.create()
  let _completion_promise: (Promise[None] | None)
  // If this is true, then whenever an event occur, we check if we have
  // met expected conditions. If so, we complete test or promise. If not,
  // we keep going.
  let _watch_for_success: Bool

  new create(h: TestHelper, test_finished_msg: (V | None) = None,
    expected_values: (Array[(V | BarrierToken)] val | None) = None,
    expected_registered_count: (USize | None) = None,
    completion_promise: (Promise[None] | None) = None,
    watch_for_success: Bool = false)
  =>
    _h = h
    _test_finished_msg = test_finished_msg
    match expected_values
    | let es: Array[(V | BarrierToken)] val =>
      let expected = Array[String]
      for e in es.values() do
        expected.push(e.string())
      end
      _expected = expected
    else
      _expected = None
    end
    _expected_registered_count = expected_registered_count
    _completion_promise = completion_promise
    _watch_for_success = watch_for_success

  fun ref process_test_output[D: Any val](d: (D | BarrierToken)) =>
    match d
    | let v: V =>
      match _test_finished_msg
      | let tfmv: V =>
        if v == tfmv then
          check_results()
          return
        end
      end
      _outputs.push(v.string())
    | let bt: BarrierToken =>
      _outputs.push(bt.string())
    else
      _h.fail("Invalid test output type!")
    end
    if _watch_for_success then
      check_results_without_failing()
    end

  fun ref check_results() =>
    match _expected
    | let expected_arr: Array[String] =>
      _h.assert_array_eq[String](_outputs, expected_arr)
    end
    match _expected_registered_count
    | let erc: USize =>
      _h.assert_eq[USize](_registered.size(), erc)
    end
    match _completion_promise
    | let p: Promise[None] =>
      p(None)
    else
      _h.complete(true)
    end

  fun ref check_results_without_failing() =>
    var conditions_met: Bool = true
    match _expected
    | let expected_arr: Array[String] =>
      if not _CheckArrayEquality(_outputs, expected_arr) then
        conditions_met = false
      end
    end
    match _expected_registered_count
    | let erc: USize =>
      if _registered.size() != erc then
        conditions_met = false
      end
    end

    if conditions_met then
      match _completion_promise
      | let p: Promise[None] =>
        p(None)
      else
        _h.complete(true)
      end
    end

  ///////////////////////
  // CONSUMER INTERFACE
  ///////////////////////
  be register_producer(id: RoutingId, producer: Producer) =>
    _registered.set(id)
    if _watch_for_success then
      check_results_without_failing()
    end

  be unregister_producer(id: RoutingId, producer: Producer) =>
    _registered.unset(id)
    if _watch_for_success then
      check_results_without_failing()
    end

  be report_status(code: ReportStatusCode) =>
    None

  be run[D: Any val](metric_name: String, pipeline_time_spent: U64, data: D,
    key: Key, event_ts: U64, watermark_ts: U64, i_producer_id: RoutingId,
    i_producer: Producer, msg_uid: MsgId, frac_ids: FractionalMessageId,
    i_seq_id: SeqId, latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    process_test_output[D](data)

  be receive_barrier(step_id: RoutingId, producer: Producer,
    barrier_token: BarrierToken)
  =>
    process_test_output[V](barrier_token)

  fun ref process_message[D: Any val](metric_name: String,
    pipeline_time_spent: U64, data: D, key: Key, event_ts: U64,
    watermark_ts: U64, i_producer_id: RoutingId, i_producer: Producer,
    msg_uid: MsgId, frac_ids: FractionalMessageId, i_seq_id: SeqId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    None

  be request_ack() =>
    None

  be application_begin_reporting(initializer: LocalTopologyInitializer) =>
    None

  be application_created(initializer: LocalTopologyInitializer) =>
    None

  be application_initialized(initializer: LocalTopologyInitializer) =>
    None

  be application_ready_to_work(initializer: LocalTopologyInitializer) =>
    None

  be cluster_ready_to_work(initializer: LocalTopologyInitializer) =>
    None

  fun ref barrier_complete(barrier_token: BarrierToken) =>
    None

  fun ref checkpoint_state(checkpoint_id: CheckpointId) =>
    None

  be prepare_for_rollback() =>
    None

  be rollback(payload: ByteSeq val, event_log: EventLog,
    checkpoint_id: CheckpointId)
  =>
    None

primitive _CheckArrayEquality
  fun apply(actual: Array[String], expect: Array[String]): Bool =>
    var ok = true

    if expect.size() != actual.size() then
      ok = false
    else
      try
        var i: USize = 0
        while i < expect.size() do
          if expect(i)? != actual(i)? then
            ok = false
            break
          end

          i = i + 1
        end
      else
        ok = false
      end
    end
    ok

primitive TestOutputCollectorStepBuilder[V: (Hashable & Equatable[V] &
  Stringable val)]
  fun apply(env: Env, auth: AmbientAuth,
    ocs: (TestOutputCollector[V] | Array[TestOutputCollector[V]])): Step
  =>
    let router =
      match ocs
      | let oc: TestOutputCollector[V] =>
        DirectRouter(0, oc)
      | let arr: Array[TestOutputCollector[V]] =>
        let routers = recover iso Array[Router] end
        var next_id: RoutingId = 0
        for oc in arr.values() do
          routers.push(DirectRouter(next_id, oc))
          next_id = next_id + 1
        end
        MultiRouter(consume routers)
      end
    Step(auth, "", RouterRunner(PassthroughPartitionerBuilder),
      _MetricsReporterDummyBuilder(), 1, _EventLogDummyBuilder(auth),
      _RecoveryReconnecterDummyBuilder(env, auth),
      recover Map[String, OutgoingBoundary] end, router)
