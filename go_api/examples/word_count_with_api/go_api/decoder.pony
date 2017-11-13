use "wallaroo/core/source"

use @DecoderHeaderLength[U64](did: U64)
use @DecoderPayloadLength[U64](did: U64, dp: Pointer[U8] tag, ds: U64)
use @DecoderDecode[U64](did: U64, dp: Pointer[U8] tag, ds: U64)

class val GoDecoder is FramedSourceHandler[GoData]
  var _decoder_id: U64

  new val create(decoder_id: U64) =>
    _decoder_id = decoder_id

  fun header_length(): USize =>
    @DecoderHeaderLength(_decoder_id).usize()

  fun payload_length(data: Array[U8] iso): USize =>
    @DecoderPayloadLength(_decoder_id, data.cpointer(),
      data.size().u64()).usize()

  fun decode(data: Array[U8] val): GoData =>
    GoData(@DecoderDecode(_decoder_id, data.cpointer(), data.size().u64()))

  fun _serialise_space(): USize =>
    ComponentSerializeGetSpace(_decoder_id)

  fun _serialise(bytes: Pointer[U8] tag) =>
    ComponentSerialize(_decoder_id, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _decoder_id = ComponentDeserialize(bytes)

  fun _final() =>
    RemoveComponent(_decoder_id)
