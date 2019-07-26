/*

Copyright 2019 The Wallaroo Authors.

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

use "time"
use "wallaroo_labs/guid"
use "wallaroo/core/boundary"
use "wallaroo/core/common"
use "wallaroo/core/invariant"
use "wallaroo/core/messages"
use "wallaroo/core/metrics"
use "wallaroo_labs/mort"
use "wallaroo_labs/time"


class ConsumerSender is TestableConsumerSender
  let _producer_id: RoutingId
  let _producer: Producer ref
  let _metrics_reporter: MetricsReporter

  new create(producer_id: RoutingId, producer: Producer ref,
    metrics_reporter: MetricsReporter iso)
  =>
    _producer_id = producer_id
    _producer = producer
    _metrics_reporter = consume metrics_reporter

  fun ref send[D: Any val](metric_name: String,
    pipeline_time_spent: U64, data: D, key: Key, event_ts: U64,
    watermark_ts: U64, msg_uid: MsgId, frac_ids: FractionalMessageId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64,
    consumer: Consumer)
  =>
    if _producer.has_route_to(consumer) then
      let o_seq_id = _producer.next_sequence_id()

      let my_latest_ts = ifdef "detailed-metrics" then
          WallClock.nanoseconds()
        else
          latest_ts
        end

      let new_metrics_id = ifdef "detailed-metrics" then
          _metrics_reporter.step_metric(metric_name,
            "Before send to next step via behavior", metrics_id,
            latest_ts, my_latest_ts)
          metrics_id + 1
        else
          metrics_id
        end

      consumer.run[D](metric_name, pipeline_time_spent, data, key, event_ts,
        watermark_ts, _producer_id, _producer, msg_uid, frac_ids, o_seq_id,
        my_latest_ts, new_metrics_id, worker_ingress_ts)
    else
      @printf[I32]("ConsumerSender couldn't find route!\n".cstring())
      Fail()
    end

  fun ref forward(delivery_msg: DeliveryMsg, pipeline_time_spent: U64,
    latest_ts: U64, metrics_id: U16, metric_name: String,
    worker_ingress_ts: U64, boundary: OutgoingBoundary)
  =>
    if _producer.has_route_to(boundary) then
      ifdef "trace" then
        @printf[I32]("\n".cstring())
      end
      let o_seq_id = _producer.next_sequence_id()
      @printf[I32]("SLF: ConsumerSender.forward msg: o_seq_id = %lu boundary = 0x%lx\n".cstring(), o_seq_id, boundary)

      boundary.forward(delivery_msg, pipeline_time_spent, _producer_id,
        _producer, o_seq_id, latest_ts, metrics_id, worker_ingress_ts)
    else
      @printf[I32]("ConsumerSender couldn't find route!\n".cstring())
      Fail()
    end

  fun ref register_producer(consumer_id: RoutingId, consumer: Consumer) =>
    match consumer
    | let ob: OutgoingBoundary =>
      ob.forward_register_producer(_producer_id, consumer_id, _producer)
    else
      consumer.register_producer(_producer_id, _producer)
    end

  fun ref unregister_producer(consumer_id: RoutingId, consumer: Consumer) =>
    match consumer
    | let ob: OutgoingBoundary =>
      ob.forward_unregister_producer(_producer_id, consumer_id, _producer)
    else
      consumer.unregister_producer(_producer_id, _producer)
    end

  fun ref update_output_watermark(w: U64): (U64, U64) =>
    _producer.update_output_watermark(w)

