use "buffered"
use "time"
use "net"
use "sendence/epoch"
use "wallaroo/backpressure"
use "wallaroo/metrics"

trait RunnableStep
  be run[D: Any val](metric_name: String, source_ts: U64, data: D)

actor Step is (RunnableStep & CreditFlowProducer)
  let _runner: Runner
  var _router: Router val
  let _metrics_reporter: MetricsReporter 

  new create(runner: Runner iso, metrics_reporter: MetricsReporter iso,
    router: Router val = EmptyRouter) =>
    _runner = consume runner
    _metrics_reporter = consume metrics_reporter
    _router = router

  be update_router(router: Router val) =>
    _router = router

  be run[D: Any val](metric_name: String, source_ts: U64, data: D) =>
    let is_finished = _runner.run[D](metric_name, source_ts, data, this,
      _router)

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

  // Credit Flow  
  // TODO: Add implementation
  be receive_credits(credits: USize, from: CreditFlowConsumer) =>
    None
    
  fun ref credit_used(c: CreditFlowConsumer, num: USize = 1) =>
    None

interface StepBuilder
  fun id(): U128

//   fun apply(next: Router val, metrics_conn: TCPConnection,
//     pipeline_name: String): Step tag

// trait ThroughStepBuilder[In: Any val, Out: Any val] is StepBuilder

class StepBuilder
  let _runner_sequence_builder: RunnerSequenceBuilder val
  let _id: U128
  let _is_stateful: Bool

  new val create(r: RunnerSequenceBuilder val, id': U128,
    is_stateful': Bool = false) =>
    _runner_sequence_builder = r
    _id = id'
    _is_stateful = is_stateful'

  fun id(): U128 => _id
  fun is_stateful(): Bool => _is_stateful

  fun apply(next: Router val, metrics_conn: TCPConnection,
    pipeline_name: String, router: Router val = EmptyRouter): Step tag =>
    let runner = _runner_sequence_builder(MetricsReporter(pipeline_name, 
      metrics_conn), router)
    let step = Step(consume runner, 
      MetricsReporter(pipeline_name, metrics_conn), router)
    step.update_router(next)
    step
