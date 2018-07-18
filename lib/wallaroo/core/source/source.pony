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
use "wallaroo/ent/barrier"
use "wallaroo/ent/data_receiver"
use "wallaroo/ent/recovery"
use "wallaroo/ent/snapshot"
use "wallaroo/core/metrics"
use "wallaroo/core/routing"
use "wallaroo/core/topology"

trait val SourceBuilder
  fun name(): String
  fun apply(source_id: StepId, event_log: EventLog, auth: AmbientAuth,
    target_router: Router, env: Env): SourceNotify iso^
  fun val update_router(router: Router): SourceBuilder

class val BasicSourceBuilder[In: Any val, SH: SourceHandler[In] val] is SourceBuilder
  let _app_name: String
  let _worker_name: String
  let _name: String
  let _runner_builder: RunnerBuilder
  let _handler: SH
  let _router: Router
  let _metrics_conn: MetricsSink
  let _pre_state_target_ids: Array[StepId] val
  let _metrics_reporter: MetricsReporter
  let _source_notify_builder: SourceNotifyBuilder[In, SH]

  new val create(app_name: String, worker_name: String,
    name': String,
    runner_builder: RunnerBuilder,
    handler: SH,
    router: Router, metrics_conn: MetricsSink,
    pre_state_target_ids: Array[StepId] val = recover Array[StepId] end,
    metrics_reporter: MetricsReporter iso,
    source_notify_builder: SourceNotifyBuilder[In, SH])
  =>
    _app_name = app_name
    _worker_name = worker_name
    _name = name'
    _runner_builder = runner_builder
    _handler = handler
    _router = router
    _metrics_conn = metrics_conn
    _pre_state_target_ids = pre_state_target_ids
    _metrics_reporter = consume metrics_reporter
    _source_notify_builder = source_notify_builder

  fun name(): String => _name

  fun apply(source_id: StepId, event_log: EventLog, auth: AmbientAuth,
    target_router: Router, env: Env): SourceNotify iso^
  =>
    _source_notify_builder(source_id, _name, env, auth, _handler,
      _runner_builder, _router, _metrics_reporter.clone(), event_log,
      target_router, _pre_state_target_ids)

  fun val update_router(router: Router): SourceBuilder =>
    BasicSourceBuilder[In, SH](_app_name, _worker_name, _name, _runner_builder,
      _handler, router, _metrics_conn, _pre_state_target_ids,
      _metrics_reporter.clone(), _source_notify_builder)

interface val SourceBuilderBuilder
  fun name(): String
  fun apply(runner_builder: RunnerBuilder, router: Router,
    metrics_conn: MetricsSink,
    pre_state_target_ids: Array[StepId] val = recover Array[StepId] end,
    worker_name: String,
    metrics_reporter: MetricsReporter iso):
      SourceBuilder

interface val SourceConfig[In: Any val]
  fun source_listener_builder_builder(): SourceListenerBuilderBuilder

  fun source_builder(app_name: String, name: String):
    SourceBuilderBuilder

interface tag Source is (DisposableActor & BoundaryUpdateable &
  StatusReporter & SnapshotRequester & Snapshottable)
  be update_router(router: PartitionRouter)
  be remove_route_to_consumer(id: StepId, c: Consumer)
  be add_boundary_builders(
    boundary_builders: Map[String, OutgoingBoundaryBuilder] val)
  be reconnect_boundary(target_worker_name: String)
  be mute(c: Consumer)
  be unmute(c: Consumer)
  be initiate_barrier(token: BarrierToken)
  be initiate_snapshot_barrier(snapshot_id: SnapshotId)

interface tag SourceListener is (DisposableActor & BoundaryUpdateable)
  be update_router(router: PartitionRouter)
  be add_boundary_builders(
    boundary_builders: Map[String, OutgoingBoundaryBuilder] val)
  be update_boundary_builders(
    boundary_builders: Map[String, OutgoingBoundaryBuilder] val)
