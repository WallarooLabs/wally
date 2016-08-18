use "collections"
use "buffy"
use "buffy/messages"
use "buffy/metrics"
use "buffy/topology"
use "buffy/sink-node"
use "sendence/fix"
use "sendence/new-fix"
use "sendence/epoch"
use "sendence/hub"
use "sendence/bytes"
use "net"
use "random"
use "time"
use "files"
use "buffered"

actor Main
  new create(env: Env) =>
    try
      let auth = env.root as AmbientAuth
      let initial_market_data = generate_initial_data(auth)

      let initial_report_msgs: Array[Array[ByteSeq] val] iso = 
        recover Array[Array[ByteSeq] val] end
      let connect_msg = Bytes.length_encode(HubJson.connect())
      let join_msg = Bytes.length_encode(HubJson.join("reports:market-spread"))
      initial_report_msgs.push(connect_msg)
      initial_report_msgs.push(join_msg)

      let topology = recover val
        Topology
          .new_pipeline[FixOrderMessage val, OrderResult val](
            TradeParser, "Orders")
            .to_stateful[OrderResult val, MarketData](
              CheckStatus,
              recover 
                lambda()(initial_market_data): MarketData => 
                  MarketData.from(initial_market_data) end
              end,
              1)
            .to_collector_sink[RejectedResultStore](
              lambda(): SinkCollector[OrderResult val, RejectedResultStore] =>
                MarketSpreadSinkCollector end,
              MarketSpreadSinkStringify, 
              recover [0] end,
              consume initial_report_msgs
            )
            // .to_simple_sink(SimpleStringify, recover [0] end)
          .new_pipeline[FixNbboMessage val, None](NbboParser, "NBBO")
            .to_stateful[None, MarketData](
              UpdateData,
              lambda(): MarketData => MarketData end,
              1)
            .to_empty_sink()
      end
      let sink_builders = recover Array[SinkNodeStepBuilder val] end
      Startup(env, topology, 2, consume sink_builders)
    else
      env.out.print("Couldn't build topology")
    end

  fun generate_initial_data(auth: AmbientAuth): 
    Map[String, MarketDataEntry val] val ? =>
    let map: Map[String, MarketDataEntry val] iso = 
      recover Map[String, MarketDataEntry val] end
    let path = FilePath(auth, "./demos/marketspread/100nbbo.msg")
    let data_source = FileDataSource(auth, path)
    for line in consume data_source do
      let fix_message = FixishMsgDecoder(line.array())
      match fix_message
      | let nbbo: FixNbboMessage val =>
        let mid = (nbbo.bid_px() + nbbo.offer_px()) / 2
        let is_rejected =
          ((nbbo.offer_px() - nbbo.bid_px()) >= 0.05) or
            (((nbbo.offer_px() - nbbo.bid_px()) / mid) >= 0.05)

        let partition_id = nbbo.symbol().hash()       
        map(nbbo.symbol()) =  
          MarketDataEntry(is_rejected, nbbo.bid_px(), nbbo.offer_px())
      end
    end
    consume map

class FileDataSource is Iterator[String]
  let _lines: Iterator[String]

  new iso create(auth: AmbientAuth, path: FilePath) =>
    _lines = File(path).lines()

  fun ref has_next(): Bool =>
    _lines.has_next()

  fun ref next(): String ? =>
    if has_next() then
      _lines.next()
    else
      error
    end

class MarketDataEntry
  let is_rejected: Bool
  let bid: F64
  let offer: F64

  new val create(is_rej: Bool, b: F64, o: F64) =>
    is_rejected = is_rej
    bid = b
    offer = o

class MarketData
  // symbol => (is_rejected, bid, offer)
  let _entries: Map[String, (Bool, F64, F64)] = 
    Map[String, (Bool, F64, F64)]
  
  new create() => None

  new from(md: Map[String, MarketDataEntry val] val) =>
    for (key, value) in md.pairs() do
      _entries(key) = (value.is_rejected, value.bid, value.offer)
    end

  fun ref apply(symbol: String): (Bool, F64, F64) ? => _entries(symbol) 

  fun ref update(symbol: String, entry: (Bool, F64, F64)): MarketData =>
    _entries(symbol) = entry
    this

  fun is_rejected(symbol: String): Bool =>
    try
      _entries(symbol)._1 //is_rejected
    else
      true
    end

  fun contains(symbol: String): Bool => _entries.contains(symbol)

