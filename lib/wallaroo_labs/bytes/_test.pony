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
use "promises"

actor Main is TestList
  new create(env: Env) => PonyTest(env, this)

  new make() => None

  fun tag tests(test: PonyTest) =>
    test(_TestBytes)
    test(_TestLengthEncode)

class iso _TestBytes is UnitTest
  fun name(): String => "bytes/_TestBytes"

  fun apply(h: TestHelper) ? =>
    let n1: U16 = 43156
    let n1_enc: Array[U8] val = Bytes.from_u16(n1)
    let n1_dec: U16 =
      Bytes.to_u16(n1_enc(0)?, n1_enc(1)?)
    h.assert_eq[U16](n1_dec, n1)

    let n2: U32 = 2843253
    let n2_enc: Array[U8] val = Bytes.from_u32(n2)
    let n2_dec: U32 =
      Bytes.to_u32(n2_enc(0)?, n2_enc(1)?, n2_enc(2)?, n2_enc(3)?)
    h.assert_eq[U32](n2_dec, n2)

    let n3: U64 = 238412413
    let n3_enc: Array[U8] val = Bytes.from_u64(n3)
    let n3_dec: U64 = Bytes.to_u64(n3_enc(0)?, n3_enc(1)?, n3_enc(2)?, n3_enc(3)?,
      n3_enc(4)?, n3_enc(5)?, n3_enc(6)?, n3_enc(7)?)
    h.assert_eq[U64](n3_dec, n3)

    true


class iso _TestLengthEncode is UnitTest
  fun name(): String => "bytes/_TestLengthEncode"

  fun apply(h: TestHelper) ? =>
    let s0: String = ""
    let s1: String = "a"
    let s3: String = "aaa"

    let s0_enc: Array[ByteSeq] val = Bytes.length_encode(s0)
    let s1_enc: Array[ByteSeq] val = Bytes.length_encode(s1)
    let s3_enc: Array[ByteSeq] val = Bytes.length_encode(s3)

    // Check outer size
    h.assert_eq[USize](0, s0_enc.size())
    h.assert_eq[USize](1, s1_enc.size())
    h.assert_eq[USize](1, s3_enc.size())

    // Check contents
    h.assert_eq[U8](0, s1_enc(0)?(0)?)
    h.assert_eq[U8](0, s1_enc(0)?(1)?)
    h.assert_eq[U8](0, s1_enc(0)?(2)?)
    h.assert_eq[U8](1, s1_enc(0)?(3)?)
    h.assert_eq[U8]('a', s1_enc(0)?(4)?)

    h.assert_eq[U8](3, s3_enc(0)?(3)?)
    h.assert_eq[U8]('a', s3_enc(0)?(4)?)
    h.assert_eq[U8]('a', s3_enc(0)?(5)?)
    h.assert_eq[U8]('a', s3_enc(0)?(6)?)
    true
