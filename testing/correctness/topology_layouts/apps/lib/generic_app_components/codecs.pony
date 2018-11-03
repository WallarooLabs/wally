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
use "wallaroo_labs/bytes"
use "wallaroo/core/source"

primitive U64Decoder is FramedSourceHandler[U64]
  fun apply(data: String val): U64 ? =>
    Bytes.to_u64(data(0)?, data(1)?, data(2)?, data(3)?, data(4)?,
      data(5)?, data(6)?, data(7)?)

  fun header_length(): USize =>
    4

  fun payload_length(data: Array[U8] iso): USize ? =>
    Bytes.to_u32(data(0)?, data(1)?, data(2)?, data(3)?).usize()

  fun decode(data: Array[U8] val): U64 ? =>
    Bytes.to_u64(data(0)?, data(1)?, data(2)?, data(3)?, data(4)?,
      data(5)?, data(6)?, data(7)?)

primitive FramedU64Encoder
  fun apply(u: U64, wb: Writer = Writer): Array[ByteSeq] val =>
    wb.u32_be(8)
    wb.u64_be(u)
    wb.done()

primitive FramedCountMaxEncoder
  fun apply(cm: CountMax val, wb: Writer = Writer): Array[ByteSeq] val =>
    wb.u32_be(16)
    wb.u64_be(cm.count.u64())
    wb.u64_be(cm.max)
    wb.done()
