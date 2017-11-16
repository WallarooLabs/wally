use "collections"
use "json"

class JsonEzData
  let _data: JsonType

  new create(data: JsonType) =>
    _data = data

  fun ref int(): I64 ? =>
    _data as I64

  fun ref string(): String ? =>
    _data as String

  fun ref bool(): Bool ? =>
    _data as Bool

  fun ref array(): Array[JsonEzData] ? =>
    let a: Array[JsonEzData] = Array[JsonEzData]

    for d in (_data as JsonArray).data.values() do
      a.push(JsonEzData(d))
    end

    a

  fun ref obj(): Map[String, JsonEzData] ? =>
    let map: Map[String, JsonEzData] = Map[String, JsonEzData]

    for (k, v) in (_data as JsonObject).data.pairs() do
      map(k) = JsonEzData(v)
    end

    map

  fun ref apply(property_name_or_idx: (String | USize)): JsonEzData ? =>
    match (_data, property_name_or_idx)
    | (let jo: JsonObject, let pn: String) =>
      JsonEzData(jo.data(pn)?)
    | (let ja: JsonArray, let idx: USize) =>
      JsonEzData(ja.data(idx)?)
    else
      error
    end

class JsonEz
  let _json_doc: JsonDoc

  new create(json_doc: JsonDoc) =>
    _json_doc = json_doc

  fun ref apply(): JsonEzData =>
    JsonEzData(_json_doc.data)
