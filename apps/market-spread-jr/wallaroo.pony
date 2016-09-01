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
  let _source: Source val
  let _metrics: JrMetrics
  let _expected: USize

  new iso create(source: Source val, metrics: JrMetrics, expected: USize) =>
    _source = source
    _metrics = metrics
    _expected = expected

  fun ref connected(listen: TCPListener ref): TCPConnectionNotify iso^ =>
    SourceNotify(SourceRunner(_source, _metrics, _expected))

class SourceRunner
  let _source: Source val
  let _metrics: JrMetrics
  let _expected: USize
  var _count: USize = 0

  new iso create(source: Source val, metrics: JrMetrics, expected: USize) =>
    _source = source
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
  let _metrics_socket: TCPConnection
  let _step_metrics_map: Map[String, MetricsReporter] =
    _step_metrics_map.create()
  let _pipeline_metrics_map: Map[String, MetricsReporter] =
    _pipeline_metrics_map.create()
  let _app_name: String
  let _wb: Writer = Writer

  new create(state_builder: {(): State} val, metrics_socket: TCPConnection, 
    app_name: String) =>
    _state = state_builder()
    _metrics_socket = metrics_socket
    _app_name = app_name

  be run[In: Any val](source_name: String val, source_ts: U64, input: In, computation: StateComputation[In, State] val) =>
    let computation_start = Time.nanos()
    computation(input, _state, _wb)
    let computation_end = Time.nanos()

    _record_pipeline_metrics(source_name, source_ts)

    _record_step_metrics(computation.name(),
      computation_start, computation_end)

  fun ref _record_step_metrics(name: String, start_ts: U64, end_ts: U64) =>
     let metrics = try
      _step_metrics_map(name)
    else
      let reporter =
        MetricsReporter(_metrics_socket, 1, _app_name, name, 
          ComputationCategory)
      _step_metrics_map(name) = reporter
      reporter
    end

    metrics.report(start_ts - end_ts)

  fun ref _record_pipeline_metrics(source_name: String val, source_ts: U64) =>
    let metrics = try
      _pipeline_metrics_map(source_name)
    else
      let reporter =
        MetricsReporter(_metrics_socket, 1, "market-spread", source_name, 
          StartToEndCategory)
      _pipeline_metrics_map(source_name) = reporter
      reporter
    end

    metrics.report(source_ts - Time.nanos())

interface Source
  fun name(): String val
  fun process(data: Array[U8 val] iso)

interface SourceParser[In: Any val]
  fun apply(data: Array[U8] iso): In ?

class StateSource[In: Any val, State: Any #read]
  let _name: String
  let _parser: SourceParser[In] val
  let _router: Router[In, StateRunner[State]]
  let _state_comp: StateComputation[In, State] val

  new val create(name': String, parser: SourceParser[In] val, 
    router: Router[In, StateRunner[State]] iso, 
    state_comp: StateComputation[In, State] val) =>
    _name = name'
    _parser = parser
    _router = consume router
    _state_comp = state_comp

  fun name(): String val => _name

  fun process(data: Array[U8 val] iso) =>
    let ingest_ts = Time.nanos()
    try
      let input = _parser(consume data)

      match _router.route(input)
      | let p: StateRunner[State] tag =>
        p.run[In](_name, ingest_ts, input, _state_comp)
      else
        // drop data that has no partition
        //@printf[I32]((_name + ": Fake logging lack of partition\n").cstring())
        None
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

