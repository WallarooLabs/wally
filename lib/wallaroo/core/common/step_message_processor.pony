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

use "wallaroo_labs/mort"
use "wallaroo/core/invariant"
use "wallaroo/core/topology"
use "wallaroo/ent/barrier"
use "wallaroo/ent/snapshot"

trait StepMessageProcessor
  fun ref run[D: Any val](metric_name: String, pipeline_time_spent: U64,
    data: D, i_producer_id: RoutingId, i_producer: Producer, msg_uid: MsgId,
    frac_ids: FractionalMessageId, i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    Fail()

  fun barrier_in_progress(): Bool =>
    false

  fun ref receive_new_barrier(step_id: RoutingId, producer: Producer,
    barrier_token: BarrierToken)
  =>
    Fail()

  fun ref receive_barrier(step_id: RoutingId, producer: Producer,
    barrier_token: BarrierToken)
  =>
    Fail()

  fun ref flush(target_id_router: TargetIdRouter)

class EmptyStepMessageProcessor is StepMessageProcessor
  fun ref run[D: Any val](metric_name: String, pipeline_time_spent: U64,
    data: D, i_producer_id: RoutingId, i_producer: Producer, msg_uid: MsgId,
    frac_ids: FractionalMessageId, i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    Fail()

  fun ref flush(target_id_router: TargetIdRouter) =>
    Fail()

class NormalStepMessageProcessor is StepMessageProcessor
  let step: Step ref

  new create(s: Step ref) =>
    step = s

  fun ref run[D: Any val](metric_name: String, pipeline_time_spent: U64,
    data: D, i_producer_id: RoutingId, i_producer: Producer, msg_uid: MsgId,
    frac_ids: FractionalMessageId, i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    step.process_message[D](metric_name, pipeline_time_spent, data,
      i_producer_id, i_producer, msg_uid, frac_ids, i_seq_id, i_route_id,
      latest_ts, metrics_id, worker_ingress_ts)

  fun ref flush(target_id_router: TargetIdRouter) =>
    ifdef debug then
      @printf[I32]("Flushing NormalStepMessageProcessor does nothing.\n"
        .cstring())
    end
    None

class NoProcessingStepMessageProcessor is StepMessageProcessor
  let step: Step ref

  new create(s: Step ref) =>
    step = s

  fun ref flush(target_id_router: TargetIdRouter) =>
    ifdef debug then
      @printf[I32]("Flushing NoProcessingStepMessageProcessor does nothing.\n"
        .cstring())
    end
    None

class BarrierStepMessageProcessor is StepMessageProcessor
  let step: Step ref
  let _barrier_forwarder: BarrierStepForwarder
  var messages: Array[QueuedMessage] = messages.create()

  new create(s: Step ref, barrier_forwarder: BarrierStepForwarder) =>
    step = s
    _barrier_forwarder = barrier_forwarder

  fun ref run[D: Any val](metric_name: String, pipeline_time_spent: U64,
    data: D, i_producer_id: RoutingId, i_producer: Producer, msg_uid: MsgId,
    frac_ids: FractionalMessageId, i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    if _barrier_forwarder.input_blocking(i_producer_id) then
      let msg = TypedQueuedMessage[D](metric_name, pipeline_time_spent,
        data, i_producer_id, i_producer, msg_uid, frac_ids, i_seq_id,
        i_route_id, latest_ts, metrics_id, worker_ingress_ts)
      messages.push(msg)
    else
      step.process_message[D](metric_name, pipeline_time_spent, data,
        i_producer_id, i_producer, msg_uid, frac_ids, i_seq_id, i_route_id,
        latest_ts, metrics_id, worker_ingress_ts)
    end

  fun barrier_in_progress(): Bool =>
    true

  fun ref receive_new_barrier(step_id: RoutingId, producer: Producer,
    barrier_token: BarrierToken)
  =>
    _barrier_forwarder.receive_new_barrier(step_id, producer, barrier_token)

  fun ref receive_barrier(step_id: RoutingId, producer: Producer,
    barrier_token: BarrierToken)
  =>
    _barrier_forwarder.receive_barrier(step_id, producer, barrier_token)

  fun ref flush(target_id_router: TargetIdRouter) =>
    for msg in messages.values() do
      msg.process_message(step)
    end
    messages = Array[QueuedMessage]
