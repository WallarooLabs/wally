use "collections"
use "net"
use "buffered"
use "options"
use "time"
use "sendence/fix"
use "sendence/new-fix"

class IncomingNotify is TCPConnectionNotify
  let _state: State
  let _metrics: Metrics
  let _expected: USize
  var _header: Bool = true
  var _count: USize = 0

  new iso create(state: State, metrics: Metrics, expected: USize) =>
    _state = state
    _metrics = metrics
    _expected = expected

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso): Bool =>
    if _header then
      try
        _count = _count + 1

        if _count == 1 then
          _metrics.set_start(Time.nanos())
        end

        let expect = Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()

        conn.expect(expect)
        _header = false
      end
    else
      try
        let expect = Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()
        match FixishMsgDecoder(consume data)
        | let m: FixOrderMessage val =>
          _state.run(m)
        else
          @printf[I32]("Error parsing Fixish\n".cstring())
        end
      else
        @printf[I32]("Error parsing Fixish\n".cstring())
      end

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

actor State
  let _outgoing: TCPConnection
  let _metrics: Metrics
  let _expected: USize

  let symbols: Map[String, F64] = Map[String, F64](8192)
  var _count: USize = 0

  new create(outgoing: TCPConnection, metrics: Metrics, expected: USize) =>
    _outgoing = outgoing
    _metrics = metrics
    _expected = expected

  be run(order: FixOrderMessage val) =>
      // assumes everything is nbbo at the moment
      symbols.update(order.symbol(), order.price())

      _count = _count + 1
      if _count == _expected then
        _metrics.set_end(Time.nanos(), _expected)
      end

      // we dont currently have any real logic for checking
      // trades and nbbo

///
/// YAWN from here on down
///

actor Main
  new create(env: Env) =>
    var i_arg: (Array[String] | None) = None
    var o_arg: (Array[String] | None) = None
    var expected: USize = 1_000_000

    try
      var options = Options(env)

      options
        .add("in", "i", StringArgument)
        .add("out", "o", StringArgument)
        .add("expected", "e", I64Argument)

      for option in options do
        match option
        | ("in", let arg: String) => i_arg = arg.split(":")
        | ("out", let arg: String) => o_arg = arg.split(":")
        | ("expected", let arg: I64) => expected = arg.usize()
        end
      end

      let in_addr = i_arg as Array[String]
      let out_addr = o_arg as Array[String]
      let metrics = Metrics

      let connect_auth = TCPConnectAuth(env.root as AmbientAuth)
      let out_socket = TCPConnection(connect_auth,
            OutNotify,
            out_addr(0),
            out_addr(1))

      let state = State(out_socket, metrics, expected)
      let listen_auth = TCPListenAuth(env.root as AmbientAuth)
      let listener = TCPListener(listen_auth,
            ListenerNotify(state, metrics, expected),
            in_addr(0),
            in_addr(1))

      @printf[I32]("Expecting %zu total messages\n".cstring(), expected)
    end

class ListenerNotify is TCPListenNotify
  let _state: State
  let _metrics: Metrics
  let _expected: USize

  new iso create(state: State, metrics: Metrics, expected: USize) =>
    _state = state
    _metrics = metrics
    _expected = expected

  fun ref connected(listen: TCPListener ref): TCPConnectionNotify iso^ =>
    IncomingNotify(_state, _metrics, _expected)

actor Metrics
  var start_t: U64 = 0
  var next_start_t: U64 = 0
  var end_t: U64 = 0
  var last_report: U64 = 0

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
    @printf[I32]("End: %zu\n".cstring(), end_t)
    @printf[I32]("Overall: %f\n".cstring(), overall)
    @printf[I32]("Throughput: %zuk\n".cstring(), throughput)
    start_t = next_start_t
    next_start_t = 0
    end_t = 0

  be report(r: U64, s: U64, e: U64) =>
    last_report = (r + s + e) + last_report

primitive Bytes
  fun to_u32(a: U8, b: U8, c: U8, d: U8): U32 =>
    (a.u32() << 24) or (b.u32() << 16) or (c.u32() << 8) or d.u32()
