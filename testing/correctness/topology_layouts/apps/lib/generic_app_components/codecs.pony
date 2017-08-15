use "buffered"
use "sendence/bytes"
use "wallaroo/source"

primitive U64Decoder is FramedSourceHandler[U64 val]
  fun apply(data: String val): U64 ? =>
    Bytes.to_u64(data(0), data(1), data(2), data(3), data(4),
      data(5), data(6), data(7))

  fun header_length(): USize =>
    4

  fun payload_length(data: Array[U8] iso): USize ? =>
    Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()

  fun decode(data: Array[U8] val): U64 ? =>
    Bytes.to_u64(data(0), data(1), data(2), data(3), data(4),
      data(5), data(6), data(7))

primitive FramedU64Encoder
  fun apply(u: U64, wb: Writer): Array[ByteSeq] val =>
    wb.u32_be(8)
    wb.u64_be(u)
    wb.done()
