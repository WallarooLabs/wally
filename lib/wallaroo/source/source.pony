use "wallaroo/metrics"
use "wallaroo/topology"
use "wallaroo/recovery"

trait val SourceBuilder
  fun name(): String
  fun apply(event_log: EventLog, auth: AmbientAuth, target_router: Router val):
    SourceNotify iso^
  fun val update_router(router: Router val): SourceBuilder val

interface val SourceBuilderBuilder
  fun name(): String
  fun apply(runner_builder: RunnerBuilder val, router: Router val,
    metrics_conn: MetricsSink, pre_state_target_id: (U128 | None) = None,
    worker_name: String,
    metrics_reporter: MetricsReporter iso):
      SourceBuilder val
  fun host(): String
  fun service(): String

interface SourceInformation[In: Any val]
  fun source_listener_builder_builder(): SourceListenerBuilderBuilder val

  fun source_builder(app_name: String, name: String):
    SourceBuilderBuilder
