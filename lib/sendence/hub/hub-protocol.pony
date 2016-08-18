use "buffered"

primitive HubProtocol
  fun payload(event: String, topic: String, data: Array[ByteSeq] val,
    wb: Writer): Array[ByteSeq] val
  =>
    let event_size = event.size().u32()
    let topic_size = topic.size().u32()
    let data_size = data.size().u32()
    let size_of_sizes: U32  = 12
    let size = event_size + topic_size + data_size + size_of_sizes
    wb.u32_be(size)
    wb.u32_be(event_size)
    wb.write(event)
    wb.u32_be(topic_size)
    wb.write(topic)
    wb.u32_be(data_size)
    wb.writev(data)
    wb.done()
