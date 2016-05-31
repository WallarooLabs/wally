use "collections"
use "buffy"
use "buffy/messages"
use "buffy/metrics"
use "buffy/topology"
use "net"

actor Main
  new create(env: Env) =>
//    try
//      let topology: Topology val = recover val
//        Topology
//          .new_pipeline[String, WordCount val](P, S, recover [0] end)
//          .to_stateful_partition[WordCount val, WordCountTotals](
//            lambda(): StateComputation[WordCount val,
//                                       WordCount val,
//                                       WordCountTotals] iso^ => Count end,
//            lambda(): WordCountTotals => WordCountTotals end,
//            FirstLetterPartition)
//          .build()
//      end
//      Startup(env, topology, 1)
//    else
      env.out.print("Couldn't build topology")
//    end

class MarketData
  let _data: Map[String, Bool] = Map[String, Bool]

  fun update(symbol: String, is_rej: Bool) =>
    _data(symbol) = is_rej

  fun is_rejected(symbol: String) =>
    try
      _data(symbol)
    else
      false
    end

class UpdateData is StateComputation[NBBO val, None, MarketData]
  let _nbbo: NBBO

  new val create(nbbo: NBBO val) =>
    _nbbo = nbbo

  fun name(): String => "update market data"
  fun ref apply(state: MarketData, default_output_step: BasicStep tag,
    message_wrapper: MessageWrapper[NBBO val] val) =>
    let mid = (_nbbo.bit + nbbo.offer) / 2
    if (_nbbo.offer - _nbbo.bid) >= 0.05 then // also (offer - bid) / mid >= 5%
      state.update(_nbbo.symbol(), true)
    else
      state.update(_nbbo.symbol(), false)
    end

class CheckStatus is StateComputation[Trade val, TradeResult val, MarketData]
  let _trade: Trade

  new val create(trade: Trade val) =>
    _trade = trade

  fun name(): String => "check trade result"
  fun ref apply(state: MarketData, trade: Trade val,
    default_output_step: BasicStep tag,
    message_wrapper: MessageWrapper[TradeResult val] val) =>
    let is_rejected = state.is_rejected(_trade.symbol())
    let result = TradeResult(_trade.symbol(), is_rejected)
    default_output_step(message_wrapper(result))

class NBBO
  let _symbol: String
  let offer: F64
  let bid: F64
  let time: U64

  new val create(s: String, o: F64, b: F64, t: U64) =>
    _symbol = s
    offer = o
    bid = b
    time = t

  fun symbol(): String => _symbol

class Trade
  let time: U64
  let msg_type: String
  let status: String
  let client_id: U64
  let order_id: U64
  let _symbol: String
  let price: F64
  let quantity: U64
  let side: F64

  new val create(time': U64
                 , msg_type': String
                 , status': String
                 , client_id': U64
                 , order_id': U64
                 , symbol': String
                 , price': F64
                 , quantity': U64
                 , side': F64) =>
    time = time'
    msg_type = msg_type'
    status = status'
    client_id = client_id'
    order_id = order_id'
    _symbol = symbol'
    price = price'
    quantity = quantity'
    side = side'

  fun symbol(): String => _symbol

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
    try s.symbol().hash() else 0 end

class NBBOParser
  fun apply(s: String): NBBO =>
    s

class TradeParser
  fun apply(s: String): Trade =>
    s

class ResultStringify
  fun apply(input: TradeResult val): String =>
    input.symbol + ":" + input.is_rejected
