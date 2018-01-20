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
use "wallaroo/core/source"
use "wallaroo/core/source/kafka_source"
use "wallaroo/core/topology"

actor Main
  new create(env: Env) =>
    let ksource_clip = KafkaSourceConfigCLIParser(env.out)

    try
      if (env.args(1)? == "--help") or (env.args(1)? == "-h") then
        ksource_clip.print_usage()
        return
      end
    else
      ksource_clip.print_usage()
      return
    end

    try
      let application = recover val
        Application("KafkaSource to Sinkhole App")
          .new_pipeline[Array[U8] val, Array[U8] val]("KafkaSource to Sinkhole",
            KafkaSourceConfig[Array[U8] val](ksource_clip.parse_options(env.args)?,
            env.root as AmbientAuth, NoOpDecoder))
            .to_sink(SinkholeSinkConfig[Array[U8] val])
      end
      Startup(env, application, "kafkasource-sinkhole")
    else
      @printf[I32]("Couldn't build topology\n".cstring())
    end

primitive NoOpDecoder is SourceHandler[Array[U8] val]
  fun decode(a: Array[U8] val): Array[U8] val => a
