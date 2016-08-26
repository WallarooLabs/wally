use "sendence/bytes"
use "sendence/hub"
use "sendence/fix"
use "buffy/topology"
use "json"
use "buffy/sink-node"
use "net"
use "collections"
use "buffered"

class MarketSpreadSinkCollector is SinkCollector[(OrderResult val | None), 
  RejectedResultStore]
  let _diff: RejectedResultStore = RejectedResultStore

  fun ref apply(input: (OrderResult val | None)) =>
    match input
    | let i: OrderResult val => _diff.add_result(i)
    end

  fun has_diff(): Bool => _diff.rejected.size() > 0

  fun ref diff(): RejectedResultStore => _diff

  fun ref clear_diff() => _diff.clear()

class ClientSummary
  var total: I64 = 0
  var rejected_total: I64 = 0

  fun ref increment_total() => total = total + 1
  fun ref increment_rejected_total() =>
    rejected_total = rejected_total + 1

class RejectedResultStore
  let client_order_counts: Map[U32, ClientSummary] = 
    Map[U32, ClientSummary]
  let client_orders_updated: Set[U32] = Set[U32]
  let rejected: Array[OrderResult val] = Array[OrderResult val]

  fun ref add_result(tr: OrderResult val) =>
    client_orders_updated.set(tr.order.account()) 
    let summary = 
      try client_order_counts(tr.order.account()) else ClientSummary end
    summary.increment_total()
    if tr.is_rejected then
      rejected.push(tr)
      summary.increment_rejected_total()
    end
    client_order_counts(tr.order.account()) = summary

  fun ref clear() => 
    client_orders_updated.clear()
    rejected.clear()

class MarketSpreadSinkByteSeqify
  fun apply(diff: RejectedResultStore, wb: Writer = Writer): 
    Array[ByteSeq] val =>
    let rejected_payload = _rejected_to_json(diff)
    let summaries_payload = _client_summaries_to_json(diff)
    let rejected_string = HubJson.payload("rejected-orders", 
      "reports:market-spread", rejected_payload)
    let summaries_string = HubJson.payload("client-order-summaries", 
      "reports:market-spread", summaries_payload)
    wb.u32_be(rejected_string.size().u32())
    wb.write(rejected_string)
    wb.u32_be(summaries_string.size().u32())
    wb.write(summaries_string)
    wb.done()

  fun _rejected_to_json(diff: RejectedResultStore): JsonArray =>
    let len: USize = diff.rejected.size() * 100
    let values: Array[JsonType] iso = 
      recover Array[JsonType](len) end
    for order in diff.rejected.values() do
      let next = recover Map[String, JsonType] end
      next("order_id") = order.order.order_id()
      next("timestamp") = order.timestamp.i64()
      next("client_id") = order.order.account().i64()
      next("symbol") = order.order.symbol()
      next("price") = order.order.price()
      next("qty") = order.order.order_qty().i64()
      next("side") = order.order.side().string()
      next("bid") = order.bid
      next("offer") = order.offer
      next("is_rejected") = order.is_rejected
      values.push(recover JsonObject.from_map(consume next) end)
    end
    JsonArray.from_array(consume values)

  fun _client_summaries_to_json(diff: RejectedResultStore): JsonArray =>
    let len: USize = diff.client_orders_updated.size() * 32
    let values: Array[JsonType] iso = 
      recover Array[JsonType](len) end
    for client_id in diff.client_orders_updated.values() do
      try
        let next = recover Map[String, JsonType] end
        next("client_id") = client_id.i64()
        next("total_orders") = diff.client_order_counts(client_id).total
        next("rejected_count") = 
          diff.client_order_counts(client_id).rejected_total
        values.push(recover JsonObject.from_map(consume next) end)
      end
    end
    JsonArray.from_array(consume values)



// class MarketSpreadSinkCollector is SinkCollector[RejectedResultStore]
//   let _diff: RejectedResultStore = RejectedResultStore

//   fun ref apply(input: Array[String] val) =>
//     try
//       let symbol = input(0)
//       let order_id = input(1)
//       let timestamp = input(2)
//       let account = input(3).u32()
//       let price = input(4).f64()
//       let qty = input(5).f64()
//       let side = 
//         match input(6)
//         | Buy.string() => Buy
//         | Sell.string() => Sell
//         else
//           Buy 
//         end
//       let bid = input(7).f64()
//       let offer = input(8).f64()
//       let is_rejected = input(9).bool()
//       let trade_result = OrderResult(FixOrderMessage(side, account, 
//         order_id, symbol, qty, price, timestamp), bid, offer, is_rejected)
//       _diff.add_result(trade_result)
//     end

//   fun has_diff(): Bool => _diff.rejected.size() > 0

//   fun ref diff(): RejectedResultStore => _diff

//   fun ref clear_diff() => _diff.clear()

// class MarketSpreadSinkConnector is SinkConnector
//   fun apply(conn: TCPConnection) =>
//     _send_connect(conn)
//     _send_join(conn)

//   fun _send_connect(conn: TCPConnection) =>
//     conn.writev(Bytes.length_encode(HubJson.connect()))

//   fun _send_join(conn: TCPConnection) =>
//     conn.writev(Bytes.length_encode(HubJson.join("reports:market-spread")))


