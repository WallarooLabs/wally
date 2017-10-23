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
use "wallaroo_labs/bytes"

actor Main is TestList
  new create(env: Env) => PonyTest(env, this)

  new make() => None

  fun tag tests(test: PonyTest) =>
    test(_TestU64Sum)
    test(_TestFramedU64Encoder)
    test(_TestCountAndMax)
    test(_TestFramedCountMaxEncoder)
    test(_TestDivideCountMax)
    test(_TestDoubleCountMax)

class iso _TestU64Sum is UnitTest
  fun name(): String => "generic_app_components/U64Sum"

  fun apply(h: TestHelper) =>
    let u64sum = U64Sum

    h.assert_eq[USize](u64sum.count, 0)
    h.assert_eq[U64](u64sum.sum, 0)

    u64sum.update(10)
    h.assert_eq[USize](u64sum.count, 1)
    h.assert_eq[U64](u64sum.sum, 10)

    u64sum.update(100)
    h.assert_eq[USize](u64sum.count, 2)
    h.assert_eq[U64](u64sum.sum, 110)

class iso _TestFramedU64Encoder is UnitTest
  fun name(): String => "generic_app_components/FramedU64Encoder"

  fun apply(h: TestHelper) ? =>
    let u64sum = U64Sum
    u64sum.update(10)
    u64sum.update(100)
    let byteseqs = FramedU64Encoder(u64sum.sum)
    let u = byteseqs(0)?
    let header: U32 = Bytes.to_u32(u(0)?, u(1)?, u(2)?, u(3)?)
    h.assert_eq[U32](header, 8)
    let sum: U64 = Bytes.to_u64(u(4)?, u(5)?, u(6)?, u(7)?, u(8)?, u(9)?,
      u(10)?, u(11)?)
    h.assert_eq[U64](sum, 110)

class iso _TestCountAndMax is UnitTest
  fun name(): String => "generic_app_components/CountAndMax"

  fun apply(h: TestHelper) =>
    var cam = CountAndMax
    cam(5)
    cam(10)
    cam(5)
    h.assert_eq[USize](cam.count, 3)
    h.assert_eq[U64](cam.max, 10)

class iso _TestFramedCountMaxEncoder is UnitTest
  fun name(): String => "generic_app_components/FramedCountMaxEncoder"

  fun apply(h: TestHelper) ? =>
    let cm = CountMax(10,10)
    let byteseqs = FramedCountMaxEncoder(cm)
    let u = byteseqs(0)?
    let header = Bytes.to_u32(u(0)?, u(1)?, u(2)?, u(3)?)
    h.assert_eq[U32](header, 16)
    let count = Bytes.to_u64(u(4)?, u(5)?, u(6)?, u(7)?,
      u(8)?, u(9)?, u(10)?, u(11)?).usize()
    h.assert_eq[USize](count, cm.count)
    let max = Bytes.to_u64(u(12)?, u(13)?, u(14)?, u(15)?,
      u(16)?, u(17)?, u(18)?, u(19)?)
    h.assert_eq[U64](max, cm.max)

class iso _TestDivideCountMax is UnitTest
  fun name(): String => "generic_app_components/DivideCountMax"

  fun apply(h: TestHelper) =>
    let cm = CountMax(10, 100)
    let cm2 = DivideCountMax(cm)
    h.assert_eq[USize](cm.count, cm2.count)
    h.assert_eq[U64](cm.max, (cm2.max * 2))
    h.assert_eq[U64](cm2.max, 50)

class iso _TestDoubleCountMax is UnitTest
  fun name(): String => "generic_app_components/DoubleCountMax"

  fun apply(h: TestHelper) =>
    let cm = CountMax(10, 100)
    let cm2 = DoubleCountMax(cm)
    h.assert_eq[USize](cm.count, cm2.count)
    h.assert_eq[U64]((cm.max * 2), cm2.max)
    h.assert_eq[U64](cm2.max, 200)
