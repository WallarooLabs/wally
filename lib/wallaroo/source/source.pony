use "collections"
use "wallaroo/boundary"
use "wallaroo/ent/data_receiver"
use "wallaroo/core"
use "wallaroo/metrics"
use "wallaroo/recovery"
use "wallaroo/routing"
use "wallaroo/topology"

trait val SourceBuilder
  fun name(): String
  fun apply(event_log: EventLog, auth: AmbientAuth, target_router: Router):
    SourceNotify iso^
  fun val update_router(router: Router): SourceBuilder

class val BasicSourceBuilder[In: Any val, SH: SourceHandler[In] val] is SourceBuilder
  let _app_name: String
  let _worker_name: String
  let _name: String
  let _runner_builder: RunnerBuilder
  let _handler: SH
  let _router: Router
  let _metrics_conn: MetricsSink
  let _pre_state_target_id: (U128 | None)
  let _metrics_reporter: MetricsReporter
  let _source_notify_builder: SourceNotifyBuilder[In, SH]

  new val create(app_name: String, worker_name: String,
    name': String,
    runner_builder: RunnerBuilder,
    handler: SH,
    router: Router, metrics_conn: MetricsSink,
    pre_state_target_id: (U128 | None) = None,
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
    _pre_state_target_id = pre_state_target_id
    _metrics_reporter = consume metrics_reporter
    _source_notify_builder = source_notify_builder

  fun name(): String => _name

  fun apply(event_log: EventLog, auth: AmbientAuth, target_router: Router):
    SourceNotify iso^
  =>
    _source_notify_builder(_name, auth, _handler, _runner_builder, _router,
      _metrics_reporter.clone(), event_log, target_router, _pre_state_target_id)

  fun val update_router(router: Router): SourceBuilder =>
    BasicSourceBuilder[In, SH](_app_name, _worker_name, _name, _runner_builder,
      _handler, router, _metrics_conn, _pre_state_target_id,
      _metrics_reporter.clone(), _source_notify_builder)

interface val SourceBuilderBuilder
  fun name(): String
  fun apply(runner_builder: RunnerBuilder, router: Router,
    metrics_conn: MetricsSink, pre_state_target_id: (U128 | None) = None,
    worker_name: String,
    metrics_reporter: MetricsReporter iso):
      SourceBuilder

interface val SourceConfig[In: Any val]
  fun source_listener_builder_builder(): SourceListenerBuilderBuilder

  fun source_builder(app_name: String, name: String):
    SourceBuilderBuilder

interface tag Source
  be update_router(router: PartitionRouter)
  be add_boundary_builders(
    boundary_builders: Map[String, OutgoingBoundaryBuilder] val)
  be reconnect_boundary(target_worker_name: String)
  be mute(c: Consumer)
  be unmute(c: Consumer)

interface tag SourceListener
  be update_router(router: PartitionRouter)
  be add_boundary_builders(
    boundary_builders: Map[String, OutgoingBoundaryBuilder] val)
