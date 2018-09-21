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
use "wallaroo/core/metrics"

primitive _Triggered
primitive _Untriggered

type _ThroughputBasedClusterGrowthTriggerState is
  ( _Triggered
  | _Untriggered
  )

class ThroughputBasedClusterGrowthTrigger is MetricsMonitor
  """
  ThroughputBasedClusterGrowthTrigger

  Triggers a request_new_worker() function call if the throughput
  per second exceeds the throughput trigger amount. This is called only
  once to avoid new worker overload.
  """
  var state: _ThroughputBasedClusterGrowthTriggerState = _Untriggered
  var _throughput_trigger_amount: U64
  let _new_worker_requester: NewWorkerRequester

  new create(new_worker_requester: NewWorkerRequester,
    throughput_trigger_amount: U64)
  =>
    _new_worker_requester = new_worker_requester
    _throughput_trigger_amount = throughput_trigger_amount

  fun clone(): ThroughputBasedClusterGrowthTrigger iso^ =>
    recover
      ThroughputBasedClusterGrowthTrigger(_new_worker_requester,
      _throughput_trigger_amount)
    end

  fun ref on_send(metrics: MetricDataList val) =>
    if state is _Untriggered then
      try
        _monitor_throughput_for(metrics)?
      end
    end

  fun ref _monitor_throughput_for(metrics: MetricDataList val) ? =>
    let metrics_size = metrics.size()
    for i in Range(0, metrics_size) do
      let metric = metrics(i)?
      if _throughput_per_sec(metric) >= _throughput_trigger_amount.f64() then
        _new_worker_requester.request_new_worker()
        _transition_to(_Triggered)
        break
      end
    end

  fun _throughput_per_sec(metric: MetricData): F64 =>
    (let metric_name, let category, let pipeline, let worker_name,
      let id, let histogram, let period, let period_ends_at, let topic,
      let event) = metric
    (histogram.size().f64() / (period.f64() * 0.000000001))

  fun ref _transition_to(state': _ThroughputBasedClusterGrowthTriggerState) =>
    state = state'
