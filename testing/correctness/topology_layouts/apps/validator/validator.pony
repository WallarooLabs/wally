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
Validator validates the received.txt file from a topology layout test run
against the expected file, for use when testing topologies with state
partitons.
"""

use "assert"
use "collections"
use "files"
use "generic_app_components"
use "wallaroo_labs/bytes"
use "wallaroo_labs/messages"
use "wallaroo_labs/options"

actor Main
  new create(env: Env) =>
    let options = Options(env.args)
    var input_file_path = "received.txt"
    var expected_file_path = "_expected.msg"

    options
      .add("input", "i", StringArgument)
      .add("expected", "e", StringArgument)
      .add("help", "h", None)

    for option in options do
      match option
      | ("input", let arg: String) => input_file_path = arg
      | ("expected", let arg: String) => expected_file_path = arg
      | ("help", None) =>
        @printf[I32](
          """
          PARAMETERS:
          -----------------------------------------------------------------------------------
            --input/-i [Sets file to read from (default: received.txt)]
            --expected/-e [Sets file to read from (default: _expected.msg)]
            -----------------------------------------------------------------------------------
          """
        )
        return
      end
    end

    try
      let auth = env.root as AmbientAuth
      let validator = U64SetValidator
      let ifp = FilePath(auth, input_file_path)?
      Fact(ifp.exists(), "Input file: '" + ifp.path + "' does not exist." )?
      let input = ReceiverFileDataSource(ifp)

      for bytes in input do
        let fields =
          try
            FallorMsgDecoder.with_timestamp(bytes)?
          else
            @printf[I32]("Problem decoding received data!\n")
            error
          end
          let ts = fields(0)?
          let data = U64Decoder(fields(1)?)?
          validator.add_received(consume data)
      end

      let efp = FilePath(auth, expected_file_path)?
      Fact(efp.exists(), "Expected file: '" + efp.path + "' does not exist." )?
      let expected = ExpectedFileDataSource(efp)

      for bytes in input do
          let data = U64Decoder.decode(bytes)?
          validator.add_expected(consume data)
      end
      validator.finalize()?
      @printf[I32]("Validation successful!\n".cstring())
    else
      @printf[I32]("Error validating received file.\n".cstring())
      @exit[None](U8(1))
    end

class U64SetValidator
  """
  Validates that the received data set is equal to the expected data set.
  """

  var _received_set: Set[U64]
  var _expected_set: Set[U64]

  new create() =>
    _received_set = Set[U64]
    _expected_set = Set[U64]

  fun ref add_received(received: U64) =>
    _received_set.add(received)

  fun ref add_expected(expected: U64) =>
    _expected_set.add(expected)

  fun finalize() ? =>
  Fact(test_received_expected_equality(),
    "Received data set does not match expected data set.\n")?

  fun test_received_expected_equality(): Bool =>
    """
    Return true if the received set is equal to the expected set.
    """
    _received_set.eq(_expected_set)


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
    // 4 bytes LENGTH HEADER + 8 byte U64 data receiver timestamp
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

class ExpectedFileDataSource is Iterator[Array[U8] val]
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
      expect
      let expected = _file.read(expect)
      expected
    else
      ifdef debug then
        @printf[I32]("Failed to convert message header!\n".cstring())
      end
      recover Array[U8] end
    end
