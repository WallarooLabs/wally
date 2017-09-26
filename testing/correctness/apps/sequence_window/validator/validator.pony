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
Validator validates the received.txt file from a sequence_window run, as saved
by giles-receiver.

It ensures that there are two types of sequences: mod2=1 and mod2=0, and that
for each, the sequence windows are in ascending order from left to right, and
that no gaps or duplicates exist between each pair of consecutive window in
their respective mod2 category.

In addition, it tests that the values begin with [0,0,0,1] and [0,0,0,2], and
that the last values in each category are within 1 of each other, as well
as that the highest value matches the expected value provided to the validator.
"""

use "assert"
use "collections"
use "files"
use "wallaroo_labs/bytes"
use "wallaroo_labs/options"
use "wallaroo_labs/messages"
use "ring"
use "window_codecs"

actor Main
  new create(env: Env) =>
    let options = Options(env.args)
    var input_file_path = "received.txt"
    var expected: U64 = 1000
    var at_least_once: Bool = false

    options
      .add("input", "i", StringArgument)
      .add("expected", "e", I64Argument)
      .add("at-least-once", "a", None)
      .add("help", "h", None)

      for option in options do
        match option
        | ("input", let arg: String) => input_file_path = arg
        | ("expected", let arg: I64) => expected = arg.u64()
        | ("at-least-once", None) => at_least_once = true
        | ("help", None) =>
          @printf[I32](
            """
            PARAMETERS:
            -----------------------------------------------------------------------------------
            --input/-i [Sets file to read from (default: received.txt)]
            --expected/-e [Sets the expected number of messages to validate (default: 1000)]
            --at-least-once/-a [Sets at-least-once mode (default: exactly-once)]
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
      let validator = WindowValidator(expected, at_least_once)

      for bytes in input do
        let fields =
          try
            FallorMsgDecoder.with_timestamp(bytes)?
          else
            @printf[I32]("Problem decoding!\n".cstring())
            error
          end
        let ts = fields(0)?
        let v = WindowU64Decoder(fields(1)?)?
        validator(consume v, consume ts)?
      end
      validator.finalize()?
      @printf[I32]("Validation successful!\n".cstring())
    else
      @printf[I32]("Error validating file.\n".cstring())
      @exit[None](U8(1))
    end

