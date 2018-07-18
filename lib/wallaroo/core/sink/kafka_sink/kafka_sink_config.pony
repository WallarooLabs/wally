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
use "crypto"
use "net"
use "options"
use "pony-kafka"
use "pony-kafka/customlogger"
use "wallaroo/core/common"
use "wallaroo_labs/mort"
use "wallaroo/core/messages"
use "wallaroo/core/metrics"
use "wallaroo/core/sink"
use "wallaroo/ent/recovery"
use "wallaroo/ent/snapshot"


primitive KafkaSinkConfigCLIParser
  fun apply(out: OutStream, prefix: String = "kafka_sink"): KafkaConfigCLIParser
  =>
    KafkaConfigCLIParser(out, KafkaProduceOnly where prefix = prefix)

class val KafkaSinkConfig[Out: Any val] is SinkConfig[Out]
  let _encoder: KafkaSinkEncoder[Out]
  let _ksco: KafkaConfigOptions val
  let _auth: TCPConnectionAuth

  new val create(encoder: KafkaSinkEncoder[Out],
    ksco: KafkaConfigOptions iso,
    auth: TCPConnectionAuth)
  =>
    ksco.client_name = "Wallaroo Kafka Sink " + ksco.topic
    _encoder = encoder
    _ksco = consume ksco
    _auth = auth

  fun apply(): SinkBuilder =>
    KafkaSinkBuilder(TypedKafkaEncoderWrapper[Out](_encoder), _ksco, _auth)

class val KafkaSinkBuilder
  let _encoder_wrapper: KafkaEncoderWrapper
  let _ksco: KafkaConfigOptions val
  let _auth: TCPConnectionAuth

  new val create(encoder_wrapper: KafkaEncoderWrapper,
    ksco: KafkaConfigOptions val,
    auth: TCPConnectionAuth)
  =>
    _encoder_wrapper = encoder_wrapper
    _ksco = ksco
    _auth = auth

  fun apply(sink_name: String, event_log: EventLog,
    reporter: MetricsReporter iso, env: Env,
    snapshot_initiator: SnapshotInitiator, recovering: Bool): Sink
  =>
    // generate md5 hash for sink id
    let rb: Reader = Reader
    let name = sink_name + "-KafkaSink-" + _ksco.topic
    let temp_id = MD5(name)
    rb.append(temp_id)

    let sink_id = try rb.u128_le()? else Fail(); 0 end

    // create kafka config
    match KafkaConfigFactory(_ksco, env.out)
    | let kc: KafkaConfig val =>
      KafkaSink(sink_id, name, event_log, recovering, _encoder_wrapper,
        consume reporter, kc, snapshot_initiator, _auth)
    | let ksce: KafkaConfigError =>
      @printf[U32]("%s\n".cstring(), ksce.message().cstring())
      Fail()
      EmptySink
    end
