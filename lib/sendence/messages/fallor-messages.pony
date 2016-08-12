use "buffered"
use "net"
use "debug"

primitive FallorMsgEncoder
  fun apply(data: (String | Array[U8] val | Seq[String] val), wb: Writer = Writer):
    Array[ByteSeq] val
  =>
  """
    [Header | Total size | (String size | String) ... ]
  """
    match data
    | let s: String =>
      //Header
      wb.u32_be((s.size() + 8).u32())
      //Message size field
      wb.u32_be((s.size() + 4).u32())
      wb.u32_be(s.size().u32())
      wb.write(s)
    | let a: Array[U8] val =>
      //Header
      wb.u32_be((a.size() + 8).u32())
      //Message size field
      wb.u32_be((a.size() + 4).u32())
      wb.u32_be(a.size().u32())
      wb.write(a)
    | let seq: Seq[String] val =>
      let sizes_size = seq.size() * 4
      var strings_size: USize = 0
      for s in seq.values() do
        strings_size = strings_size + s.size()
      end
      //Header
      wb.u32_be((sizes_size + strings_size + 4).u32())
      //Message size field
      wb.u32_be((sizes_size + strings_size).u32())
      for s in seq.values() do
        wb.u32_be(s.size().u32())
        wb.write(s)
      end
    end
    wb.done()

  fun timestamp_raw(timestamp: U64, data: Array[U8] val,
    wb: Writer = Writer): Array[ByteSeq] val
  =>
    """
    Encodes with a payload already encoded with Fallor (usually messages received at a sink as they are already in Fallor format as sent by ExternalConnection). In this case, this just provides the outer wrapper
      encoding for the payload and timestamp.
    """
    let size = data.size()
    wb.u32_be(size.u32())
    wb.u64_be(timestamp)
    wb.write(data)
    wb.done()

  fun timestamp_unencoded_payload(timestamp: U64, data: ByteSeq,
    wb: Writer = Writer): Array[ByteSeq] val =>
    """
    Encodes with a payload not already in Fallor format. So in addition to encoding the payload, it also provides the Fallor outer wrapper for the payload and timestamp.
    """
    let encoded_payload = apply(data)
    var size: USize = 0
    for v in encoded_payload.values() do
      match v
      | let s: String => size = size + s.array().size().usize()
      | let a: Array[U8] val => size = size + a.size().usize()
      else
        None
      end
    end
    wb.u32_be(size.u32())
    wb.u64_be(timestamp)
    wb.writev(encoded_payload)
    wb.done()


primitive FallorMsgDecoder
  fun apply(data: Array[U8] val): Array[String] val ? =>
    _decode(data)

  fun _decode(data: Array[U8] val): Array[String] val ? =>
    let rb = Reader
    rb.append(data)
    var total_size = rb.u32_be()
    let arr: Array[String] iso = recover Array[String](total_size.usize()) end

    var bytes_left = total_size
    while bytes_left > 0 do
      let s_len = rb.u32_be()
      let next_str = String.from_array(rb.block(s_len.usize()))
      arr.push(next_str)
      bytes_left = bytes_left - (s_len + 4)
    end

    consume arr

  fun with_timestamp(data: Array[U8] val): Array[String] val ?
  =>
    let arr: Array[String] iso = recover Array[String] end
    let rb = Reader
    rb.append(data)
    var bytes_left = rb.u32_be()
    let timestamp = rb.u64_be()
    arr.push(timestamp.string())
    while bytes_left > 0 do
      var next_total_size = rb.u32_be()
      var next_bytes_left = next_total_size
      while next_bytes_left > 0 do
        let s_len = rb.u32_be()
        next_bytes_left = next_bytes_left - 4
        let next_str = String.from_array(rb.block(s_len.usize()))
        arr.push(next_str)
        next_bytes_left = next_bytes_left - s_len
      end
      bytes_left = bytes_left - (next_total_size + 4)
    end
    consume arr

