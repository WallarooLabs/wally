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

primitive TCPSourceConfigCLIParser
  fun apply(source_name: SourceName, args: Array[String] val):
    TCPSourceConfigOptions val ?
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
        return _from_input_string(input, source_name)?
      end
    end
    TCPSourceConfigOptions("0", "0", source_name, false)

  fun _from_input_string(inputs: String, source_name: SourceName):
    TCPSourceConfigOptions val ?
  =>
    let opts = recover trn Map[SourceName, TCPSourceConfigOptions] end

    for input in inputs.split(",").values() do
      try
        let source_name_and_address = input.split("@")
        let source_name_data = source_name_and_address(0)?
        let address_data = source_name_and_address(1)?.split(":")
        opts.update(source_name_data,
          TCPSourceConfigOptions(address_data(0)?, address_data(1)?,
          source_name_data))
      else
        FatalUserError("Inputs must be in the `source_name@host:service`" +
          " format!")
      end
    end

  opts(source_name)?

class val TCPSourceConfigOptions
  let host: String
  let service: String
  let source_name: SourceName
  let valid: Bool

  new val create(host': String, service': String,
    source_name': SourceName, valid': Bool = true)
  =>
    host = host'
    service = service'
    source_name = source_name'
    valid = valid'


class val TCPSourceConfig[In: Any val] is SourceConfig
  let handler: FramedSourceHandler[In] val
  let parallelism: USize
  let _worker_source_config: WorkerTCPSourceConfig

  new val create(source_name': SourceName,
    handler': FramedSourceHandler[In] val, host': String, service': String,
    valid': Bool, parallelism': USize = 10)
  =>
    handler = handler'
    parallelism = parallelism'
    _worker_source_config = WorkerTCPSourceConfig(source_name', host',
      service', valid')

  new val from_options(handler': FramedSourceHandler[In] val,
    opts: TCPSourceConfigOptions, parallelism': USize = 10)
  =>
    handler = handler'
    parallelism = parallelism'
    _worker_source_config = WorkerTCPSourceConfig(opts.source_name, opts.host,
      opts.service, opts.valid)

  fun val source_coordinator_builder_builder(): TCPSourceCoordinatorBuilderBuilder[In] =>
    TCPSourceCoordinatorBuilderBuilder[In](this)

  fun default_partitioner_builder(): PartitionerBuilder =>
    RandomPartitionerBuilder

  fun worker_source_config(): WorkerSourceConfig =>
    _worker_source_config

class val WorkerTCPSourceConfig is WorkerSourceConfig
  let host: String
  let service: String
  let source_name: SourceName
  let valid: Bool

  new val create(source_name': SourceName, host': String,
    service': String, valid': Bool)
  =>
    host = host'
    service = service'
    source_name = source_name'
    valid = valid'