class WindowValidator
  """
  To test the output of sequence_window, we need to validate that the correct
  sequence of windows follows throughout.

  1. For each observed window, test:
  1.1. size == 4
  1.2. no non-leading zeroes are present (and at least one value is non-zero)
  1.3. all non-zero values have the same parity
  1.4. Values in a window increment as expected (by 0,1, or 2, and always by 2
    after a non-zero increment)
  1.5. sequentiality: the current window follows from the previous window
    (e.g. [4,6,8,10] follows [2,4,6,8])

  2. For the two final windows, test:
  2.1. the highest value matches the `--expected/-e` value
  2.2. the highet value in the non-highest-value window is exactly 1 less than
    the `--expected/-e` value.
  """

  var ring_0: Ring[U64] = Ring[U64].from_array(recover [0;0;0;0] end, 4, 0)
  var ring_1: Ring[U64] = Ring[U64].from_array(recover [0;0;0;0] end, 4 ,0)
  var count_0: U64 = 0
  var count_1: U64 = 0
  var counter: USize = 0
  let expect: U64
  let at_least_once: Bool
  let test_upper_bound: U64 = I64.max_value().u64()

  new create(expected: U64, at_least_once_mode: Bool = false) =>
    expect = expected
    at_least_once = at_least_once_mode

  fun ref apply(values: Array[U64] val, ts: String) ? =>
    """
    Test size, no-nonlead-zeroes, parity, and sequentiality.
    """
    counter = counter + 1

    let val_string: String val = recover
      var s: Array[U8] iso = recover Array[U8] end
      s.>append("[")
       .>append(",".join(values.values()))
       .>append("]")
      String.from_array(consume s)
    end

    Fact(test_size(values), "Size test failed at " + ts + " on " + val_string
      + " after " + counter.string() + " values")?

    Fact(test_no_nonlead_zeroes(values), "No non-leading zeroes test failed at "
      + ts + " on " + val_string + " after " + counter.string() + " values")?

    Fact(test_parity(values), "Parity test failed at " + ts + " on "
      + val_string + " after " + counter.string() + " values")?

    Fact(test_testable_range(values), "Testable range test failed at " + ts +
      " on " + val_string + " after " + counter.string() + " values")?

    let cat = get_category(values)?

    Fact(test_increments(values), "Increments test failed at " + ts +
      " on " + val_string + " after " + counter.string() + " values")?

    Fact(test_sequentiality(values, cat), "Sequentiality test failed at " +
      ts + ". Expected " + (if cat then ring_0 else ring_1 end).string(
        where fill = "0")? + " but got " + val_string + " after " +
      counter.string() + " values")?

  fun finalize() ? =>
    """
    Test expected_max and expected_difference.
    """
    Fact(test_expected_max(), "Expected max test failed with final windows " +
      ring_0.string()? + " and " + ring_1.string()? + " and expected value " +
      expect.string() + " after " + counter.string() + " values")?
    Fact(test_expected_difference(), "Expected difference test failed with " +
      "final windows " +ring_0.string()? + " and " + ring_1.string()? +
      " and expected value " + expect.string() + " after " + counter.string()
      + " values")?

  fun test_expected_max(): Bool =>
    """
    Return true if the maximum value from both categories is the expected
    value given by `--expected`
    """
    try
      let r0 = ring_0(0)?
      let r1 = ring_1(0)?
      if r0 > r1 then
        if r0 != expect then
          return false
        end
      else
        if r1 != expect then
          return false
        end
      end
    else
      return false
    end
    true

  fun test_expected_difference(): Bool =>
    """
    Return true if the difference between the maximum value from both categories
    is exactly 1 greater than the maximum in the other category.
    """
    try
      let r0 = ring_0(0)?
      let r1 = ring_1(0)?
      if r0 > r1 then
        if r1 != (expect - 1) then
          return false
        end
      else
        if r0 != (expect - 1) then
          return false
        end
      end
    else
      return false
    end
    true

  fun test_size(values: Array[U64] val): Bool =>
    """
    Test that the values array is exactly 4 in size.
    """
    if values.size() == 4 then
      true
    else
      false
    end

  fun test_no_nonlead_zeroes(values: Array[U64] val): Bool =>
    """
    Test that there are no non-leading zeros in the array.
    """
    var out = false
    for v in values.values() do
      if v != 0 then
        out = true
      elseif out and (v == 0) then
        return false
      end
    end
    out

  fun test_parity(values: Array[U64] val): Bool =>
    """
    Test that all values in the array are either even or odd, ignoring leading
    zeroes.
    Requires size test.
    """
  try
    for x in Range[USize](0,3) do
      if values(x)? != 0 then
        if (values(x)? % 2) != (values(x + 1)? % 2) then
          return false
        end
      end
    end
  else
    return false
  end
  true

  fun test_increments(values: Array[U64] val): Bool =>
  """
  Test that values are incrementing correctly, except for leading zeroes.
  """
    // diff may be 0, 1, or 2, and only 2 after 1 or 2
    try
      var previous: U64 = values(0)?
      for pos in Range[USize](1,4) do
        let cur = values(pos)?
        let diff = cur - previous
        if (diff == 0) or (diff == 1) then
          if previous != 0 then
            return false
          else
            previous = cur
          end
        elseif diff != 2 then
          return false
        else
          previous = cur
        end
      end
    else
      return false
    end
    true

  fun test_testable_range(values: Array[U64] val): Bool =>
    """
    Return true if the maximum value in the sequence is in the testable range.
    """
    try
      if (values(0)? >= 0) and (values(3)? <= test_upper_bound) then
        return true
      end
    end
    false

  fun ref test_sequentiality(values: Array[U64] val, cat: Bool): Bool =>
    """
    Returns true if the new values follow sequentially from the previously
    seen window in the relevant category.
    e.g. if the values are [2,4,6,8], we expect the previous sequence to be
    [0,2,4,6].
    If at_least_once is true, going back is allowed, so long as the new message
    is still internally sequential.
    """
    // increment the correct ring and counter
    let r = if cat then // mod2=0
      count_0 = count_0 + 1
      ring_0.push(count_0 * 2)
      ring_0
    else // mod2=1
      count_1 = count_1 + 1
      ring_1.push((count_1 * 2) - 1)
      ring_1
    end

    try
      if at_least_once then
        let last = values(3)?
        if last < r(0)? then
          let ilast = last.i64()
          for i in Range[I64](ilast - 6, ilast + 2, 2) do
            let i':U64 = if i < 0 then 0 else i.u64() end
            r.push(i')
          end
          if cat then
            count_0 = last/2
          else
            count_1 = (last/2) + 1
          end
        end
      end
    else
      return false
    end

    for x in Range[USize](0,4) do
      try
        if values(x)? != r(3 - x)? then
          return false
        end
      else
        return false
      end
    end
    true

  fun get_category(ar: Array[U64] val): Bool ? =>
    """
    Returns true if even, false if odd.
    Requires parity, size, and no-nonleading zeroes tests.
    """
    if (ar(3)? % 2) == 0 then
      true
    else
      false
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
