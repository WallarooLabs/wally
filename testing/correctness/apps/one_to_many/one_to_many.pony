use "buffered"
use "sendence/bytes"
use "wallaroo/"
use "wallaroo/state"
use "wallaroo/tcp_source"
use "wallaroo/topology"

actor Main
  new create(env: Env) =>
    try
      let application = recover val
        Application("One to Many App")
          .new_pipeline[String, String]("Pipeline", MyDecoder)
            .to[String]({(): Computation[String, String] iso^
              => ComputeIt })
            .to_sink(MyEncoder, recover [0] end)
      end
      Startup(env, application, None)
    else
      @printf[I32]("Couldn't build topology\n".cstring())
    end

class iso ComputeIt is Computation[String, String]
  fun apply(input: String): Array[String] val =>
    @printf[I32]("Computing it!\n".cstring())

    recover val [input, " ", input, "\n"] end

  fun name(): String => "ComputeIt"

primitive MyDecoder is FramedSourceHandler[String]
  fun header_length(): USize =>
    4

  fun payload_length(data: Array[U8] iso): USize ? =>
    Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()

  fun decode(data: Array[U8] val): String val =>
    String.from_array(data)

primitive MyEncoder
  fun apply(c: String, wb: Writer): Array[ByteSeq] val =>
    @printf[I32]("Got a result!\n".cstring())
    // Header
    wb.u32_be(c.size().u32())
    // Fields
    wb.write(c)
    wb.done()
