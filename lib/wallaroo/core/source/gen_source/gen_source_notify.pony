/*

Copyright (C) 2016-2017, Wallaroo Labs
Copyright (C) 2016-2017, The Pony Developers
Copyright (c) 2014-2015, Causality Ltd.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/

use "collections"
use "wallaroo/core/boundary"
use "wallaroo/core/common"
use "wallaroo/ent/data_receiver"
use "wallaroo/ent/recovery"
use "wallaroo/ent/router_registry"
use "wallaroo/core/initialization"
use "wallaroo/core/messages"
use "wallaroo/core/metrics"
use "wallaroo/core/routing"
use "wallaroo/core/source"
use "wallaroo/core/topology"

class val GenSourceNotifyBuilder[In: Any val] is
  SourceNotifyBuilder[In val, GenSourceHandler[In val] val]
  let _gen: GenSourceGenerator[In]

  new val create(g: GenSourceGenerator[In]) =>
    _gen = g

  fun apply(source_id: RoutingId, pipeline_name: String, env: Env,
    auth: AmbientAuth, handler: GenSourceHandler[In],
    runner_builder: RunnerBuilder,
    router: Router, metrics_reporter: MetricsReporter iso, event_log: EventLog,
    target_router: Router,
    pre_state_target_ids: Array[RoutingId] val = recover Array[RoutingId] end):
    SourceNotify iso^
  =>
    GenSourceNotify[In](runner_builder, _gen, source_id, pipeline_name, env,
      auth, handler, runner_builder, router, consume metrics_reporter,
      event_log, target_router, pre_state_target_ids)

class GenSourceNotify[In: Any val]
  let _runner_builder: RunnerBuilder
  let _generator: GenSourceGenerator[In]
  let _source_id: RoutingId
  let _pipeline_name: String
  let _env: Env
  let _auth: AmbientAuth
  let _router: Router
  let _metrics_reporter: MetricsReporter iso
  let _event_log: EventLog
  let _target_router: Router
  let _pre_state_target_ids: Array[RoutingId] val

  new iso create(r_builder: RunnerBuilder, g: GenSourceGenerator[In],
    source_id: RoutingId, pipeline_name: String, env: Env,
    auth: AmbientAuth, handler: GenSourceHandler[In] val,
    runner_builder: RunnerBuilder, router: Router,
    metrics_reporter: MetricsReporter iso, event_log: EventLog,
    target_router: Router,
    pre_state_target_ids: Array[RoutingId] val = recover Array[RoutingId] end)
  =>
    _runner_builder = r_builder
    _generator = g
    _source_id = source_id
    _pipeline_name = pipeline_name
    _env = env
    _auth = auth
    _router = router
    _metrics_reporter = consume metrics_reporter
    _event_log = event_log
    _target_router = target_router
    _pre_state_target_ids = pre_state_target_ids

  // TODO: CREDITFLOW - this is weird that its here
  // It exists so that a GenSource can get its routes
  // on startup. It probably makes more sense to make this
  // available via the source builder that Listener gets
  // and it can then make routes available
  fun ref routes(): Map[RoutingId, Consumer] val =>
    recover Map[RoutingId, Consumer] end

  fun ref update_router(router': Router) =>
    None

  fun ref update_boundaries(obs: box->Map[String, OutgoingBoundary]) =>
    None

  fun ref source(layout_initializer: LayoutInitializer,
    router_registry: RouterRegistry,
    outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder] val):
    Source
  =>
    GenSource[In](_source_id, _auth, _pipeline_name, _runner_builder, _router,
      _target_router, _generator, _event_log, outgoing_boundary_builders,
      layout_initializer, _metrics_reporter.clone(), router_registry,
      _pre_state_target_ids)

primitive GenSourceHandler[In: Any val]
  fun decode(data: Array[U8] val): In ? =>
    error
