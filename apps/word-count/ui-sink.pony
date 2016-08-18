use "sendence/bytes"
use "sendence/hub"
use "json"
use "buffy/sink-node"
use "net"
use "collections"

// class WordCountSinkCollector is SinkCollector[Map[String, U64]]
//   let _diff: Map[String, U64] = Map[String, U64]

//   fun ref apply(input: Array[String] val) =>
//     try
//       let word = input(0)
//       let count = input(1).u64()
//       _diff(word) = count
//     end

//   fun has_diff(): Bool => _diff.size() > 0

//   fun ref diff(): Map[String, U64] => _diff

//   fun ref clear_diff() => _diff.clear()

// class WordCountSinkConnector is SinkConnector
//   fun apply(conn: TCPConnection) =>
//     _send_connect(conn)
//     _send_join(conn)

//   fun _send_connect(conn: TCPConnection) =>
//     conn.writev(Bytes.length_encode(HubJson.connect()))

//   fun _send_join(conn: TCPConnection) =>
//     conn.writev(Bytes.length_encode(HubJson.join("reports:word-count")))

// class WordCountSinkStringify
//   fun apply(diff: Map[String, U64]): (String | Array[String] val) =>
//     let payload = map_to_json(diff)
//     HubJson.payload("word-count-msgs", "reports:word-count", payload)

//   fun map_to_json(diff: Map[String, U64]): JsonArray =>
//     let values: Array[JsonType] iso = recover Array[JsonType] end
//     for (word, count) in diff.pairs() do
//       let next = recover Map[String, JsonType] end
//       next("word") = word
//       next("count") = count.i64()
//       values.push(recover JsonObject.from_map(consume next) end)
//     end
//     JsonArray.from_array(consume values)
