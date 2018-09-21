/*

Copyright 2018 The Wallaroo Authors.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
 implied. See the License for the specific language governing
 permissions and limitations under the License.

*/

use "net"
use "wallaroo_labs/options"
use "files"
use "wallaroo_labs/messages"
use "wallaroo_labs/fix"
use "wallaroo_labs/new_fix"
use "buffered"
use "collections"

actor Main
  let _env: Env

  new create(env: Env) =>
    _env = env
    let options = Options(env.args)
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

      let input_file = File(FilePath(auth, input_file_path)?)
      let output_file = File(FilePath(auth, output_file_path)?)
      output_file.set_length(0)

      if readable then
        let input: Array[U8] val = input_file.read(input_file.size())
        let rb = Reader
        rb.append(input)
        var left = input.size()
        while left > 0 do
          let size = rb.u32_be()?.usize()
          let next = rb.block(size)?
          match FixishMsgDecoder(consume next)?
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
      @printf[I32]("Error reading and writing files.\n".cstring())
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
    @printf[I32](
      """
      PARAMETERS:
      -----------------------------------------------------------------------------------
      --input/-i [Sets file to read from]
      --output/-o [Sets file to write to]
      -----------------------------------------------------------------------------------
      """.cstring())
