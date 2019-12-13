/*

Copyright 2018-2020 The Wallaroo Authors.

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

use "wallaroo/core/sink/connector_sink"
use "wallaroo_labs/mort"

trait val QueuedMessage
  fun process_message(consumer: Consumer ref)
  fun run(consumer: Consumer ref)
  fun post_valve_process_message(sink: ConnectorSink ref)

class val TypedQueuedMessage[D: Any val] is QueuedMessage
  let metric_name: String
  let pipeline_time_spent: U64
  let data: D
  let key: Key
  let event_ts: U64
  let watermark_ts: U64
  let i_producer_id: RoutingId
  let i_producer: Producer
  let msg_uid: MsgId
  let frac_ids: FractionalMessageId
  let i_seq_id: SeqId
  let latest_ts: U64
  let metrics_id: U16
  let worker_ingress_ts: U64

  new val create(metric_name': String, pipeline_time_spent': U64,
    data': D, key': Key, event_ts': U64, watermark_ts': U64,
    i_producer_id': RoutingId, i_producer': Producer, msg_uid': MsgId,
    frac_ids': FractionalMessageId, i_seq_id': SeqId, latest_ts': U64,
    metrics_id': U16, worker_ingress_ts': U64)
  =>
    metric_name = metric_name'
    pipeline_time_spent = pipeline_time_spent'
    data = data'
    key = key'
    event_ts = event_ts'
    watermark_ts = watermark_ts'
    i_producer_id = i_producer_id'
    i_producer = i_producer'
    msg_uid = msg_uid'
    frac_ids = frac_ids'
    i_seq_id = i_seq_id'
    latest_ts = latest_ts'
    metrics_id = metrics_id'
    worker_ingress_ts = worker_ingress_ts'

  fun process_message(consumer: Consumer ref) =>
    consumer.process_message[D](metric_name, pipeline_time_spent, data, key,
      event_ts, watermark_ts, i_producer_id, i_producer, msg_uid, frac_ids,
      i_seq_id, latest_ts, metrics_id, worker_ingress_ts)

  fun run(consumer: Consumer ref) =>
    consumer._run[D](metric_name, pipeline_time_spent, data, key,
      event_ts, watermark_ts, i_producer_id, i_producer, msg_uid, frac_ids,
      i_seq_id, latest_ts, metrics_id, worker_ingress_ts)

  fun post_valve_process_message(sink: ConnectorSink ref) =>
    sink.process_message2[D](metric_name, pipeline_time_spent, data, key,
      event_ts, watermark_ts, i_producer_id, i_producer, msg_uid, frac_ids,
      i_seq_id, latest_ts, metrics_id, worker_ingress_ts)
