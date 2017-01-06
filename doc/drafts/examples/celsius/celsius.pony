use "buffered"
use "sendence/bytes"
use "wallaroo"
use "wallaroo/tcp-source"
use "wallaroo/topology"

actor Main
  new create(env: Env) =>
    try
      let application = recover val
        Application("Celsius Conversion App")
          .new_pipeline[F32, F32]("Celsius Conversion", CelsiusDecoder)
            .to[F32]({(): Multiply => Multiply})
            .to[F32]({(): Add => Add})
            .to_sink(FahrenheitEncoder, recover [0] end)
      end
      Startup(env, application, "celsius-conversion")
    else
      env.out.print("Couldn't build topology")
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
