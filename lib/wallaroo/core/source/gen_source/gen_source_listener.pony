
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

use "buffered"
use "collections"
use "crypto"
use "wallaroo/core/boundary"
use "wallaroo/core/common"
use "wallaroo/ent/data_receiver"
use "wallaroo/ent/recovery"
use "wallaroo/ent/router_registry"
use "wallaroo_labs/mort"
use "wallaroo/core/initialization"
use "wallaroo/core/metrics"
use "wallaroo/core/routing"
use "wallaroo/core/sink/tcp_sink"
use "wallaroo/core/source"
use "wallaroo/core/topology"

interface _Sourcey
  fun ref source(layout_initializer: LayoutInitializer,
    router_registry: RouterRegistry,
    outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder] val):
    Source

actor GenSourceListener is SourceListener
  """
  # GenSourceListener
  """
  let _routing_id_gen: RoutingIdGenerator = RoutingIdGenerator
  let _env: Env
  let _auth: AmbientAuth
  let _pipeline_name: String
  var _router: Router
  let _router_registry: RouterRegistry
  var _outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder] val
  let _layout_initializer: LayoutInitializer
  let _metrics_reporter: MetricsReporter
  var _source_builder: SourceBuilder
  let _event_log: EventLog
  let _target_router: Router
  let _sources: Array[Source] = _sources.create()

  new create(env: Env, source_builder: SourceBuilder, router: Router,
    router_registry: RouterRegistry,
    outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder] val,
    event_log: EventLog, auth: AmbientAuth, pipeline_name: String,
    layout_initializer: LayoutInitializer,
    metrics_reporter: MetricsReporter iso,
    target_router: Router = EmptyRouter)
  =>
    _env = env
    _auth = auth
    _pipeline_name = pipeline_name
    _router = router
    _router_registry = router_registry
    _outgoing_boundary_builders = outgoing_boundary_builders
    _layout_initializer = layout_initializer
    _metrics_reporter = consume metrics_reporter
    _source_builder = source_builder
    _event_log = event_log
    _target_router = target_router

    match router
    | let pr: PartitionRouter =>
      _router_registry.register_partition_router_subscriber(pr.state_name(),
        this)
    | let spr: StatelessPartitionRouter =>
      _router_registry.register_stateless_partition_router_subscriber(
        spr.partition_id(), this)
    end

    _create_source()

  fun ref _create_source() =>
    let name = _pipeline_name + " source"
    let temp_id = MD5(name)
    let rb = Reader
    rb.append(temp_id)

    let source_id = try rb.u128_le()? else Fail(); 0 end

    let notify = _source_builder(source_id, _event_log, _auth,
      _target_router, _env)

    match consume notify
    | let gsn: _Sourcey =>
      let s = gsn.source(_layout_initializer, _router_registry,
        _outgoing_boundary_builders)
      match s
      | let source: (Source & RouterUpdatable) =>
        source.mute(this)
        _router_registry.register_source(source, source_id)
        match _router
        | let pr: PartitionRouter =>
          _router_registry.register_partition_router_subscriber(
            pr.state_name(), source)
        | let spr: StatelessPartitionRouter =>
          _router_registry.register_stateless_partition_router_subscriber(
            spr.partition_id(), source)
        end
        _sources.push(source)
      else
        Fail()
      end
    else
      Fail()
    end

  be recovery_protocol_complete() =>
    for s in _sources.values() do
      s.unmute(this)
    end

  be update_router(router: Router) =>
    _source_builder = _source_builder.update_router(router)
    _router = router

  be remove_route_for(moving_step: Consumer) =>
    None

  be add_boundary_builders(
    boundary_builders: Map[String, OutgoingBoundaryBuilder] val)
  =>
    let new_builders = recover trn Map[String, OutgoingBoundaryBuilder] end
    // TODO: A persistent map on the field would be much more efficient here
    for (target_worker_name, builder) in _outgoing_boundary_builders.pairs() do
      new_builders(target_worker_name) = builder
    end
    for (target_worker_name, builder) in boundary_builders.pairs() do
      if not new_builders.contains(target_worker_name) then
        new_builders(target_worker_name) = builder
      end
    end
    _outgoing_boundary_builders = consume new_builders

  be add_boundaries(bs: Map[String, OutgoingBoundary] val) =>
    //!@ Should we fail here?
    None

  be update_boundary_builders(
    boundary_builders: Map[String, OutgoingBoundaryBuilder] val)
  =>
    _outgoing_boundary_builders = boundary_builders

  be remove_boundary(worker: String) =>
    let new_boundary_builders =
      recover iso Map[String, OutgoingBoundaryBuilder] end
    for (w, b) in _outgoing_boundary_builders.pairs() do
      if w != worker then new_boundary_builders(w) = b end
    end

    _outgoing_boundary_builders = consume new_boundary_builders

  be dispose() =>
    @printf[I32]("Shutting down GenSourceListener\n".cstring())
