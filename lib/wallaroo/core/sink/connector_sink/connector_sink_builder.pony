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

use "backpressure"
use "options"
use "wallaroo"
use "wallaroo/core/common"
use "wallaroo/core/messages"
use "wallaroo/core/metrics"
use "wallaroo/core/sink"
use "wallaroo/core/barrier"
use "wallaroo/core/recovery"
use "wallaroo/core/checkpoint"
use "wallaroo_labs/logging"
use "wallaroo_labs/mort"

primitive ConnectorSinkConfigCLIParser
  fun apply(args: Array[String] val): Array[ConnectorSinkConfigOptions] val ?
  =>
    let out_arg = "out"
    let out_short_arg = "o"
    let options = Options(args, false)

    options.add(out_arg, out_short_arg, StringArgument, Required)
    options.add("help", "h", None)

    for option in options do
      match option
      | ("help", let arg: None) =>
        StartupHelp()
      | (out_arg, let output: String) =>
        return _from_output_string(output)?
      end
    end

    error

  fun _from_output_string(outputs: String):
    Array[ConnectorSinkConfigOptions] val ?
  =>
    let opts = recover trn Array[ConnectorSinkConfigOptions] end

    for output in outputs.split(",").values() do
      let o = output.split(":")
      opts.push(ConnectorSinkConfigOptions(o(0)?, o(1)?, "v0.0.1",
        "Dragons Love Tacos!"))
    end

    consume opts

class val ConnectorSinkConfigOptions
  let host: String
  let service: String
  let protocol_version: String
  let cookie: String

  new val create(host': String, service': String,
    protocol_version': String, cookie': String)
=>
    host = host'
    service = service'
    protocol_version = protocol_version'
    cookie = cookie'

class val ConnectorSinkConfig[Out: Any val] is SinkConfig[Out]
  let _encoder: ConnectorSinkEncoder[Out]
  let _host: String
  let _service: String
  let _protocol_version: String
  let _cookie: String
  let _initial_msgs: Array[Array[ByteSeq] val] val

  new val create(encoder: ConnectorSinkEncoder[Out],
    host: String, service: String,
    protocol_version: String, cookie: String,
    initial_msgs: Array[Array[ByteSeq] val] val =
    recover Array[Array[ByteSeq] val] end)
  =>
    _encoder = encoder
    _host = host
    _service = service
    _protocol_version = protocol_version
    _cookie = cookie
    _initial_msgs = initial_msgs

  new val from_options(encoder: ConnectorSinkEncoder[Out], opts: ConnectorSinkConfigOptions,
    initial_msgs: Array[Array[ByteSeq] val] val =
    recover Array[Array[ByteSeq] val] end)
  =>
    _encoder = encoder
    _initial_msgs = initial_msgs
    _host = opts.host
    _service = opts.service
    _protocol_version = opts.protocol_version
    _cookie = opts.cookie

  fun apply(): SinkBuilder =>
    ConnectorSinkBuilder(TypedConnectorEncoderWrapper[Out](_encoder), _host, _service, _protocol_version, _cookie, _initial_msgs)

class val ConnectorSinkBuilder
  let _encoder_wrapper: ConnectorEncoderWrapper
  let _host: String
  let _service: String
  let _protocol_version: String
  let _cookie: String
  let _initial_msgs: Array[Array[ByteSeq] val] val

  new val create(encoder_wrapper: ConnectorEncoderWrapper, host: String,
    service: String, protocol_version: String, cookie: String,
    initial_msgs: Array[Array[ByteSeq] val] val)
  =>
    _encoder_wrapper = encoder_wrapper
    _host = host
    _service = service
    _protocol_version = protocol_version
    _cookie = cookie
    _initial_msgs = initial_msgs

  fun apply(sink_name: String, event_log: EventLog,
    reporter: MetricsReporter iso, env: Env,
    barrier_coordinator: BarrierCoordinator, checkpoint_initiator: CheckpointInitiator,
    recovering: Bool, worker_name: WorkerName, auth: AmbientAuth): Sink
  =>
    @l(Log.info(), Log.conn_sink(),
      ("ConnectorSinkBuilder: Connecting to sink at " + _host + ":" + _service + "\n")
      .cstring())

    let id: RoutingId = RoutingIdGenerator()

    ConnectorSink(id, sink_name, event_log, recovering, env, _encoder_wrapper,
      consume reporter, barrier_coordinator, checkpoint_initiator, _host, _service, worker_name, _protocol_version, _cookie,
      ApplyReleaseBackpressureAuth(auth), _initial_msgs)
