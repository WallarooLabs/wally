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

use "options"
use "wallaroo"
use "wallaroo/core/partitioning"
use "wallaroo/core/source"

primitive ConnectorSource2ConfigCLIParser
  fun apply(args: Array[String] val): Array[ConnectorSource2ConfigOptions] val ? =>
    let in_arg = "in"
    let short_in_arg = "i"

    let options = Options(args, false)

    options.add(in_arg, short_in_arg, StringArgument, Required)
    options.add("help", None)

    for option in options do
      match option
      | ("help", let arg: None) =>
        StartupHelp()
      | (in_arg, let input: String) =>
        return _from_input_string(input)?
      end
    end

    error

  fun _from_input_string(inputs: String): Array[ConnectorSource2ConfigOptions] val ? =>
    let opts = recover trn Array[ConnectorSource2ConfigOptions] end

    for input in inputs.split(",").values() do
      let i = input.split(":")
      opts.push(ConnectorSource2ConfigOptions(i(0)?, i(1)?, i(2)?,
        i(3)?.u32()?, i(4)?.u32()?))
    end

    consume opts

class val ConnectorSource2ConfigOptions
  let host: String
  let service: String
  let connector_cookie: String
  let connector_max_credits: U32
  let connector_refill_credits: U32

  new val create(host': String,
    service': String,
    connector_cookie': String = "default_cookie",
    connector_max_credits': U32 = 4_000,
    connector_refill_credits': U32 = 3_000) =>
    host = host'
    service = service'
    connector_cookie = connector_cookie'
    connector_max_credits = connector_max_credits'
    connector_refill_credits = connector_refill_credits'

class val ConnectorSource2Config[In: Any val]
  let _handler: FramedSourceHandler[In] val
  let _host: String
  let _service: String
  let _parallelism: USize
  let _connector_cookie: String
  let _connector_max_credits: U32
  let _connector_refill_credits: U32

  new val create(handler': FramedSourceHandler[In] val,
    host': String,
    service': String,
    connector_cookie': String,
    connector_max_credits': U32,
    connector_refill_credits': U32,
    parallelism': USize = 10)
  =>
    _handler = handler'
    _host = host'
    _service = service'
    _parallelism = parallelism'
    _connector_cookie = connector_cookie'
    _connector_max_credits = connector_max_credits'
    _connector_refill_credits = connector_refill_credits'

  new val from_options(foo: Bool, handler': FramedSourceHandler[In] val,
    opts: ConnectorSource2ConfigOptions, parallelism': USize = 10)
  =>
    _handler = handler'
    _host = opts.host
    _service = opts.service
    _parallelism = parallelism'
    _connector_cookie = opts.connector_cookie
    _connector_max_credits = opts.connector_max_credits
    _connector_refill_credits = opts.connector_refill_credits

  fun source_listener_builder_builder(): ConnectorSource2ListenerBuilderBuilder[In] =>
    ConnectorSource2ListenerBuilderBuilder[In](_host, _service, _parallelism,
      _handler, _connector_cookie,
      _connector_max_credits, _connector_refill_credits)

  fun default_partitioner_builder(): PartitionerBuilder =>
    PassthroughPartitionerBuilder
