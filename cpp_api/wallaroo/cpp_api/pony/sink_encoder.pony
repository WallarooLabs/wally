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

use "buffered"
use "wallaroo/sink/tcp_sink"

use @w_sink_encoder_get_size[USize](sink_encoder: SinkEncoderP,
  data: DataP tag)

use @w_sink_encoder_encode[None](sink_encoder: SinkEncoderP,
  data: DataP tag, bytes: Pointer[U8] tag, size: USize)

type SinkEncoderP is Pointer[U8] val

class CPPSinkEncoder is TCPSinkEncoder[CPPData val]
  var _sink_encoder: SinkEncoderP

  new create(sink_encoder: SinkEncoderP) =>
    _sink_encoder = sink_encoder

  fun apply(data: CPPData val, wb: Writer): Array[ByteSeq] val =>
    let size = @w_sink_encoder_get_size(_sink_encoder, data.obj())
    recover
      [as ByteSeq: recover
        let bytes = Array[U8].undefined(size)
        if size > 0 then
          @w_sink_encoder_encode(_sink_encoder, data.obj(),
            bytes.cpointer(), size)
        end
        bytes
      end]
    end

  fun _serialise_space(): USize =>
    @w_serializable_serialize_get_size(_sink_encoder)

  fun _serialise(bytes: Pointer[U8] tag) =>
    @w_serializable_serialize(_sink_encoder, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _sink_encoder = recover
      @w_user_serializable_deserialize(bytes)
    end

  fun _final() =>
    @w_managed_object_delete(_sink_encoder)
