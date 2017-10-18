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

actor Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)

  new make() => None

  fun tag tests(test: PonyTest) =>
    test(_TestFallorMsgEncoder)
    test(_TestFallorTimestampRaw)

class iso _TestFallorMsgEncoder is UnitTest
  fun name(): String => "messages/_TestFallorMsgEncoder"

  fun apply(h: TestHelper) ? =>
    let test: Array[String] val = recover val ["hi"; "there"; "pal"; "!"] end

    let byteseqs = FallorMsgEncoder(test)
    let bytes: Array[U8] iso = recover Array[U8] end
    var header_count: USize = 4
    for bs in byteseqs.values() do
      match bs
      | let str: String =>
        bytes.append(str.array())
      | let arr_b: Array[U8] val =>
        for b in arr_b.values() do
          if header_count > 0 then
            header_count = header_count - 1
          else
            bytes.push(b)
          end
        end
      end
    end
    let msgs = FallorMsgDecoder(consume bytes)?

    h.assert_eq[USize](msgs.size(), 4)
    h.assert_eq[String](msgs(0)?, "hi")
    h.assert_eq[String](msgs(1)?, "there")
    h.assert_eq[String](msgs(2)?, "pal")
    h.assert_eq[String](msgs(3)?, "!")

class iso _TestFallorTimestampRaw is UnitTest
  fun name(): String => "messages/_TestFallorTimestampRaw"

  fun apply(h: TestHelper) ? =>
    let text: String val = "Hello world"
    let at: U64 = 1234567890
    let msg: Array[U8] val = recover val
      let a': Array[U8] = Array[U8]
      a'.append(text)
      a'
    end
    let byteseqs = FallorMsgEncoder.timestamp_raw(at, consume msg)
    // Decoder expects a single stream of bytes, so we need to join
    // the byteseqs into a single Array[U8]
    let encoded: Array[U8] iso = recover Array[U8] end
    for seq in byteseqs.values() do
      encoded.append(seq)
    end
    let tup = FallorMsgDecoder.with_timestamp(consume encoded)?
    h.assert_eq[USize](tup.size(), 2)
    h.assert_eq[String](tup(0)?, at.string())
    h.assert_eq[String](tup(1)?, text)
