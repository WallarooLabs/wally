/*

Copyright 2017 The Wallaroo Authors.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
 implied. See the License for the specific language governing
 permissions and limitations under the License.

*/

"""
Market Spread App

Setting up a market spread run (in order):
1) reports sink (if not using Monitoring Hub):
nc -l 127.0.0.1 5555 >> /dev/null

2) metrics sink (if not using Monitoring Hub):
nc -l 127.0.0.1 5001 >> /dev/null

350 Symbols

3a) market spread app (1 worker):
./market-spread -i 127.0.0.1:7000,127.0.0.1:7001 -o 127.0.0.1:5555 -m 127.0.0.1:5001 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -n node-name -t --ponythreads=4 --ponynoblock

3b) market spread app (2 workers):
./market-spread -i 127.0.0.1:7000,127.0.0.1:7001 -o 127.0.0.1:5555 -m 127.0.0.1:5001 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -n node-name --ponythreads=4 --ponynoblock -t -w 2

./market-spread -i 127.0.0.1:7000,127.0.0.1:7001 -o 127.0.0.1:5555 -m 127.0.0.1:5001 -c 127.0.0.1:6000 -n worker2 --ponythreads=4 --ponynoblock

4) initial nbbo (must be sent in or all orders will be rejected):
giles/sender/sender -h 127.0.0.1:7001 -m 350 -s 300 -i 2_500_000 -f testing/data/market_spread/nbbo/350-symbols_initial-nbbo-fixish.msg -r --ponythreads=1 -y -g 46 -w

5) orders:
giles/sender/sender -h 127.0.0.1:7000 -m 5000000000 -s 300 -i 2_500_000 -f testing/data/market_spread/orders/350-symbols_orders-fixish.msg -r --ponythreads=1 -y -g 57 -w --ponynoblock

6) nbbo:
giles/sender/sender -h 127.0.0.1:7001 -m 10000000000 -s 300 -i 1_250_000 -f testing/data/market_spread/nbbo/350-symbols_nbbo-fixish.msg -r --ponythreads=1 -y -g 46 -w --ponynoblock

R3K or other Symbol Set (700, 1400, 2100)

3a) market spread app (1 worker):
./market-spread -i 127.0.0.1:7000,127.0.0.1:7001 -o 127.0.0.1:5555 -m 127.0.0.1:5001 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -n node-name -t -s ../../../data/market_spread/symbols/r3k-legal-symbols.msg --ponythreads=4 --ponynoblock

3b) market spread app (2 workers):
./market-spread -i 127.0.0.1:7000,127.0.0.1:7001 -o 127.0.0.1:5555 -m 127.0.0.1:5001 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -n node-name -s ../../../data/market_spread/symbols/r3k-legal-symbols.msg --ponythreads=4 --ponynoblock -t -w 2

./market-spread -i 127.0.0.1:7000,127.0.0.1:7001 -o 127.0.0.1:5555 -m 127.0.0.1:5001 -c 127.0.0.1:6000 -n worker2 --ponythreads=4 --ponynoblock

4) initial nbbo (must be sent in or all orders will be rejected):
giles/sender/sender -h 127.0.0.1:7001 -m 2926 -s 300 -i 2_500_000 -f testing/data/market_spread/nbbo/r3k-symbols_initial-nbbo-fixish.msg -r --ponythreads=1 -y -g 46 -w

5) orders:
giles/sender/sender -h 127.0.0.1:7000 -m 5000000 -s 300 -i 5_000_000 -f testing/data/market_spread/orders/r3k-symbols_orders-fixish.msg -r --ponythreads=1 -y -g 57 -w

6) nbbo:
giles/sender/sender -h 127.0.0.1:7001 -m 10000000 -s 300 -i 2_500_000 -f testing/data/market_spread/nbbo/r3k-symbols_nbbo-fixish.msg -r --ponythreads=1 -y -g 46 -w
"""
use "assert"
use "buffered"
use "collections"
use "net"
use "serialise"
use "time"
use "wallaroo_labs/bytes"
use "wallaroo_labs/conversions"
use "wallaroo_labs/fix"
use "wallaroo_labs/hub"
use "wallaroo_labs/new_fix"
use "wallaroo_labs/options"
use "wallaroo_labs/time"
use "wallaroo"
use "wallaroo_labs/mort"
use "wallaroo/core/common"
use "wallaroo/core/metrics"
use "wallaroo/core/sink/tcp_sink"
use "wallaroo/core/source"
use "wallaroo/core/source/tcp_source"
use "wallaroo/core/state"
use "wallaroo/core/topology"

