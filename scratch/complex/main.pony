use "collections"
use "options"
use "random"
use "time"
use "buffered"
use "files"

actor Main
  new create(env: Env) =>
    let options = Options(env.args)
    var file_path = "complex_numbers.msg"
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

      let half = message_count / 2

      for idx in Range[I32](-half, half) do
        let real = idx
        let imaginary = idx * 2
        file.writev(ComplexEncoder(real, imaginary, wb))
      end

      file.dispose()
    end


primitive ComplexEncoder
  fun apply(r: I32, i: I32, wb: Writer = Writer): Array[ByteSeq] val =>
    // Header
    wb.u32_be(8)
    // Fields
    wb.i32_be(r)
    wb.i32_be(i)
    wb.done()