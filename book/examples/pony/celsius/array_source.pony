use "buffered"
use "collections"
use "net"
use "time"
use "sendence/guid"
use "wallaroo/boundary"
use "wallaroo/fail"
use "wallaroo/initialization"
use "wallaroo/metrics"
use "wallaroo/recovery"
use "wallaroo/routing"
use "wallaroo/source"
use "wallaroo/tcp_sink"
use "wallaroo/topology"


class val ArraySourceConfig[In: Any val] is SourceConfig[In]
  let _array: Array[Array[U8] val] val
  let _emit_gap: U64
  let _handler: SourceHandler[In] val

  new val create(array: Array[Array[U8] val] val, emit_gap: U64, handler: SourceHandler[In] val) =>
    _array = array
    _emit_gap = emit_gap
    _handler = handler

  fun source_listener_builder_builder(): ArraySourceListenerBuilderBuilder[In] =>
    ArraySourceListenerBuilderBuilder[In](_array, _emit_gap)

  fun source_builder(app_name: String, name: String): ArraySourceBuilderBuilder[In] =>
    ArraySourceBuilderBuilder[In](app_name, name, _handler)

class val ArraySourceListenerBuilderBuilder[In: Any val]
  let _array: Array[Array[U8] val] val
  let _emit_gap: U64

  new val create(array: Array[Array[U8] val] val, emit_gap: U64) =>
    _array = array
    _emit_gap = emit_gap

  fun apply(source_builder: SourceBuilder val, router: Router val,
    router_registry: RouterRegistry, route_builder: RouteBuilder val,
    outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder val] val,
    tcp_sinks: Array[TCPSink] val, event_log: EventLog, auth: AmbientAuth,
    layout_initializer: LayoutInitializer,
    metrics_reporter: MetricsReporter iso,
    default_target: (Step | None) = None,
    default_in_route_builder: (RouteBuilder val | None) = None,
    target_router: Router val = EmptyRouter): ArraySourceListenerBuilder[In] val
  =>
    ArraySourceListenerBuilder[In](source_builder, router, router_registry,
      route_builder,
      outgoing_boundary_builders, tcp_sinks, event_log, auth,
      layout_initializer, consume metrics_reporter, default_target,
      default_in_route_builder, target_router, _array, _emit_gap)

class ArraySourceListenerBuilder[In: Any val]
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
  let _metrics_reporter: MetricsReporter
  let _array: Array[Array[U8] val] val
  let _emit_gap: U64

  new val create(source_builder: SourceBuilder val, router: Router val,
    router_registry: RouterRegistry, route_builder: RouteBuilder val,
    outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder val] val,
    tcp_sinks: Array[TCPSink] val, event_log: EventLog, auth: AmbientAuth,
    layout_initializer: LayoutInitializer,
    metrics_reporter: MetricsReporter iso,
    default_target: (Step | None) = None,
    default_in_route_builder: (RouteBuilder val | None) = None,
    target_router: Router val = EmptyRouter,
    array: Array[Array[U8] val] val,
    emit_gap: U64)
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
    _metrics_reporter = consume metrics_reporter
    _array = array
    _emit_gap = emit_gap

  fun apply(): SourceListener =>
    ArraySourceListener[In](_source_builder, _router, _router_registry,
      _route_builder, _outgoing_boundary_builders, _tcp_sinks,
      _event_log, _auth, _layout_initializer, _metrics_reporter.clone(),
      _default_target, _default_in_route_builder, _target_router, _array,
      _emit_gap)

