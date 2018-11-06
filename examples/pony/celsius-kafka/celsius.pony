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
use "wallaroo"
use "wallaroo/core/sink/kafka_sink"
use "wallaroo/core/source"
use "wallaroo/core/source/kafka_source"
use "wallaroo/core/topology"

actor Main
  new create(env: Env) =>
    let ksource_clip = KafkaSourceConfigCLIParser(env.out)
    let ksink_clip = KafkaSinkConfigCLIParser(env.out)

    try
      if (env.args(1)? == "--help") or (env.args(1)? == "-h") then
        ksource_clip.print_usage()
        ksink_clip.print_usage()
        return
      end
    else
      ksource_clip.print_usage()
      ksink_clip.print_usage()
      return
    end

    try
      let pipeline = recover val
        let inputs = Wallaroo.source[F32]("Celsius Conversion",
          KafkaSourceConfig[F32](ksource_clip.parse_options(env.args)?,
          env.root as AmbientAuth, CelsiusKafkaDecoder))

        inputs
          .to[F32](Multiply)
          .to[F32](Add)
          .to_sink(KafkaSinkConfig[F32](FahrenheitEncoder,
            ksink_clip.parse_options(env.args)?,
            env.root as AmbientAuth))
      end
      Wallaroo.build_application(env, "Celsius Conversion", pipeline)
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

primitive FahrenheitEncoder
  fun apply(f: F32, wb: Writer): (Array[ByteSeq] val, None, None) =>
    wb.f32_be(f)
    (wb.done(), None, None)

primitive CelsiusKafkaDecoder is SourceHandler[F32]
  fun decode(a: Array[U8] val): F32 ? =>
    let r = Reader
    r.append(a)
    r.f32_be()?
