use "buffered"

interface val SinkEncoder[In: Any val]
  fun apply(input: In, wb: Writer): Array[ByteSeq] val

trait val EncoderWrapper
  fun encode[D: Any val](d: D, wb: Writer): Array[ByteSeq] val ?

class val TypedEncoderWrapper[In: Any val] is EncoderWrapper
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
