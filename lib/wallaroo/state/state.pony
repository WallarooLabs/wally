use "buffered"
use "serialise"
use "wallaroo/fail"

trait ref State
  fun write_log_entry(out_writer: Writer, auth: AmbientAuth) =>
    try
      let serialized =
        Serialised(SerialiseAuth(auth), this).output(OutputSerialisedAuth(auth))
      out_writer.write(serialized)
    else
      Fail()
    end

  fun read_log_entry(in_reader: Reader, auth: AmbientAuth): State ? =>
    try
      let data: Array[U8] iso = in_reader.block(in_reader.size())
      match Serialised.input(InputSerialisedAuth(auth), consume data)(
        DeserialiseAuth(auth))
      | let s: State => s
      else
        error
      end
    else
      error
    end
