/*

Copyright (C) 2016-2017, Wallaroo Labs
Copyright (C) 2016-2017, The Pony Developers
Copyright (c) 2014-2015, Causality Ltd.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/

use "ponytest"

actor Main is TestList
  new create(env: Env) => PonyTest(env, this)
  new make() => None

  fun tag tests(test: PonyTest) =>
    test(_TestLongOptions)
    test(_TestShortOptions)
    test(_TestCombineShortOptions)
    test(_TestCombineShortArg)
    test(_TestArgLeadingDash)

class iso _TestLongOptions is UnitTest
  """
  Long options start with two leading dashes, and can be lone, have a following
  arg, or combined arg with =.
  """
  fun name(): String => "options/Options.longOptions"

  fun apply(h: TestHelper) =>
    let options = Options(["--none", "--i64", "12345", "--f64=67.890"])
    var none: Bool = false
    var i64: I64 = -1
    var f64: F64 = -1
    options
      .add("none", "n", None, Optional)
      .add("i64", "i", I64Argument, Optional)
      .add("f64", "f", F64Argument, Optional)
    for option in options do
      match option
      | ("none", let arg: None) => none = true
      | ("i64", let arg: I64) => i64 = arg
      | ("f64", let arg: F64) => f64 = arg
      end
    end

    h.assert_eq[Bool](true, none)
    h.assert_eq[I64](12345, i64)
    h.assert_eq[F64](67.890, f64)

class iso _TestShortOptions is UnitTest
  """
  Short options start with a single leading dash, and can be lone, have a
  following arg, or combined arg with =.
  """
  fun name(): String => "options/Options.shortOptions"

  fun apply(h: TestHelper) =>
    let options = Options(["-n", "-i", "12345", "-f67.890"])
    var none: Bool = false
    var i64: I64 = -1
    var f64: F64 = -1
    options
      .add("none", "n", None, Optional)
      .add("i64", "i", I64Argument, Optional)
      .add("f64", "f", F64Argument, Optional)
    for option in options do
      match option
      | ("none", let arg: None) => none = true
      | ("i64", let arg: I64) => i64 = arg
      | ("f64", let arg: F64) => f64 = arg
      else
        h.fail("Invalid option reported")
      end
    end

    h.assert_eq[Bool](true, none)
    h.assert_eq[I64](12345, i64)
    h.assert_eq[F64](67.890, f64)

class iso _TestCombineShortOptions is UnitTest
  """
  Short options can be combined into one string with a single leading dash.
  """
  fun name(): String => "options/Options.combineShort"

  fun apply(h: TestHelper) =>
    let options = Options(["-ab"])
    var aaa: Bool = false
    var bbb: Bool = false
    options
      .add("aaa", "a", None, Optional)
      .add("bbb", "b", None, Optional)
    for option in options do
      match option
      | ("aaa", _) => aaa = true
      | ("bbb", _) => bbb = true
      end
    end

    h.assert_eq[Bool](true, aaa)
    h.assert_eq[Bool](true, bbb)

class iso _TestCombineShortArg is UnitTest
  """
  Short options can be combined up to the first option that takes an argument.
  """
  fun name(): String => "options/Options.combineShortArg"

  fun apply(h: TestHelper) =>
    let options = Options(["-ab99", "-ac", "99"])
    var aaa: Bool = false
    var bbb: I64 = -1
    var ccc: I64 = -1
    options
      .add("aaa", "a", None, Optional)
      .add("bbb", "b", I64Argument, Optional)
      .add("ccc", "c", I64Argument, Optional)
    for option in options do
      match option
      | ("aaa", _) => aaa = true
      | ("bbb", let arg: I64) => bbb = arg
      | ("ccc", let arg: I64) => ccc = arg
      end
    end

    h.assert_eq[Bool](true, aaa)
    h.assert_eq[I64](99, bbb)
    h.assert_eq[I64](99, ccc)

class iso _TestArgLeadingDash is UnitTest
  """
  Arguments can only start with a leading dash if they are separated from
  the option using '=', otherwise they will be interpreted as named options.
  """
  fun name(): String => "options/Options.testArgLeadingDash"

  fun apply(h: TestHelper) =>
    let options = Options(["--aaa", "-2", "--bbb=-2"])
    var aaa: I64 = -1
    var bbb: I64 = -1
    options
      .add("aaa", "c", I64Argument, Optional)
      .add("bbb", "b", I64Argument, Optional)
      .add("ttt", "2", None, Optional)  // to ignore the -2
    for option in options do
      match option
      | ("aaa", let arg: I64) => aaa = arg
      | ("bbb", let arg: I64) => bbb = arg
      end
    end

    h.assert_eq[I64](-1, aaa)
    h.assert_eq[I64](-2, bbb)
