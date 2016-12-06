use "buffered"
use "wallaroo/metrics"

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
    wb: Writer)
  =>
    let event_size = event.size().u32()
    let topic_size = topic.size().u32()
    var data_size: U32 = 0
    for seq in data.values() do
      data_size = data_size + seq.size().u32()
    end
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

  fun metrics(name: String, category: String, pipeline_name: String,
    worker_name: String, id: U16, histogram: Histogram,
    period: U64, period_ends_at: U64, wb: Writer)
  =>
    let name_size = name.size().u32()
    let category_size = category.size().u32()
    let worker_name_size = worker_name.size().u32()
    let pipeline_name_size = pipeline_name.size().u32()
    let size = 4 + 4 + 4 + 4 + 2 + name_size + category_size +
      worker_name_size + pipeline_name_size + (64 * 11)
    wb.u32_be(size)
    wb.u32_be(name_size)
    wb.write(name)
    wb.u32_be(category_size)
    wb.write(category)
    wb.u32_be(worker_name_size)
    wb.write(worker_name)
    wb.u32_be(pipeline_name_size)
    wb.write(pipeline_name)
    wb.u16_be(id)
    for metric in histogram.counts().values() do
      wb.u64_be(metric)
    end
    wb.u64_be(histogram.min())
    wb.u64_be(histogram.max())
    wb.u64_be(period)
    wb.u64_be(period_ends_at)

primitive HubMsgTypes
  fun connect(): U8 => 1
  fun join(): U8 => 2
  fun payload(): U8 => 3
