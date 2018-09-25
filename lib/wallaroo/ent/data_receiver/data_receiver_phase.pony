/*

Copyright 2018 The Wallaroo Authors.

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

use "wallaroo/core/common"
use "wallaroo/core/messages"
use "wallaroo/ent/barrier"
use "wallaroo_labs/mort"

trait _DataReceiverPhase
  fun name(): String

  fun has_pending(): Bool =>
    false

  fun ref flush(): Array[_Queued]

  fun ref deliver(d: DeliveryMsg, pipeline_time_spent: U64, seq_id: SeqId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    _invalid_call()
    Fail()

  fun ref replay_deliver(r: ReplayableDeliveryMsg, pipeline_time_spent: U64,
    seq_id: SeqId, latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    _invalid_call()
    Fail()

  fun ref forward_barrier(input_id: RoutingId, output_id: RoutingId,
    token: BarrierToken, seq_id: SeqId)
  =>
    _invalid_call()
    Fail()

  fun ref data_connect(highest_seq_id: SeqId) =>
    _invalid_call()
    Fail()

  fun _invalid_call() =>
    @printf[I32]("Invalid call on Data Receiver phase %s\n".cstring(),
      name().cstring())

class _DataReceiverNotProcessingPhase is _DataReceiverPhase
  fun name(): String => "_DataReceiverNotProcessingPhase"

  fun ref data_connect(highest_seq_id: SeqId) =>
    // If we're not processing, then we need to wait for DataReceivers to be
    // initialized.
    @printf[I32](("DataReceiver: data_connect received, but still waiting " +
      "for DataReceivers to initialize.\n").cstring())

  fun ref flush(): Array[_Queued] =>
    Array[_Queued]

class _RecoveringDataReceiverPhase is _DataReceiverPhase
  let _data_receiver: DataReceiver ref

  new create(dr: DataReceiver ref) =>
    _data_receiver = dr

  fun name(): String =>
    "_RecoveringDataReceiverPhase"

  fun has_pending(): Bool =>
    false

  fun ref deliver(d: DeliveryMsg, pipeline_time_spent: U64, seq_id: SeqId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    // Drop non-barriers
    ifdef debug then
      @printf[I32]("Recovering DataReceiver dropping non-rollback-barrier\n"
        .cstring())
    end
    None

  fun ref replay_deliver(r: ReplayableDeliveryMsg, pipeline_time_spent: U64,
    seq_id: SeqId, latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    // Drop non-barriers
    ifdef debug then
      @printf[I32]("Recovering DataReceiver dropping non-rollback-barrier\n"
        .cstring())
    end
    None

  fun ref forward_barrier(input_id: RoutingId, output_id: RoutingId,
    token: BarrierToken, seq_id: SeqId)
  =>
    // Drop anything that's not related to rollback
    match token
    | let srt: CheckpointRollbackBarrierToken =>
      _data_receiver.send_barrier(input_id, output_id, token, seq_id)
    | let srt: CheckpointRollbackResumeBarrierToken =>
      _data_receiver.send_barrier(input_id, output_id, token, seq_id)
    else
      ifdef debug then
        @printf[I32]("Recovering DataReceiver dropping non-rollback barrier\n"
          .cstring())
      end
    end

  fun ref data_connect(highest_seq_id: SeqId) =>
    // If we're recovering, then we ignore existing queues on upstream
    // boundaries, which will be cleared as part of rollback.
    _data_receiver._update_last_id_seen(highest_seq_id)
    _data_receiver._inform_boundary_to_send_normal_messages()

  fun ref flush(): Array[_Queued] =>
    Array[_Queued]

class _NormalDataReceiverPhase is _DataReceiverPhase
  let _data_receiver: DataReceiver ref

  new create(dr: DataReceiver ref) =>
    _data_receiver = dr

  fun name(): String =>
    "_NormalDataReceiverPhase"

  fun has_pending(): Bool =>
    false

  fun ref deliver(d: DeliveryMsg, pipeline_time_spent: U64, seq_id: SeqId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    _data_receiver.deliver(d, pipeline_time_spent, seq_id, latest_ts,
      metrics_id, worker_ingress_ts)

  fun ref replay_deliver(r: ReplayableDeliveryMsg, pipeline_time_spent: U64,
    seq_id: SeqId, latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    _data_receiver.replay_deliver(r, pipeline_time_spent, seq_id, latest_ts,
      metrics_id, worker_ingress_ts)

  fun ref forward_barrier(input_id: RoutingId, output_id: RoutingId,
    token: BarrierToken, seq_id: SeqId)
  =>
    _data_receiver.send_barrier(input_id, output_id, token, seq_id)

  fun ref data_connect(highest_seq_id: SeqId) =>
    _data_receiver._inform_boundary_to_send_normal_messages()

  fun ref flush(): Array[_Queued] =>
    Array[_Queued]

class _QueuingDataReceiverPhase is _DataReceiverPhase
  let _data_receiver: DataReceiver ref
  var _queued: Array[_Queued] = _queued.create()

  new create(dr: DataReceiver ref) =>
    _data_receiver = dr

  fun name(): String =>
    "_QueuingDataReceiverPhase"

  fun has_pending(): Bool =>
    _queued.size() == 0

  fun ref deliver(d: DeliveryMsg, pipeline_time_spent: U64, seq_id: SeqId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    let qdm = _QueuedDeliveryMessage(d, pipeline_time_spent, seq_id,
      latest_ts, metrics_id, worker_ingress_ts)
    _queued.push(qdm)

  fun ref replay_deliver(r: ReplayableDeliveryMsg, pipeline_time_spent: U64,
    seq_id: SeqId, latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    let qrdm = _QueuedReplayableDeliveryMessage(r, pipeline_time_spent, seq_id,
      latest_ts, metrics_id, worker_ingress_ts)
    _queued.push(qrdm)

  fun ref forward_barrier(input_id: RoutingId, output_id: RoutingId,
    token: BarrierToken, seq_id: SeqId)
  =>
    ifdef "checkpoint_trace" then
      @printf[I32]("DataReceiver: Queuing barrier to %s\n".cstring(),
        output_id.string().cstring())
    end
    _queued.push((input_id, output_id, token, seq_id))

  fun ref data_connect(highest_seq_id: SeqId) =>
    _data_receiver._inform_boundary_to_send_normal_messages()

  fun ref flush(): Array[_Queued] =>
    // Return and clear
    _queued = Array[_Queued]

type _Queued is (_QueuedBarrier | _QueuedDeliveryMessage |
  _QueuedReplayableDeliveryMessage)

type _QueuedBarrier is (RoutingId, RoutingId, BarrierToken, SeqId)

class _QueuedDeliveryMessage
  let msg: DeliveryMsg
  let pipeline_time_spent: U64
  let seq_id: SeqId
  let latest_ts: U64
  let metrics_id: U16
  let worker_ingress_ts: U64

  new create(msg': DeliveryMsg, pipeline_time_spent': U64, seq_id': SeqId,
    latest_ts': U64, metrics_id': U16, worker_ingress_ts': U64)
  =>
    msg = msg'
    pipeline_time_spent = pipeline_time_spent'
    seq_id = seq_id'
    latest_ts = latest_ts'
    metrics_id = metrics_id'
    worker_ingress_ts = worker_ingress_ts'

  fun process_message(dr: DataReceiver ref) =>
    dr.process_message(msg, pipeline_time_spent, seq_id, latest_ts,
      metrics_id, worker_ingress_ts)

class _QueuedReplayableDeliveryMessage
  let msg: ReplayableDeliveryMsg
  let pipeline_time_spent: U64
  let seq_id: SeqId
  let latest_ts: U64
  let metrics_id: U16
  let worker_ingress_ts: U64

  new create(msg': ReplayableDeliveryMsg, pipeline_time_spent': U64,
    seq_id': SeqId, latest_ts': U64, metrics_id': U16, worker_ingress_ts': U64)
  =>
    msg = msg'
    pipeline_time_spent = pipeline_time_spent'
    seq_id = seq_id'
    latest_ts = latest_ts'
    metrics_id = metrics_id'
    worker_ingress_ts = worker_ingress_ts'

  fun replay_process_message(dr: DataReceiver ref) =>
    dr.replay_process_message(msg, pipeline_time_spent, seq_id, latest_ts,
      metrics_id, worker_ingress_ts)
