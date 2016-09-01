use "net"
use "time"
use "metrics"
use "buffered"
use "collections"

///
/// Junior-to-Senior
///

class SourceNotify is TCPConnectionNotify
  let _source: SourceRunner
  var _header: Bool = true

  new iso create(source: SourceRunner iso) =>
    _source = consume source

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso): Bool =>
    if _header then
      try
        let expect = Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()

        conn.expect(expect)
        _header = false
      end
    else
      _source.process(consume data)

      conn.expect(4)
      _header = true
    end
    false

  fun ref accepted(conn: TCPConnection ref) =>
    @printf[None]("accepted\n".cstring())
    conn.expect(4)

  fun ref connected(sock: TCPConnection ref) =>
    @printf[None]("incoming connected\n".cstring())

class SourceListenerNotify is TCPListenNotify
  let _source_builder: {(): Source iso^} val
  let _metrics: JrMetrics
  let _expected: USize

  new iso create(source_builder: {(): Source iso^} val, metrics: JrMetrics, 
    expected: USize) =>
    _source_builder = source_builder
    _metrics = metrics
    _expected = expected

  fun ref connected(listen: TCPListener ref): TCPConnectionNotify iso^ =>
    SourceNotify(SourceRunner(_source_builder(), _metrics, _expected))

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

actor StateRunner[State: Any #read]
  let _state: State
  let _metrics_reporter: MetricsReporter
  let _wb: Writer = Writer

  new create(state_builder: {(): State} val, 
    metrics_reporter: MetricsReporter iso) 
  =>
    _state = state_builder()
    _metrics_reporter = consume metrics_reporter

  be run[In: Any val](source_name: String val, source_ts: U64, input: In, computation: StateComputation[In, State] val) =>
    let computation_start = Time.nanos()
    computation(input, _state, _wb)
    let computation_end = Time.nanos()

    _metrics_reporter.pipeline_metric(source_name, source_ts)

    _metrics_reporter.step_metric(computation.name(),
      computation_start, computation_end)

interface Source
  fun name(): String val
  fun ref process(data: Array[U8 val] iso)

interface SourceParser[In: Any val]
  fun apply(data: Array[U8] iso): (In | None) ?

class StateSource[In: Any val, State: Any #read]
  let _name: String
  let _parser: SourceParser[In] val
  let _router: Router[In, StateRunner[State]]
  let _state_comp: StateComputation[In, State] val
  let _metrics_reporter: MetricsReporter

  new iso create(name': String, parser: SourceParser[In] val, 
    router: Router[In, StateRunner[State]] iso, 
    state_comp: StateComputation[In, State] val,
    metrics_reporter: MetricsReporter iso) =>
    _name = name'
    _parser = parser
    _router = consume router
    _state_comp = state_comp
    _metrics_reporter = consume metrics_reporter

  fun name(): String val => _name

  fun ref process(data: Array[U8 val] iso) =>
    let ingest_ts = Time.nanos()
    try
      // For recording metrics for filtered messages
      let computation_start = Time.nanos()

      match _parser(consume data)
      | let input: In =>
        match _router.route(input)
        | let p: StateRunner[State] tag =>
          p.run[In](_name, ingest_ts, input, _state_comp)
        else
          // drop data that has no partition
          //@printf[I32]((_name + ": Fake logging lack of partition\n").cstring())
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

interface Sink
  be process[D: Any val](data: D)

interface Router[In: Any val, RoutesTo: Any tag]
  fun route(input: In): (RoutesTo | None)

interface StateComputation[In: Any val, State: Any #read]
  fun apply(input: In, state: State, wb: (Writer | None)): None
  fun name(): String

primitive Bytes
  fun to_u32(a: U8, b: U8, c: U8, d: U8): U32 =>
    (a.u32() << 24) or (b.u32() << 16) or (c.u32() << 8) or d.u32()

actor JrMetrics
  var start_t: U64 = 0
  var next_start_t: U64 = 0
  var end_t: U64 = 0
  var last_report: U64 = 0
  let _name: String
  new create(name: String) =>
    _name = name

  be set_start(s: U64) =>
    if start_t != 0 then
      next_start_t = s
    else
      start_t = s
    end
    @printf[I32]("Start: %zu\n".cstring(), start_t)

  be set_end(e: U64, expected: USize) =>
    end_t = e
    let overall = (end_t - start_t).f64() / 1_000_000_000
    let throughput = ((expected.f64() / overall) / 1_000).usize()
    @printf[I32]("%s End: %zu\n".cstring(), _name.cstring(), end_t)
    @printf[I32]("%s Overall: %f\n".cstring(), _name.cstring(), overall)
    @printf[I32]("%s Throughput: %zuk\n".cstring(), _name.cstring(), throughput)
    start_t = next_start_t
    next_start_t = 0
    end_t = 0

  be report(r: U64, s: U64, e: U64) =>
    last_report = (r + s + e) + last_report

