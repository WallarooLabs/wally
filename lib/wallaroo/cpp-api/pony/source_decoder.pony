use "wallaroo/tcp-source"

use @w_source_decoder_header_length[USize](source_decoder: SourceDecoderP)

use @w_source_decoder_payload_length[USize](source_decoder: SourceDecoderP,
  data: Pointer[U8] tag)

use @w_source_decoder_decode[DataP](source_decoder: SourceDecoderP,
  data: Pointer[U8] tag, size: USize)

type SourceDecoderP is ManagedObjectP

class CPPSourceDecoder is FramedSourceHandler[CPPData val]
  let _source_decoder: CPPManagedObject val
  let _header_length: USize

  new create(source_decoder: CPPManagedObject val) =>
    _source_decoder = source_decoder
    _header_length = @w_source_decoder_header_length(_source_decoder.obj())

  fun header_length(): USize =>
    _header_length

  fun payload_length(data: Array[U8] iso): USize =>
    @w_source_decoder_payload_length(_source_decoder.obj(), data.cpointer())

  fun decode(data: Array[U8] val): CPPData val ? =>
    match @w_source_decoder_decode(_source_decoder.obj(), data.cpointer(),
      data.size())
    | let result: DataP if (not result.is_null()) =>
      recover CPPData(CPPManagedObject(result)) end
    else
      error
    end