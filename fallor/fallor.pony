use "net"
use "options"
use "files"
use "sendence/messages"

actor Main
  new create(env: Env) =>
    let options = Options(env)
    var input_file_path = "received.txt"
    var output_file_path = "fallor-readable.txt"

    options
      .add("input", "i", StringArgument)
      .add("output", "o", StringArgument)
      .add("help", "h", None)

      for option in options do
        match option
        | ("input", let arg: String) => input_file_path = arg
        | ("output", let arg: String) => output_file_path = arg
        | ("help", None) => 
          env.out.print(
            """
            PARAMETERS:
            -----------------------------------------------------------------------------------
            --input/-i [Sets file to read from (default: received.txt)]
            --output/-o [Sets file to write to (default: fallor-readable.txt)]
            -----------------------------------------------------------------------------------
            """
          )
          return
        end
      end

    try
      let auth = env.root as AmbientAuth

      let input_file = File(FilePath(auth, input_file_path))
      let input: Array[U8] val = input_file.read(input_file.size())

      let output_file = File(FilePath(auth, output_file_path))

      let rb = ReadBuffer
      rb.append(input)
      var bytes_left = input.size()
      while bytes_left > 0 do
        // Msg size, msg size u32, and timestamp together make up next payload 
        // size
        let next_payload_size = rb.peek_u32_be() + 12 
        let fields = 
          try
            FallorMsgDecoder.with_timestamp(rb.block(next_payload_size.usize()))
          else
            env.err.print("Problem decoding!")
            error 
          end
        output_file.print(", ".join(fields))
        bytes_left = bytes_left - next_payload_size.usize()
      end
      input_file.dispose()
      output_file.dispose()
    else
      env.err.print("Error reading and writing files.")
    end
