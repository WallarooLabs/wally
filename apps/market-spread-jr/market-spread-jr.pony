"""
Market Spread App

Setting up a market spread run (in order):
1) reports sink:
nc -l 127.0.0.1 7002 >> /dev/null

2) metrics sink:
nc -l 127.0.0.1 7003 >> /dev/null

3) market spread app:
./market-spread-jr -i 127.0.0.1:7000,127.0.0.1:7001 -o 127.0.0.1:7002 -m 127.0.0.1:7003 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -f ../../demos/marketspread/initial-nbbo-fixish.msg -e 10000000 -n node-name

4) orders:
giles/sender/sender -b 127.0.0.1:7001 -m 5000000 -s 300 -i 5_000_000 -f demos/marketspread/350k-orders-fixish.msg -r --ponythreads=1 -y -g 57

5) nbbo:
giles/sender/sender -b 127.0.0.1:7000 -m 10000000 -s 300 -i 2_500_000 -f demos/marketspread/350k-nbbo-fixish.msg -r --ponythreads=1 -y -g 46

Baseline using Junior metrics (on John's 4 core, Sean sees similar):
20-30mb of memory used
70k/sec Trades throughput
120-140k/sec NBBO throughput
"""
use "collections"
use "net"
use "time"
use "buffered"
use "sendence/fix"
use "sendence/new-fix"
use "sendence/hub"
use "sendence/epoch"
use "wallaroo/metrics"
use "wallaroo/topology"

class SymbolData
  var should_reject_trades: Bool = true
  var last_bid: F64 = 0
  var last_offer: F64 = 0

primitive UpdateNbbo is StateComputation[FixNbboMessage val, SymbolData]
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
        Epoch.nanoseconds())
      match wb
      | let w: Writer =>
        _conn.writev(OrderResultEncoder(result, w))
      else
        @printf[I32]("No write buffer for some reason\n".cstring())
      end
    end

class NbboSourceParser 
  fun apply(data: Array[U8] val): (FixNbboMessage val | None) =>
    try
      match FixishMsgDecoder(data)
      | let m: FixNbboMessage val => m
      end
    end

class OrderSourceParser 
  fun apply(data: Array[U8] val): (FixOrderMessage val | None) =>
    try
      match FixishMsgDecoder(data)
      | let m: FixOrderMessage val => m
      end
    end

class SymbolRouter is Router[(FixNbboMessage val | FixOrderMessage val),
  Step tag]
  let _routes: Map[String, (U64, Step tag)] val

  new iso create(routes: Map[String, Step tag] val) =>
    _routes = recover val
      var i: U64 = 1
      let r = Map[String, (U64, Step tag)]
      for (k,v) in routes.pairs() do
        r.update(k,(i,v))
      end
      i = i + 1
      r
    end

  fun route(input: (FixNbboMessage val | FixOrderMessage val)): 
    ((U64, Step tag) | None) 
  =>
    if _routes.contains(input.symbol()) then
      try
        _routes(input.symbol())
      end
    end

class OnlyRejectionsRouter is Router[Bool, TCPConnection]
  let _sink: TCPConnection

  new iso create(sink: TCPConnection) =>
    _sink = sink

  fun route(rejected: Bool): ((U64, TCPConnection) | None)  =>
    if rejected then (0,_sink) end

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
    (order.symbol().clone().append(", ")
      .append(order.order_id()).append(", ")
      .append(order.account().string()).append(", ")
      .append(order.price().string()).append(", ")
      .append(order.order_qty().string()).append(", ")
      .append(order.side().string()).append(", ")
      .append(bid.string()).append(", ")
      .append(offer.string()).append(", ")
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
