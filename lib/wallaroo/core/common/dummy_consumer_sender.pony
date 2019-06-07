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

use "collections"
use "promises"
use "wallaroo/core/boundary"
use "wallaroo/core/initialization"
use "wallaroo/core/messages"
use "wallaroo/core/metrics"
use "wallaroo/core/routing"
use "wallaroo/core/topology"
use "wallaroo/core/data_receiver"
use "wallaroo/core/recovery"
use "wallaroo/core/checkpoint"
use "wallaroo_labs/mort"

class DummyConsumerSender is TestableConsumerSender
  fun ref send[D: Any val](metric_name: String,
    pipeline_time_spent: U64, data: D, key: Key, event_ts: U64,
    watermark_ts: U64, msg_uid: MsgId, frac_ids: FractionalMessageId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64,
    consumer: Consumer)
  =>
    None

  fun ref forward(delivery_msg: DeliveryMsg, pipeline_time_spent: U64,
    latest_ts: U64, metrics_id: U16, metric_name: String,
    worker_ingress_ts: U64, boundary: OutgoingBoundary)
  =>
    None

  fun ref register_producer(consumer_id: RoutingId, consumer: Consumer) =>
    None

  fun ref unregister_producer(consumer_id: RoutingId, consumer: Consumer) =>
    None

  fun ref update_output_watermark(w: U64): (U64, U64) =>
    (0, 0)
