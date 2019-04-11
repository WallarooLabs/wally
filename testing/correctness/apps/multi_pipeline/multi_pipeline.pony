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
use "serialise"
use "wallaroo_labs/bytes"
use "wallaroo"
use "wallaroo_labs/mort"
use "wallaroo_labs/time"
use "wallaroo/core/sink/tcp_sink"
use "wallaroo/core/source"
use "wallaroo/core/source/tcp_source"
use "wallaroo/core/topology"

actor Main
  new create(env: Env) =>
    try
      let pipeline = recover val
        let inputs1 = Wallaroo.source[(U32, U32)]("Pipeline1",
            TCPSourceConfig[(U32, U32)].from_options(Decoder,
              TCPSourceConfigCLIParser("Pipeline1", env.args)?))
            .to[(U32, U32)](Comp1("inputs1"))
            .to[(U32, U32)](Comp2("inputs1"))

        let inputs2 = Wallaroo.source[(U32, U32)]("Pipeline2",
            TCPSourceConfig[(U32, U32)].from_options(Decoder,
              TCPSourceConfigCLIParser("Pipeline2", env.args)?))
            .to[(U32, U32)](Comp1("inputs2"))
            .to[(U32, U32)](Comp2("inputs2"))

        inputs1.merge[(U32, U32)](inputs2)
          .to_sink(TCPSinkConfig[(U32, U32)].from_options(Encoder,
            TCPSinkConfigCLIParser(env.args)?(0)?))
      end
      Wallaroo.build_application(env, "multi-pipeline", pipeline)
    else
      @printf[I32]("Couldn't build topology\n".cstring())
    end

class val Comp1 is StatelessComputation[(U32, U32), (U32, U32)]
  let _pipeline: String
  new val create(p: String) => _pipeline = p

  fun apply(input: (U32, U32)): (U32, U32) =>
    @printf[I32]("Comp1 (%s): (%s, %s)\n".cstring(), _pipeline.cstring(),
      input._1.string().cstring(), input._2.string().cstring())
    (input._1, input._2)

  fun name(): String => "Computation 1"

class val Comp2 is StatelessComputation[(U32, U32), (U32, U32)]
  let _pipeline: String
  new val create(p: String) => _pipeline = p

  fun apply(input: (U32, U32)): (U32, U32) =>
    @printf[I32]("-- Comp2 (%s): (%s, %s)\n".cstring(), _pipeline.cstring(),
      input._1.string().cstring(), input._2.string().cstring())
    (input._1, input._2)

  fun name(): String => "Computation 2"

primitive Decoder is FramedSourceHandler[(U32, U32)]
  fun header_length(): USize =>
    4

  fun payload_length(data: Array[U8] iso): USize =>
    8

  fun decode(data: Array[U8] val): (U32, U32) ? =>
    let input = (Bytes.to_u32(data(0)?, data(1)?, data(2)?, data(3)?),
      Bytes.to_u32(data(4)?, data(5)?, data(6)?, data(7)?))
    @printf[I32]("Decoder: (%s, %s)\n".cstring(),
      input._1.string().cstring(), input._2.string().cstring())
    input

primitive Encoder
  fun apply(v: (U32, U32), wb: Writer): Array[ByteSeq] val =>
    @printf[I32]("Encoder: (%s, %s)\n".cstring(),
      v._1.string().cstring(), v._2.string().cstring())
    wb.u32_be(8)
    wb.u32_be(v._1)
    wb.u32_be(v._2)
    wb.done()
