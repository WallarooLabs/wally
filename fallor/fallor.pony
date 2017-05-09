use "buffered"
use "net"
use "files"
use "sendence/bytes"
use "sendence/messages"
use "sendence/options"

actor Main
  new create(env: Env) =>
    let options = Options(env.args)
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

      let fp = FilePath(auth, input_file_path)
      let input = ReceiverFileDataSource(fp)
      let output_file = File(FilePath(auth, output_file_path))

      for bytes in input do
        let fields =
          try
            FallorMsgDecoder.with_timestamp(bytes)
          else
            env.err.print("Problem decoding!")
            error
          end
        output_file.print(", ".join(fields))
      end
      output_file.dispose()
    else
      env.err.print("Error reading and writing files.")
    end

class ReceiverFileDataSource is Iterator[Array[U8] val]
  let _file: File

  new create(path: FilePath val) =>
    _file = File(path)

  fun ref has_next(): Bool =>
    if _file.position() < _file.size() then
      true
    else
      false
    end

  fun ref next(): Array[U8] val =>
    // 4 bytes LENGTH HEADER + 8 byte U64 giles receiver timestamp
    let h = _file.read(12)
    try
      let expect: USize = Bytes.to_u32(h(0), h(1), h(2), h(3)).usize()
      h.append(_file.read(expect))
      h
    else
      ifdef debug then
        @printf[I32]("Failed to convert message header!\n".cstring())
      end
      recover Array[U8] end
    end
