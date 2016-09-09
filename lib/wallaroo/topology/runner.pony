use "buffered"
use "time"
use "sendence/epoch"
use "../metrics"

interface Runner
  fun ref run[In: Any val](metric_name: String, source_ts: U64, input: In)

class iso SimpleSink
  fun ref run[In: Any val](metric_name: String, source_ts: U64, input: In) =>
    match input
    | let s: Stringable val =>
      @printf[I32](("Simple sink: Received " + s.string() + "\n").cstring())
    else
      @printf[I32]("Simple sink: Got it!\n".cstring())
    end

class ComputationRunner[In: Any val, Out: Any val]
  let _computation: Computation[In, Out] val
  let _computation_name: String
  let _target: Step tag
  let _metrics_reporter: MetricsReporter

  new iso create(computation: Computation[In, Out] val, 
    target: Step tag,
    metrics_reporter: MetricsReporter iso) 
  =>
    _computation = computation
    _computation_name = _computation.name()
    _target = target
    _metrics_reporter = consume metrics_reporter

  fun ref run[D: Any val](source_name: String val, source_ts: U64, input: D) 
  =>
    let computation_start = Epoch.nanoseconds()
    match input
    | let i: In =>
      match _computation(i)
      | let output: Out =>
        _target.run[Out](source_name, source_ts, output)
      else
        _metrics_reporter.pipeline_metric(source_name, source_ts)
      end

      let computation_end = Epoch.nanoseconds()   

      _metrics_reporter.step_metric(_computation_name,
        computation_start, computation_end)
    end

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
      let computation_start = Epoch.nanoseconds()
      sp(_state, _wb)
      let computation_end = Epoch.nanoseconds()

      _metrics_reporter.pipeline_metric(source_name, source_ts)

      _metrics_reporter.step_metric(sp.name(),
        computation_start, computation_end)
    else
      @printf[I32]("StateRunner: Input was not a StateProcessor!\n".cstring())
    end
