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

use "collections"
use "ponytest"

actor Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)

  new make() => None

  fun tag tests(test: PonyTest) =>
    test(_TestIncrementsTest)

class iso _TestIncrementsTest is UnitTest
  fun name(): String => "inline_validation/IncrementsTest"

  fun apply(h: TestHelper) =>
    let valid_cases: Array[Array[U64] val] = [
      [1] // normal first element test
      [1;2;3] // normal sequence
      [0;0;1] // normal with leading zeroes
      [0;1] // normal with leading zeroes, minimal length
      [10;11;12;13]] // normal without leading zeroes

    let invalid_cases: Array[Array[U64] val] = [
      [0] // only leading zeros is same as empty, which isn't testable
      [0;2] // invalid increment with leading zeroes
      [0;0;2] // invalid increment with leading zeroes, longer
      [1;2;3;5] // invalid increment
      [1;3;4;5]] // invalid increment

    for case in valid_cases.values() do
      h.assert_true(IncrementsTest(case))
    end

    for case in invalid_cases.values() do
      h.assert_false(IncrementsTest(case))
    end
