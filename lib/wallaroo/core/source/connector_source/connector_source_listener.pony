
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
use "wallaroo/core/checkpoint"
use "wallaroo/core/data_receiver"
use "wallaroo/core/initialization"
use "wallaroo/core/invariant"
use "wallaroo/core/metrics"
use "wallaroo/core/partitioning"
use "wallaroo/core/recovery"
use "wallaroo/core/router_registry"
use "wallaroo/core/routing"
use "wallaroo/core/sink/tcp_sink"
use "wallaroo/core/source"
use "wallaroo/core/topology"
use "wallaroo_labs/mort"

actor ConnectorSourceListener[In: Any val] is SourceListener
  """
  # ConnectorSourceListener
  """
  let _routing_id_gen: RoutingIdGenerator = RoutingIdGenerator
  let _env: Env
  let _worker_name: WorkerName
  let _pipeline_name: String
  let _runner_builder: RunnerBuilder
  let _partitioner_builder: PartitionerBuilder
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
  let _cookie: String
  let _max_credits: U32
  let _refill_credits: U32

  var _fd: U32 = U32.max_value()
  var _event: AsioEventID = AsioEvent.none()
  let _limit: USize
  var _count: USize = 0
  var _closed: Bool = false
  var _init_size: USize
  var _max_size: USize

  let _connected_sources: SetIs[ConnectorSource[In]] = _connected_sources.create()
  let _available_sources: Array[ConnectorSource[In]] = _available_sources.create()

  // Active Stream Registry
  let _active_streams: Map[U64, (String,Any tag,U64,U64)] =
    _active_streams.create()

  new create(env: Env, worker_name: WorkerName, pipeline_name: String,
    runner_builder: RunnerBuilder, partitioner_builder: PartitionerBuilder,
    router: Router, metrics_conn: MetricsSink,
    metrics_reporter: MetricsReporter iso, router_registry: RouterRegistry,
    outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder] val,
    event_log: EventLog, auth: AmbientAuth,
    layout_initializer: LayoutInitializer,
    recovering: Bool, target_router: Router = EmptyRouter, parallelism: USize,
    handler: FramedSourceHandler[In] val,
    host: String, service: String, cookie: String,
    max_credits: U32, refill_credits: U32,
    init_size: USize = 64, max_size: USize = 16384)
  =>
    """
    Listens for both IPv4 and IPv6 connections.
    """
    _env = env
    _worker_name = worker_name
    _pipeline_name = pipeline_name
    _runner_builder = runner_builder
    _partitioner_builder = partitioner_builder
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
    _cookie = cookie
    _max_credits = max_credits
    _refill_credits = refill_credits

    _limit = parallelism
    _init_size = init_size
    _max_size = max_size

    match router
    | let pr: StatePartitionRouter =>
      _router_registry.register_partition_router_subscriber(pr.step_group(),
        this)
    | let spr: StatelessPartitionRouter =>
      _router_registry.register_stateless_partition_router_subscriber(
        spr.partition_routing_id(), this)
    end

    @printf[I32]((pipeline_name + " source will listen (but not yet) on "
      + host + ":" + service + "\n").cstring())

    for i in Range(0, _limit) do
      let source_id = _routing_id_gen()
      let notify = ConnectorSourceNotify[In](source_id, _pipeline_name,
        _env, _auth, _handler, _runner_builder, _partitioner_builder, _router,
        _metrics_reporter.clone(), _event_log, _target_router, _cookie,
        _max_credits, _refill_credits)
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

  be start_listening() =>
    _event = @pony_os_listen_tcp[AsioEventID](this,
      _host.cstring(), _service.cstring())
    _fd = @pony_asio_event_fd(_event)
    _notify_listening()
    ifdef debug then
      @printf[I32]("Socket for %s now listening on %s:%s\n".cstring(),
        _pipeline_name.cstring(), _host.cstring(), _service.cstring())
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

  // Active Stream Registry

  be get_all_streams(session_tag: USize,
    connector_source: ConnectorSource[In] tag)
  =>
    let data: Array[(U64,String,U64)] trn = recover data.create() end

    for (stream_id, (stream_name, _, p_o_r, last_message_id)) in _active_streams.pairs()
    do
      data.push((stream_id, stream_name, p_o_r))
    end
    connector_source.get_all_streams_result(session_tag, consume data)

  be stream_notify(session_tag: USize,
    stream_id: U64, stream_name: String, point_of_reference: U64,
    connector_source: ConnectorSource[In] tag)
  =>
    ifdef "trace" then
      @printf[I32]("TRACE: %s.%s(%lu, %lu, ...)\n".cstring(),
        __loc.type_name().cstring(), __loc.method_name().cstring(),
        stream_id, point_of_reference)
    end
    if _active_streams.contains(stream_id) then
      try
        (let stream_name': String, let tag_or_none: Any tag,
          let p_o_r, let last_message_id) = _active_streams(stream_id)?
        ifdef "trace" then
          @printf[I32]("TRACE: %s.%s existing stream_id %lu @ p-o-r %lu l-msgid %lu in-use %s\n".cstring(),
            __loc.type_name().cstring(), __loc.method_name().cstring(),
            stream_id, p_o_r, last_message_id, (not (tag_or_none is None)).string().cstring())
        end
        if stream_name' != stream_name then
          Fail()
        end

        if tag_or_none is None then
          if point_of_reference != p_o_r then
            // TODO any other action needed?
            ifdef "trace" then
              @printf[I32](("stream_notify: stream-id %d stream %s " +
                "point_of_reference %lu != recorded p_o_r %lu").cstring(),
              stream_id, stream_name.cstring(), point_of_reference, p_o_r)
            end
          end
          _active_streams(stream_id) =
            (stream_name, connector_source, p_o_r, last_message_id)
          connector_source.stream_notify_result(session_tag, true,
            stream_id, p_o_r, last_message_id)
          ifdef "trace" then
            @printf[I32]("TRACE: %s.%s existing stream_id %lu is ok\n".cstring(),
              __loc.type_name().cstring(), __loc.method_name().cstring(),
              stream_id)
          end
        else
          connector_source.stream_notify_result(session_tag, false,
            0, 0, 0) // TODO args
          ifdef "trace" then
            @printf[I32]("TRACE: %s.%s existing stream_id %lu is rejected\n".cstring(),
              __loc.type_name().cstring(), __loc.method_name().cstring(),
              stream_id)
          end
        end
      else
        Fail()
      end
    else
      ifdef "trace" then
        @printf[I32]("TRACE: %s.%s new stream_id %lu @ p-o-r %lu\n".cstring(),
          __loc.type_name().cstring(), __loc.method_name().cstring(),
          stream_id, point_of_reference)
      end
      _active_streams(stream_id) =
        (stream_name, connector_source, point_of_reference, point_of_reference)
      connector_source.stream_notify_result(session_tag, true,
        stream_id, point_of_reference, point_of_reference)
    end

  be stream_update(stream_id: U64, checkpoint_id: CheckpointId,
    point_of_reference: U64, last_message_id: U64,
    connector_source: (ConnectorSource[In] tag|None))
  =>
    let update = if connector_source is None then
        true
      else
        try
          if _active_streams(stream_id)?._2 is None then
            false
          else
            true
          end
        else
          false
        end
      end
    ifdef "trace" then
      @printf[I32]("TRACE: %s.%s(stmid %lu, chkp %lu, p-o-r %lu, l-msgid %lu, conn %s) update %s\n".cstring(),
        __loc.type_name().cstring(), __loc.method_name().cstring(),
        stream_id, checkpoint_id, point_of_reference, last_message_id,
        (if connector_source is None then
          "None"
        else
          "not None"
        end).cstring(), update.string().cstring())
    end
    if update then
      let stream_name = try _active_streams(stream_id)?._1 else Fail(); "" end
      _active_streams(stream_id) =
        (stream_name, connector_source, point_of_reference, last_message_id)
    end
