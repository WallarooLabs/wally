use "buffered"
use "wallaroo/messages"
// use "wallaroo/topology"

use @w_sink_encoder_get_size[USize](sink_encoder: SinkEncoderP,
  data: DataP tag)

use @w_sink_encoder_encode[None](sink_encoder: SinkEncoderP,
  data: DataP tag, bytes: Pointer[U8] tag, size: USize)

type SinkEncoderP is ManagedObjectP

class CPPSinkEncoder is SinkEncoder[CPPData val]
  let _sink_encoder: CPPManagedObject val

  new create(sink_encoder: CPPManagedObject val) =>
    _sink_encoder = sink_encoder

  fun apply(data: CPPData val, wb: Writer): Array[ByteSeq] val =>
    let size = @w_sink_encoder_get_size(_sink_encoder.obj(), data.obj())
    recover 
      [as ByteSeq: recover
        let bytes = Array[U8].undefined(size)
        if size > 0 then
          @w_sink_encoder_encode(_sink_encoder.obj(), data.obj(),
            bytes.cstring(), size)
        end
        bytes
      end]
    end