class UpdateData is StateComputation[FixNbboMessage val, None, MarketData]
  fun name(): String => "Update Market Data"
  fun apply(nbbo: FixNbboMessage val, state: MarketData, 
    output: MessageTarget[None] val): MarketData =>
    if ((nbbo.offer_px() - nbbo.bid_px()) >= 0.05) or
      (((nbbo.offer_px() - nbbo.bid_px()) / nbbo.mid()) >= 0.05) then
      output(None)
      state.update(nbbo.symbol(), (true, nbbo.bid_px(), 
        nbbo.offer_px()))
    else
      output(None)
      state.update(nbbo.symbol(), (false, nbbo.bid_px(), 
        nbbo.offer_px()))
    end

class CheckStatus is StateComputation[FixOrderMessage val, OrderResult val, 
  MarketData]
  fun name(): String => "Check Order Result"
  fun apply(order: FixOrderMessage val, state: MarketData, 
    output: MessageTarget[OrderResult val] val):
    MarketData =>
    let symbol = order.symbol()
    let market_data_entry = 
      if state.contains(symbol) then
        try
          state(order.symbol())
        else
          (true, 0, 0)
        end
      else
        (true, 0, 0)
      end
    // if market_data_entry.is_rejected then
      let result: OrderResult val = OrderResult(order,
        market_data_entry._2, market_data_entry._3,
        market_data_entry._1, Epoch.seconds())
      output(result)
    // end
    state
 
class OrderResult
  let order: FixOrderMessage val
  let bid: F64
  let offer: F64
  let is_rejected: Bool
  let timestamp: U64

  new val create(order': FixOrderMessage val,
    bid': F64,
    offer': F64,
    is_rejected': Bool,
    timestamp': U64) 
  =>
    order = order'
    bid = bid'
    offer = offer'
    is_rejected = is_rejected'
    timestamp = timestamp'

  fun string(): String =>
    (order.symbol().clone().append(order.order_id())
      .append(order.account().string())
      .append(order.price().string()).append(order.order_qty().string())
      .append(order.side().string()).append(bid.string()).append(offer.string())
      .append(is_rejected.string())
      .append(timestamp.string())).clone()

interface Symboly
  fun symbol(): String

class SymbolPartition is PartitionFunction[Symboly val]
  fun apply(s: Symboly val): U64 =>
    s.symbol().hash()

class NbboParser is Parser[FixNbboMessage val]
  fun apply(s: String): (FixNbboMessage val | None) =>
    try
      match FixishMsgDecoder(s.array())
      | let m: FixNbboMessage val => m
      else
        None
      end
    else
      None  
    end

class TradeParser is Parser[FixOrderMessage val]
  fun apply(s: String): (FixOrderMessage val | None) =>
    try
      match FixishMsgDecoder(s.array())
      | let m: FixOrderMessage val => m
      else
        None
      end
    else
      @printf[I32]("Error parsing fixish\n".cstring())
      None
    end

// class ToMonitoring is ArrayByteSeqify[RejectedResultStore]
//   fun apply(i: RejectedResultStore, wb: Writer): Array[ByteSeq] val =>
//     let rejected_payload = RejectedResultsStoreBytes.rejected(i, wb)
//     let summaries_payload = RejectedResultsStoreBytes.client_summaries(i, wb)

//     let rejected = HubProtocol.payload("rejected-orders", 
//       "reports:market-spread", rejected_payload)
//     let summaries_string = HubJson.payload("client-order-summaries", 
//         "reports:market-spread", summaries_payload)
//     wb.done()

// primitive RejectedResultsStoreBytes
//   fun rejected(i: RejectedResultStore, wb: Writer): Array[ByteSeq] val  =>
//     let rejected_size = ((i.rejected.size() * 53) + 16).u32()
//     wb.u32_be(rejected_size)
//     for order_result in i.rejected.values() do
//       match order_result.order.side()
//       | Buy => wb.u8(SideTypes.buy())
//       | Sell => wb.u8(SideTypes.sell())
//       end
//       wb.u32_be(order_result.order.account())
//       wb.write(order_result.order.order_id())
//       wb.write(order_result.order.symbol())
//       wb.f64_be(order_result.order.order_qty())
//       wb.f64_be(order_result.order.price())
//       wb.f64_be(order_result.bid)
//       wb.f64_be(order_result.offer)
//     end
//     wb.done()

//   fun client_summaries(i: RejectedResultStore, wb: Writer): Array[ByteSeq] val
//   =>
//     let client_orders_size = i.client_orders_updated.size() * 16
//     for client in i.client_orders_updated.values() do
//       try
//         let summary = i.client_order_counts(client)
//         wb.u32_be(client)
//         // Change this to U64 once Json is removed
//         wb.i64_be(summary.total)
//         wb.i64_be(summary.rejected_total)
//       end
//     end
//     wb.done()














