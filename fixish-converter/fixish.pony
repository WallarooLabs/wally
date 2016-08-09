use "net"
use "options"
use "files"
use "sendence/messages"
use "sendence/fix"
use "sendence/new-fix"
use "buffered"
use "collections"

actor Main
  let _env: Env

  new create(env: Env) =>
    _env = env
    let options = Options(env)
    var input_file_path = ""
    var output_file_path = ""
    var readable = false

    options
      .add("input", "i", StringArgument)
      .add("output", "o", StringArgument)
      .add("readable", "r", None)
      .add("help", "h", None)

      for option in options do
        match option
        | ("input", let arg: String) => input_file_path = arg
        | ("output", let arg: String) => output_file_path = arg
        | ("readable", None) => readable = true
        | ("help", None) => 
          help()
          return
        end
      end

    if (input_file_path == "") or (output_file_path == "") then
      help()
      return
    end

    try
      let auth = env.root as AmbientAuth

      let input_file = File(FilePath(auth, input_file_path))
      let output_file = File(FilePath(auth, output_file_path))
      output_file.set_length(0)

      if readable then
        let input: Array[U8] val = input_file.read(input_file.size())
        let rb = Reader
        rb.append(input)
        var left = input.size()
        while left > 0 do
          let size = rb.u32_be().usize()
          let next = rb.block(size)
          match FixishMsgDecoder(consume next)
          | let m: FixOrderMessage val =>
            output_file.print(m.string())
          | let m: FixNbboMessage val => 
            output_file.print(m.string())
          end
          left = left - (4 + size)
        end
      else
        let wb = Writer
        var p = true
        for line in input_file.lines() do
          match FixParser(line)
          | let m: FixOrderMessage val => 
            try
              if m.order_id().size() != 6 then error end
              if m.transact_time().size() != 21 then error end

              let symbol = pad_symbol(m.symbol())
              let encoded = FixishMsgEncoder.order(m.side(), m.account(),
                m.order_id(), symbol, m.order_qty(), m.price(), 
                m.transact_time())
              wb.writev(encoded)
            else
              @printf[I32]("Error: Field size not respected\n".cstring())
            end
          | let m: FixNbboMessage val => 
            try
              if m.transact_time().size() != 21 then error end
              let symbol = pad_symbol(m.symbol())
              let encoded = FixishMsgEncoder.nbbo(symbol, m.transact_time(),
                m.bid_px(), m.offer_px())
              // wb.u32_be(encoded.size().u32())
              wb.writev(encoded)
            else
              @printf[I32]("Error: Field size not respected\n".cstring())
            end
          end
        end
        output_file.writev(wb.done())
      end 
      
      input_file.dispose()
      output_file.dispose()
    else
      env.err.print("Error reading and writing files.")
    end

  fun pad_symbol(symbol': String): String =>
    var symbol = symbol'
    var symbol_diff = 
      if symbol.size() < 4 then
        4 - symbol.size()
      else
        0
      end
    for i in Range(0 , symbol_diff) do
      symbol = " " + symbol
    end
    symbol

  fun help() =>
    _env.out.print(
      """
      PARAMETERS:
      -----------------------------------------------------------------------------------
      --input/-i [Sets file to read from]
      --output/-o [Sets file to write to]
      -----------------------------------------------------------------------------------
      """
    )
