
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
use "wallaroo/core/grouping"
use "wallaroo/ent/data_receiver"
use "wallaroo/ent/recovery"
use "wallaroo/ent/router_registry"
use "wallaroo_labs/mort"
use "wallaroo/core/initialization"
use "wallaroo/core/invariant"
use "wallaroo/core/metrics"
use "wallaroo/core/routing"
use "wallaroo/core/sink/tcp_sink"
use "wallaroo/core/source"
use "wallaroo/core/topology"

actor ConnectorSourceListener[In: Any val] is SourceListener
  """
  # ConnectorSourceListener
  """
  let _routing_id_gen: RoutingIdGenerator = RoutingIdGenerator
  let _env: Env
  let _worker_name: WorkerName
  let _pipeline_name: String
  let _runner_builder: RunnerBuilder
  let _grouper_builder: GrouperBuilder
  var _router: Router
  let _metrics_conn: MetricsSink
  let _metrics_reporter: MetricsReporter
  let _router_registry: RouterRegistry
  var _outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder] val
  let _event_log: EventLog
  let _auth: AmbientAuth
  let _layout_initializer: LayoutInitializer
  let _recovering: Bool
  let _target_router: Router
  let _parallelism: USize
  let _handler: FramedSourceHandler[In] val
  let _host: String
  let _service: String

  var _fd: U32
  var _event: AsioEventID = AsioEvent.none()
  let _limit: USize
  var _count: USize = 0
  var _closed: Bool = false
  var _init_size: USize
  var _max_size: USize

  let _connected_sources: SetIs[ConnectorSource[In]] = _connected_sources.create()
  let _available_sources: Array[ConnectorSource[In]] = _available_sources.create()

  new create(env: Env, worker_name: WorkerName, pipeline_name: String,
    runner_builder: RunnerBuilder, grouper: GrouperBuilder, router: Router,
    metrics_conn: MetricsSink,
    metrics_reporter: MetricsReporter iso, router_registry: RouterRegistry,
    outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder] val,
    event_log: EventLog, auth: AmbientAuth,
    layout_initializer: LayoutInitializer,
    recovering: Bool, target_router: Router = EmptyRouter, parallelism: USize,
    handler: FramedSourceHandler[In] val,
    host: String = "", service: String = "0",
    init_size: USize = 64, max_size: USize = 16384)
  =>
    """
    Listens for both IPv4 and IPv6 connections.
    """
    _env = env
    _worker_name = worker_name
    _pipeline_name = pipeline_name
    _runner_builder = runner_builder
    _grouper_builder = grouper
    _router = router
    _metrics_conn = metrics_conn
    _metrics_reporter = consume metrics_reporter
    _router_registry = router_registry
    _outgoing_boundary_builders = outgoing_boundary_builders
    _event_log = event_log
    _auth = auth
    _layout_initializer = layout_initializer
    _recovering = recovering
    _target_router = target_router
    _parallelism = parallelism
    _handler = handler
    _host = host
    _service = service

    _event = @pony_os_listen_tcp[AsioEventID](this,
      host.cstring(), service.cstring())
    _limit = parallelism
    _init_size = init_size
    _max_size = max_size
    _fd = @pony_asio_event_fd(_event)

    match router
    | let pr: StatePartitionRouter =>
      _router_registry.register_partition_router_subscriber(pr.step_group(),
        this)
    | let spr: StatelessPartitionRouter =>
      _router_registry.register_stateless_partition_router_subscriber(
        spr.partition_routing_id(), this)
    end

    @printf[I32]((pipeline_name + " source attempting to listen on "
      + host + ":" + service + "\n").cstring())
    _notify_listening()

    for i in Range(0, _limit) do
      let source_id = _routing_id_gen()
      let notify = ConnectorSourceNotify[In](source_id, _pipeline_name,
        _env, _auth, _handler, _runner_builder, _grouper_builder, _router,
        _metrics_reporter.clone(), _event_log, _target_router)
      let source = ConnectorSource[In](source_id, _auth, this,
        consume notify, _event_log, _router,
        _outgoing_boundary_builders, _layout_initializer,
        _metrics_reporter.clone(), _router_registry)
      source.mute(this)

      _router_registry.register_source(source, source_id)
      match _router
      | let pr: StatePartitionRouter =>
        _router_registry.register_partition_router_subscriber(
          pr.step_group(), source)
      | let spr: StatelessPartitionRouter =>
        _router_registry.register_stateless_partition_router_subscriber(
          spr.partition_routing_id(), source)
      end

      _available_sources.push(source)
    end

  be recovery_protocol_complete() =>
    """
    Called when Recovery is finished. If we're not recovering, that's right
    away. At that point, we can tell sources that from our perspective it's
    safe to unmute.
    """
    for s in _available_sources.values() do
      s.unmute(this)
    end
    for s in _connected_sources.values() do
      s.unmute(this)
    end

  be update_router(router: Router) =>
    _router = router

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
    @printf[I32]("Shutting down ConnectorSourceListener\n".cstring())
    _close()

  be _event_notify(event: AsioEventID, flags: U32, arg: U32) =>
    """
    When we are readable, we accept new connections until none remain.
    """
    if event isnt _event then
      return
    end

    if AsioEvent.readable(flags) then
      _accept(arg)
    end

    if AsioEvent.disposable(flags) then
      @pony_asio_event_destroy(_event)
      _event = AsioEvent.none()
    end

  be _conn_closed(s: ConnectorSource[In]) =>
    """
    An accepted connection has closed. If we have dropped below the limit, try
    to accept new connections.
    """
    if _connected_sources.contains(s) then
      _connected_sources.unset(s)
      _available_sources.push(s)
    else
      Fail()
    end
    _count = _count - 1
    ifdef debug then
      Invariant(_count == _connected_sources.size())
      Invariant(_available_sources.size() == (_limit - _count))
    end

    if _count < _limit then
      _accept()
    end

  fun ref _accept(ns: U32 = 0) =>
    """
    Accept connections as long as we have spawned fewer than our limit.
    """
    if _closed then
      return
    elseif _count >= _limit then
      @printf[I32]("ConnectorSourceListener: Already reached connection limit\n"
        .cstring())
      return
    end

    while _count < _limit do
      var fd = @pony_os_accept[U32](_event)

      match fd
      | -1 =>
        // Something other than EWOULDBLOCK, try again.
        None
      | 0 =>
        // EWOULDBLOCK, don't try again.
        return
      else
        _spawn(fd)
      end
    end

  fun ref _spawn(ns: U32) =>
    """
    Spawn a new connection.
    """
    try
      let source = _available_sources.pop()?
      source.accept(ns, _init_size, _max_size)
      _connected_sources.set(source)
      _count = _count + 1
    else
      @pony_os_socket_close[None](ns)
      Fail()
    end

  fun ref _notify_listening() =>
    """
    Inform the notifier that we're listening.
    """
    if not _event.is_null() then
      @printf[I32]((_pipeline_name + " source is listening\n")
        .cstring())
    else
      _closed = true
      @printf[I32]((_pipeline_name +
        " source is unable to listen\n").cstring())
      Fail()
    end

  fun ref _close() =>
    """
    Dispose of resources.
    """
    if _closed then
      return
    end

    _closed = true

    if not _event.is_null() then
      // When not on windows, the unsubscribe is done immediately.
      ifdef not windows then
        @pony_asio_event_unsubscribe(_event)
      end

      @pony_os_socket_close[None](_fd)
      _fd = -1
    end
