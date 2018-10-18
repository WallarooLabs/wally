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

use "buffered"
use "collections"
use "ponytest"

actor Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)

  new make() => None

  fun tag tests(test: PonyTest) =>
    test(_TestWindowEncoder)
    test(_TestWindowDecoder)
    test(_TestWindowState)

class iso _TestWindowEncoder is UnitTest
  fun name(): String => "window_codecs/WindowEncoder"

  fun apply(h: TestHelper) =>
    let s = "[1,2,3,4]"
    let byteseqs = WindowEncoder(s)

    let payload = recover val
      let flat : Array[U8] trn = recover trn Array[U8] end
      for subarray in byteseqs.values() do flat.append(subarray) end
      flat.slice(where from = 4)
    end

    h.assert_eq[String]("[1,2,3,4]", String.from_array(payload))

class iso _TestWindowDecoder is UnitTest
  fun name(): String => "window_codecs/WindowDecoder"

  fun apply(h: TestHelper) ? =>
    let s: String val = "[1,2,3,4]"
    let decoded: Array[U64] val = WindowU64Decoder(s)?
    h.assert_eq[U64](1, decoded(0)?)
    h.assert_eq[U64](2, decoded(1)?)
    h.assert_eq[U64](3, decoded(2)?)
    h.assert_eq[U64](4, decoded(3)?)

class iso _TestWindowState is UnitTest
  fun name(): String => "window_codecs/WindowState"

  fun apply(h: TestHelper) ? =>
    // Encode
    let out_writer: Writer = Writer
    let index: USize = 15
    let buf: Array[U64] iso = recover [12; 13; 14; 11] end
    let size: USize = 4
    let count: USize = 15

    WindowStateEncoder(index, consume buf, size, count, out_writer)
    let byteseqs: Array[ByteSeq] val = out_writer.done()
    let s = recover Array[U8] end
    for bs in byteseqs.values() do
      s.append(bs)
    end
    // Expecting: 4xU64 + 3xUSize = (4*8 bytes) + (3*8 bytes) = 56 bytes
    h.assert_eq[USize](56, s.size())

    // Decode
    let in_reader: Reader = Reader
    in_reader.append(consume s)
    (let index', let buf', let size', let count') =
      WindowStateDecoder(in_reader)?
    h.assert_eq[USize](index, index')
    h.assert_eq[USize](size, size')
    h.assert_eq[USize](count, count')
    // we have to make another copy of the original buffer since we used it up
    let buf'': Array[U64] val = consume buf'
    let buf_clone: Array[U64] val = recover [12; 13; 14; 11] end
    for (i, v) in buf_clone.pairs() do
      h.assert_eq[U64](v, buf''(i)?)
    end




