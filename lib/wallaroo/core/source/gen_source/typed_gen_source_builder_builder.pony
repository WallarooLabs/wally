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

use "wallaroo/core/common"
use "wallaroo/core/metrics"
use "wallaroo/core/source"
use "wallaroo/core/topology"

class val TypedGenSourceBuilderBuilder[In: Any val]
  let _app_name: String
  let _name: String
  let _handler: GenSourceHandler[In] = GenSourceHandler[In]
  let _gen: GenSourceGenerator[In]

  new val create(app_name: String, name': String, gen: GenSourceGenerator[In])
  =>
    _app_name = app_name
    _name = name'
    _gen = gen

  fun name(): String => _name

  fun apply(runner_builder: RunnerBuilder, router: Router,
    metrics_conn: MetricsSink,
    pre_state_target_ids: Array[RoutingId] val = recover Array[RoutingId] end,
    worker_name: String, metrics_reporter: MetricsReporter iso):
      SourceBuilder
  =>
    BasicSourceBuilder[In, GenSourceHandler[In]](_app_name, worker_name,
      _name, runner_builder, _handler, router,
      metrics_conn, pre_state_target_ids, consume metrics_reporter,
      GenSourceNotifyBuilder[In](_gen))
