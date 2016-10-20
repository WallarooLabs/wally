use "buffered"

interface SourceDecoder[Out: Any val]
  fun apply(data: Array[U8] val): Out ?

interface SinkEncoder[In: Any val]
  fun apply(input: In, wb: Writer): Array[ByteSeq] val
    
trait EncoderWrapper
  fun encode[D: Any val](d: D, wb: Writer): Array[ByteSeq] val ?

class TypedEncoderWrapper[In: Any val] is EncoderWrapper
  let _encoder: SinkEncoder[In] val

  new val create(e: SinkEncoder[In] val) =>
    _encoder = e

  fun encode[D: Any val](d: D, wb: Writer): Array[ByteSeq] val ? =>
    match d
    | let i: In =>
      _encoder(i, wb)
    else
      error
    end
