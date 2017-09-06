use "collections"
use "random"
use "time"
use "buffered"
use "files"

use "wallaroo_labs/options"

actor Main
  new create(env: Env) =>
    let options = Options(env.args)
    var output_file_path = "celsius.msg"
    var expected_file_path = ""
    var message_count: I32 = 0

    options
      .add("output", "o", StringArgument)
      .add("expected", "e", StringArgument)
      .add("message-count", "m", I64Argument)

    for option in options do
      match option
      | ("output", let arg: String) => output_file_path = arg
      | ("message-count", let arg: I64) => message_count = arg.i32()
      | ("expected", let arg: String) => expected_file_path = arg
      end
    end

    try
      let auth = env.root as AmbientAuth

      let wb: Writer = Writer

      let rand = MT(Time.nanos())

      let out_file = File(FilePath(auth, output_file_path))
      let exp_file = if expected_file_path != "" then
        File(FilePath(auth, expected_file_path))
      else
        None
      end

      if message_count == 0 then
        @printf[I32]("Specify a message count (--message-count/-m)!\n"
          .cstring())
        error
      end

      for idx in Range[I32](0, message_count) do
        let next_value = (rand.real() * 10000).f32()
        out_file.writev(CelsiusEncoder(next_value, wb))
        match exp_file
        | (let e: File) => e.writev(FahrenheitEncoder(next_value, wb))
        end
      end

      out_file.dispose()
      match exp_file
      | (let e: File) => e.dispose()
      end
    end


primitive FahrenheitEncoder
  fun apply(c: F32, wb: Writer = Writer): Array[ByteSeq] val =>
  // Header
  wb.u32_be(4)
  // convert to fahrenheit: *1.8 + 32
  let f = (c*1.8) + 32
  // Write fahrenheit
  wb.f32_be(f)
  wb.done()

primitive CelsiusEncoder
  fun apply(c: F32, wb: Writer = Writer): Array[ByteSeq] val =>
    // Header
    wb.u32_be(4)
    // Fields
    wb.f32_be(c)
    wb.done()
