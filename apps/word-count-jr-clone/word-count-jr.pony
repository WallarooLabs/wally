use "buffered"
use "collections"
use "net"
use "options"
use "regex"
use "time"
use "sendence/guid"

class IncomingNotify is TCPConnectionNotify
  let _state: State tag
  let _metrics: Metrics
  let _expected: USize
  var _header: Bool = true
  var _count: USize = 0
  let _guid_gen: GuidGenerator = GuidGenerator

  var _msg_count: USize = 0

  new iso create(state: State tag, metrics: Metrics, expected: USize) =>
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
        //if (_count % 100_000) == 0 then
        //  @printf[None]("%zu received\n".cstring(), _count)
        //end
        if _count == _expected then
          _metrics.set_end(Time.nanos(), _expected)
        end

        let expect = Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()

        conn.expect(expect)
        _header = false
      end
    else
      if _count <= _expected then
        let now = Time.cycles()

        _state.run(_guid_gen(), now, now, consume data)
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

class WordCount
  let word: String
  let count: U32

  new val create(w: String, c: U32) =>
    word = w
    count = c

  fun apply(state: WordCountTotals ref): WordCount val =>
    state(word, count)

actor State
  let _wct: WordCountTotals

  var _count: USize = 0
  let _expected: USize
  let _sender: TCPConnection
  let _metrics: Metrics

  new create(sender: TCPConnection, metrics: Metrics, expected: USize) =>
    _wct = WordCountTotals
    _sender = sender
    _expected = expected
    _metrics = metrics

  be run(a: U64, b: U64, c: U64, od: Array[U8] iso) =>
    _count = _count + 1

    let string = Converter(consume od)

    for word in string.split(" ").values() do
      if word.size() > 0 then
        let computation = WordCount(word, 1)
        let wc = computation(_wct)

        let dws = 4 + 4 + wc.word.size()
        let dws' = dws.u32()
        var current: Array[U8] iso = recover Array[U8](1) end

        current.push((dws' >> 24).u8())
        /*current.push((dws' >> 16).u8())
        current.push((dws' >> 8).u8())
        current.push(dws'.u8())
        current.push((wc.count >> 24).u8())
        current.push((wc.count >> 16).u8())
        current.push((wc.count >> 8).u8())
        current.push(wc.count.u8())
        current.append(wc.word)*/

        _sender.write("hi")
      end
    end

    if (_count % 1_000_000) == 0 then
      @printf[None]("%zu received\n".cstring(), _count)
    end

primitive Converter
  fun apply(input: Array[U8] iso): String =>
    recover String.from_iso_array(consume input).lower_in_place() end

class WordCountTotals
  let words: Map[String, U32] = Map[String, U32](50_000)

  fun ref apply(word: String, count: U32): WordCount val =>

    try
      let x = words.upsert(word, count,
        lambda(x1: U32, x2: U32): U32 => x1 + x2 end)

      WordCount(word, x)
    else
      WordCount(word, count)
    end

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
      let metrics2 = Metrics

      let connect_auth = TCPConnectAuth(env.root as AmbientAuth)
      let out_socket = TCPConnection.ip4(connect_auth,
            OutNotify,
            out_addr(0),
            out_addr(1))

      // These are the "Steps".
      //let last = Last(out_socket, metrics, expected)
      let state = State(out_socket, metrics, expected)
      let state2 = State(out_socket, metrics2, expected)
      //let first = First(state)

      let listen_auth = TCPListenAuth(env.root as AmbientAuth)
      let listener = TCPListener(listen_auth,
            ListenerNotify(state, metrics, expected),
            in_addr(0),
            in_addr(1))

      @printf[I32]("Expecting %zu messages\n".cstring(), expected)
    end

class ListenerNotify is TCPListenNotify
  let _fp: State tag
  let _metrics: Metrics
  let _expected: USize

  new iso create(fp: State tag, metrics: Metrics, expected: USize) =>
    _fp = fp
    _metrics = metrics
    _expected = expected

  fun ref connected(listen: TCPListener ref): TCPConnectionNotify iso^ =>
    IncomingNotify(_fp, _metrics, _expected)

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

  be report(r: U64, s: U64, e: U64) => last_report = (r + s + e) + last_report

primitive Bytes
  fun to_u32(a: U8, b: U8, c: U8, d: U8): U32 =>
    (a.u32() << 24) or (b.u32() << 16) or (c.u32() << 8) or d.u32()
