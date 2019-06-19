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

use "collections"
use "options"
use "wallaroo"
use "wallaroo/core/partitioning"
use "wallaroo/core/source"
use "wallaroo_labs/mort"

primitive ConnectorSourceConfigCLIParser
  fun apply(args: Array[String] val):
    Map[SourceName, ConnectorSourceConfigOptions] val ?
  =>
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
        return _from_input_string(input)
      end
    end

    error

  fun _from_input_string(inputs: String):
    Map[SourceName, ConnectorSourceConfigOptions] val
  =>
    let opts = recover trn Map[SourceName, ConnectorSourceConfigOptions] end

    for input in inputs.split(",").values() do
      try
        let source_name_and_address = input.split("@")
        let source_name' = source_name_and_address(0)?
        let address_data = source_name_and_address(1)?.split(":")
        let host = address_data(0)?
        let service = address_data(1)?
        let cookie = address_data(2)?
        let max_credits = address_data(3)?.u32()?
        let refill_credits = address_data(4)?.u32()?

        opts.update(source_name_and_address(0)?,
          ConnectorSourceConfigOptions(source_name', host, service, cookie,
            max_credits, refill_credits))
      else
        FatalUserError("Inputs must be in the `source_name@host:service`" +
          " format!")
      end
    end

    consume opts

// TODO: Refactor. Why is this identical to WorkerConnectorSourceConfig?
class val ConnectorSourceConfigOptions
  let host: String
  let service: String
  let source_name: SourceName
  let cookie :String
  let max_credits: U32
  let refill_credits: U32

  new val create(source_name': SourceName, host': String, service': String,
    cookie': String, max_credits': U32, refill_credits': U32)
  =>
    host = host'
    service = service'
    source_name = source_name'
    cookie = cookie'
    max_credits = max_credits'
    refill_credits = refill_credits'

class val ConnectorSourceConfig[In: Any val] is SourceConfig
  let handler: FramedSourceHandler[In] val
  let parallelism: USize
  let _worker_source_config: WorkerConnectorSourceConfig

  new val create(source_name: SourceName, handler': FramedSourceHandler[In] val,
    host: String, service: String, cookie: String,
    max_credits: U32, refill_credits: U32, parallelism': USize = 50)
  =>
    handler = handler'
    parallelism = parallelism'
    _worker_source_config = WorkerConnectorSourceConfig(source_name, host,
      service, cookie, max_credits, refill_credits)

  new val from_options(handler': FramedSourceHandler[In] val,
    opts: ConnectorSourceConfigOptions, parallelism': USize = 50)
  =>
    handler = handler'
    parallelism = parallelism'
    _worker_source_config = WorkerConnectorSourceConfig(opts.source_name,
      opts.host, opts.service, opts.cookie, opts.max_credits,
      opts.refill_credits)

  fun val source_coordinator_builder_builder():
    ConnectorSourceCoordinatorBuilderBuilder[In]
  =>
    ConnectorSourceCoordinatorBuilderBuilder[In](this)

  fun default_partitioner_builder(): PartitionerBuilder =>
    PassthroughPartitionerBuilder

  fun worker_source_config(): WorkerSourceConfig =>
    _worker_source_config

class val WorkerConnectorSourceConfig is WorkerSourceConfig
  let host: String
  let service: String
  let source_name: SourceName
  let cookie: String
  let max_credits: U32
  let refill_credits: U32

  new val create(source_name': SourceName, host': String, service': String,
    cookie': String, max_credits': U32, refill_credits': U32)
  =>
    host = host'
    service = service'
    source_name = source_name'
    cookie = cookie'
    max_credits = max_credits'
    refill_credits = refill_credits'
