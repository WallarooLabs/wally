use "buffered"
use "files"
use "serialise"
use "time"
use "sendence/bytes"
use "wallaroo"
use "wallaroo/fail"
use "wallaroo/tcp_source"
use "wallaroo/topology"

actor Main
  new create(env: Env) =>
    try
      let application = recover val
        Application("Celsius Conversion App")
          .new_pipeline[F32, F32]("Celsius Conversion")
            .from(CelsiusDecoder)
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

// primitive CelsiusFileDecoder is FileSourceHandler[F32]
//   fun decode(s: String): F32 ? =>
//     s.f32()

// class _FileSourceNotify is TimerNotify
//   let _file_source: FileSource

//   new create(file_source: FileSource) =>
//     _file_source = file_source

//   fun ref apply(timer: Timer, count: U64): Bool =>
//     _file_source.read()
//     true

// actor FileSource is TimerNotify
//   let _file_input: File iso
//   let _interval: U64

//   new create(file_input: File iso, interval: U64) =>
//     _file_input = consume file_input
//     _interval = interval
//     let timers = Timers
//     let timer = Timer(recover _FileSourceNotify(this) end, 1_000, _interval)
//     timers(consume timer)

//   be read() =>
//     try
//       @printf[I32]("%s\n".cstring(), _file_input.line().cstring())
//     end
