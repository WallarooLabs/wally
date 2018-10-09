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
use "wallaroo/ent/recovery"
use "wallaroo/ent/router_registry"
use "wallaroo/core/initialization"
use "wallaroo/core/metrics"
use "wallaroo/core/routing"
use "wallaroo/core/source"
use "wallaroo/core/topology"

class val SimpleFileSourceListenerBuilder[In: Any val]
  let _worker_name: WorkerName
  let _pipeline_name: String
  let _runner_builder: RunnerBuilder
  let _router: Router
  let _metrics_conn: MetricsSink
  let _metrics_reporter: MetricsReporter
  let _router_registry: RouterRegistry
  let _outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder] val
  let _event_log: EventLog
  let _auth: AmbientAuth
  let _layout_initializer: LayoutInitializer
  let _recovering: Bool
  let _pre_state_target_ids: Array[RoutingId] val
  let _target_router: Router
  let _filename: String
  let _decoder: Decoder[In]
  let _is_repeating: Bool

  new val create(worker_name: WorkerName, pipeline_name: String,
    runner_builder: RunnerBuilder, router: Router, metrics_conn: MetricsSink,
    metrics_reporter: MetricsReporter iso, router_registry: RouterRegistry,
    outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder] val,
    event_log: EventLog, auth: AmbientAuth,
    layout_initializer: LayoutInitializer,
    recovering: Bool, pre_state_target_ids: Array[RoutingId] val,
    target_router: Router, filename: String, decoder: Decoder[In],
    is_repeating: Bool)
  =>
    _worker_name = worker_name
    _pipeline_name = pipeline_name
    _runner_builder = runner_builder
    _router = router
    _metrics_conn = metrics_conn
    _metrics_reporter = consume metrics_reporter
    _router_registry = router_registry
    _outgoing_boundary_builders = outgoing_boundary_builders
    _event_log = event_log
    _auth = auth
    _layout_initializer = layout_initializer
    _recovering = recovering
    _pre_state_target_ids = pre_state_target_ids
    _target_router = target_router
    _filename = filename
    _decoder = decoder
    _is_repeating = is_repeating

  fun apply(env: Env): SourceListener =>
    SimpleFileSourceListener[In](env, _worker_name, _pipeline_name,
      _runner_builder, _router, _metrics_conn, _metrics_reporter.clone(),
      _router_registry, _outgoing_boundary_builders, _event_log, _auth,
      _layout_initializer, _recovering, _pre_state_target_ids,
      _target_router, _filename, _decoder, _is_repeating)

class val SimpleFileSourceListenerBuilderBuilder[In: Any val]
  let _filename: String
  let _decoder: Decoder[In]
  let _is_repeating: Bool

  new val create(filename: String, decoder: Decoder[In], is_repeating: Bool)
  =>
    _filename = filename
    _decoder = decoder
    _is_repeating = is_repeating

  fun apply(worker_name: WorkerName, pipeline_name: String,
    runner_builder: RunnerBuilder, router: Router, metrics_conn: MetricsSink,
    metrics_reporter: MetricsReporter iso, router_registry: RouterRegistry,
    outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder] val,
    event_log: EventLog, auth: AmbientAuth,
    layout_initializer: LayoutInitializer,
    recovering: Bool, pre_state_target_ids: Array[RoutingId] val,
    target_router: Router = EmptyRouter): SimpleFileSourceListenerBuilder[In]
  =>
    SimpleFileSourceListenerBuilder[In](worker_name, pipeline_name,
      runner_builder, router, metrics_conn, consume metrics_reporter,
      router_registry, outgoing_boundary_builders, event_log, auth,
      layout_initializer, recovering, pre_state_target_ids,
      target_router, _filename, _decoder, _is_repeating)
