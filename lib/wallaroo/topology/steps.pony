use "buffered"
use "time"
use "net"
use "sendence/epoch"
use "wallaroo/metrics"

actor Step
  let _runner: Runner
  var _router: Router val = EmptyRouter

  new create(runner: Runner iso) =>
    _runner = consume runner

  be update_router(router: Router val) =>
    _router = router

  be run[D: Any val](metric_name: String, source_ts: U64, data: D) =>
    _runner.run[D](metric_name, source_ts, data, _router)

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

  new create(r: RunnerSequenceBuilder val, id': U128) =>
    _runner_sequence_builder = r
    _id = id'

  fun id(): U128 => _id

  fun apply(next: Router val, metrics_conn: TCPConnection,
    pipeline_name: String): Step tag =>
    let runner = _runner_sequence_builder(MetricsReporter(pipeline_name, 
      metrics_conn))
    // let runner = ComputationRunner[In, Out](_computation_builder(),
      // consume next, MetricsReporter(pipeline_name, metrics_conn))
    let step = Step(consume runner)
    step.update_router(next)
    step
