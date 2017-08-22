use "buffered"

interface val TCPSinkEncoder[In: Any val]
  fun apply(input: In, wb: Writer): Array[ByteSeq] val

trait val TCPEncoderWrapper
  fun encode[D: Any val](d: D, wb: Writer): Array[ByteSeq] val ?

class val TypedTCPEncoderWrapper[In: Any val] is TCPEncoderWrapper
  let _encoder: TCPSinkEncoder[In] val

  new val create(e: TCPSinkEncoder[In] val) =>
    _encoder = e

  fun encode[D: Any val](d: D, wb: Writer): Array[ByteSeq] val ? =>
    match d
    | let i: In =>
      _encoder(i, wb)
    else
      error
    end
