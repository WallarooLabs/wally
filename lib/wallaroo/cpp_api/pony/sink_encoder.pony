use "buffered"
use "wallaroo/messages"

use @w_sink_encoder_get_size[USize](sink_encoder: SinkEncoderP,
  data: DataP tag)

use @w_sink_encoder_encode[None](sink_encoder: SinkEncoderP,
  data: DataP tag, bytes: Pointer[U8] tag, size: USize)

type SinkEncoderP is Pointer[U8] val

class CPPSinkEncoder is SinkEncoder[CPPData val]
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
    @w_serializable_serialize(_sink_encoder, bytes, USize(0))

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _sink_encoder = recover @w_user_serializable_deserialize(bytes, USize(0)) end

  fun _final() =>
    @w_managed_object_delete(_sink_encoder)
