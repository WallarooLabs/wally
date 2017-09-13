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

interface MetricsMonitor
  """
  MetricsMonitor

  Interface for hooking into a MetricsReporter and being able to
  monitor metrics via on_send prior to a send_metrics() call.
  """
  fun clone(): MetricsMonitor iso^

  fun ref on_send(metrics: MetricDataList val) =>
    """
    Hook for monitoring metrics prior to send_metrics() call.
    """
    None

class DefaultMetricsMonitor is MetricsMonitor

  fun clone(): DefaultMetricsMonitor iso^ =>
    recover DefaultMetricsMonitor end
