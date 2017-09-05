/*

Copyright 2017 The Wallaroo Authors.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
 implied. See the License for the specific language governing
 permissions and limitations under the License.

*/

use "wallaroo/source"
use "wallaroo/source/tcp_source"

use @w_source_decoder_header_length[USize](source_decoder: SourceDecoderP)

use @w_source_decoder_payload_length[USize](source_decoder: SourceDecoderP,
  data: Pointer[U8] tag)

use @w_source_decoder_decode[DataP](source_decoder: SourceDecoderP,
  data: Pointer[U8] tag, size: USize)

type SourceDecoderP is Pointer[U8] val

class CPPSourceDecoder is FramedSourceHandler[CPPData val]
  var _source_decoder: SourceDecoderP
  let _header_length: USize

  new create(source_decoder: SourceDecoderP) =>
    _source_decoder = source_decoder
    _header_length = @w_source_decoder_header_length(_source_decoder)

  fun header_length(): USize =>
    _header_length

  fun payload_length(data: Array[U8] iso): USize =>
    @w_source_decoder_payload_length(_source_decoder, data.cpointer())

  fun decode(data: Array[U8] val): CPPData val ? =>
    match @w_source_decoder_decode(_source_decoder, data.cpointer(),
      data.size())
    | let result: DataP if (not result.is_null()) =>
      recover CPPData(result) end
    else
      error
    end

  fun _serialise_space(): USize =>
    @w_serializable_serialize_get_size(_source_decoder)

  fun _serialise(bytes: Pointer[U8] tag) =>
    @w_serializable_serialize(_source_decoder, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _source_decoder = recover
      @w_user_serializable_deserialize(bytes)
    end

  fun _final() =>
    @w_managed_object_delete(_source_decoder)
