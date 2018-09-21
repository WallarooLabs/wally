/*

Copyright 2018 The Wallaroo Authors.

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
use "wallaroo/core/metrics"

actor _TestThroughputBasedClusterGrowthTrigger is TestList
  new make() =>
    None

  fun tag tests(test: PonyTest) =>
    test(_TestWhenAboveThreshold)
    test(_TestWhenBelowThreshold)
    test(_TestOnlyTriggersOnce)

class iso _TestWhenAboveThreshold is UnitTest
  """
  Test that we make a request_new_worker() call when the throughput per
  second exceeds the throughput trigger amount.
  """
  fun name(): String =>
    "throughput_based_cluster_growth_trigger/WhenAboveThreshold"

  fun apply(h: TestHelper) =>
    let trigger_histogram =
      _HistogramGenerator(_ThroughputBasedClusterGrowthTriggerThreshold() +
        1_000)

    let triggering_metrics_list =
      recover val [_TestMetricData(trigger_histogram)] end

    let test_worker_request = _TestNewWorkerRequester(h)
    let new_worker_request_trigger_monitor =
      ThroughputBasedClusterGrowthTrigger(test_worker_request,
        _ThroughputBasedClusterGrowthTriggerThreshold())

    new_worker_request_trigger_monitor.on_send(triggering_metrics_list)
    h.expect_action("request_new_worker")
    h.long_test(1_000_000_000)

class iso _TestWhenBelowThreshold is UnitTest
  """
  Test that we do not make a request_new_worker() call when the throughput per
  second does not exceed the throughput trigger amount.
  """
  fun name(): String =>
    "throughput_based_cluster_growth_trigger/WhenBelowThreshold"

  fun apply(h: TestHelper) =>
    let non_trigger_histogram =
      _HistogramGenerator(_ThroughputBasedClusterGrowthTriggerThreshold() -
        1_000)

    let non_triggering_metrics_list =
      recover val [_TestMetricData(non_trigger_histogram)] end

    let test_worker_request = _TestNewWorkerRequester(h)

    let new_worker_request_trigger_monitor =
      ThroughputBasedClusterGrowthTrigger(test_worker_request,
        _ThroughputBasedClusterGrowthTriggerThreshold())

    new_worker_request_trigger_monitor.on_send(non_triggering_metrics_list)
    test_worker_request.test_call_count(0)

class iso _TestOnlyTriggersOnce is UnitTest
  """
  Test that we only make a single request_new_worker() call when the
  throughput per second exceeds the throughput trigger amount.
  """
  fun name(): String =>
    "throughput_based_cluster_growth_trigger/OnlyTriggersOnce"

  fun apply(h: TestHelper) =>
    let trigger_histogram =
      _HistogramGenerator(_ThroughputBasedClusterGrowthTriggerThreshold() +
        1_000)

    let multi_triggering_metrics_list =
      recover val [
        _TestMetricData(trigger_histogram)
        _TestMetricData(trigger_histogram)
      ] end

    let test_worker_request = _TestNewWorkerRequester(h)

    let new_worker_request_trigger_monitor =
      ThroughputBasedClusterGrowthTrigger(test_worker_request,
        _ThroughputBasedClusterGrowthTriggerThreshold())

    new_worker_request_trigger_monitor.on_send(multi_triggering_metrics_list)
    new_worker_request_trigger_monitor.on_send(multi_triggering_metrics_list)
    test_worker_request.test_call_count(1)

actor _TestNewWorkerRequester is NewWorkerRequester
  let _h: TestHelper
  var _call_count: U64 = 0

  new create(h: TestHelper) =>
    _h = h

  be test_call_count(expected_count: U64) =>
    _h.assert_eq[U64](expected_count, _call_count)

  be request_new_worker() =>
    _call_count = _call_count + 1
    _h.complete_action("request_new_worker")

primitive _TestMetricData
  """
  _TestMetricData

  Creates a mock metric object where the only value we care about for this
  test is the Histogram.
  """
  fun apply(histogram: Histogram val): MetricData =>
    ("Update NBBO", "computation", "NBBO", "worker1", U16(1),
      histogram, U64(1_000_000_000), U64(2_000_000_000), "metrics",
      "app")

primitive _ThroughputBasedClusterGrowthTriggerThreshold
  """
  _ThroughputBasedClusterGrowthTriggerThreshold

  Testing throughput threshold for ThroughputBasedClusterGrowthTrigger
  """
  fun apply(): U64 =>
    10_000

primitive _HistogramGenerator
  fun apply(size: U64) : Histogram val =>
    let histogram: Histogram iso = Histogram
    for i in Range[U64](0, size) do
      histogram(1)
    end
    histogram
