use "collections"
use "buffy"
use "buffy/messages"
use "buffy/metrics"
use "buffy/topology"
use "sendence/fix"
use "net"
use "random"
use "time"

actor Main
  new create(env: Env) =>
    try
      let topology: Topology val = recover val
        Topology
          .new_pipeline[FixOrderMessage val, TradeResult val](TradeParser, ResultStringify, recover [0] end)
          .to_stateful_partition[TradeResult val, MarketData](
            lambda(): Computation[FixOrderMessage val, CheckStatus val] iso^ => GenerateCheckStatus end,
            lambda(): MarketData => MarketData end,
            SymbolPartition, 1)
          .build()
          .new_pipeline[FixNbboMessage val, None](NbboParser, NoneStringify, recover [0] end)
          .to_stateful_partition[None, MarketData](
            lambda(): Computation[FixNbboMessage val, UpdateData val] iso^ => GenerateUpdateData end,
            lambda(): MarketData => MarketData end,
            SymbolPartition, 1)
          .build()
      end
      Startup(env, consume topology, 2)
    else
      env.out.print("Couldn't build topology")
    end

class MarketData
  let _data_rejected: Map[String, Bool] = Map[String, Bool]
  let _id: U64 = Dice(MT(Time.micros()))(1, 10000)

  fun ref update(symbol: String, is_rej: Bool) =>
    _data_rejected(symbol) = is_rej

  fun is_rejected(symbol: String): Bool =>
    try
      _data_rejected(symbol)
    else
      true
    end

  fun id(): U64 => _id

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
    let mid = (_nbbo.bid_px() + _nbbo.offer_px()) / 2
    if ((_nbbo.offer_px() - _nbbo.bid_px()) >= 0.05) or
      (((_nbbo.offer_px() - _nbbo.bid_px()) / mid) >= 0.05) then
      state.update(_nbbo.symbol(), true)
    else
      state.update(_nbbo.symbol(), false)
    end
    state

class GenerateCheckStatus is Computation[FixOrderMessage val, CheckStatus val]
  fun name(): String => "check status"
  fun apply(order: FixOrderMessage val): CheckStatus val =>
    CheckStatus(order)

class CheckStatus is StateComputation[TradeResult val, MarketData]
  let _trade: FixOrderMessage val

  new val create(trade: FixOrderMessage val) =>
    _trade = trade

  fun name(): String => "check trade result"
  fun apply(state: MarketData, output: MessageTarget[TradeResult val] val): MarketData =>
    let is_rejected = state.is_rejected(_trade.symbol())
    let result: TradeResult val = TradeResult(_trade.symbol(), is_rejected)
    output(result)
    state

class TradeResult
  let symbol: String
  let is_rejected: Bool

  new val create(s: String, is_rej: Bool) =>
    symbol = s
    is_rejected = is_rej

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
    input.symbol + ":" + input.is_rejected.string()
