use "buffered"

interface val KafkaSinkEncoder[In: Any val]
  // Returns a tuple (encoded_value, encoded_key) where you can pass None
  // for the encoded_key if there is none
  fun apply(input: In, wb: Writer):
    (Array[ByteSeq] val, (Array[ByteSeq] val | None))

trait val KafkaEncoderWrapper
  fun encode[D: Any val](d: D, wb: Writer):
    (Array[ByteSeq] val, (Array[ByteSeq] val | None)) ?

class val TypedKafkaEncoderWrapper[In: Any val] is KafkaEncoderWrapper
  let _encoder: KafkaSinkEncoder[In] val

  new val create(e: KafkaSinkEncoder[In] val) =>
    _encoder = e

  fun encode[D: Any val](data: D, wb: Writer):
    (Array[ByteSeq] val, (Array[ByteSeq] val | None)) ?
  =>
    match data
    | let i: In =>
      _encoder(i, wb)
    else
      error
    end
