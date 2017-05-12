use "collections"
use "random"
use "time"
use "buffered"
use "files"

use "sendence/options"

actor Main
  new create(env: Env) =>
    let options = Options(env.args)
    var file_path = "celsius.msg"
    var message_count: I32 = 0

    options
      .add("output", "o", StringArgument)
      .add("message-count", "m", I64Argument)

    for option in options do
      match option
      | ("output", let arg: String) => file_path = arg
      | ("message-count", let arg: I64) => message_count = arg.i32()
      end
    end

    try
      let auth = env.root as AmbientAuth

      let wb: Writer = Writer

      let rand = MT(Time.nanos())

      let file = File(FilePath(auth, file_path))

      if message_count == 0 then
        env.out.print("Specify a message count (--message-count/-m)!")
        error
      end

      for idx in Range[I32](0, message_count) do
        let next_value = (rand.real() * 10000).f32()
        file.writev(CelsiusEncoder(next_value, wb))
      end

      file.dispose()
    end


primitive CelsiusEncoder
  fun apply(c: F32, wb: Writer = Writer): Array[ByteSeq] val =>
    // Header
    wb.u32_be(4)
    // Fields
    wb.f32_be(c)
    wb.done()
