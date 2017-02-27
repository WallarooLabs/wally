"""
Validator validates the received.txt file from a sequence-window run, as saved
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
use "buffered"
use "collections"
use "files"
use "options"
use "sendence/messages"
use "ring"
use "window_codecs"

actor Main
  new create(env: Env) =>
    let options = Options(env.args)
    var input_file_path = "received.txt"
    var expected: U64 = 1000

    options
      .add("input", "i", StringArgument)
      .add("expected", "e", I64Argument)
      .add("help", "h", None)

      for option in options do
        match option
        | ("input", let arg: String) => input_file_path = arg
        | ("expected", let arg: I64) => expected = arg.u64()
        | ("help", None) =>
          env.out.print(
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
      let fp = FilePath(auth, input_file_path)
      Fact(fp.exists(), "Input file '" + fp.path + "' does not exist.")
      let input_file = File(fp)
      // TODO: Don't read entire file into memory at once
      let input: Array[U8] val = input_file.read(input_file.size())


      let rb = Reader
      rb.append(input)

      let validator = WindowValidator(expected)
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
        bytes_left = bytes_left - next_payload_size.usize()
        let v = WindowU64Decoder(fields(1))
        validator(consume v)
      end
      validator.finalize()
      env.out.print("Validation successful!")
      input_file.dispose()
    else
      env.err.print("Error validating file.")
    end

class WindowValidator
  """
  To test the output of Sequence-Window, we need to validate that the correct
  sequence of windows follows throughout.

  1. For each observed window, test:
  1.1. size == 4
  1.2. no non-leading zeroes are present (and at least one value is non-zero)
  1.3. all non-zero values have the same parity
  1.4. sequentiality: the current window follows from the previous window
    (e.g. [4,6,8,10] follows [2,4,6,8])

  2. For the two final windows, test:
  2.1. the highest value matches the `--expected/-e` value
  2.2. the highet value in the non-highest-value window is exactly 1 less than
    the `--expected/-e` value.
  """

  var ring_0: Ring[U64] = Ring[U64].from_array(recover [0,0,0,0] end, 4, 0)
  var ring_1: Ring[U64] = Ring[U64].from_array(recover [0,0,0,0] end, 4 ,0)
  var count_0: U64 = 0
  var count_1: U64 = 0
  var counter: USize = 0
  let expect: U64

  new create(expected: U64) =>
    expect = expected

  fun ref apply(values: Array[U64] val) ? =>
    """
    Test size, no-nonlead-zeroes, parity, and sequentiality.
    """
    counter = counter + 1

    let val_string: String val = recover
      var s: Array[U8] iso = recover Array[U8] end
      s.append("[")
      s.append(",".join(values))
      s.append("]")
      String.from_array(consume s)
    end


    Fact(test_size(values), "Size test failed on " + val_string + " after " +
      counter.string() + " values")

    Fact(test_no_nonlead_zeroes(values), "No non-leading zeroes test failed on "
      + val_string + " after " + counter.string() + " values")

    Fact(test_parity(values), "Parity test failed on " + val_string + " after "
      + counter.string() + " values")

    let cat = get_category(values)

    Fact(test_sequentiality(values, cat), "Sequentiality test failed. Expected "
      + ring_0.string(where fill = "0") + " but got " + val_string + " after " +
      counter.string() + " values")

  fun finalize() ? =>
    """
    Test expected_max and expected_difference.
    """
    Fact(test_expected_max(), "Expected max test failed with final windows " +
      ring_0.string() + " and " + ring_1.string() + " and expected value " +
      expect.string() + " after " + counter.string() + " values")
    Fact(test_expected_difference(), "Expected difference test failed with " +
      "final windows " +ring_0.string() + " and " + ring_1.string() +
      " and expected value " + expect.string() + " after " + counter.string()
      + " values")

  fun test_expected_max(): Bool =>
    """
    Return true if the maximum value from both categories is the expected
    value given by `--expected`
    """
    try
      let r0 = ring_0(0)
      let r1 = ring_1(0)
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
      let r0 = ring_0(0)
      let r1 = ring_1(0)
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
      if values(x) != 0 then
        if (values(x) % 2) != (values(x+1) % 2) then
          return false
        end
      end
    end
  else
    return false
  end
  true

  fun ref test_sequentiality(values: Array[U64] val, cat: Bool): Bool =>
    """
    Returns true if the new values follow sequentially from the previously
    seen window in the relevant category.
    e.g. if the values are [2,4,6,8], we expect the previous sequence to be
    [0,2,4,6].
    """
    var out: Bool = true
    if cat then // mod2=0
      count_0 = count_0 + 1
      ring_0.push(count_0*2)
      for x in Range[USize](0,4) do
        try
          if values(x) != ring_0(3-x) then
            out = false
          end
        else
          out = false
        end
      end
    else
      count_1 = count_1 + 1
      ring_1.push((count_1*2)-1)
      for x in Range[USize](0,4) do
        try
          if values(x) != ring_1(3-x) then
            out = false
          end
        else
          out = false
        end
      end
    end
    out

  fun get_category(ar: Array[U64] val): Bool ? =>
    """
    Returns true if even, false if odd.
    Requires parity, size, and no-nonleading zeroes tests.
    """
    if (ar(3) % 2) == 0 then
      true
    else
      false
    end
