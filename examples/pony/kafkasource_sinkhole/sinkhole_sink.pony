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
use "time"
use "wallaroo/core/common"
use "wallaroo/ent/watermarking"
use "wallaroo/core/initialization"
use "wallaroo/core/invariant"
use "wallaroo/core/metrics"
use "wallaroo/core/routing"
use "wallaroo/core/sink"
use "wallaroo/core/topology"
use "wallaroo_labs/mort"

class val SinkholeSinkConfig[Out: Any val] is SinkConfig[Out]
  new val create() => None

  fun apply(): SinkBuilder =>
    SinkholeSinkBuilder

class val SinkholeSinkBuilder
  new val create() => None

  fun apply(reporter: MetricsReporter iso, env: Env): Sink =>
    SinkholeSink(consume reporter)

actor SinkholeSink is Consumer
  // Steplike
  let _metrics_reporter: MetricsReporter

  // Consumer
  var _upstreams: SetIs[Producer] = _upstreams.create()

  // Producer (Resilience)
  let _terminus_route: TerminusRoute = TerminusRoute

  new create(metrics_reporter: MetricsReporter iso)
  =>
    _metrics_reporter = consume metrics_reporter

  be run[D: Any val](metric_name: String, pipeline_time_spent: U64, data: D,
    i_producer: Producer, msg_uid: MsgId, frac_ids: FractionalMessageId,
    i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    var receive_ts: U64 = 0
    ifdef "detailed-metrics" then
      receive_ts = Time.nanos()
      _metrics_reporter.step_metric(metric_name, "Before receive at sink",
        9998, latest_ts, receive_ts)
    end

    ifdef "trace" then
      @printf[I32]("Rcvd msg at SinkholeSink\n".cstring())
    end

    let next_tracking_id = _next_tracking_id(i_producer, i_route_id, i_seq_id)

    ifdef "resilience" then
      match next_tracking_id
      | let sent: SeqId =>
        _terminus_route.receive_ack(sent)
      end
    end

    let end_ts = Time.nanos()
    let time_spent = end_ts - worker_ingress_ts

    ifdef "detailed-metrics" then
      _metrics_reporter.step_metric(metric_name, "Before end at sink", 9999,
        receive_ts, end_ts)
    end

    _metrics_reporter.pipeline_metric(metric_name,
      time_spent + pipeline_time_spent)
    _metrics_reporter.worker_metric(metric_name, time_spent)

  be replay_run[D: Any val](metric_name: String, pipeline_time_spent: U64,
    data: D, i_producer: Producer, msg_uid: MsgId, frac_ids: FractionalMessageId,
    i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    run[D](metric_name, pipeline_time_spent, data, i_producer, msg_uid, frac_ids,
      i_seq_id, i_route_id, latest_ts, metrics_id, worker_ingress_ts)

  be application_begin_reporting(initializer: LocalTopologyInitializer) =>
    initializer.report_created(this)

  be application_created(initializer: LocalTopologyInitializer,
    omni_router: OmniRouter)
  =>
    initializer.report_initialized(this)

  be application_initialized(initializer: LocalTopologyInitializer) =>
    initializer.report_ready_to_work(this)

  be application_ready_to_work(initializer: LocalTopologyInitializer) =>
    None

  be register_producer(producer: Producer) =>
    _upstreams.set(producer)

  be unregister_producer(producer: Producer) =>
    ifdef debug then
      Invariant(_upstreams.contains(producer))
    end

    _upstreams.unset(producer)

  be request_ack() =>
    _terminus_route.request_ack()

  fun ref _next_tracking_id(i_producer: Producer, i_route_id: RouteId,
    i_seq_id: SeqId): (U64 | None)
  =>
    ifdef "resilience" then
      return _terminus_route.terminate(i_producer, i_route_id, i_seq_id)
    end

    None

  be receive_state(state: ByteSeq val) => Fail()

  be dispose() =>
    None
