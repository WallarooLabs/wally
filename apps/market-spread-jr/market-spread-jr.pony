"""
JUNIOR (on its way to Senior)

Setting up a market spread run:
1) reports sink
nc -l 127.0.0.1 7002 >> /dev/null

2) metrics sink
nc -l 127.0.0.1 7003 >> /dev/null

3) Junior itself (market spread)
apps/market-spread-jr/market-spread-jr -i 127.0.0.1:7000 -j 127.0.0.1:7001 -o 127.0.0.1:7002 -m 127.0.0.1:7003 -e 10000000

4) orders:
giles/sender -b 127.0.0.1:7001 -m 5000000 -s 300 -i 5_000_000 -f demos/marketspread/1000trades-fixish.msg --ponythreads=1 -y -g 57

5) nbbo:
giles/sender -b 127.0.0.1:7000 -m 10000000 -s 300 -i 2_500_000 -f demos/marketspread/1000nbbo-fixish.msg --ponythreads=1 -y -g 47

Baseline using Junior metrics (on John's 4 core, Sean sees similar):
20-30mb of memory used
70k/sec Trades throughput
120-140k/sec NBBO throughput
"""
use "collections"
use "net"
use "time"
use "sendence/fix"
use "sendence/new-fix"
use "sendence/hub"
use "metrics"
use "buffered"

//
// State handling
//

class SymbolData
  var should_reject_trades: Bool = true
  var last_bid: F64 = 0
  var last_offer: F64 = 0

primitive UpdateNBBO is StateComputation[FixNbboMessage val, SymbolData]
  fun name(): String =>
    "Update NBBO"

  fun apply(msg: FixNbboMessage val, state: SymbolData, wb: (Writer | None)) =>
    let offer_bid_difference = msg.offer_px() - msg.bid_px()

    state.should_reject_trades = (offer_bid_difference >= 0.05) or
      ((offer_bid_difference / msg.mid()) >= 0.05)

    state.last_bid = msg.bid_px()
    state.last_offer = msg.offer_px()

class CheckOrder is StateComputation[FixOrderMessage val, SymbolData]
  let _conn: TCPConnection tag

  new val create(conn: TCPConnection tag) =>
    _conn = conn

  fun name(): String =>
    "Check Order against NBBO"

  fun apply(msg: FixOrderMessage val, state: SymbolData,
    wb: (Writer | None)) =>
    if state.should_reject_trades then
      let result = OrderResult(msg, state.last_bid, state.last_offer,
        Time.nanos())
      match wb
      | let w: Writer =>
        _conn.writev(OrderResultEncoder(result, w))
      else
        @printf[I32]("No write buffer for some reason\n".cstring())
      end
    end

class NBBOSource is Source
  let _router: SymbolRouter

  new val create(router: SymbolRouter iso) =>
    _router = consume router

  fun name(): String val =>
    "Nbbo source"

  fun process(data: Array[U8 val] iso) =>
    // A lot of this needs to be moved out into more generic code
    let ingest_ts = Time.nanos()
    let m = FixishMsgDecoder.nbbo(consume data)

    match _router.route(m.symbol())
    | let p: StateHandler[SymbolData] tag =>
      p.run[FixNbboMessage val](name(), ingest_ts, m, UpdateNBBO)
    else
      // drop data that has no partition
      @printf[None]("NBBO Source: Fake logging lack of partition for %s\n".cstring(), m.symbol().null_terminated().cstring())
    end

class OrderSource is Source
  let _router: SymbolRouter
  let _state_comp: CheckOrder val

  new val create(router: SymbolRouter iso, state_comp: CheckOrder val) =>
    _router = consume router
    _state_comp = state_comp

  fun name(): String val =>
    "Order source"

  fun process(data: Array[U8 val] iso) =>
    // I DONT LIKE THAT ORDER THROWS AN ERROR IF IT ISNT AN ORDER
    // BUT.... when we are processing trades in general, this would
    // probably make us really slow because of tons of errors being
    // thrown. Use apply here?
    // FIXISH decoder has a broken API, because I could hand an
    // order to nbbo and it would process it. :(
    try
      let ingest_ts = Time.nanos()
      let m = FixishMsgDecoder.order(consume data)

      match _router.route(m.symbol())
      | let p: StateHandler[SymbolData] tag =>
        p.run[FixOrderMessage val](name(), ingest_ts, m, _state_comp)
      else
        // DONT DO THIS RIGHT NOW BECAUSE WE HAVE BAD DATA
        // AND THIS FLOODS STDOUT

        // drop data that has no route
        //@printf[None]("Order source: Fake logging lack of route for %s\n".cstring(), m.symbol().null_terminated().cstring())
        None
      end
    else
      // drop bad data that isn't an order
      @printf[None]("Order Source: Fake logging bad data a message\n".cstring())
    end

class SymbolRouter is Router[String, StateRunner[SymbolData]]
  let _routes: Map[String, StateRunner[SymbolData]] val

  new iso create(routes: Map[String, StateRunner[SymbolData]] val) =>
    _routes = routes

  fun route(symbol: String): (StateRunner[SymbolData] | None) =>
    if _routes.contains(symbol) then
      try
        _routes(symbol)
      end
    end

class OnlyRejectionsRouter is Router[Bool, TCPConnection]
  let _sink: TCPConnection

  new iso create(sink: TCPConnection) =>
    _sink = sink

  fun route(rejected: Bool): (TCPConnection | None)  =>
    if rejected then _sink end

class OrderResult
  let order: FixOrderMessage val
  let bid: F64
  let offer: F64
  let timestamp: U64

  new val create(order': FixOrderMessage val,
    bid': F64,
    offer': F64,
    timestamp': U64)
  =>
    order = order'
    bid = bid'
    offer = offer'
    timestamp = timestamp'

  fun string(): String =>
    (order.symbol().clone().append(order.order_id())
      .append(order.account().string())
      .append(order.price().string()).append(order.order_qty().string())
      .append(order.side().string()).append(bid.string()).append(offer.string())
      .append(timestamp.string())).clone()

primitive OrderResultEncoder
  fun apply(r: OrderResult val, wb: Writer = Writer): Array[ByteSeq] val =>
    //Header (size == 55 bytes)
    let msgs_size: USize = 1 + 4 + 6 + 4 + 8 + 8 + 8 + 8 + 8
    wb.u32_be(msgs_size.u32())
    //Fields
    match r.order.side()
    | Buy => wb.u8(SideTypes.buy())
    | Sell => wb.u8(SideTypes.sell())
    end
    wb.u32_be(r.order.account())
    wb.write(r.order.order_id().array()) // assumption: 6 bytes
    wb.write(r.order.symbol().array()) // assumption: 4 bytes
    wb.f64_be(r.order.order_qty())
    wb.f64_be(r.order.price())
    wb.f64_be(r.bid)
    wb.f64_be(r.offer)
    wb.u64_be(r.timestamp)
    let payload = wb.done()
    HubProtocol.payload("rejected-orders", "reports:market-spread", 
      consume payload, wb)


//actor Reporter is Sink
//   let _conn: TCPConnection

//   new create(conn: TCPConnection) =>
//     _conn = conn

//   be process[D: Any val](data: D) =>
//     match data
//     | let b: ByteSeq => _conn.write(b)
//     end
