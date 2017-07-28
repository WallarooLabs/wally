use "buffered"
use "files"
use "serialise"
use "time"
use "sendence/bytes"
use "wallaroo"
use "wallaroo/fail"
use "wallaroo/source"
use "wallaroo/tcp_source"
use "wallaroo/topology"

actor Main
  new create(env: Env) =>
    try
      let temps: Array[Array[U8] val] trn = recover Array[Array[U8] val] end
      temps.push(recover [as U8: 0, 0, 0, 0] end)
      let t: Array[Array[U8] val] val = consume temps

      let application = recover val
        Application("Celsius Conversion App")
          .new_pipeline[F32, F32]("Celsius Conversion")
            // TODO: get the host and service from the command line, not hard coded
            // .from(TCPSourceInformation[F32](CelsiusDecoder, "localhost", "3030"))
            .from(ArraySourceConfig[F32](t, 2_000_000_000, CelsiusArrayDecoder))
            .to[F32]({(): Multiply => Multiply})
            .to[F32]({(): Add => Add})
            .to_sink(FahrenheitEncoder, recover [0] end)
      end
      Startup(env, application, "celsius-conversion")
    else
      @printf[I32]("Couldn't build topology\n".cstring())
    end

primitive Multiply is Computation[F32, F32]
  fun apply(input: F32): F32 =>
    input * 1.8

  fun name(): String => "Multiply by 1.8"

primitive Add is Computation[F32, F32]
  fun apply(input: F32): F32 =>
    input + 32

  fun name(): String => "Add 32"

primitive CelsiusDecoder is FramedSourceHandler[F32]
  fun header_length(): USize =>
    4

  fun payload_length(data: Array[U8] iso): USize =>
    4

  fun decode(data: Array[U8] val): F32 ? =>
    Bytes.to_f32(data(0), data(1), data(2), data(3))

primitive FahrenheitEncoder
  fun apply(f: F32, wb: Writer): Array[ByteSeq] val =>
    wb.f32_be(f)
    wb.done()

primitive CelsiusArrayDecoder is SourceHandler[F32]
  fun decode(a: Array[U8] val): F32 ? =>
    let r = Reader
    r.append(a)
    r.f32_be()
