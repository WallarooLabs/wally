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
      let initial_market_data: Map[U64, {(): MarketData} val] iso = 
        generate_initial_data(auth)

      let topology = recover val
        Topology
          .new_pipeline[FixOrderMessage val, TradeResult val](
            TradeParser, ResultStringify, recover [0] end, "Trades")
          .to_stateful_partition[TradeResult val, MarketData](
            recover
              StatePartitionConfig[FixOrderMessage val, TradeResult val,
                MarketData](
                lambda(): Computation[FixOrderMessage val, 
                  CheckStatus val] iso^ => GenerateCheckStatus end,
                lambda(): MarketData => MarketData end,
                SymbolPartition, 1)
              .with_initialization_map(consume initial_market_data)
              .with_initialize_at_start()
            end)
          .build()
          .new_pipeline[FixNbboMessage val, None](NbboParser, NoneStringify,
            recover [1] end, "NBBO")
          .to_stateful_partition[None, MarketData](
            recover
              StatePartitionConfig[FixNbboMessage val, None, MarketData](
                lambda(): Computation[FixNbboMessage val, UpdateData val] iso^ 
                  => GenerateUpdateData end,
                lambda(): MarketData => MarketData end,
                SymbolPartition, 1)
            end)
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
    Map[U64, {(): MarketData} val] iso^ ? =>
    let map = recover Map[U64, {(): MarketData} val] end
    let path = FilePath(auth, "./demos/marketspread/100nbbo.msg")
    let data_source = FileDataSource(auth, path)
    for line in consume data_source do
      let fix_message = FixParser(line)
      match fix_message
      | let nbbo: FixNbboMessage val =>
        let mid = (nbbo.bid_px() + nbbo.offer_px()) / 2
        let is_rejected =
          if ((nbbo.offer_px() - nbbo.bid_px()) >= 0.05) or
            (((nbbo.offer_px() - nbbo.bid_px()) / mid) >= 0.05) then
            true
          else
            false
          end
        let partition_id = nbbo.symbol().hash()       
        map(partition_id) = recover 
            lambda()(nbbo, is_rejected): MarketData => 
              MarketData.update(nbbo.symbol(), 
                MarketDataEntry(is_rejected, nbbo.bid_px(), nbbo.offer_px())) end
          end
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

  new create(is_rej: Bool, b: F64, o: F64) =>
    is_rejected = is_rej
    bid = b
    offer = o

class MarketData
  let _entries: Map[String, MarketDataEntry] = 
    Map[String, MarketDataEntry]
  
  fun ref apply(symbol: String): MarketDataEntry ? => _entries(symbol) 

  fun ref update(symbol: String, entry: MarketDataEntry): MarketData =>
    _entries(symbol) = entry
    this

  fun is_rejected(symbol: String): Bool =>
    try
      _entries(symbol).is_rejected
    else
      true
    end

  fun contains(symbol: String): Bool => _entries.contains(symbol)

class GenerateUpdateData is Computation[FixNbboMessage val, UpdateData val]
  fun name(): String => "update data"
  fun apply(nbbo: FixNbboMessage val): UpdateData val =>
    UpdateData(nbbo)

class UpdateData is StateComputation[None, MarketData]
  let _nbbo: FixNbboMessage val

  new val create(nbbo: FixNbboMessage val) =>
    _nbbo = nbbo

  fun name(): String => "update market data"
  fun apply(state: MarketData, output: MessageTarget[None] val): MarketData =>
    if ((_nbbo.offer_px() - _nbbo.bid_px()) >= 0.05) or
      (((_nbbo.offer_px() - _nbbo.bid_px()) / _nbbo.mid()) >= 0.05) then
      output(None)
      state.update(_nbbo.symbol(), MarketDataEntry(true, _nbbo.bid_px(), 
        _nbbo.offer_px()))
    else
      output(None)
      state.update(_nbbo.symbol(), MarketDataEntry(false, _nbbo.bid_px(), 
        _nbbo.offer_px()))
    end

class GenerateCheckStatus is Computation[FixOrderMessage val, CheckStatus val]
  fun name(): String => "check status"
  fun apply(order: FixOrderMessage val): CheckStatus val =>
    CheckStatus(order)

class CheckStatus is StateComputation[TradeResult val, MarketData]
  let _trade: FixOrderMessage val

  new val create(trade: FixOrderMessage val) =>
    _trade = trade

  fun name(): String => "check trade result"
  fun apply(state: MarketData, output: MessageTarget[TradeResult val] val):
    MarketData =>
    let symbol = _trade.symbol()
    let market_data_entry = 
      if state.contains(symbol) then
        try
          state(_trade.symbol())
        else
          MarketDataEntry(true, 0, 0)
        end
      else
        MarketDataEntry(true, 0, 0)
      end
    let result: TradeResult val = TradeResult(_trade.order_id(),
      Epoch.seconds(), _trade.account(), _trade.symbol(), 
      _trade.price(), _trade.order_qty().u64(), _trade.side().string(), 
      market_data_entry.bid, market_data_entry.offer, 
      market_data_entry.is_rejected)
    output(result)
    state
 
class TradeResult
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
  fun apply(input: TradeResult val): String =>
    input.string()
