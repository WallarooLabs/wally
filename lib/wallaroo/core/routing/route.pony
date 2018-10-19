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

use "time"
use "wallaroo_labs/guid"
use "wallaroo/core/boundary"
use "wallaroo/core/common"
use "wallaroo_labs/mort"
use "wallaroo/core/invariant"
use "wallaroo/core/messages"
use "wallaroo/core/metrics"
use "wallaroo/core/topology"


primitive Route
  fun run[D: Any val](metric_name: String, pipeline_time_spent: U64,
    data: D, key: Key, cfp_id: RoutingId, cfp: Producer ref, msg_uid: MsgId,
    frac_ids: FractionalMessageId, latest_ts: U64, metrics_id: U16,
    worker_ingress_ts: U64, consumer: Consumer)
  =>
    let o_seq_id = cfp.next_sequence_id()

    let my_latest_ts = ifdef "detailed-metrics" then
        Time.nanos()
      else
        latest_ts
      end

    let new_metrics_id = ifdef "detailed-metrics" then
        cfp.metrics_reporter().step_metric(metric_name,
          "Before send to next step via behavior", metrics_id,
          latest_ts, my_latest_ts)
        metrics_id + 1
      else
        metrics_id
      end

    consumer.run[D](metric_name, pipeline_time_spent, data, key, cfp_id,
      cfp, msg_uid, frac_ids, o_seq_id, my_latest_ts, new_metrics_id,
      worker_ingress_ts)

  fun forward(delivery_msg: DeliveryMsg,
    pipeline_time_spent: U64, producer_id: RoutingId, cfp: Producer ref,
    latest_ts: U64, metrics_id: U16, metric_name: String,
    worker_ingress_ts: U64, boundary: OutgoingBoundary)
  =>
    ifdef "trace" then
      @printf[I32]("Route.forward msg\n".cstring())
    end
    let o_seq_id = cfp.next_sequence_id()

    boundary.forward(delivery_msg, pipeline_time_spent, producer_id, cfp,
      o_seq_id, latest_ts, metrics_id, worker_ingress_ts)

  fun register_producer(producer_id: RoutingId, target_id: RoutingId,
    producer: Producer, consumer: Consumer)
  =>
    match consumer
    | let ob: OutgoingBoundary =>
      ob.forward_register_producer(producer_id, target_id, producer)
    else
      consumer.register_producer(producer_id, producer)
    end

  fun unregister_producer(producer_id: RoutingId, target_id: RoutingId,
    producer: Producer, consumer: Consumer)
  =>
    match consumer
    | let ob: OutgoingBoundary =>
      ob.forward_unregister_producer(producer_id, target_id, producer)
    else
      consumer.unregister_producer(producer_id, producer)
    end
