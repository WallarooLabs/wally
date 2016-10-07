use "buffered"

interface SourceDecoder[Out: Any val]
  fun apply(data: Array[U8] val): Out ?

interface SinkEncoder[In: Any val]
  fun apply(input: In, wb: Writer): Array[ByteSeq] val
    