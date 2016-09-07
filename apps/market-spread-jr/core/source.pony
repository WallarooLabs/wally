use "net"
use "time"
use "buffered"
use "collections"
use "../metrics"

class SourceRunner
  let _source: Source
  let _metrics: JrMetrics
  let _expected: USize
  var _count: USize = 0

  new iso create(source: Source iso, metrics: JrMetrics, expected: USize) =>
    _source = consume source
    _metrics = metrics
    _expected = expected

  fun ref process(data: Array[U8 val] iso) =>
    _begin_tracking()
    _source.process(consume data)
    _end_tracking()

  fun ref _begin_tracking() =>
    _count = _count + 1
    if _count == 1 then
      _metrics.set_start(Time.nanos())
    end
    if (_count % 1_000_000) == 0 then
      @printf[None]("%s %zu\n".cstring(), _source.name().null_terminated().cstring(), _count)
    end

  fun ref _end_tracking() =>
    if _count == _expected then
      _metrics.set_end(Time.nanos(), _expected)
    end

interface Source
  fun name(): String val
  fun ref process(data: Array[U8 val] iso)

interface SourceParser[In: Any val]
  fun apply(data: Array[U8] val): (In | None) ?

class StateSource[In: Any val, State: Any #read]
  let _name: String
  let _parser: SourceParser[In] val
  let _router: Router[In, StateRunner[State]]
  let _state_comp: StateComputation[In, State] val
  let _metrics_reporter: MetricsReporter

  new iso create(name': String, parser: SourceParser[In] val, 
    router: Router[In, StateRunner[State]] iso, 
    state_comp: StateComputation[In, State] val,
    metrics_reporter: MetricsReporter iso,
    initial_msgs: Array[Array[U8] val] val = 
      recover Array[Array[U8] val] end) =>
    _name = name'
    _parser = parser
    _router = consume router
    _state_comp = state_comp
    _metrics_reporter = consume metrics_reporter
    for msg in initial_msgs.values() do
      process(msg)
    end

  fun name(): String val => _name

  fun ref process(data: Array[U8] val) =>
    let ingest_ts = Time.nanos()
    try
      // For recording metrics for filtered messages
      let computation_start = Time.nanos()

      match _parser(consume data)
      | let input: In =>
        match _router.route(input)
        | let p: StateRunner[State] tag =>
          let processor = 
            StateComputationWrapper[In, State](input, _state_comp)
          p.run[StateProcessor[State] val](_name, ingest_ts, processor)
        else
          // drop data that has no partition
          @printf[I32]((_name + ": Fake logging lack of partition\n").cstring())
          None
        end
      else
        // If parser returns None, we're filtering the message out already
        let computation_end = Time.nanos()
        _metrics_reporter.pipeline_metric(_name, ingest_ts)

        _metrics_reporter.step_metric(_state_comp.name(),
          computation_start, computation_end)
      end
    else 
      @printf[I32]((_name + ": Problem parsing source input\n").cstring())
    end