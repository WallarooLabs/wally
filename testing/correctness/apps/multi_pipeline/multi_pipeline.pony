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
        let inputs1 = Wallaroo.source[F32]("Celsius Conversion0",
            TCPSourceConfig[F32].from_options(CelsiusDecoder,
              TCPSourceConfigCLIParser(env.args)?("Celsius Conversion0")?))
            .collect()
            .to[F32](Multiply)
            .to[F32](Add)

        let inputs2 = Wallaroo.source[F32]("Celsius Conversion1",
            TCPSourceConfig[F32].from_options(CelsiusDecoder,
              TCPSourceConfigCLIParser(env.args)?("Celsius Conversion1")?))
            .collect()
            .to[F32](Multiply)
            .to[F32](Add)

        inputs1.merge[F32](inputs2)
          .to_sink(TCPSinkConfig[F32 val].from_options(FahrenheitEncoder,
            TCPSinkConfigCLIParser(env.args)?(0)?))
      end
      Wallaroo.build_application(env, "celsius-multi-pipeline", pipeline)
    else
      @printf[I32]("Couldn't build topology\n".cstring())
    end

primitive Multiply is StatelessComputation[F32, F32]
  fun apply(input: F32): F32 =>
    input * 1.8

  fun name(): String => "Multiply by 1.8"

primitive Add is StatelessComputation[F32, F32]
  fun apply(input: F32): F32 =>
    input + 32

  fun name(): String => "Add 32"

primitive CelsiusDecoder is FramedSourceHandler[F32]
  fun header_length(): USize =>
    4

  fun payload_length(data: Array[U8] iso): USize =>
    4

  fun decode(data: Array[U8] val): F32 ? =>
    Bytes.to_f32(data(0)?, data(1)?, data(2)?, data(3)?)

primitive FahrenheitEncoder
  fun apply(f: F32, wb: Writer): Array[ByteSeq] val =>
    wb.u32_be(4)
    wb.f32_be(f)
    wb.done()
