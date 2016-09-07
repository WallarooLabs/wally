use "buffered"
use "time"
use "../metrics"

interface Step
  be run[In: Any val](metric_name: String, source_ts: U64, input: In)

actor StateRunner[State: Any #read]
  let _state: State
  let _metrics_reporter: MetricsReporter
  let _wb: Writer = Writer

  new create(state_builder: {(): State} val, 
    metrics_reporter: MetricsReporter iso) 
  =>
    _state = state_builder()
    _metrics_reporter = consume metrics_reporter

  be run[In: Any val](source_name: String val, source_ts: U64, input: In) =>
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

interface Router[In: Any val, RoutesTo: Any tag]
  fun route(input: In): (RoutesTo | None)