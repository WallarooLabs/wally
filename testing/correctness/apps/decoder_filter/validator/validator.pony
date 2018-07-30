/*

Copyright 2017 The Wallaroo Authors.

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

"""
Validator validates the received.txt file from a run of
decoder_filter.

It ensures the following:
1. we've filtered out odd values in the decoder.
"""

use "assert"
use "collections"
use "files"
use "wallaroo_labs/bytes"
use "wallaroo_labs/options"

actor Main
  new create(env: Env) =>
    let options = Options(env.args)
    var input_file_path = "received.txt"
    var expected: U64 = 1000
    var at_least_once: Bool = false
    var keys: Array[String] val = recover Array[String] end

    options
      .add("input", "i", StringArgument)
      .add("expected", "e", I64Argument)
      .add("help", "h", None)

      for option in options do
        match option
        | ("input", let arg: String) => input_file_path = arg
        | ("expected", let arg: I64) => expected = arg.u64()
        | ("help", None) =>
          @printf[I32](
            """
            PARAMETERS:
            -----------------------------------------------------------------------------------
            --input/-i [Sets file to read from (default: received.txt)]
            --expected/-e [Sets the expected number of messages to validate (default: 1000)]
            -----------------------------------------------------------------------------------
            """
          )
          return
        end
      end

    try
      let auth = env.root as AmbientAuth
      let fp = FilePath(auth, input_file_path)?
      Fact(fp.exists(), "Input file '" + fp.path + "' does not exist.")?
      let input = ReceiverFileDataSource(fp)
      let validator = OutputValidator(expected)

      for bytes in input do
        let v =
          try
            U64Decoder.decode(bytes)?
          else
            @printf[I32]("Problem decoding!\n".cstring())
            error
          end
        validator.add_received(consume v)
      end
      validator.finalize()?
      @printf[I32]("Validation successful!\n".cstring())
    else
      @printf[I32]("Error validating file.\n".cstring())
      @exit[None](U8(1))
    end

class OutputValidator
  """
  Test the output from the decoder_filter.

  - For each number, verify it is even.
  """
  let _expected: U64
  var _received_array: Array[U64]

  new create(expected: U64) =>
    _received_array = Array[U64]
    _expected = expected

  fun ref add_received(received: U64) =>
    _received_array.push(received)

  fun finalize() ? =>
    for num in _received_array.values() do
      verify_is_even(num)?
    end

  fun verify_is_even(num: U64) ? =>
    Fact(((num % 2) == 0), "Encountered an odd value: " + num.string())?

primitive U64Decoder
    fun decode(data: Array[U8] val): U64 ? =>
    Bytes.to_u64(data(0)?, data(1)?, data(2)?, data(3)?, data(4)?,
      data(5)?, data(6)?, data(7)?)


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
    // 4 bytes LENGTH HEADER
    let h = _file.read(4)
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
