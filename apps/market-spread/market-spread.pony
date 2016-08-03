use "collections"
use "buffy"
use "buffy/messages"
use "buffy/metrics"
use "buffy/topology"
use "buffy/sink-node"
use "sendence/fix"
use "sendence/epoch"
use "net"
use "random"
use "time"
use "files"

actor Main
  new create(env: Env) =>
    try
      let auth = env.root as AmbientAuth
      let initial_market_data = generate_initial_data(auth)

      let topology = recover val
        Topology
          .new_pipeline[FixOrderMessage val, OrderResult val](
            TradeParser, ResultArrayStringify, recover [0, 1] end, "Orders")
          .to_stateful[OrderResult val, MarketData](
            CheckStatus,
            recover 
              lambda()(initial_market_data): MarketData => 
                MarketData.from(initial_market_data) end
            end,
            1)
          .build()
          .new_pipeline[FixNbboMessage val, None](NbboParser, NoneStringify,
            recover [2] end, "NBBO")
          .to_stateful[None, MarketData](
            UpdateData,
            lambda(): MarketData => MarketData end,
            1)
          .build()
      end
      let sink_builders = recover Array[SinkNodeStepBuilder val] end
      let ui_sink_builder = SinkNodeConfig[RejectedResultStore](
        lambda(): SinkCollector[RejectedResultStore] => 
          MarketSpreadSinkCollector end,
        MarketSpreadSinkConnector,
        MarketSpreadSinkStringify
      )
      sink_builders.push(ui_sink_builder)
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
      let fix_message = FixParser(line)
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
  let _entries: Map[String, MarketDataEntry val] = 
    Map[String, MarketDataEntry val]
  
  new create() => None

  new from(md: Map[String, MarketDataEntry val] val) =>
    for (key, value) in md.pairs() do
      _entries(key) = value
    end

  fun ref apply(symbol: String): MarketDataEntry val ? => _entries(symbol) 

  fun ref update(symbol: String, entry: MarketDataEntry val): MarketData =>
    _entries(symbol) = entry
    this

  fun is_rejected(symbol: String): Bool =>
    try
      _entries(symbol).is_rejected
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
      state.update(nbbo.symbol(), MarketDataEntry(true, nbbo.bid_px(), 
        nbbo.offer_px()))
    else
      output(None)
      state.update(nbbo.symbol(), MarketDataEntry(false, nbbo.bid_px(), 
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
          MarketDataEntry(true, 0, 0)
        end
      else
        MarketDataEntry(true, 0, 0)
      end
    let result: OrderResult val = OrderResult(order.order_id(),
      Epoch.seconds(), order.account(), order.symbol(), 
      order.price(), order.order_qty().u64(), order.side().string(), 
      market_data_entry.bid, market_data_entry.offer, 
      market_data_entry.is_rejected)
    output(result)
    state
 
class OrderResult
  let order_id: String
  let timestamp: U64
  let client_id: String
  let symbol: String
  let price: F64
  let qty: U64
  let side: String
  let bid: F64
  let offer: F64
  let is_rejected: Bool

  new val create(order_id': String,
    timestamp': U64,
    client_id': String,
    symbol': String,
    price': F64,
    qty': U64,
    side': String,
    bid': F64,
    offer': F64,
    is_rejected': Bool) 
  =>
    order_id = order_id'
    timestamp = timestamp'
    client_id = client_id'
    symbol = symbol'
    price = price'
    qty = qty'
    side = side'
    bid = bid'
    offer = offer'
    is_rejected = is_rejected'

  fun string(): String =>
    symbol + "," + order_id + "," + timestamp.string() + "," + client_id + ","
      + price.string() + "," + qty.string() + "," + side + "," 
      + bid.string() + "," + offer.string() + "," + is_rejected.string()

interface Symboly
  fun symbol(): String

class SymbolPartition is PartitionFunction[Symboly val]
  fun apply(s: Symboly val): U64 =>
    s.symbol().hash()

class NbboParser is Parser[FixNbboMessage val]
  fun apply(s: String): (FixNbboMessage val | None) =>
    match FixParser(s)
    | let m: FixNbboMessage val => m
    else
      None
    end

class TradeParser is Parser[FixOrderMessage val]
  fun apply(s: String): (FixOrderMessage val | None) =>
    match FixParser(s)
    | let m: FixOrderMessage val => m
    else
      None
    end

class ResultStringify
  fun apply(input: OrderResult val): String =>
    input.string()

primitive ResultArrayStringify
  fun apply(input: OrderResult val): Array[String] val =>
    let result: Array[String] iso = recover Array[String] end
    result.push(input.symbol)
    result.push(input.order_id)
    result.push(input.timestamp.string())
    result.push(input.client_id)
    result.push(input.price.string())
    result.push(input.qty.string())
    result.push(input.side)
    result.push(input.bid.string())
    result.push(input.offer.string())
    result.push(input.is_rejected.string())
    consume result
