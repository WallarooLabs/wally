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
use "pony-kafka"
use "time"
use "wallaroo/core/boundary"
use "wallaroo/core/common"
use "wallaroo/core/metrics"
use "wallaroo/core/routing"
use "wallaroo/core/source"
use "wallaroo/core/topology"
use "wallaroo/ent/recovery"
use "wallaroo_labs/mort"

primitive KafkaSourceNotifyBuilder[In: Any val]
  fun apply(source_id: RoutingId, pipeline_name: String, env: Env,
    auth: AmbientAuth, handler: SourceHandler[In] val,
    runner_builder: RunnerBuilder, router: Router,
    metrics_reporter: MetricsReporter iso, event_log: EventLog,
    target_router: Router): KafkaSourceNotify[In] iso^
  =>
    KafkaSourceNotify[In](source_id, pipeline_name, env, auth, handler,
      runner_builder, router, consume metrics_reporter, event_log,
      target_router)

class KafkaSourceNotify[In: Any val]
  let _source_id: RoutingId
  let _env: Env
  let _auth: AmbientAuth
  let _msg_id_gen: MsgIdGenerator = MsgIdGenerator
  let _pipeline_name: String
  let _source_name: String
  let _handler: SourceHandler[In] val
  let _runner: Runner
  var _router: Router
  let _metrics_reporter: MetricsReporter

  new iso create(source_id: RoutingId, pipeline_name: String, env: Env,
    auth: AmbientAuth, handler: SourceHandler[In] val,
    runner_builder: RunnerBuilder, router': Router,
    metrics_reporter: MetricsReporter iso, event_log: EventLog,
    target_router: Router)
  =>
    _source_id = source_id
    _pipeline_name = pipeline_name
    _source_name = pipeline_name + " source"
    _env = env
    _auth = auth
    _handler = handler
    _runner = runner_builder(event_log, auth, None, target_router)
    _router = router'
    _metrics_reporter = consume metrics_reporter

  fun routes(): Map[RoutingId, Consumer] val =>
    _router.routes()

  fun ref received(source: KafkaSource[In] ref, kafka_msg_value: Array[U8] iso,
    kafka_msg_key: (Array[U8] val | None),
    kafka_msg_metadata: KafkaMessageMetadata val,
    network_received_timestamp: U64)
  =>
    _metrics_reporter.pipeline_ingest(_pipeline_name, _source_name)
    let ingest_ts = Time.nanos()
    let pipeline_time_spent: U64 = 0
    var latest_metrics_id: U16 = 1

    ifdef "detailed-metrics" then
      _metrics_reporter.step_metric(_pipeline_name,
        "Kafka Client decode time (before wallaroo)", latest_metrics_id,
        network_received_timestamp, ingest_ts)
      latest_metrics_id = latest_metrics_id + 1
    end

    let data = consume kafka_msg_value

    ifdef "trace" then
      @printf[I32](("Rcvd msg at " + _pipeline_name + " source\n").cstring())
    end

    (let is_finished, let last_ts) =
      try
        let decoded =
          try
            _handler.decode(consume data)?
          else
            ifdef debug then
              @printf[I32]("Error decoding message at source\n".cstring())
            end
            error
          end
        let decode_end_ts = Time.nanos()
        _metrics_reporter.step_metric(_pipeline_name,
          "Decode Time in Kafka Source", latest_metrics_id, ingest_ts,
          decode_end_ts)
        latest_metrics_id = latest_metrics_id + 1

        ifdef "trace" then
          @printf[I32](("Msg decoded at " + _pipeline_name +
            " source\n").cstring())
        end
        _runner.run[In](_pipeline_name, pipeline_time_spent, decoded,
          "kafka-source-key", _source_id, source, _router,
          _msg_id_gen(), None, decode_end_ts, latest_metrics_id, ingest_ts,
          _metrics_reporter)
      else
        @printf[I32](("Unable to decode message at " + _pipeline_name +
          " source\n").cstring())
        ifdef debug then
          Fail()
        end
        (true, ingest_ts)
      end

    if is_finished then
      let end_ts = Time.nanos()
      let time_spent = end_ts - ingest_ts

      ifdef "detailed-metrics" then
        _metrics_reporter.step_metric(_pipeline_name,
          "Before end at Kafka Source", 9999,
          last_ts, end_ts)
      end

      _metrics_reporter.pipeline_metric(_pipeline_name, time_spent +
        pipeline_time_spent)
      _metrics_reporter.worker_metric(_pipeline_name, time_spent)
    end

  fun ref update_router(router': Router) =>
    _router = router'

  fun ref update_boundaries(obs: box->Map[String, OutgoingBoundary]) =>
    match _router
    | let p_router: StatePartitionRouter =>
      _router = p_router.update_boundaries(_auth, obs)
    else
      ifdef "trace" then
        @printf[I32](("KafkaSourceNotify doesn't have StatePartitionRouter. " +
          "Updating boundaries is a noop for this kind of Source.\n").cstring())
      end
    end
