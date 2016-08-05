use "sendence/bytes"
use "sendence/hub"
use "json"
use "buffy/sink-node"
use "net"
use "collections"

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
    client_orders_updated.set(tr.client_id) 
    let summary = 
      try client_order_counts(tr.client_id) else ClientSummary end
    summary.increment_total()
    if tr.is_rejected then
      rejected.push(tr)
      summary.increment_rejected_total()
    end
    client_order_counts(tr.client_id) = summary

  fun ref clear() => 
    client_orders_updated.clear()
    rejected.clear()

class MarketSpreadSinkCollector is SinkCollector[RejectedResultStore]
  let _diff: RejectedResultStore = RejectedResultStore

  fun ref apply(input: Array[String] val) =>
    try
      let symbol = input(0)
      let order_id = input(1)
      let timestamp = input(2).u64()
      let client_id = input(3).u32()
      let price = input(4).f64()
      let qty = input(5).u64()
      let side = input(6)
      let bid = input(7).f64()
      let offer = input(8).f64()
      let is_rejected = input(9).bool()
      let trade_result = OrderResult(order_id, timestamp, client_id, symbol,
        price, qty, side, bid, offer, is_rejected)
      _diff.add_result(trade_result)
    end

  fun has_diff(): Bool => _diff.rejected.size() > 0

  fun ref diff(): RejectedResultStore => _diff

  fun ref clear_diff() => _diff.clear()

class MarketSpreadSinkConnector is SinkConnector
  fun apply(conn: TCPConnection) =>
    _send_connect(conn)
    _send_join(conn)

  fun _send_connect(conn: TCPConnection) =>
    conn.writev(Bytes.length_encode(HubJson.connect()))

  fun _send_join(conn: TCPConnection) =>
    conn.writev(Bytes.length_encode(HubJson.join("reports:market-spread")))

class MarketSpreadSinkStringify
  fun apply(diff: RejectedResultStore): (String | Array[String] val) =>
    let rejected_payload = _rejected_to_json(diff)
    let summaries_payload = _client_summaries_to_json(diff)
    let rejected_string = HubJson.payload("rejected-orders", 
      "reports:market-spread", rejected_payload)
    let summaries_string = HubJson.payload("client-order-summaries", 
      "reports:market-spread", summaries_payload)
    let len = rejected_string.size() + summaries_string.size()
    let arr: Array[String] iso = recover Array[String](len) end
    arr.push(rejected_string)
    arr.push(summaries_string)
    consume arr

  fun _rejected_to_json(diff: RejectedResultStore): JsonArray =>
    let len: USize = diff.rejected.size() * 100
    let values: Array[JsonType] iso = 
      recover Array[JsonType](len) end
    for order in diff.rejected.values() do
      let next = recover Map[String, JsonType] end
      next("order_id") = order.order_id
      next("timestamp") = order.timestamp.i64()
      next("client_id") = order.client_id.i64()
      next("symbol") = order.symbol
      next("price") = order.price
      next("qty") = order.qty.i64()
      next("side") = order.side
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



