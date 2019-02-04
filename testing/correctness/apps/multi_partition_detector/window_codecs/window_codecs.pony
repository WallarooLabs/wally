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

"""
Functionality that has to do with encoding and decoding anything goes in here
so that it may be unit tested separately from the main application.
"""


use "time"
use "buffered"
use "collections"
use "../building_blocks"
use "wallaroo_labs/bytes"
use "wallaroo_labs/time"
use "wallaroo/core/source"
use "wallaroo/core/source/tcp_source"

primitive WindowPartitionFunction
  fun apply(m: Message): String =>
    try
      m.key().split(".", 2)(0)?
    else
      m.key()
    end

primitive MessageEncoder
  fun apply(m: Message, wb: Writer = Writer): Array[ByteSeq] val =>
    ifdef debug then
      @printf[I32]("output: %s\n".cstring(), m.string().cstring())
    end
    wb.writev(Bytes.length_encode(m.string()))
    wb.done()

primitive WindowDecoder
  fun apply(s: String val): Window val ? =>
    // check for brackets
    let left_bracket = ("[".array())(0)?
    let right_bracket = ("]".array())(0)?
    var a = s.array()
    if a(0)? == left_bracket then
      a = recover a.slice(1) end
    end
    if a(a.size()-1)? == right_bracket then
      a = recover a.slice(0,a.size()-1) end
    end
    // parse U64s
    let out = recover iso Window(WindowSize()) end
    let parts:Array[String] val = recover String.from_array(a).split(",") end
    for p in parts.values() do
      out.push(p.u64()?)
    end
    consume out

primitive PartitionedU64FramedHandler is FramedSourceHandler[Message]
  fun header_length(): USize => 4

  fun payload_length(data: Array[U8] iso): USize ? =>
    Bytes.to_u32(data(0)?, data(1)?, data(2)?, data(3)?).usize()

  fun decode(data: Array[U8] val): Message ? =>
    let u: Value = Bytes.to_u64(data(0)?, data(1)?, data(2)?, data(3)?,
      data(4)?, data(5)?, data(6)?, data(7)?)
    let k: Key = String.from_array(recover data.slice(8) end)
    let m = Message(k, u)
    ifdef debug then
        (let sec', let ns') = Time.now()
        let us' = ns' / 1000
        let ts' = PosixDate(sec', ns').format("%Y-%m-%d %H:%M:%S." + us'.string())
      @printf[I32]("%s Source decoded: %s\n".cstring(), ts'.cstring(),
        m.string().cstring())
    end
    consume m
