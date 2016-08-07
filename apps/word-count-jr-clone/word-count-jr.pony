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
        if ((_count % 100_000) == 0) and (_count <= _expected) then
          @printf[I32]("%zu received\n".cstring(), _count)
        end

        if _count == 1 then
          _metrics.set_start(Time.nanos())
        end
        // if _count == 1_000_000 then
        //   _count = 0
        // end
        let expect = Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()

        conn.expect(expect)
        _header = false
      end
    else
      if _count <= _expected then
        let now = Time.cycles()//Epoch.nanoseconds()

        _state.run(_guid_gen(), now, now, consume data)
      else
        _count = 0
      end

      conn.expect(4)
      _header = true

      _msg_count = _msg_count + 1
      if _msg_count >= 100 then
        return false
      end
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

actor First
  let _r: (Regex | None)
  let _state: State

  new create(s: State) =>
    _r = try Regex("[\\W_]+") else None end
    _state = s

  be run(a: U64, b: U64, c: U64, data: String) =>
    /*
    let updated_d = match _r
      | let r: Regex =>
        try r.replace(data, " " where global = true) else data end
      else data end


    for word in data.split(" ").values() do
      let next = _lower(data)
      if next.size() > 0 then
        _state.run(WordCount(data, 1))
      end
    end
    */
    None


  fun _lower(s: String): String =>
    recover s.lower() end

class WordCount
  let word: String
  let count: U64

  new val create(w: String, c: U64) =>
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
  let buffer: Writer = Writer
  let _size: USize = 64
  let words: Map[String, U64] = Map[String, U64]

  new create(sender: TCPConnection, metrics: Metrics, expected: USize) =>
    _wct = WordCountTotals
    _sender = sender
    _expected = expected
    _metrics = metrics
    buffer.reserve_chunks(_size)

  be run(a: U64, b: U64, c: U64, od: Array[U8] val) =>
    let string = Converter(od)

    for word in string.split(" ").values() do
      let next = _lower(word)
      if next.size() > 0 then
        let computation = WordCount(next, 1)
        let data = computation(_wct)
        _count = _count + 1
        if (_count % 100_000) == 0 then
          @printf[I32]("%zu sent\n".cstring(), _count)
        end
        // if (_count % 1_000_000) == 0 then
        //   // @printf[I32]("%zu sent\n".cstring(), _count)
        //   @printf[None]("%s is at %zu\n".cstring(), data.word.cstring(), data.count)
        // end

        //if (_count % _size) == 0 then
        //  buffer.reserve_chunks(_size)
        //end

/*
        let cs: String val = data.count.string()
        var current: Array[U8] iso = recover Array[U8](data.word.size() + 1 + cs.size() + 4) end
        current.append(data.word)
        current.append("=")
        current.append(cs)
        //buffer.u32_be((s.size() + 8).u32())
        //Message size field
        //buffer.u32_be((s.size() + 4).u32())
        buffer.u32_be(data.word.size().u32())
        buffer.write(consume current)
        if (_count % _size) == 0 then
          _sender.writev(buffer.done())
        end
*/

        Sender(_sender, data)

        if _count == _expected then
          _metrics.set_end(Time.nanos(), _expected)
          _count = 0
        end
      end
    end

  fun _lower(s: String): String =>
    recover s.lower() end

primitive Converter
  fun apply(input: Array[U8] val): String =>
    String.from_array(input)

primitive Sender
  fun apply(sender: TCPConnection tag, data: WordCount val) =>
        // try
          let cs: String val = data.count.string()
          let dws = data.word.size() + cs.size() + 1
          var current: Array[U8] iso = recover Array[U8](dws + 4) end
          let dws' = dws.u32()
          current.push((dws' >> 24).u8())
          current.push((dws' >> 16).u8())
          current.push((dws' >> 8).u8())
          current.push(dws'.u8())
          current.append(data.word)
          current.append("=")
          current.append(cs)

          sender.write(consume current)
        // else
        //   @printf[I32]("Problem sending!\n".cstring())
        // end

class WordCountTotals
  let words: Map[String, U64] = Map[String, U64]

  fun ref apply(word: String, count: U64): WordCount val =>
    try
     let new_count = words.upsert(word, count,
      lambda(x1: U64, x2: U64): U64 => x1 + x2 end)

      WordCount(word, new_count)
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
      let out_socket = TCPConnection(connect_auth,
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
  fun length_encode(data: ByteSeq val): Array[ByteSeq] val =>
    let len: U32 = data.size().u32()
    let wb = Writer
    wb.u32_be(len)
    wb.write(data)
    wb.done()

  fun to_u16(high: U8, low: U8): U16 =>
    (high.u16() << 8) or low.u16()

  fun to_u32(a: U8, b: U8, c: U8, d: U8): U32 =>
    (a.u32() << 24) or (b.u32() << 16) or (c.u32() << 8) or d.u32()

  fun to_u64(a: U8, b: U8, c: U8, d: U8, e: U8, f: U8, g: U8, h: U8): U64 =>
    (a.u64() << 56) or (b.u64() << 48) or (c.u64() << 40) or (d.u64() << 32)
    or (e.u64() << 24) or (f.u64() << 16) or (g.u64() << 8) or h.u64()

  fun from_u16(u16: U16, arr: Array[U8] iso = recover Array[U8] end): Array[U8] iso^ =>
    let l1: U8 = (u16 and 0xFF).u8()
    let l2: U8 = ((u16 >> 8) and 0xFF).u8()
    arr.push(l2)
    arr.push(l1)
    consume arr

  fun from_u32(u32: U32, arr: Array[U8] iso = recover Array[U8] end): Array[U8] iso^ =>
    let l1: U8 = (u32 and 0xFF).u8()
    let l2: U8 = ((u32 >> 8) and 0xFF).u8()
    let l3: U8 = ((u32 >> 16) and 0xFF).u8()
    let l4: U8 = ((u32 >> 24) and 0xFF).u8()
    arr.push(l4)
    arr.push(l3)
    arr.push(l2)
    arr.push(l1)
    consume arr

  fun from_u64(u64: U64, arr: Array[U8] iso = recover Array[U8] end): Array[U8] iso^ =>
    let l1: U8 = (u64 and 0xFF).u8()
    let l2: U8 = ((u64 >> 8) and 0xFF).u8()
    let l3: U8 = ((u64 >> 16) and 0xFF).u8()
    let l4: U8 = ((u64 >> 24) and 0xFF).u8()
    let l5: U8 = ((u64 >> 32) and 0xFF).u8()
    let l6: U8 = ((u64 >> 40) and 0xFF).u8()
    let l7: U8 = ((u64 >> 48) and 0xFF).u8()
    let l8: U8 = ((u64 >> 56) and 0xFF).u8()
    arr.push(l8)
    arr.push(l7)
    arr.push(l6)
    arr.push(l5)
    arr.push(l4)
    arr.push(l3)
    arr.push(l2)
    arr.push(l1)
    consume arr

  fun u16_from_idx(idx: USize, arr: Array[U8]): U16 ? =>
    Bytes.to_u16(arr(idx), arr(idx + 1))

  fun u32_from_idx(idx: USize, arr: Array[U8]): U32 ? =>
    Bytes.to_u32(arr(idx), arr(idx + 1), arr(idx + 2), arr(idx + 3))

  fun u64_from_idx(idx: USize, arr: Array[U8]): U64 ? =>
    Bytes.to_u64(arr(idx), arr(idx + 1), arr(idx + 2), arr(idx + 3),
      arr(idx + 4), arr(idx + 5), arr(idx + 6), arr(idx + 7))
