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

use "wallaroo/core/recovery"
use "wallaroo_labs/mort"
use "wallaroo/core/common"
use "wallaroo/core/partitioning"
use "wallaroo/core/metrics"
use "wallaroo/core/registries"
use "wallaroo/core/source"
use "wallaroo/core/topology"

class KafkaSourceCoordinatorNotify[In: Any val]
  let _pipeline_name: String
  let _auth: AmbientAuth
  let _handler: SourceHandler[In] val
  let _runner_builder: RunnerBuilder
  let _partitioner_builder: PartitionerBuilder
  let _router: Router
  let _metrics_reporter: MetricsReporter
  let _event_log: EventLog
  let _target_router: Router
  let _router_registry: RouterRegistry

  new iso create(pipeline_name: String, auth: AmbientAuth,
    handler: SourceHandler[In] val, runner_builder: RunnerBuilder,
    partitioner_builder: PartitionerBuilder, router': Router,
    metrics_reporter: MetricsReporter iso,
    event_log: EventLog, target_router: Router,
    router_registry: RouterRegistry)
  =>
    _pipeline_name = pipeline_name
    _auth = auth
    _handler = handler
    _runner_builder = runner_builder
    _partitioner_builder = partitioner_builder
    _router = router'
    _metrics_reporter = consume metrics_reporter
    _event_log = event_log
    _target_router = target_router
    _router_registry = router_registry

  fun ref build_source(source_id: RoutingId, env: Env):
    KafkaSourceNotify[In] iso^
  =>
    KafkaSourceNotify[In](source_id, _pipeline_name, env, _auth,
      _handler, _runner_builder, _partitioner_builder, _router,
      _metrics_reporter.clone(), _event_log, _target_router,
      _router_registry)
