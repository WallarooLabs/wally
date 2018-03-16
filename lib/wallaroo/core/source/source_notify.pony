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

use "collections"
use "wallaroo/core/boundary"
use "wallaroo/core/common"
use "wallaroo/ent/data_receiver"
use "wallaroo/ent/recovery"
use "wallaroo/core/messages"
use "wallaroo/core/metrics"
use "wallaroo/core/routing"
use "wallaroo/core/topology"

interface SourceHandler[In: Any val]
  fun decode(data: Array[U8] val): In ?

interface FramedSourceHandler[In: Any val]
  fun header_length(): USize
  fun payload_length(data: Array[U8] iso): USize ?
  fun decode(data: Array[U8] val): In ?

interface SourceNotify
  fun ref routes(): Array[Consumer] val

  fun ref update_router(router: Router)

  fun ref update_boundaries(obs: box->Map[String, OutgoingBoundary])

interface val SourceNotifyBuilder[In: Any val, SH: SourceHandler[In] val]
  fun apply(source_id: StepId, pipeline_name: String, env: Env,
    auth: AmbientAuth, handler: SH, runner_builder: RunnerBuilder,
    router: Router, metrics_reporter: MetricsReporter iso, event_log: EventLog,
    target_router: Router,
    pre_state_target_ids: Array[StepId] val = recover Array[StepId] end):
    SourceNotify iso^
