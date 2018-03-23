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
use "wallaroo/core/common"
use "wallaroo/ent/data_receiver"
use "wallaroo/core/initialization"
use "wallaroo/core/routing"
use "wallaroo/core/topology"
use "wallaroo_labs/mort"

actor EmptySink is Consumer
  be run[D: Any val](metric_name: String, pipeline_time_spent: U64, data: D,
    producer: Producer, msg_uid: MsgId, frac_ids: FractionalMessageId,
    seq_id: SeqId, route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    ifdef "trace" then
      @printf[I32]("Rcvd msg at EmptySink\n".cstring())
    end
    None

  be replay_run[D: Any val](metric_name: String, pipeline_time_spent: U64,
    data: D, producer: Producer, msg_uid: MsgId, frac_ids: FractionalMessageId,
    incoming_seq_id: SeqId, route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    None

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
    None

  be unregister_producer(producer: Producer) =>
    None

  be request_finished_ack(request_id: RequestId, requester_id: StepId,
    producer: FinishedAckRequester)
  =>
    // @printf[I32]("!@ request_finished_ack EmptySink\n".cstring())
    producer.receive_finished_ack(request_id)

  be request_finished_ack_complete(requester_id: StepId,
    requester: FinishedAckRequester)
  =>
    // @printf[I32]("!@ request_finished_ack_complete EmptySink\n".cstring())
    None

  be try_finish_request_early(requester_id: StepId) =>
    None

  be request_ack() =>
    None

  be receive_state(state: ByteSeq val) => Fail()

  be dispose() =>
    None
