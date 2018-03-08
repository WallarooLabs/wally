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

use "ponytest"

actor Main is TestList
  new create(env: Env) => PonyTest(env, this)

  new make() => None

  fun tag tests(test: PonyTest) =>
    test(_TestGCD)
    test(_TestLCM)

class iso _TestGCD is UnitTest
  fun name(): String =>
    "math/_TestGCD"

  fun apply(h: TestHelper) =>
    h.assert_eq[USize](3, Math.gcd(3,27))
    h.assert_eq[USize](3, Math.gcd(9,24))
    h.assert_eq[USize](2, Math.gcd(14,72))
    h.assert_eq[USize](1, Math.gcd(3,10))
    h.assert_eq[USize](0, Math.gcd(0,10))
    h.assert_eq[USize](0, Math.gcd(10,0))

class iso _TestLCM is UnitTest
  fun name(): String =>
    "math/_TestLCM"

  fun apply(h: TestHelper) =>
    h.assert_eq[USize](27, Math.lcm(3,27))
    h.assert_eq[USize](72, Math.lcm(9,24))
    h.assert_eq[USize](504, Math.lcm(14,72))
    h.assert_eq[USize](30, Math.lcm(3,10))
    h.assert_eq[USize](10, Math.lcm(2,5))
    h.assert_eq[USize](0, Math.lcm(0,10))
    h.assert_eq[USize](0, Math.lcm(10,0))
