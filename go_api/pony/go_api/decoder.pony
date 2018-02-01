use "wallaroo/core/source"

use @DecoderHeaderLength[U64](did: U64)
use @DecoderPayloadLength[U64](did: U64, dp: Pointer[U8] tag, ds: U64)
use @DecoderDecode[U64](did: U64, dp: Pointer[U8] tag, ds: U64)

class val GoFramedSourceHandler is FramedSourceHandler[GoData]
  var _decoder_id: U64

  new val create(decoder_id: U64) =>
    _decoder_id = decoder_id

  fun header_length(): USize =>
   //@DecoderHeaderLength(_decoder_id).usize()
   4

  fun payload_length(data: Array[U8] iso): USize =>
    //@DecoderPayloadLength().usize()
    //@DecoderPayloadLength(_decoder_id, data.cpointer(),
     // data.size().u64()).usize()
    42

  fun decode(data: Array[U8] val): GoData =>
    GoData(@DecoderDecode(_decoder_id, data.cpointer(), data.size().u64()))
    //@DecoderDecode(_decoder_id, data.cpointer(), data.size().u64())
    //GoData(1)

  fun _serialise_space(): USize =>
    ComponentSerializeGetSpace(_decoder_id, ComponentType.decoder())

  fun _serialise(bytes: Pointer[U8] tag) =>
    ComponentSerialize(_decoder_id, bytes, ComponentType.decoder())

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _decoder_id = ComponentDeserialize(bytes, ComponentType.decoder())

  fun _final() =>
    RemoveComponent(_decoder_id, ComponentType.decoder())

class val GoSourceHandler is SourceHandler[GoData]
  var _decoder_id: U64

  new val create(decoder_id: U64) =>
    _decoder_id = decoder_id

  fun decode(data: Array[U8] val): GoData =>
    @printf[I32]("DIDNT EXPECT TO SEE THIS\n".cstring())
    GoData(@DecoderDecode(_decoder_id, data.cpointer(), data.size().u64()))

  fun _serialise_space(): USize =>
    ComponentSerializeGetSpace(_decoder_id, ComponentType.decoder())

  fun _serialise(bytes: Pointer[U8] tag) =>
    ComponentSerialize(_decoder_id, bytes, ComponentType.decoder())

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _decoder_id = ComponentDeserialize(bytes, ComponentType.decoder())

  fun _final() =>
    RemoveComponent(_decoder_id, ComponentType.decoder())
