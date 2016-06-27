use "json"

primitive HubJson
  fun connect(): String =>
    let j: JsonObject = JsonObject
    j.data.update("path", "/socket/tcp")
    j.data.update("params", None)
    j.string(where pretty_print=false)

  fun join(topic: String): String =>
    let j: JsonObject = JsonObject
    j.data.update("event", "phx_join")
    j.data.update("topic", topic)
    j.data.update("ref", None)
    j.data.update("payload", JsonObject)
    j.string(where pretty_print=false)

  fun payload(event: String, topic: String, payload': JsonArray,
    pretty_print: Bool = false): String =>
    let j: JsonObject = JsonObject
    j.data.update("event", event)
    j.data.update("topic", topic)
    j.data.update("ref", None)
    j.data.update("payload", payload')
    j.string(where pretty_print=pretty_print)
