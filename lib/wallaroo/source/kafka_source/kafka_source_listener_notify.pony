use "wallaroo/fail"
use "wallaroo/metrics"
use "wallaroo/source"
use "wallaroo/topology"
use "wallaroo/recovery"

class KafkaSourceListenerNotify[In: Any val]
  var _source_builder: SourceBuilder
  let _event_log: EventLog
  let _target_router: Router
  let _auth: AmbientAuth

  new iso create(builder: SourceBuilder, event_log: EventLog,
    auth: AmbientAuth, target_router: Router) =>
    _source_builder = builder
    _event_log = event_log
    _target_router = target_router
    _auth = auth

  fun ref build_source(): KafkaSourceNotify[In] iso^ ? =>
    try
      _source_builder(_event_log, _auth, _target_router) as
        KafkaSourceNotify[In] iso^
    else
      @printf[I32](
        (_source_builder.name()
          + " could not create a KafkaSourceNotify\n").cstring())
      Fail()
      error
    end

  fun ref update_router(router: Router) =>
    _source_builder = _source_builder.update_router(router)

class val KafkaSourceBuilderBuilder[In: Any val]
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

  fun apply(runner_builder: RunnerBuilder, router: Router,
    metrics_conn: MetricsSink, pre_state_target_id: (U128 | None) = None,
    worker_name: String, metrics_reporter: MetricsReporter iso):
      SourceBuilder
  =>
    BasicSourceBuilder[In, SourceHandler[In] val](_app_name, worker_name,
      _name, runner_builder, _handler, router,
      metrics_conn, pre_state_target_id, consume metrics_reporter,
      KafkaSourceNotifyBuilder[In])

