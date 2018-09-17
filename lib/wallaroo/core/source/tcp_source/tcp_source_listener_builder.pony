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

class val TCPSourceListenerBuilder
  let _source_builder: SourceBuilder
  let _pipeline_name: String
  let _router: Router
  let _router_registry: RouterRegistry
  let _outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder] val
  let _layout_initializer: LayoutInitializer
  let _event_log: EventLog
  let _auth: AmbientAuth
  let _target_router: Router
  let _host: String
  let _service: String
  let _metrics_reporter: MetricsReporter

  new val create(source_builder: SourceBuilder, router: Router,
    router_registry: RouterRegistry,
    outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder] val,
    event_log: EventLog, auth: AmbientAuth, pipeline_name: String,
    layout_initializer: LayoutInitializer,
    metrics_reporter: MetricsReporter iso,
    target_router: Router = EmptyRouter,
    host: String = "", service: String = "0")
  =>
    _source_builder = source_builder
    _pipeline_name = pipeline_name
    _router = router
    _router_registry = router_registry
    _outgoing_boundary_builders = outgoing_boundary_builders
    _layout_initializer = layout_initializer
    _event_log = event_log
    _auth = auth
    _target_router = target_router
    _host = host
    _service = service
    _metrics_reporter = consume metrics_reporter

  fun apply(env: Env): SourceListener =>
    TCPSourceListener(env, _source_builder, _router, _router_registry,
      _outgoing_boundary_builders, _event_log, _auth,
      _pipeline_name, _layout_initializer, _metrics_reporter.clone(),
      _target_router, _host, _service)

class val TCPSourceListenerBuilderBuilder
  let _host: String
  let _service: String

  new val create(host: String, service: String) =>
    _host = host
    _service = service

  fun apply(source_builder: SourceBuilder, router: Router,
    router_registry: RouterRegistry,
    outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder] val,
    event_log: EventLog, auth: AmbientAuth, pipeline_name: String,
    layout_initializer: LayoutInitializer,
    metrics_reporter: MetricsReporter iso, recovering: Bool,
    target_router: Router = EmptyRouter): TCPSourceListenerBuilder
  =>
    TCPSourceListenerBuilder(source_builder, router, router_registry,
      outgoing_boundary_builders, event_log, auth, pipeline_name,
      layout_initializer, consume metrics_reporter,
      target_router, _host, _service)
