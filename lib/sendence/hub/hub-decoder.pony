use "buffered"
use "collections"
use "wallaroo/metrics"

primitive HubProtocolDecoder
  fun apply(data: Array[U8 val] val): HubProtocolMsg val ? =>
    match _decode(data)
    | (_Join(), let d: Array[U8 val] val) =>
      HubJoinMsg
    | (_Connect(), let d: Array[U8 val] val) =>
      HubConnectMsg
    | (_Payload(), let d: Array[U8 val] val) =>
      HubPayloadMsg(d)
    else
      error
    end

  fun _decode(data: Array[U8 val] val): (U8, Array[U8 val] val) ? =>
    let rb = Reader
    rb.append(data)
    let msg_id = rb.u8()
    let data_len = data.size() - 1
    let data' = rb.block(data_len)
    (msg_id, consume data')

primitive _Join    fun apply(): U8 => 1
primitive _Connect fun apply(): U8 => 2
primitive _Payload fun apply(): U8 => 3


trait val HubProtocolMsg

primitive HubJoinMsg is HubProtocolMsg
primitive HubConnectMsg is HubProtocolMsg
primitive HubOtherMsg is HubProtocolMsg

primitive HubPayloadMsg is HubProtocolMsg
  fun apply(data: Array[U8] val): HubProtocolMsg =>
    try
      let rb = Reader
      rb.append(data)
      let event_size = rb.u32_be().usize()
      let event = String.from_array(rb.block(event_size))
      let topic_size = rb.u32_be().usize()
      let topic = String.from_array(rb.block(topic_size))
      let data_size = rb.u32_be().usize()
      let data' = rb.block(data_size)
      match event
      | "metrics" =>
        HubMetricsMsg(consume data')
      else
        HubOtherMsg
      end
    else
      HubOtherMsg
    end

class HubMetricsMsg is HubProtocolMsg
  var name: String = ""
  var category: String = ""
  var period_ends_at: U64 = 0
  var period: U64 = 0
  var histogram_min: U64 = 0
  var histogram_max: U64 = 0
  var histogram: Array[U64] = Array[U64]

  new val create(data: Array[U8] val) ? =>
    try
      let rb = Reader
      rb.append(data)
      let header_size = rb.u32_be().usize()
      let name_size = rb.u32_be().usize()
      name = String.from_array(rb.block(name_size))
      let category_size = rb.u32_be().usize()
      category = String.from_array(rb.block(category_size))
      for i in Range[U64](0, 65) do
        let bin = rb.u64_be()
        histogram.push(bin)
      end
      histogram_min = rb.u64_be()
      histogram_max = rb.u64_be()
      period = rb.u64_be()
      period_ends_at = rb.u64_be()
    else
      error
    end
