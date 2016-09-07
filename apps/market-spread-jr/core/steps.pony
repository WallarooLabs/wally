use "buffered"
use "time"
use "../metrics"

interface Router[In: Any val, RoutesTo: Any tag]
  fun route(input: In): (RoutesTo | None)

actor Step
  let _runner: Runner

  new create(runner: Runner iso) =>
    _runner = consume runner

  be run[In: Any val](metric_name: String, source_ts: U64, input: In) =>
    _runner.run[In](metric_name, source_ts, input)

interface Runner
  fun ref run[In: Any val](metric_name: String, source_ts: U64, input: In)

class StateRunner[State: Any #read]
  let _state: State
  let _metrics_reporter: MetricsReporter
  let _wb: Writer = Writer

  new iso create(state_builder: {(): State} val, 
    metrics_reporter: MetricsReporter iso) 
  =>
    _state = state_builder()
    _metrics_reporter = consume metrics_reporter

  fun ref run[In: Any val](source_name: String val, source_ts: U64, input: In) =>
    match input
    | let sp: StateProcessor[State] val =>
      let computation_start = Time.nanos()
      sp(_state, _wb)
      let computation_end = Time.nanos()

      _metrics_reporter.pipeline_metric(source_name, source_ts)

      _metrics_reporter.step_metric(sp.name(),
        computation_start, computation_end)
    else
      @printf[I32]("StateRunner: Input was not a StateProcessor!\n".cstring())
    end