actor Main
  new create(env: Env) =>
    try
      let pipeline = recover val
        let orders = Wallaroo.source[FixOrderMessage val]("Orders",
            TCPSourceConfig[FixOrderMessage val].from_options(FixOrderFrameHandler,
              TCPSourceConfigCLIParser(env.args)?(0)?))
          .key_by(OrderSymbolExtractor)

        let nbbos = Wallaroo.source[FixNbboMessage val]("Nbbo",
            TCPSourceConfig[FixNbboMessage val].from_options(FixNbboFrameHandler,
              TCPSourceConfigCLIParser(env.args)?(1)?))
          .key_by(NbboSymbolExtractor)

        orders.merge[FixNbboMessage val](nbbos)
          .to[OrderResult val](CheckMarketData)
          .to_sink(TCPSinkConfig[OrderResult val].from_options(
            OrderResultEncoder, TCPSinkConfigCLIParser(env.args)?(0)?))

      end
      Wallaroo.build_application(env, "Market Spread", pipeline)
    else
      @printf[I32]("Couldn't build topology\n".cstring())
    end


class SymbolData is State
  var should_reject_trades: Bool = true
  var last_bid: F64 = 0
  var last_offer: F64 = 0

primitive CheckMarketData is StateComputation[
  (FixOrderMessage val | FixNbboMessage val), OrderResult val, SymbolData]
  fun name(): String => "Check Market Data"

  fun apply(msg: (FixOrderMessage val | FixNbboMessage val),
    state: SymbolData): (OrderResult val | None)
  =>
    match msg
    | let order: FixOrderMessage val =>
      if state.should_reject_trades then
        OrderResult(order, state.last_bid, state.last_offer,
          WallClock.nanoseconds() where accept' = false)
      else
        OrderResult(order, state.last_bid, state.last_offer,
          WallClock.nanoseconds() where accept' = true)
      end
    | let nbbo: FixNbboMessage val =>
      let offer_bid_difference = nbbo.offer_px() - nbbo.bid_px()

      let should_reject_trades = (offer_bid_difference >= 0.05) or
        ((offer_bid_difference / nbbo.mid()) >= 0.05)

      state.last_bid = nbbo.bid_px()
      state.last_offer = nbbo.offer_px()
      state.should_reject_trades = should_reject_trades
      None
    end

  fun initial_state(): SymbolData =>
    SymbolData

primitive FixOrderFrameHandler is FramedSourceHandler[FixOrderMessage val]
  fun header_length(): USize =>
    4

  fun payload_length(data: Array[U8] iso): USize ? =>
    Bytes.to_u32(data(0)?, data(1)?, data(2)?, data(3)?).usize()

  fun decode(data: Array[U8] val): FixOrderMessage val ? =>
    match FixishMsgDecoder(data)?
    | let m: FixOrderMessage val => m
    | let m: FixNbboMessage val => @printf[I32]("Got FixNbbo\n".cstring()); Fail(); error
    else
      @printf[I32]("Could not get FixOrder from incoming data\n".cstring())
      @printf[I32]("data size: %d\n".cstring(), data.size())
      error
    end

primitive FixNbboFrameHandler is FramedSourceHandler[FixNbboMessage val]
  fun header_length(): USize =>
    4

  fun payload_length(data: Array[U8] iso): USize ? =>
    Bytes.to_u32(data(0)?, data(1)?, data(2)?, data(3)?).usize()

  fun decode(data: Array[U8] val): FixNbboMessage val ? =>
    match FixishMsgDecoder(data)?
    | let m: FixNbboMessage val => m
    | let m: FixOrderMessage val => @printf[I32]("Got FixOrder\n".cstring()); Fail(); error
    else
      @printf[I32]("Could not get FixNbbo from incoming data\n".cstring())
      @printf[I32]("data size: %d\n".cstring(), data.size())
      error
    end

primitive OrderSymbolExtractor
  fun apply(input: FixOrderMessage val): Key =>
    input.symbol()

primitive NbboSymbolExtractor
  fun apply(input: FixNbboMessage val): Key =>
    input.symbol()

class OrderResult
  let order: FixOrderMessage val
  let bid: F64
  let offer: F64
  let timestamp: U64
  let accept: Bool

  new val create(order': FixOrderMessage val,
    bid': F64,
    offer': F64,
    timestamp': U64,
    accept': Bool)
  =>
    order = order'
    bid = bid'
    offer = offer'
    timestamp = timestamp'
    accept = accept'

  fun string(): String =>
    (order.symbol().clone().>append(", ")
      .>append(order.order_id()).>append(", ")
      .>append(order.account().string()).>append(", ")
      .>append(order.price().string()).>append(", ")
      .>append(order.order_qty().string()).>append(", ")
      .>append(order.side().string()).>append(", ")
      .>append(bid.string()).>append(", ")
      .>append(offer.string()).>append(", ")
      .>append(timestamp.string()).>append(", ")
      .>append(accept.string())).clone()

primitive OrderResultEncoder
  fun apply(r: OrderResult val, wb: Writer = Writer): Array[ByteSeq] val =>
    ifdef "market_results" then
      @printf[I32](("!!" + r.order.order_id() + " " + r.order.symbol() + "\n").cstring())
    end
    //Header (size == 55 bytes)
    let msgs_size: USize = 1 + 4 + 6 + 4 + 8 + 8 + 8 + 8 + 8 + 1
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
    wb.u8(if r.accept then 1 else 0 end)
    wb.done()
