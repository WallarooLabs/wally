"""
Topology Layout Filtered Stateless Data Gen App

Given an integer input of "-m", this application will generate a framed
message processable by Giles Sender for 1 and up to the value passed.
These messages will be output to the file name passed to "-o".

Since our Filtering Stateless computation is an OddFilter and followed by
a Stateless U64 Double, the values will be filtered if odd and then
doubled  if not filtered. The non-filtered results will be written to file
as a framed message to compare the expected results. These messages will be
written to the file passed to the "-e" argument.
"""

use "buffered"
use "collections"
use "files"
use "generic_app_components"
use "random"
use "sendence/options"

actor Main
  new create(env: Env) =>
    let options = Options(env.args)
    var output_file_path = "numbers.msg"
    var expected_file_path = ""
    var message_count: I64 = 0

    options
      .add("output", "o", StringArgument)
      .add("message-count", "m", I64Argument)
      .add("expected", "e", StringArgument)

    for option in options do
      match option
      | ("output", let arg: String) =>  output_file_path = arg
      | ("message-count", let arg: I64) => message_count = arg.i64()
      | ("expected", let arg: String) => expected_file_path = arg
      end
    end

    try
      let auth = env.root as AmbientAuth

      let wb: Writer = Writer

      let out_file = File(FilePath(auth, output_file_path))
      let exp_file = if expected_file_path != "" then
        File(FilePath(auth, expected_file_path))
      else
       None
    end

    for i in Range[I64](0, message_count) do
      let next_value = i + 1
      out_file.writev(FramedU64Encoder(next_value.u64(), wb))

      let filtered_value = OddFilter(next_value.u64())
      match filtered_value
      | (let n: U64) =>
        let doubled_value = Double(n)
        match exp_file
        | (let e: File) => e.writev(FramedU64Encoder(doubled_value, wb))
        end
      end
    end

    out_file.dispose()
    match exp_file
      | (let e: File) => e.dispose()
      end
    end
