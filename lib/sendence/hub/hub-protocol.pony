use "buffered"
use "../../../apps/market-spread-jr/metrics"

primitive HubProtocol
  fun connect(wb: Writer = Writer): Array[ByteSeq] val =>
    wb.u32_be(1)
    wb.u8(HubMsgTypes.connect())
    wb.done()

  fun join(topic: String, wb: Writer = Writer): Array[ByteSeq] val =>
    let size = (1 + 4 + topic.size()).u32()
    wb.u32_be(size)
    wb.u8(HubMsgTypes.join())
    wb.u32_be(topic.size().u32())
    wb.write(topic.array())
    wb.done()

  fun payload(event: String, topic: String, data: Array[ByteSeq] val,
    wb: Writer = Writer): Array[ByteSeq] val
  =>
    let event_size = event.size().u32()
    let topic_size = topic.size().u32()
    let data_size = data.size().u32()
    let size_of_sizes: U32  = 12
    let size = 1 + event_size + topic_size + data_size + size_of_sizes
    wb.u32_be(size)
    wb.u8(HubMsgTypes.payload())
    wb.u32_be(event_size)
    wb.write(event)
    wb.u32_be(topic_size)
    wb.write(topic)
    wb.u32_be(data_size)
    wb.writev(data)
    wb.done()

  fun metrics(name: String, category: String, histogram: Histogram, 
    wb: Writer = Writer): Array[ByteSeq] val =>
    let name_size = name.size().u32()
    let category_size = category.size().u32()
    let size = 4 + 4 + name_size + category_size + (64 * 8)
    wb.u32_be(size)
    wb.u32_be(name_size)
    wb.write(name)
    wb.u32_be(category_size)
    wb.write(category)
    for metric in histogram.counts().values() do
      wb.u64_be(metric)
    end
    wb.done()



primitive HubMsgTypes
  fun connect(): U8 => 1
  fun join(): U8 => 2
  fun payload(): U8 => 3
