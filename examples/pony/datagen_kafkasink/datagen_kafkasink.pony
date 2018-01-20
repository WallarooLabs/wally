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
use "options"
use "wallaroo"
use "wallaroo/core/sink/kafka_sink"
use "wallaroo/core/source"
use "wallaroo/core/topology"


actor Main
  fun tag opts(): Array[(String, (None | String), ArgumentType, (Required |
    Optional), String)]
  =>
    // items in the tuple are: Argument Name, Argument Short Name,
    //   Argument Type, Required or Optional, Help Text
    let opts_array = Array[(String, (None | String), ArgumentType, (Required |
      Optional), String)]

    opts_array.push(("help", "h", None, Optional,
      "print help"))
    opts_array.push(("key_size", None, I64Argument, Required,
      "size of key to generate where 0 means no key (0)"))

    opts_array

  fun print_usage(out: OutStream) =>
    for (long, short, arg_type, arg_req, help) in opts().values() do
      let short_str = match short
             | let s: String => "/-" + s
             else "" end

      let arg_type_str = match arg_type
             | StringArgument => "(String)"
             | I64Argument => "(Integer)"
             | F64Argument => "(Float)"
             else "" end

      out.print("--" + long + short_str + "       " + arg_type_str + "    "
        + help)
    end

  new create(env: Env) =>
    let ksink_clip = KafkaSinkConfigCLIParser(env.out)
    let dgsource_clip = DataGenSourceConfigCLIParser(env.out)

    var key_size: USize = 0
    var message_size: USize = 0

    var help: Bool = false

    let options = Options(env.args, false)

    for (long, short, arg_type, arg_req, _) in opts().values() do
      options.add(long, short, arg_type, arg_req)
    end

    // add message size separately so it's not part of help message
    options.add("message_size", None, I64Argument, Required)

    for option in options do
      match option
      | ("help", let input: None) =>
        help = true
      | ("message_size", let input: I64) =>
        message_size = input.usize()
      | ("key_size", let input: I64) =>
        key_size = input.usize()
      end
    end

    if key_size > message_size then
      env.out.print("Error! key_size (" + key_size.string() + ") cannot be larger than message_size (" + message_size.string() + ")!")
      help = true
    end

    if env.args.size() == 1 then
      help = true
    end

    if help then
      StartupHelp()
      print_usage(env.out)
      ksink_clip.print_usage()
      dgsource_clip.print_usage()
      return
    end

    (let num_msgs, let msg_size) = try
        dgsource_clip.parse_options(env.args)?
      else
        dgsource_clip.print_usage()
        ksink_clip.print_usage()
        return
      end

    try
      let application = recover val
        Application("Datagen to KafkaSink App")
          .new_pipeline[Array[U8] val, Array[U8] val]("Datagen to KafkaSink",
            DataGenSourceConfig[Array[U8] val](num_msgs, msg_size,
            NoOpDecoder))
            .to_sink(KafkaSinkConfig[Array[U8] val](recover val KafkaKeySinkEncoder(key_size) end,
              ksink_clip.parse_options(env.args)?,
              env.root as AmbientAuth))
      end
      Startup(env, application, "datagen-kafkasink")
    else
      @printf[I32]("Couldn't build topology\n".cstring())
    end

class KafkaKeySinkEncoder
  let _key_size: USize

  new create(key_size: USize) =>
    _key_size = key_size

  fun apply(a: Array[U8] val, wb: Writer): (ByteSeq, (None | ByteSeq)) =>
    let k = if
              _key_size == 0
            then
              None
            else
              a.trim(0, _key_size)
            end


    (a, k)

primitive NoOpDecoder is SourceHandler[Array[U8] val]
  fun decode(a: Array[U8] val): Array[U8] val => a
