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
use "wallaroo/core/common"
use "wallaroo/core/topology"

primitive TestRunnerSender[V: (Hashable & Equatable[V] val)]
  fun send_seq(inputs: Array[V] val, key: Key, runner: Runner,
    router: Router, consumer_sender: TestableConsumerSender)
  =>
    for input in inputs.values() do
      send(input, key, runner, router, consumer_sender)
    end

  fun send(input: V, key: Key, runner: Runner, router: Router,
    consumer_sender: TestableConsumerSender)
  =>
    let metric_name = ""
    let pipeline_time_spent: U64 = 1
    let event_ts: U64 = 1
    let watermark_ts: U64 = 1
    let i_msg_uid: MsgId = 1
    let frac_ids = None
    let latest_ts: U64 = 1
    let metrics_id: U16 = 1
    let worker_ingress_ts: U64 = 1

    runner.run[V](metric_name, pipeline_time_spent, input, key, event_ts,
      watermark_ts, consumer_sender, router, i_msg_uid, frac_ids, latest_ts,
      metrics_id, worker_ingress_ts)
