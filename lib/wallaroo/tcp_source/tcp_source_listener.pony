use "collections"
use "wallaroo/boundary"
use "wallaroo/initialization"
use "wallaroo/metrics"
use "wallaroo/recovery"
use "wallaroo/routing"
use "wallaroo/tcp_sink"
use "wallaroo/topology"

class TCPSourceListenerBuilder
  let _source_builder: SourceBuilder val
  let _router: Router val
  let _router_registry: RouterRegistry
  let _route_builder: RouteBuilder val
  let _default_in_route_builder: (RouteBuilder val | None)
  let _outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder val] val
  let _tcp_sinks: Array[TCPSink] val
  let _layout_initializer: LayoutInitializer
  let _event_log: EventLog
  let _auth: AmbientAuth
  let _default_target: (Step | None)
  let _target_router: Router val
  let _host: String
  let _service: String
  let _metrics_reporter: MetricsReporter

  new val create(source_builder: SourceBuilder val, router: Router val,
    router_registry: RouterRegistry, route_builder: RouteBuilder val,
    outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder val] val,
    tcp_sinks: Array[TCPSink] val, event_log: EventLog, auth: AmbientAuth,
    layout_initializer: LayoutInitializer,
    metrics_reporter: MetricsReporter iso,
    default_target: (Step | None) = None,
    default_in_route_builder: (RouteBuilder val | None) = None,
    target_router: Router val = EmptyRouter,
    host: String = "", service: String = "0")
  =>
    _source_builder = source_builder
    _router = router
    _router_registry = router_registry
    _route_builder = route_builder
    _default_in_route_builder = default_in_route_builder
    _outgoing_boundary_builders = outgoing_boundary_builders
    _tcp_sinks = tcp_sinks
    _layout_initializer = layout_initializer
    _event_log = event_log
    _auth = auth
    _default_target = default_target
    _target_router = target_router
    _host = host
    _service = service
    _metrics_reporter = consume metrics_reporter

  fun apply(): TCPSourceListener =>
    let tcp_l = TCPSourceListener(_source_builder, _router, _router_registry,
      _route_builder, _outgoing_boundary_builders, _tcp_sinks,
      _event_log, _auth, _layout_initializer, _metrics_reporter.clone(),
      _default_target, _default_in_route_builder, _target_router, _host,
      _service)
    _router_registry.register_source_listener(tcp_l)
    tcp_l

actor TCPSourceListener
  """
  # TCPSourceListener
  """

  var _notify: TCPSourceListenerNotify
  let _router: Router val
  let _router_registry: RouterRegistry
  let _route_builder: RouteBuilder val
  let _default_in_route_builder: (RouteBuilder val | None)
  var _outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder val] val
  let _tcp_sinks: Array[TCPSink] val
  let _layout_initializer: LayoutInitializer
  let _default_target: (Step | None)
  var _fd: U32
  var _event: AsioEventID = AsioEvent.none()
  let _limit: USize
  var _count: USize = 0
  var _closed: Bool = false
  var _init_size: USize
  var _max_size: USize
  let _metrics_reporter: MetricsReporter

  new create(source_builder: SourceBuilder val, router: Router val,
    router_registry: RouterRegistry, route_builder: RouteBuilder val,
    outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder val] val,
    tcp_sinks: Array[TCPSink] val, event_log: EventLog, auth: AmbientAuth,
    layout_initializer: LayoutInitializer,
    metrics_reporter: MetricsReporter iso,
    default_target: (Step | None) = None,
    default_in_route_builder: (RouteBuilder val | None) = None,
    target_router: Router val = EmptyRouter,
    host: String = "", service: String = "0", limit: USize = 0,
    init_size: USize = 64, max_size: USize = 16384)
  =>
    """
    Listens for both IPv4 and IPv6 connections.
    """
    _notify = SourceListenerNotify(source_builder, event_log, auth, target_router)
    _router = router
    _router_registry = router_registry
    _route_builder = route_builder
    _default_in_route_builder = default_in_route_builder
    _outgoing_boundary_builders = outgoing_boundary_builders
    _tcp_sinks = tcp_sinks
    _layout_initializer = layout_initializer
    _event = @pony_os_listen_tcp[AsioEventID](this,
      host.cstring(), service.cstring())
    _limit = limit
    _default_target = default_target
    _metrics_reporter = consume metrics_reporter

    _init_size = init_size
    _max_size = max_size
    _fd = @pony_asio_event_fd(_event)
     @printf[I32]((source_builder.name() + " source attempting to listen on "
      + host + ":" + service + "\n").cstring())
    _notify_listening()

  be update_router(router: PartitionRouter val) =>
    _notify.update_router(router)

  be remove_route_for(moving_step: ConsumerStep) =>
    None

  be add_boundary_builders(
    boundary_builders: Map[String, OutgoingBoundaryBuilder val] val)
  =>
    let new_builders: Map[String, OutgoingBoundaryBuilder val] trn =
      recover Map[String, OutgoingBoundaryBuilder val] end
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

  be _conn_closed() =>
    """
    An accepted connection has closed. If we have dropped below the limit, try
    to accept new connections.
    """
    _count = _count - 1

    if _count < _limit then
      _accept()
    end

  fun ref _accept(ns: U32 = 0) =>
    """
    Accept connections as long as we have spawned fewer than our limit.
    """
    if _closed then
      return
    end

    while (_limit == 0) or (_count < _limit) do
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
      let source = TCPSource._accept(this, _notify.connected(this),
        _router.routes(), _route_builder, _outgoing_boundary_builders,
        _tcp_sinks, _layout_initializer, ns, _default_target,
        _default_in_route_builder, _init_size, _max_size,
        _metrics_reporter.clone())
      // TODO: We need to figure out how to unregister this when the
      // connection dies
      _router_registry.register_source(source)
      _count = _count + 1
    else
      @pony_os_socket_close[None](ns)
    end

  fun ref _notify_listening() =>
    """
    Inform the notifier that we're listening.
    """
    if not _event.is_null() then
      _notify.listening(this)
    else
      _closed = true
      _notify.not_listening(this)
    end
