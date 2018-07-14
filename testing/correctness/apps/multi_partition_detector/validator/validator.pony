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
multi_partition_detector.

It ensures the following:
1. for each key there is exactly one of each sequence.
2. for each sequence, the windows are in ascending order from left to right
3. for each window, no gaps or duplicates exist
4. for each consecutive pair of windows, no gaps or duplicates exist.
5. in each sequence, the last values match the expected final value.
"""

use "assert"
use "collections"
use "files"
use "wallaroo_labs/bytes"
use "wallaroo_labs/options"
use "../building_blocks"
use "../inline_validation"
use "../window_codecs"

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
      .add("keys", "k", StringArgument)
      .add("at-least-once", "a", None)
      .add("help", "h", None)

      for option in options do
        match option
        | ("input", let arg: String) => input_file_path = arg
        | ("expected", let arg: I64) => expected = arg.u64()
        | ("at-least-once", None) => at_least_once = true
        | ("keys", let arg: String) => keys = arg.split(",")
        | ("help", None) =>
          @printf[I32](
            """
            PARAMETERS:
            -----------------------------------------------------------------------------------
            --input/-i [Sets file to read from (default: received.txt)]
            --expected/-e [Sets the expected number of messages to validate (default: 1000)]
            --at-least-once/-a [Sets at-least-once mode (default: exactly-once)]
            --keys/-k [Optional: list of keys to verify. (default: assume all
                       keys are valid)]
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
      let validator = OutputValidator(expected, at_least_once, consume keys)

      for bytes in input do
        let v =
          try
            Message.decode(bytes)?
          else
            @printf[I32]("Problem decoding!\n".cstring())
            error
          end
        validator(consume v)?
      end
      validator.finalize()?
      @printf[I32]("Validation successful!\n".cstring())
    else
      @printf[I32]("Error validating file.\n".cstring())
      @exit[None](U8(1))
    end

class OutputValidator
  """
  Test the output from the multi_partition_detector.

  - For each new key, create a new SequenceValidator if the key is in the
    specified key list, or if the list is empty.
  - For each new point in an existing key's sequence, run its validator's
    apply()
  - At finalize():
    - compare all the final values in each sequence validator
    - validate all required keys are present
  """
  let _keys: Set[String] val 
  let _seen: Array[String] ref = recover Array[String] end
  let _expected: U64
  let _at_least_once: Bool
  let _sequence_validators: Map[Key, SequenceValidator ref] ref = recover
      Map[Key, SequenceValidator ref] end

  new create(expected: U64, at_least_once_mode: Bool = false,
    keys: Array[String] val = recover Array[String] end) =>
    _expected = expected
    _at_least_once = at_least_once_mode
    _keys = recover
      let s: Set[String] ref = recover Set[String] end
      s.union(keys.values())
      consume s
    end

  fun ref apply(m: Message) ? =>
    let k = WindowPartitionFunction(m)
    if _keys.size() > 0 then
      // validate k is in whitelisted keys set _keys
      Fact(_keys.contains(k), "Encountered a non-whitelisted key: " + k)?
    end
    let sv = 
      try
        _sequence_validators(k)?
      else 
        _sequence_validators.insert(k, SequenceValidator(k, _at_least_once))?
      end
    sv(m)?


  fun finalize() ? =>
    """
    - validate all the final values in each sequence validator
    - validate all required keys are present
    """
    // Validate keys
    if _keys.size() > 1 then 
      let observed_keys: Set[String] = recover Set[String] end
      observed_keys.union(_sequence_validators.keys())
      Fact(_keys == observed_keys, "Expected keys do not match observed keys")?
    end

    // Validate final values in each sequence validator
    for sv in _sequence_validators.values() do
      sv.test_expected_value(_expected)?
    end

class SequenceValidator
  """
  Apply sequentiality and increments tests for a single partition
  """
  let _at_least_once: Bool
  var _last: (Message | None) = None
  var _counter: USize = 0
  let _key: Key

  new create(k: Key, at_least_once_mode: Bool = false) =>
    _at_least_once = at_least_once_mode
    _key = k

  fun ref apply(m: Message) ? =>
    let a: Array[Value] val = m.window()?.to_array()
    // increments test
    Fact(IncrementsTest(a), "Increments test failed with window " +
      m.string() + " after " + _counter.string() + " values.")?
    match _last
    | None =>
      // set current to last
      _last = m
    | let m': Message =>
      // compare with last
      Fact(test_sequentiality(m)?,
         "Sequentiality test failed on key " + _key +
        " with the windows (" + m'.string() + ", " + m.string() + ") after " +
        _counter.string() + " values.")?
      // set to last
      _last = m
    end
    _counter = _counter + 1

    fun test_sequentiality(m: Message): Bool ? =>
      let m' = _last as Message
      let v = m.value()
      let v' = m'.value()
      if _at_least_once then
        // at_least_once: either advance by one or be less than equal to prev
        return ((v == (v' + 1)) or (v <= v'))
      else
        // exactly_once: advance by one
        return (v == (v' + 1))
      end

    fun test_expected_value(u: U64) ? =>
      match _last
      | None => Fact(false, "Expected value test failed for key " + _key +
        " because there is no data for this key.")?
      | let m: Message =>
        Fact(m.value() == u, "Expected value test failed for key " + _key +
          " with expected: " + u.string() + " and window: " + m.string())?
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