actor ArraySourceListener[In: Any val] is SourceListener
  let _notify: ArraySourceListenerNotify[In]
  let _router: Router val
  let _router_registry: RouterRegistry
  let _route_builder: RouteBuilder val
  let _default_in_route_builder: (RouteBuilder val | None)
  var _outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder val] val
  let _layout_initializer: LayoutInitializer
  let _default_target: (Step | None)
  let _metrics_reporter: MetricsReporter
  let _array: Array[Array[U8] val] val
  let _emit_gap: U64

  new create(source_builder: SourceBuilder val, router: Router val,
    router_registry: RouterRegistry, route_builder: RouteBuilder val,
    outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder val] val,
    tcp_sinks: Array[TCPSink] val, event_log: EventLog, auth: AmbientAuth,
    layout_initializer: LayoutInitializer,
    metrics_reporter: MetricsReporter iso,
    default_target: (Step | None) = None,
    default_in_route_builder: (RouteBuilder val | None) = None,
    target_router: Router val = EmptyRouter,
    array: Array[Array[U8] val] val,
    emit_gap: U64)
  =>
    _notify = ArraySourceListenerNotify[In](source_builder, event_log, auth, target_router)
    _router = router
    _router_registry = router_registry
    _route_builder = route_builder
    _default_in_route_builder = default_in_route_builder
    _outgoing_boundary_builders = outgoing_boundary_builders
    _layout_initializer = layout_initializer
    _default_target = default_target
    _metrics_reporter = consume metrics_reporter

    _array = array
    _emit_gap = emit_gap

    _spawn()

  be _spawn() =>
    try
      let source = ArraySource[In](this, _notify.build_source(),
        _router.routes(), _route_builder, _outgoing_boundary_builders,
        _layout_initializer, _default_target,
        _default_in_route_builder,
        _metrics_reporter.clone(), _array, _emit_gap)
      _router_registry.register_source(source)
    else
      @printf[I32](("Could not create ArraySource.\n").cstring())
      Fail()
    end

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

primitive ArraySourceNotifyBuilder[In: Any val]
  fun apply(pipeline_name: String, auth: AmbientAuth,
    handler: SourceHandler[In] val,
    runner_builder: RunnerBuilder val, router: Router val,
    metrics_reporter: MetricsReporter iso, event_log: EventLog,
    target_router: Router val, pre_state_target_id: (U128 | None) = None):
    SourceNotify iso^
  =>
    ArraySourceNotify[In](pipeline_name, auth, handler, runner_builder, router,
      consume metrics_reporter, event_log, target_router, pre_state_target_id)

class ArraySourceNotify[In: Any val]
  let _guid_gen: GuidGenerator = GuidGenerator
  let _pipeline_name: String
  let _source_name: String
  let _handler: SourceHandler[In] val
  let _runner: Runner
  var _router: Router val
  let _omni_router: OmniRouter val = EmptyOmniRouter
  let _metrics_reporter: MetricsReporter

  new iso create(pipeline_name: String, auth: AmbientAuth,
    handler: SourceHandler[In] val,
    runner_builder: RunnerBuilder val, router: Router val,
    metrics_reporter: MetricsReporter iso, event_log: EventLog,
    target_router: Router val, pre_state_target_id: (U128 | None) = None)
  =>
    _pipeline_name = pipeline_name
    // TODO: Figure out how to name sources
    _source_name = pipeline_name + " source"
    _handler = handler
    _runner = runner_builder(event_log, auth, None,
      target_router, pre_state_target_id)
    _router = _runner.clone_router_and_set_input_type(router)
    _metrics_reporter = consume metrics_reporter

  fun routes(): Array[ConsumerStep] val =>
    _router.routes()

  fun ref received(src: ArraySource[In] ref, data: Array[U8] val) =>
    let ingest_ts = Time.nanos()
    let pipeline_time_spent: U64 = 0
    var latest_metrics_id: U16 = 1

    ifdef "trace" then
      @printf[I32](("Rcvd msg at " + _pipeline_name + " source\n").cstring())
    end

    (let is_finished, let keep_sending, let last_ts) =
      try
        src.next_sequence_id()
        let decoded =
          try
            _handler.decode(consume data)
          else
            ifdef debug then
              @printf[I32]("Error decoding message at source\n".cstring())
            end
            error
          end
        let decode_end_ts = Time.nanos()
        _metrics_reporter.step_metric(_pipeline_name,
          "Decode Time in Array Source", latest_metrics_id, ingest_ts,
          decode_end_ts)
        latest_metrics_id = latest_metrics_id + 1

        ifdef "trace" then
          @printf[I32](("Msg decoded at " + _pipeline_name +
            " source\n").cstring())
        end
        _runner.run[In](_pipeline_name, pipeline_time_spent, decoded,
          src, _router, _omni_router, src, _guid_gen.u128(), None, 0, 0,
          decode_end_ts, latest_metrics_id, ingest_ts, _metrics_reporter)
      else
        @printf[I32](("Unable to decode message at " + _pipeline_name +
          " source\n").cstring())
        ifdef debug then
          Fail()
        end
        (true, true, ingest_ts)
      end

    if is_finished then
      let end_ts = Time.nanos()
      let time_spent = end_ts - ingest_ts

      ifdef "detailed-metrics" then
        _metrics_reporter.step_metric(_pipeline_name,
          "Before end at TCP Source", 9999,
          last_ts, end_ts)
      end

      _metrics_reporter.pipeline_metric(_pipeline_name, time_spent +
        pipeline_time_spent)
      _metrics_reporter.worker_metric(_pipeline_name, time_spent)
    end

  fun ref update_router(router: Router val) =>
    _router = router

  fun ref update_boundaries(obs: box->Map[String, OutgoingBoundary]) =>
    match _router
    | let p_router: PartitionRouter val =>
      _router = p_router.update_boundaries(obs)
    else
      ifdef debug then
        @printf[I32](("ArraySourceNotify doesn't have PartitionRouter." +
          " Updating boundaries is a noop for this kind of Source.\n").cstring())
      end
    end

