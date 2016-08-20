use "net"
use "time"

///
/// Buffy-ness
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

class OutNotify is TCPConnectionNotify
  fun ref connected(sock: TCPConnection ref) =>
    @printf[None]("outgoing connected\n".cstring())

  fun ref throttled(sock: TCPConnection ref, x: Bool) =>
    if x then
      @printf[None]("outgoing throttled\n".cstring())
    else
      @printf[None]("outgoing no longerthrottled\n".cstring())
    end

class SourceListenerNotify is TCPListenNotify
  let _source: Source val
  let _metrics: Metrics
  let _expected: USize

  new iso create(source: Source val, metrics: Metrics, expected: USize) =>
    _source = source
    _metrics = metrics
    _expected = expected

  fun ref connected(listen: TCPListener ref): TCPConnectionNotify iso^ =>
    SourceNotify(SourceRunner(_source, _metrics, _expected))

class SourceRunner
  let _source: Source val
  let _metrics: Metrics
  let _expected: USize
  var _count: USize = 0

  new iso create(source: Source val, metrics: Metrics, expected: USize) =>
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
    if (_count % 500_000) == 0 then
      @printf[None]("%s %zu\n".cstring(), _source.name().null_terminated().cstring(), _count)
    end

  fun ref _end_tracking() =>
    if _count == _expected then
      _metrics.set_end(Time.nanos(), _expected)
    end

interface Source
  fun name(): String val
  fun process(data: Array[U8 val] iso)

interface Router[On: Any val, RoutesTo: Any tag]
  fun route(key: On): (RoutesTo | None)

interface StateHandler[State: Any ref]
  be run[In: Any val](input: In, computation: StateComputation[In, State] val)

interface StateComputation[In: Any val, State: Any #read]
  fun apply(input: In, state: State): None
  fun name(): String

/*
// Actual buffy signature
interface StateComputation[In: Any val, Out: Any val, State: Any #read]
  fun apply(input: In, state: State, output: MessageTarget[Out] val)
    : State
  fun name(): String
*/

//
// SUPPORT
// Not so BUFFYNESS
//

primitive Bytes
  fun to_u32(a: U8, b: U8, c: U8, d: U8): U32 =>
    (a.u32() << 24) or (b.u32() << 16) or (c.u32() << 8) or d.u32()

actor Metrics
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

