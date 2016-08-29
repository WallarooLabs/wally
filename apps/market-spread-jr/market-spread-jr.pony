"""
This market-spread-jr partitions by symbol. In order to accomplish this,
given that partitioning happens inside the TCPConnection, we set up the
map from Symbol to NBBOData actor on startup using a hard coded list
of symbols. For many scenarios, this is a reasonable alternative. What
would be ideal is for classes like a TCPConnectionNotify to be able to receive
messages as callbacks. Something Sylvan and I are calling "async lambda". Its
a cool idea. Sylvan thinks it could be done but its not coming anytime soon,
so... Here we have this.

I tested this on my laptop (4 cores). Important to note, I used giles-sender
and data files from the "market-spread-perf-runs-08-19" which has a fix to
correct data handling for the fixish binary files. This will be merged to
master shortly but hasn't been yet.

I started trades/orders sender as:

/usr/bin/time -l ./sender -b 127.0.0.1:7001 -m 5000000 -s 300 -i 5_000_000 -f ../../demos/marketspread/1000trades-fixish.msg --ponythreads=1 -y -g 57

I started nbbo sender as:
/usr/bin/time -l ./sender -b 127.0.0.1:7000 -m 10000000 -s 300 -i 2_500_000 -f ../../demos/marketspread/1000nbbo-fixish.msg --ponythreads=1 -y -g 47

I started market-spread-jr as:
./market-spread-jr -i 127.0.0.1:7000 -j 127.0.0.1:7001 -o 127.0.0.1:7002 -e 10000000

I started a sink for the output as:
nc -l 127.0.0.1 7002 >> /dev/null

With the above settings, based on the albeit, hacky perf tracking, I got:

145k/sec NBBO throughput
71k/sec Trades throughput

Memory usage for market-spread-jr was stable and came in around 22 megs. After
run was completed, I left market-spread-jr running and started up the senders
using the same parameters again and it performed equivalently to the first run
with no appreciable change in memory.

145k/sec NBBO throughput
71k/sec Trades throughput
22 Megs of memory used.

While I don't have the exact performance numbers for this version compared to
the previous version that was partitioning across 2 NBBOData actors based on
last letter of the symbol (not first due to so many having a leading "_" as
padding) this version performs much better.

This version is a much more full featured "buffy" from where we started.
There's still a lot to add though. At this point, it has rejections going
to an outgoing socket. One of out every 10 per symbol. There's been no impact
on throughput or performance, however, we send the same String each time,
by way of output. This should be switched over to info about the order for
more info.

N.B. as part of startup, we really should be setting initial values for each
symbol. This would be equiv to "end of day on last previous trading data".
"""
use "collections"
use "net"
use "sendence/fix"
use "sendence/new-fix"

//
// State handling
//

class SymbolData
  var should_reject_trades: Bool = true
  var last_bid: F64 = 0
  var last_offer: F64 = 0

actor NBBOData is StateHandler[SymbolData ref]
  let _symbol: String
  let _symbol_data: SymbolData = SymbolData
  let _router: OnlyRejectionsRouter

  var _count: USize = 0

  new create(symbol: String, router: OnlyRejectionsRouter iso) =>
    // Should remove leading whitespace padding from symbol here
    _symbol = symbol
    _router = consume router

  be run[In: Any val](input: In, computation: StateComputation[In, SymbolData] val) =>
    _count = _count + 1
    computation(input, _symbol_data)

    // we don't have output from computation yet, fake it
    let result = if (_count % 10) == 0 then true else false end

    match _router.route(result)
    | let conn: TCPConnection =>
      conn.write(_count.string())
    end


primitive UpdateNBBO is StateComputation[FixNbboMessage val, SymbolData]
  fun name(): String =>
    "Update NBBO"

  fun apply(msg: FixNbboMessage val, state: SymbolData) =>
    let offer_bid_difference = msg.offer_px() - msg.bid_px()

    state.should_reject_trades = (offer_bid_difference >= 0.05) or
      ((offer_bid_difference / msg.mid()) >= 0.05)

    state.last_bid = msg.bid_px()
    state.last_offer = msg.offer_px()

primitive CheckOrder is StateComputation[FixOrderMessage val, SymbolData]
  fun name(): String =>
    "Check Order against NBBO"

  fun apply(msg: FixOrderMessage val, state: SymbolData) =>
    if state.should_reject_trades then
      None
      // do rejection here
    end

class NBBOSource is Source
  let _router: SymbolRouter

  new val create(router: SymbolRouter iso) =>
    _router = consume router

  fun name(): String val =>
    "Nbbo source"

  fun process(data: Array[U8 val] iso) =>
    let m = FixishMsgDecoder.nbbo(consume data)

    match _router.route(m.symbol())
    | let p: StateHandler[SymbolData] tag =>
      p.run[FixNbboMessage val](m, UpdateNBBO)
    else
      // drop data that has no partition
      @printf[None]("NBBO Source: Fake logging lack of partition for %s\n".cstring(), m.symbol().null_terminated().cstring())
    end

class OrderSource is Source
  let _router: SymbolRouter

  new val create(router: SymbolRouter iso) =>
    _router = consume router

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
      let m = FixishMsgDecoder.order(consume data)

      match _router.route(m.symbol())
      | let p: StateHandler[SymbolData] tag =>
        p.run[FixOrderMessage val](m, CheckOrder)
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

class SymbolRouter is Router[String, NBBOData]
  let _routes: Map[String, NBBOData] val

  new iso create(routes: Map[String, NBBOData] val) =>
    _routes = routes

  fun route(symbol: String): (NBBOData | None) =>
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


//actor Reporter is Sink
//   let _conn: TCPConnection

//   new create(conn: TCPConnection) =>
//     _conn = conn

//   be process[D: Any val](data: D) =>
//     match data
//     | let b: ByteSeq => _conn.write(b)
//     end