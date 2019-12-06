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

use "wallaroo/core/checkpoint"
use "wallaroo/core/common"
use "wallaroo/core/messages"
use "wallaroo/core/barrier"
use "wallaroo_labs/mort"

trait _DataReceiverPhase
  fun name(): String

  fun has_pending(): Bool =>
    false

  fun ref deliver(d: DeliveryMsg, producer_id: RoutingId,
    pipeline_time_spent: U64, seq_id: SeqId, latest_ts: U64, metrics_id: U16,
    worker_ingress_ts: U64)
  =>
    _invalid_call(__loc.method_name()); Fail()

  fun ref forward_barrier(input_id: RoutingId, output_id: RoutingId,
    token: BarrierToken, seq_id: SeqId)
  =>
    _invalid_call(__loc.method_name()); Fail()

  fun ref data_connect(highest_seq_id: SeqId) =>
    _invalid_call(__loc.method_name()); Fail()

  fun _invalid_call(method_name: String) =>
    @printf[I32]("Invalid call to %s on Data Receiver phase %s\n".cstring(),
      method_name.cstring(), name().cstring())

  fun _print_phase_transition() =>
    ifdef debug then
      @printf[I32]("_DataReceiverPhase transition to %s\n".cstring(),
        name().string().cstring())
    end

class _DataReceiverNotProcessingPhase is _DataReceiverPhase
  fun name(): String => __loc.type_name()

  fun ref data_connect(highest_seq_id: SeqId) =>
    // If we're not processing, then we need to wait for DataReceivers to be
    // initialized.
    @printf[I32](("DataReceiver: data_connect received, but still waiting " +
      "for DataReceivers to initialize.\n").cstring())

class _RecoveringNotAcceptingMessagesOrBarriersDataReceiverPhase is
  _DataReceiverPhase
  let _data_receiver: DataReceiver ref

  new create(dr: DataReceiver ref) =>
    _data_receiver = dr
    _print_phase_transition()

  fun name(): String => __loc.type_name()

  fun has_pending(): Bool =>
    false

  fun ref deliver(d: DeliveryMsg, producer_id: RoutingId,
    pipeline_time_spent: U64, seq_id: SeqId, latest_ts: U64, metrics_id: U16,
    worker_ingress_ts: U64)
  =>
    ifdef debug then
      @printf[I32]("Recovering DataReceiver dropping message\n"
        .cstring())
    end
    _data_receiver._update_last_id_seen(seq_id, true)

  fun ref forward_barrier(input_id: RoutingId, output_id: RoutingId,
    token: BarrierToken, seq_id: SeqId)
  =>
    ifdef debug then
      @printf[I32]("Recovering DataReceiver dropping barrier\n"
        .cstring())
    end
    _data_receiver._update_last_id_seen(seq_id, true)

  fun ref data_connect(highest_seq_id: SeqId) =>
    _data_receiver._update_last_id_seen(highest_seq_id)
    _data_receiver._inform_boundary_to_send_normal_messages()

class _RecoveringOnlyAcceptingRollbackBarriersDataReceiverPhase is
  _DataReceiverPhase
  let _data_receiver: DataReceiver ref
  let _minimum_rollback_id: RollbackId

  new create(dr: DataReceiver ref, min_rollback_id: RollbackId) =>
    _data_receiver = dr
    _minimum_rollback_id = min_rollback_id
    _print_phase_transition()

  fun name(): String => __loc.type_name()

  fun has_pending(): Bool =>
    false

  fun ref deliver(d: DeliveryMsg, producer_id: RoutingId,
    pipeline_time_spent: U64, seq_id: SeqId, latest_ts: U64, metrics_id: U16,
    worker_ingress_ts: U64)
  =>
    // Drop non-barriers
    ifdef debug then
      @printf[I32]("Recovering DataReceiver dropping non-rollback-barrier\n"
        .cstring())
    end
    _data_receiver._update_last_id_seen(seq_id, true)

  fun ref forward_barrier(input_id: RoutingId, output_id: RoutingId,
    token: BarrierToken, seq_id: SeqId)
  =>
    // Drop anything that's not related to rollback
    match token
    | let srt: CheckpointRollbackBarrierToken =>
      if srt.rollback_id >= _minimum_rollback_id then
        _data_receiver.send_barrier(input_id, output_id, token, seq_id)
      else
        @printf[I32]("Recovery DataReceiver ignoring lower rollback id %s\n"
          .cstring(), srt.rollback_id.string().cstring())
      end
    | let srt: CheckpointRollbackResumeBarrierToken =>
      if srt.rollback_id >= _minimum_rollback_id then
        _data_receiver.send_barrier(input_id, output_id, token, seq_id)
      else
        @printf[I32]("Recovery DataReceiver ignoring lower rollback id %s\n"
          .cstring(), srt.rollback_id.string().cstring())
      end
    else
      ifdef debug then
        @printf[I32]("Recovering DataReceiver dropping non-rollback barrier\n"
          .cstring())
      end
      _data_receiver._update_last_id_seen(seq_id, true)
    end

  fun ref data_connect(highest_seq_id: SeqId) =>
    _data_receiver._update_last_id_seen(highest_seq_id)
    _data_receiver._inform_boundary_to_send_normal_messages()

class _NormalDataReceiverPhase is _DataReceiverPhase
  let _data_receiver: DataReceiver ref

  new create(dr: DataReceiver ref) =>
    _data_receiver = dr
    _print_phase_transition()

  fun name(): String => __loc.type_name()

  fun has_pending(): Bool =>
    false

  fun ref deliver(d: DeliveryMsg, producer_id: RoutingId,
    pipeline_time_spent: U64, seq_id: SeqId, latest_ts: U64, metrics_id: U16,
    worker_ingress_ts: U64)
  =>
    _data_receiver.deliver(d, producer_id, pipeline_time_spent, seq_id,
      latest_ts, metrics_id, worker_ingress_ts)

  fun ref forward_barrier(input_id: RoutingId, output_id: RoutingId,
    token: BarrierToken, seq_id: SeqId)
  =>
    _data_receiver.send_barrier(input_id, output_id, token, seq_id)

  fun ref data_connect(highest_seq_id: SeqId) =>
    _data_receiver._inform_boundary_to_send_normal_messages()
