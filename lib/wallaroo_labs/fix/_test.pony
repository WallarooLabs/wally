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

use "ponytest"
use "collections"

actor Main is TestList
  new create(env: Env) => PonyTest(env, this)
  new make() => None

  fun tag tests(test: PonyTest) =>
    test(_TestFixTradeParsing)
    test(_TestFixNbboParsing)

class _TestFixTradeParsing is UnitTest
  let input: String =
    "8=FIX.4.2\x019=121\x0135=D\x011=CLIENT35\x0111=s0XCIa\x01"
    + "21=3\x0138=4000\x0140=2\x0144=252.85366153511416\x0154=1\x01"
    + "55=TSLA\x0160=20151204-14:30:00.000\x01107=Tesla Motors\x01"
    + "10=108\x01"

  let expected: FixOrderMessage val =
    FixOrderMessage(
      Buy
      , 35
      , "s0XCIa"
      , "TSLA"
      , 4000.0
      , 252.85366153511416
      , "20151204-14:30:00.000"
      )

  fun name(): String => "fix/FixTradeParsing"

  fun apply(h: TestHelper) =>
    let p = FixParser
    match p(input)
      | let parsed: FixOrderMessage val =>
        h.assert_eq[FixOrderMessage box](expected, parsed)
    else
      h.fail("Incorrect message type")
    end

class _TestFixNbboParsing is UnitTest
  let input: String =
    "8=FIX.4.2\x019=64\x0135=S\x0155=TSLA\x01"
    + "60=20151204-14:30:00.000\x01117=S\x01132=16.40\x01133=16.60"
    + "\x0110=098\x01"

  let expected: FixNbboMessage val =
    FixNbboMessage("TSLA", "20151204-14:30:00.000", 16.40, 16.60)

  fun name(): String => "fix/FixNbboParsing"

  fun apply(h: TestHelper) =>
    let p = FixParser
    match p(input)
      | let parsed: FixNbboMessage val =>
        h.assert_eq[FixNbboMessage box](expected, parsed)
    else
      h.fail("Incorrect message type")
    end
