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
use "wallaroo/core/common"
use "wallaroo/core/messages"
use "wallaroo/core/metrics"
use "wallaroo/core/sink"
use "wallaroo/ent/barrier"
use "wallaroo/ent/recovery"
use "wallaroo/ent/snapshot"


primitive TCPSinkConfigCLIParser
  fun apply(args: Array[String] val): Array[TCPSinkConfigOptions] val ? =>
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

  fun _from_output_string(outputs: String): Array[TCPSinkConfigOptions] val ? =>
    let opts = recover trn Array[TCPSinkConfigOptions] end

    for output in outputs.split(",").values() do
      let o = output.split(":")
      opts.push(TCPSinkConfigOptions(o(0)?, o(1)?))
    end

    consume opts

class val TCPSinkConfigOptions
  let host: String
  let service: String

  new val create(host': String, service': String) =>
    host = host'
    service = service'

class val TCPSinkConfig[Out: Any val] is SinkConfig[Out]
  let _encoder: TCPSinkEncoder[Out]
  let _host: String
  let _service: String
  let _initial_msgs: Array[Array[ByteSeq] val] val

  new val create(encoder: TCPSinkEncoder[Out], host: String, service: String,
    initial_msgs: Array[Array[ByteSeq] val] val =
    recover Array[Array[ByteSeq] val] end)
  =>
    _encoder = encoder
    _initial_msgs = initial_msgs
    _host = host
    _service = service

  new val from_options(encoder: TCPSinkEncoder[Out], opts: TCPSinkConfigOptions,
    initial_msgs: Array[Array[ByteSeq] val] val =
    recover Array[Array[ByteSeq] val] end)
  =>
    _encoder = encoder
    _initial_msgs = initial_msgs
    _host = opts.host
    _service = opts.service


  fun apply(): SinkBuilder =>
    TCPSinkBuilder(TypedTCPEncoderWrapper[Out](_encoder), _host, _service,
      _initial_msgs)

class val TCPSinkBuilder
  let _encoder_wrapper: TCPEncoderWrapper
  let _host: String
  let _service: String
  let _initial_msgs: Array[Array[ByteSeq] val] val

  new val create(encoder_wrapper: TCPEncoderWrapper, host: String,
    service: String, initial_msgs: Array[Array[ByteSeq] val] val)
  =>
    _encoder_wrapper = encoder_wrapper
    _host = host
    _service = service
    _initial_msgs = initial_msgs

  fun apply(sink_name: String, event_log: EventLog,
    reporter: MetricsReporter iso, env: Env,
    barrier_initiator: BarrierInitiator, snapshot_initiator: SnapshotInitiator,
    recovering: Bool): Sink
  =>
    @printf[I32](("Connecting to sink at " + _host + ":" + _service + "\n")
      .cstring())

    let id: RoutingId = RoutingIdGenerator()

    TCPSink(id, sink_name, event_log, recovering, env, _encoder_wrapper,
      consume reporter, barrier_initiator, snapshot_initiator, _host, _service,
      _initial_msgs)
