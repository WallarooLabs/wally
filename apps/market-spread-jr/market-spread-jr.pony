use "collections"
use "net"
use "buffered"
use "options"
use "time"
use "sendence/fix"
use "sendence/new-fix"

class NbboNotify is TCPConnectionNotify
  let _state1: State
  let _state2: State
  let _metrics: Metrics
  let _expected: USize
  var _header: Bool = true
  var _count: USize = 0

  new iso create(state1: State, state2: State, metrics: Metrics, expected: USize) =>
    _state1 = state1
    _state2 = state2
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
        let  m = FixishMsgDecoder.nbbo(consume data)
        if (m.symbol()(3) < 78) then
          _state1.nbbo(m)
        else
          _state2.nbbo(m)
        end
      else
        @printf[I32]("Error parsing Fixish\n".cstring())
      end

      conn.expect(4)
      _header = true


      if _count == _expected then
        _metrics.set_end(Time.nanos(), _expected)
      end
    end
    false

  fun ref accepted(conn: TCPConnection ref) =>
    @printf[None]("accepted\n".cstring())
    conn.expect(4)

  fun ref connected(sock: TCPConnection ref) =>
    @printf[None]("incoming connected\n".cstring())

class OrderNotify is TCPConnectionNotify
  let _state1: State
  let _state2: State
  let _metrics: Metrics
  let _expected: USize
  var _header: Bool = true
  var _count: USize = 0

  new iso create(state1: State, state2: State, metrics: Metrics, expected: USize) =>
    _state1 = state1
    _state2 = state2
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
        let  m = FixishMsgDecoder.order(consume data)
        if (m.symbol()(3) < 78) then
          _state1.order(m)
        else
          _state2.order(m)
        end
      else
        @printf[I32]("Error parsing Fixish\n".cstring())
      end

      conn.expect(4)
      _header = true

      if _count == _expected then
        _metrics.set_end(Time.nanos(), _expected)
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

  let symbols: Map[String, (Bool, F64, F64)] = Map[String, (Bool, F64, F64)](350)
  var _count: USize = 0
  var _order_count: USize = 0
  var _rejections: USize = 0

  new create(outgoing: TCPConnection, metrics: Metrics, expected: USize) =>
    _outgoing = outgoing
    _metrics = metrics
    _expected = expected

  be nbbo(msg: FixNbboMessage val) =>
    // assumes everything is nbbo at the moment
    let offer_bid_difference = msg.offer_px() - msg.bid_px()
    if (offer_bid_difference >= 0.05) or ((offer_bid_difference / msg.mid()) >= 0.05) then
      symbols.update(msg.symbol(),
        (true, msg.bid_px(), msg.offer_px()))
    else
      symbols.update(msg.symbol(),
        (false, msg.bid_px(), msg.offer_px()))
    end

    _count = _count + 1
    //if _count == _expected then
    //  _metrics.set_end(Time.nanos(), _expected)
    //end
    if (_count % 100_000)  == 0 then
      @printf[None]("nbbo: %zu %zu %zu\n".cstring(), _count, symbols.space(), symbols.size())
    end

  be order(msg: FixOrderMessage val) =>
    /*
    let d = symbols.sean(msg.symbol())
    let market_data_entry = if d is None then
      (true, 0, 0)
    else
      d
    end
    */

    let market_data_entry =
      if symbols.contains(msg.symbol()) then
        try
          symbols(msg.symbol())
        else
          (true, 0, 0)
        end
      else
        (true, 0, 0)
      end

    if market_data_entry._1 == true then
      _rejections = _rejections + 1
    end
    //if _count == _expected then
    //  _metrics.set_end(Time.nanos(), _expected)
    //end
    _order_count = _order_count + 1
    if (_order_count % 100_000)  == 0 then
      @printf[None]("orders: %zu\n".cstring(), _order_count)
    end
///
/// YAWN from here on down
///

actor Main
  new create(env: Env) =>
    var i_arg: (Array[String] | None) = None
    var j_arg: (Array[String] | None) = None
    var o_arg: (Array[String] | None) = None
    var expected: USize = 1_000_000

    try
      var options = Options(env)

      options
        .add("nbbo", "i", StringArgument)
        .add("order", "j", StringArgument)
        .add("out", "o", StringArgument)
        .add("expected", "e", I64Argument)

      for option in options do
        match option
        | ("nbbo", let arg: String) => i_arg = arg.split(":")
        | ("order", let arg: String) => j_arg = arg.split(":")
        | ("out", let arg: String) => o_arg = arg.split(":")
        | ("expected", let arg: I64) => expected = arg.usize()
        end
      end

      let i_addr = i_arg as Array[String]
      let j_addr = j_arg as Array[String]
      let out_addr = o_arg as Array[String]
      let metrics1 = Metrics("NBBO")
      let metrics2 = Metrics("Orders")

      let connect_auth = TCPConnectAuth(env.root as AmbientAuth)
      let out_socket = TCPConnection(connect_auth,
            OutNotify,
            out_addr(0),
            out_addr(1))

      let state1 = State(out_socket, metrics1, expected)
      let state2 = State(out_socket, metrics2, expected)
      let listen_auth = TCPListenAuth(env.root as AmbientAuth)
      let nbbo = TCPListener(listen_auth,
            NbboListenerNotify(state1, state2, metrics1, expected),
            i_addr(0),
            i_addr(1))

      let order = TCPListener(listen_auth,
            OrderListenerNotify(state1, state2, metrics2, (expected/2)),
            j_addr(0),
            j_addr(1))

      @printf[I32]("Expecting %zu total messages\n".cstring(), expected)
    end

class NbboListenerNotify is TCPListenNotify
  let _state1: State
  let _state2: State
  let _metrics: Metrics
  let _expected: USize

  new iso create(state1: State, state2: State, metrics: Metrics, expected: USize) =>
    _state1 = state1
    _state2 = state2
    _metrics = metrics
    _expected = expected

  fun ref connected(listen: TCPListener ref): TCPConnectionNotify iso^ =>
    NbboNotify(_state1, _state2, _metrics, _expected)

class OrderListenerNotify is TCPListenNotify
  let _state1: State
  let _state2: State
  let _metrics: Metrics
  let _expected: USize

  new iso create(state1: State, state2: State, metrics: Metrics, expected: USize) =>
    _state1 = state1
    _state2 = state2
    _metrics = metrics
    _expected = expected

  fun ref connected(listen: TCPListener ref): TCPConnectionNotify iso^ =>
    OrderNotify(_state1, _state2, _metrics, _expected)

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

primitive Bytes
  fun to_u32(a: U8, b: U8, c: U8, d: U8): U32 =>
    (a.u32() << 24) or (b.u32() << 16) or (c.u32() << 8) or d.u32()
