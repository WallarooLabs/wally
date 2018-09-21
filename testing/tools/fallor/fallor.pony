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

use "buffered"
use "net"
use "files"
use "wallaroo_labs/bytes"
use "wallaroo_labs/messages"
use "wallaroo_labs/options"

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
          @printf[I32](
            """
            PARAMETERS:
            -----------------------------------------------------------------------------------
            --input/-i [Sets file to read from (default: received.txt)]
            --output/-o [Sets file to write to (default: fallor-readable.txt)]
            -----------------------------------------------------------------------------------
            """.cstring())
          return
        end
      end

    try
      let auth = env.root as AmbientAuth

      let fp = FilePath(auth, input_file_path)?
      let input = ReceiverFileDataSource(fp)
      let output_file = File(FilePath(auth, output_file_path)?)

      for bytes in input do
        let fields =
          try
            FallorMsgDecoder.with_timestamp(bytes)?
          else
            @printf[I32]("Problem decoding!\n".cstring())
            error
          end
        output_file.print(", ".join(fields.values()))
      end
      output_file.dispose()
    else
      @printf[I32]("Error reading and writing files.\n".cstring())
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
      let expect: USize = Bytes.to_u32(h(0)?, h(1)?, h(2)?, h(3)?).usize()
      h.append(_file.read(expect))
      h
    else
      ifdef debug then
        @printf[I32]("Failed to convert message header!\n".cstring())
      end
      recover Array[U8] end
    end
