use "buffered"
use "wallaroo/core/sink"

use @EncoderEncode[Pointer[U8] ref](eid: U64, did: U64, size: Pointer[U64])

class val GoEncoder
  var _encoder_id: U64

  new val create(encoder_id: U64) =>
    _encoder_id = encoder_id

  fun apply(data: GoData, wb: Writer): Array[ByteSeq] val =>
    var s: U64 = 0
    let r = recover val
      let e = @EncoderEncode(_encoder_id, data.id(), addressof s)
      let r' = Array[U8].from_cpointer(e, s.usize()).clone()
      @free(e)
      r'
    end
    wb.write(r)
    wb.done()

  fun _serialise_space(): USize =>
    ComponentSerializeGetSpace(_encoder_id)

  fun _serialise(bytes: Pointer[U8] tag) =>
    ComponentSerialize(_encoder_id, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _encoder_id = ComponentDeserialize(bytes)

  fun _final() =>
    RemoveComponent(_encoder_id)