class ArraySourceListenerNotify[In: Any val]
  var _source_builder: SourceBuilder val
  let _event_log: EventLog
  let _target_router: Router val
  let _auth: AmbientAuth

  new iso create(builder: SourceBuilder val, event_log: EventLog, auth: AmbientAuth,
    target_router: Router val) =>
    _source_builder = builder
    _event_log = event_log
    _target_router = target_router
    _auth = auth

  fun ref build_source(): ArraySourceNotify[In] iso^ ? =>
    try
      _source_builder(_event_log, _auth, _target_router) as ArraySourceNotify[In] iso^
    else
      @printf[I32](
        (_source_builder.name() + " could not create a ArraySourceNotify\n").cstring())
      Fail()
      error
    end

  fun ref update_router(router: Router val) =>
    _source_builder = _source_builder.update_router(router)

class val ArraySourceBuilderBuilder[In: Any val]
  let _app_name: String
  let _name: String
  let _handler: SourceHandler[In] val

  new val create(app_name: String, name': String,
    handler: SourceHandler[In] val)
  =>
    _app_name = app_name
    _name = name'
    _handler = handler

  fun name(): String => _name

  fun apply(runner_builder: RunnerBuilder val, router: Router val,
    metrics_conn: MetricsSink, pre_state_target_id: (U128 | None) = None,
    worker_name: String, metrics_reporter: MetricsReporter iso):
      SourceBuilder val
  =>
    BasicSourceBuilder[In, SourceHandler[In] val](_app_name, worker_name,
      _name, runner_builder, _handler, router,
      metrics_conn, pre_state_target_id, consume metrics_reporter,
      ArraySourceNotifyBuilder[In])

class ArraySourceTimerNotify[In: Any val] is TimerNotify
  let _array_source: ArraySource[In] tag

  new iso create(array_source: ArraySource[In] tag) =>
    _array_source = array_source

  fun ref apply(timer: Timer, count: U64): Bool =>
    @printf[I32](("tick\n").cstring())
    _array_source.emit()
    true

