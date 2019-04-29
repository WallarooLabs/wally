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
use "../building_blocks"
use "wallaroo_labs/bytes"

actor Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)

  new make() => None

  fun tag tests(test: PonyTest) =>
    test(_TestMessageEncoder)
    test(_TestWindowDecoder)
    test(_TestPartitionedU64FramedHandler)

class iso _TestMessageEncoder is UnitTest
  fun name(): String => "window_codecs/MessageEncoder"

  fun apply(h: TestHelper) ? =>
    let w = Window(WindowSize())
    let k = "key"
    w.push(1)
    w.push(2)
    w.push(3)
    w.push(4)
    let msg = Message(k, w.clone())
    let byteseqs = MessageEncoder(msg)
    let encoded = match byteseqs(1)?
    | let m: String val => m
    | let m: Array[U8] val => String.from_array(m)
    end
    h.assert_eq[String]("(key,[1,2,3,4])", encoded)

class iso _TestWindowDecoder is UnitTest
  fun name(): String => "window_codecs/WindowDecoder"

  fun apply(h: TestHelper) ? =>
    let a: Array[U64] val = [11;2;3;4]
    let s1 = "[11,2,3,4]"
    let s2 = "11,2,3,4"

    let w1 = WindowDecoder(s1)?
    let w2 = WindowDecoder(s2)?
    for win in [w1;w2].values() do
      for (i,v) in a.pairs() do
        h.assert_eq[Value](v, win((win.size()-1)-i)?)
      end
    end

class iso _TestPartitionedU64FramedHandler is UnitTest
  fun name(): String => "window_codecs/PartitionedU64FramedHandler"

  fun apply(h: TestHelper) ? =>
    let key: Key = "key"
    let value: Value = 10
    let binary = Bytes.from_u64(value, Bytes.from_u32(11))
    binary.append(key)
    let data: Array[U8] val = consume binary
    let pl = PartitionedU64FramedHandler.payload_length(recover
      data.slice(0,4) end)?
    h.assert_eq[USize](11, pl)
    let m = PartitionedU64FramedHandler.decode(recover data.slice(4) end)?
    h.assert_eq[Key](key, m.key())
    h.assert_eq[Value](value, m.value())

