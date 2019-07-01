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
use "wallaroo"
use "wallaroo/core/common"
use "wallaroo_labs/logging"
use "wallaroo_labs/mort"
use "wallaroo_labs/time"
use "wallaroo/core/sink/tcp_sink"
use "wallaroo/core/source"
use "wallaroo/core/source/tcp_source"
use "wallaroo/core/state"
use "wallaroo/core/topology"

actor Main
  new create(env: Env) =>
    Log.set_defaults()
    try
      let pipeline = recover val
        Wallaroo.source[U64]("Filter Test",
            TCPSourceConfig[(U64 | None)].from_options(OddFilterDecoder,
              TCPSourceConfigCLIParser("Filter Test", env.args)?))
          // .to(PassThrough)
          .to_sink(TCPSinkConfig[U64].from_options(FramedU64Encoder,
            TCPSinkConfigCLIParser(env.args)?(0)?))
      end
      Wallaroo.build_application(env, "Decoder Filter Test App", pipeline)
    else
      @printf[I32]("Couldn't build topology\n".cstring())
    end

primitive OddFilterDecoder is FramedSourceHandler[(U64 | None)]
    fun header_length(): USize =>
    4

  fun payload_length(data: Array[U8] iso): USize ? =>
    Bytes.to_u32(data(0)?, data(1)?, data(2)?, data(3)?).usize()

  fun decode(data: Array[U8] val): (U64 | None) ? =>
    let num = Bytes.to_u64(data(0)?, data(1)?, data(2)?, data(3)?, data(4)?,
      data(5)?, data(6)?, data(7)?)
    if ((num % 2) == 0) then num else None end

// primitive PassThrough is StatelessComputation[U64, U64]
//   fun apply(input: U64): U64 =>
//     @printf[I32](("Received: " + input.string() + "\n").cstring())
//     input

//   fun name(): String => "Pass Through"


primitive FramedU64Encoder
  fun apply(u: U64, wb: Writer = Writer): Array[ByteSeq] val =>
    // @printf[I32](("Encoding: " + u.string() + "\n").cstring())
    wb.u32_be(8)
    wb.u64_be(u)
    wb.done()