actor ArraySource[In: Any val] is Producer
  let _guid: GuidGenerator = GuidGenerator
  // Credit Flow
  let _routes: MapIs[Consumer, Route] = _routes.create()
  let _route_builder: RouteBuilder val
  let _outgoing_boundaries: Map[String, OutgoingBoundary] =
    _outgoing_boundaries.create()
  let _layout_initializer: LayoutInitializer
  var _unregistered: Bool = false

  let _metrics_reporter: MetricsReporter

  let _listen: ArraySourceListener[In]
  let _notify: ArraySourceNotify[In]

  var _muted: Bool = true
  var _expect_read_buf: Reader = Reader
  let _muted_downstream: SetIs[Any tag] = _muted_downstream.create()

  // Origin (Resilience)
  var _seq_id: SeqId = 1 // 0 is reserved for "not seen yet"

  let _array: Array[Array[U8] val] val
  let _emit_gap: U64
  var _array_idx: USize = 0

  new create(listen: ArraySourceListener[In], notify: ArraySourceNotify[In] iso,
    routes: Array[ConsumerStep] val, route_builder: RouteBuilder val,
    outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder val] val,
    layout_initializer: LayoutInitializer,
    default_target: (ConsumerStep | None) = None,
    forward_route_builder: (RouteBuilder val | None) = None,
    metrics_reporter: MetricsReporter iso,
    array: Array[Array[U8] val] val, emit_gap: U64)
  =>
    _array = array
    _emit_gap = emit_gap

    let timers = Timers
    let timer = Timer(ArraySourceTimerNotify[In](this), _emit_gap, _emit_gap)
    timers(consume timer)

    _metrics_reporter = consume metrics_reporter
    _listen = listen
    _notify = consume notify

    _layout_initializer = layout_initializer

    _route_builder = route_builder
    for (target_worker_name, builder) in outgoing_boundary_builders.pairs() do
      _outgoing_boundaries(target_worker_name) = builder.build_and_initialize(
        _guid.u128(), _layout_initializer)
    end

    for consumer in routes.values() do
      _routes(consumer) =
        _route_builder(this, consumer, _metrics_reporter)
    end

    for (worker, boundary) in _outgoing_boundaries.pairs() do
      _routes(boundary) =
        _route_builder(this, boundary, _metrics_reporter)
    end

    _notify.update_boundaries(_outgoing_boundaries)

    match default_target
    | let r: ConsumerStep =>
      match forward_route_builder
      | let frb: RouteBuilder val =>
        _routes(r) = frb(this, r, _metrics_reporter)
      end
    end

    for r in _routes.values() do
      // TODO: this is a hack, we shouldn't be calling application events
      // directly. route lifecycle needs to be broken out better from
      // application lifecycle
      r.application_created()
    end

    for r in _routes.values() do
      r.application_initialized("TCPSource")
    end

    _mute()

  be update_router(router: PartitionRouter val) =>
    let new_router = router.update_boundaries(_outgoing_boundaries)
    _notify.update_router(new_router)

  be add_boundary_builders(
    boundary_builders: Map[String, OutgoingBoundaryBuilder val] val)
  =>
    """
    Build a new boundary for each builder that corresponds to a worker we
    don't yet have a boundary to. Each TCPSource has its own
    OutgoingBoundary to each worker to allow for higher throughput.
    """
    for (target_worker_name, builder) in boundary_builders.pairs() do
      if not _outgoing_boundaries.contains(target_worker_name) then
        let boundary = builder.build_and_initialize(_guid.u128(),
          _layout_initializer)
        _outgoing_boundaries(target_worker_name) = boundary
        _routes(boundary) =
          _route_builder(this, boundary, _metrics_reporter)
      end
    end
    _notify.update_boundaries(_outgoing_boundaries)

  be reconnect_boundary(target_worker_name: String) =>
    try
      _outgoing_boundaries(target_worker_name).reconnect()
    else
      Fail()
    end

  be remove_route_for(step: ConsumerStep) =>
    try
      _routes.remove(step)
    else
      Fail()
    end

  //////////////
  // ORIGIN (resilience)
  fun ref _x_resilience_routes(): Routes =>
    // TODO: we don't really need this
    // Because we dont actually do any resilience work
    Routes

  // Override these for TCPSource as we are currently
  // not resilient.
  fun ref _flush(low_watermark: U64) =>
    None

  be log_flushed(low_watermark: SeqId) =>
    None

  fun ref _bookkeeping(o_route_id: RouteId, o_seq_id: SeqId,
    i_origin: Producer, i_route_id: RouteId, i_seq_id: SeqId)
  =>
    None

  be update_watermark(route_id: RouteId, seq_id: SeqId) =>
    ifdef "trace" then
      @printf[I32]("TCPSource received update_watermark\n".cstring())
    end

  fun ref _update_watermark(route_id: RouteId, seq_id: SeqId) =>
    None

  //
  // CREDIT FLOW
  fun ref route_to(c: Consumer): (Route | None) =>
    try
      _routes(c)
    else
      None
    end

  fun ref next_sequence_id(): SeqId =>
    _seq_id = _seq_id + 1

  fun ref current_sequence_id(): SeqId =>
    _seq_id

  fun ref _mute() =>
    ifdef "credit_trace" then
      @printf[I32]("MUTE SOURCE\n".cstring())
    end
    _muted = true

  fun ref _unmute() =>
    ifdef "credit_trace" then
      @printf[I32]("UNMUTE SOURCE\n".cstring())
    end
    _muted = false

  be mute(c: Consumer) =>
    @printf[I32]("MUTE\n".cstring())
    _muted_downstream.set(c)
    _mute()

  be unmute(c: Consumer) =>
    @printf[I32]("UNMUTE\n".cstring())
    _muted_downstream.unset(c)

    if _muted_downstream.size() == 0 then
      _unmute()
    end

  fun ref is_muted(): Bool =>
    _muted

  be emit() =>
    // TODO: add some muting logic
    let carry_on = _notify.received(this, _next_array())

  fun ref _next_array(): Array[U8] val =>
    let a = try _array(_array_idx) else recover val Array[U8] end end
    _array_idx = (_array_idx + 1) % _array.size()
    a
