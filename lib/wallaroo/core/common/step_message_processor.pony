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

class QueueingStepMessageProcessor is StepMessageProcessor
  let step: Step ref
  var messages: Array[QueuedStepMessage] = messages.create()

  new create(s: Step ref, messages': Array[QueuedStepMessage] val =
    recover Array[QueuedStepMessage] end)
  =>
    step = s
    for m in messages'.values() do
      messages.push(m)
    end

  fun ref run[D: Any val](metric_name: String, pipeline_time_spent: U64,
    data: D, i_producer_id: RoutingId, i_producer: Producer, msg_uid: MsgId,
    frac_ids: FractionalMessageId, i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    @printf[I32]("!@ QUEUEING MESSAGE\n".cstring())
    //!@
    Fail()

    let msg = TypedQueuedStepMessage[D](metric_name, pipeline_time_spent, data,
      i_producer_id, msg_uid, frac_ids, i_seq_id, i_route_id, latest_ts,
      metrics_id, worker_ingress_ts)
    messages.push(msg)
    step.filter_queued_msg(i_producer, i_route_id, i_seq_id)

  fun ref flush(target_id_router: TargetIdRouter) =>
    for msg in messages.values() do
      msg.run(step, target_id_router)
    end
    messages = Array[QueuedStepMessage]

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

trait val QueuedStepMessage
  fun run(step: Step ref, target_id_router: TargetIdRouter)

class val TypedQueuedStepMessage[D: Any val] is QueuedStepMessage
  let metric_name: String
  let pipeline_time_spent: U64
  let data: D
  let i_producer_id: RoutingId
  let msg_uid: MsgId
  let frac_ids: FractionalMessageId
  let i_seq_id: SeqId
  let i_route_id: RouteId
  let latest_ts: U64
  let metrics_id: U16
  let worker_ingress_ts: U64

  new val create(metric_name': String, pipeline_time_spent': U64,
    data': D, i_producer_id': RoutingId, msg_uid': MsgId,
    frac_ids': FractionalMessageId, i_seq_id': SeqId, i_route_id': RouteId,
    latest_ts': U64, metrics_id': U16, worker_ingress_ts': U64)
  =>
    metric_name = metric_name'
    pipeline_time_spent = pipeline_time_spent'
    data = data'
    i_producer_id = i_producer_id'
    msg_uid = msg_uid'
    frac_ids = frac_ids'
    i_seq_id = i_seq_id'
    i_route_id = i_route_id'
    latest_ts = latest_ts'
    metrics_id = metrics_id'
    worker_ingress_ts = worker_ingress_ts'

  fun run(step: Step ref, target_id_router: TargetIdRouter) =>
    // TODO: When we develop a strategy for migrating watermark information for
    // migrated queued messages, then we should look up the correct producer
    // that we'll use to send acks to for the case when our upstream is no
    // longer on the same worker.
    let i_producer = DummyProducer
    // let i_producer =
    //   try
    //     target_id_router.producer_for(i_producer_id)?
    //   else
    //     DummyProducer
    //   end
    step.process_message[D](metric_name, pipeline_time_spent, data, i_producer_id,
      i_producer, msg_uid, frac_ids, i_seq_id, i_route_id, latest_ts,
      metrics_id, worker_ingress_ts)
