use "buffered"
use "time"
use "net"
use "sendence/epoch"
use "wallaroo/metrics"

actor Step
  let _runner: Runner
  var _router: Router val = EmptyRouter
  let _metrics_reporter: MetricsReporter 

  new create(runner: Runner iso, metrics_reporter: MetricsReporter iso) =>
    _runner = consume runner
    _metrics_reporter = consume metrics_reporter

  be update_router(router: Router val) =>
    _router = router

  be run[D: Any val](metric_name: String, source_ts: U64, data: D) =>
    let is_finished = _runner.run[D](metric_name, source_ts, data, _router)

    if is_finished then
      _metrics_reporter.pipeline_metric(metric_name, source_ts)
    end

  be dispose() =>
    match _router
    | let r: TCPRouter val =>
      r.dispose()
    // | let sender: DataSender =>
    //   sender.dispose()
    end

interface StepBuilder
  fun id(): U128

  fun apply(next: Router val, metrics_conn: TCPConnection,
    pipeline_name: String): Step tag

// trait ThroughStepBuilder[In: Any val, Out: Any val] is StepBuilder

class StatelessStepBuilder
  let _runner_sequence_builder: RunnerSequenceBuilder val
  let _id: U128

  new val create(r: RunnerSequenceBuilder val, id': U128) =>
    _runner_sequence_builder = r
    _id = id'

  fun id(): U128 => _id

  fun apply(next: Router val, metrics_conn: TCPConnection,
    pipeline_name: String): Step tag =>
    let runner = _runner_sequence_builder(MetricsReporter(pipeline_name, 
      metrics_conn))
    // let runner = ComputationRunner[In, Out](_computation_builder(),
      // consume next, MetricsReporter(pipeline_name, metrics_conn))
    let step = Step(consume runner, 
      MetricsReporter(pipeline_name, metrics_conn))
    step.update_router(next)
    step
