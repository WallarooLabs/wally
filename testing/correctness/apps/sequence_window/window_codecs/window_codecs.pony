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


use "buffered"
use "collections"
use "wallaroo_labs/bytes"
use "wallaroo_labs/time"
use "wallaroo/core/source"
use "wallaroo/core/source/tcp_source"

primitive WindowEncoder
  fun apply(s: String val, wb: Writer = Writer): Array[ByteSeq] val =>
    ifdef debug then
      @printf[I32]("output: %s\n".cstring(), s.cstring())
    end
    wb.writev(Bytes.length_encode(s))
    wb.done()

primitive WindowU64Decoder
  """
  Decode a text array of numbers in the format '[1,2,3]' or '[1, 2, 3]'
  into an Array[U64].
  """
  fun apply(s: String val, delim: String val = "[, ]"): Array[U64] val ? =>
    let a = recover iso Array[U64] end
    let parts:Array[String] val = s.split(delim)
    for p in parts.slice(1,parts.size()-1).values() do
      // skip empty strings
      if p.size() > 0 then
        a.push(p.u64()?)
      end
    end
    consume a

primitive WindowStateEncoder
  fun apply(last_value: U64, out_writer: Writer) =>
    out_writer.u64_be(last_value)

primitive WindowStateDecoder
  fun apply(in_reader: Reader): U64 ? =>
    in_reader.u64_be()?

primitive U64FramedHandler is FramedSourceHandler[U64 val]
  fun header_length(): USize =>
    4

  fun payload_length(data: Array[U8] iso): USize ? =>
    Bytes.to_u32(data(0)?, data(1)?, data(2)?, data(3)?).usize()

  fun decode(data: Array[U8] val): U64 ? =>
    Bytes.to_u64(data(0)?, data(1)?, data(2)?, data(3)?,
      data(4)?, data(5)?, data(6)?, data(7)?)
