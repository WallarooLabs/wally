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
use "wallaroo/core/boundary"
use "wallaroo/core/initialization"
use "wallaroo/core/routing"
use "wallaroo/core/topology"
use "wallaroo/ent/barrier"
use "wallaroo/ent/data_receiver"
use "wallaroo/ent/recovery"
use "wallaroo/ent/checkpoint"


actor DummyConsumer is Consumer
  be register_producer(id: RoutingId, producer: Producer) =>
    None

  be unregister_producer(id: RoutingId, producer: Producer) =>
    None

  be report_status(code: ReportStatusCode) =>
    None

  be run[D: Any val](metric_name: String, pipeline_time_spent: U64, data: D,
    i_producer_id: RoutingId, i_producer: Producer, msg_uid: MsgId,
    frac_ids: FractionalMessageId, i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    None

  fun ref process_message[D: Any val](metric_name: String,
    pipeline_time_spent: U64, data: D, i_producer_id: RoutingId,
    i_producer: Producer, msg_uid: MsgId, frac_ids: FractionalMessageId,
    i_seq_id: SeqId, i_route_id: RouteId, latest_ts: U64, metrics_id: U16,
    worker_ingress_ts: U64)
  =>
    None

  be replay_run[D: Any val](metric_name: String, pipeline_time_spent: U64,
    data: D, i_producer_id: RoutingId, i_producer: Producer, msg_uid: MsgId,
    frac_ids: FractionalMessageId, i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    None

  be receive_state(state: ByteSeq val) =>
    None

  be request_ack() =>
    None

  be application_begin_reporting(initializer: LocalTopologyInitializer) =>
    None

  be application_created(initializer: LocalTopologyInitializer) =>
    None

  be application_initialized(initializer: LocalTopologyInitializer) =>
    None

  be application_ready_to_work(initializer: LocalTopologyInitializer) =>
    None

  be receive_barrier(step_id: RoutingId, producer: Producer,
    barrier_token: BarrierToken)
  =>
    None

  fun ref barrier_complete(barrier_token: BarrierToken) =>
    None

  fun ref checkpoint_state(checkpoint_id: CheckpointId) =>
    None

  be prepare_for_rollback() =>
    None

  be rollback(payload: ByteSeq val, event_log: EventLog,
    checkpoint_id: CheckpointId)
  =>
    None

