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

use "net"
use "options"
use "pony-kafka"
use "pony-kafka/customlogger"
use "wallaroo/core/partitioning"
use "wallaroo/core/source"


primitive KafkaSourceConfigCLIParser
  fun apply(out: OutStream, prefix: String = "kafka_source"): KafkaConfigCLIParser =>
    KafkaConfigCLIParser(out, KafkaConsumeOnly where prefix = prefix)

class val KafkaSourceConfig[In: Any val] is SourceConfig
  let auth: TCPConnectionAuth
  let handler: SourceHandler[In] val
  let _worker_source_config: WorkerKafkaSourceConfig

  new val create(source_name: SourceName, ksco: KafkaConfigOptions iso,
    auth': TCPConnectionAuth, handler': SourceHandler[In] val)
  =>
    ksco.client_name = "Wallaroo Kafka Source " + ksco.topic
    handler = handler'
    auth = auth'
    _worker_source_config = WorkerKafkaSourceConfig(source_name, consume ksco)

  fun val source_listener_builder_builder(): KafkaSourceListenerBuilderBuilder[In]
  =>
    KafkaSourceListenerBuilderBuilder[In](this)

  fun default_partitioner_builder(): PartitionerBuilder =>
    PassthroughPartitionerBuilder

  fun worker_source_config(): WorkerSourceConfig =>
    _worker_source_config

class val WorkerKafkaSourceConfig is WorkerSourceConfig
  let ksco: KafkaConfigOptions val
  let source_name: SourceName

  new val create(source_name': SourceName, ksco': KafkaConfigOptions val) =>
    ksco = ksco'
    source_name = source_name'
