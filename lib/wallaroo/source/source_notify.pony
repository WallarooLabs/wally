use "collections"
use "wallaroo/boundary"
use "wallaroo/core"
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/recovery"
use "wallaroo/routing"
use "wallaroo/topology"

interface SourceHandler[In: Any val]
  fun decode(data: Array[U8] val): In ?

interface FramedSourceHandler[In: Any val]
  fun header_length(): USize
  fun payload_length(data: Array[U8] iso): USize ?
  fun decode(data: Array[U8] val): In ?

interface SourceNotify
  fun ref routes(): Array[Consumer] val

  fun ref update_router(router: Router val)

  fun ref update_boundaries(obs: box->Map[String, OutgoingBoundary])

interface val SourceNotifyBuilder[In: Any val, SH: SourceHandler[In] val]
  fun apply(pipeline_name: String, auth: AmbientAuth,
    handler: SH,
    runner_builder: RunnerBuilder val, router: Router val,
    metrics_reporter: MetricsReporter iso, event_log: EventLog,
    target_router: Router val, pre_state_target_id: (U128 | None) = None):
    SourceNotify iso^
