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

use "wallaroo/ent/recovery"
use "wallaroo_labs/mort"
use "wallaroo/core/common"
use "wallaroo/core/metrics"
use "wallaroo/core/source"
use "wallaroo/core/topology"

class KafkaSourceListenerNotify[In: Any val]
  var _source_builder: SourceBuilder
  let _event_log: EventLog
  let _target_router: Router
  let _auth: AmbientAuth

  new iso create(builder: SourceBuilder, event_log: EventLog,
    auth: AmbientAuth, target_router: Router) =>
    _source_builder = builder
    _event_log = event_log
    _target_router = target_router
    _auth = auth

  fun ref build_source(source_id: StepId, env: Env):
    KafkaSourceNotify[In] iso^ ?
  =>
    try
      _source_builder(source_id, _event_log, _auth, _target_router, env) as
        KafkaSourceNotify[In] iso^
    else
      @printf[I32](
        (_source_builder.name()
          + " could not create a KafkaSourceNotify\n").cstring())
      Fail()
      error
    end

  fun ref update_router(router: Router) =>
    _source_builder = _source_builder.update_router(router)

class val KafkaSourceBuilderBuilder[In: Any val]
  let _app_name: String
  let _name: String
  let _handler: SourceHandler[In] val

  new val create(app_name: String, name': String,
    handler: SourceHandler[In] val)
  =>
    _app_name = app_name
    _name = name'
    _handler = handler

  fun name(): String => _name

  fun apply(runner_builder: RunnerBuilder, router: Router,
    metrics_conn: MetricsSink,
    pre_state_target_ids: Array[StepId] val = recover Array[StepId] end,
    worker_name: String, metrics_reporter: MetricsReporter iso):
      SourceBuilder
  =>
    BasicSourceBuilder[In, SourceHandler[In] val](_app_name, worker_name,
      _name, runner_builder, _handler, router,
      metrics_conn, pre_state_target_ids, consume metrics_reporter,
      KafkaSourceNotifyBuilder[In])

