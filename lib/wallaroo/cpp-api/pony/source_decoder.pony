use "wallaroo/messages"

use @w_source_decoder_decode[DataP](source_decoder: SourceDecoderP,
  data: Pointer[U8] tag, size: USize)

type SourceDecoderP is ManagedObjectP

class CPPSourceDecoder is SourceDecoder[CPPData val]
  let _source_decoder: CPPManagedObject val

  new create(source_decoder: CPPManagedObject val) =>
    _source_decoder = source_decoder

  fun apply(data: Array[U8] val): CPPData val ? =>
    match @w_source_decoder_decode(_source_decoder.obj(), data.cstring(),
      data.size())
    | let result: DataP if (not result.is_null()) =>
      recover CPPData(CPPManagedObject(result)) end
    else
      error
    end