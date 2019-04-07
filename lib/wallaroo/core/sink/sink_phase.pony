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
use "wallaroo_labs/mort"
use "wallaroo/core/common"
use "wallaroo/core/invariant"
use "wallaroo/core/topology"
use "wallaroo/core/barrier"
use "wallaroo/core/checkpoint"

trait SinkPhase
  fun name(): String

  fun ref process_message[D: Any val](metric_name: String,
    pipeline_time_spent: U64, data: D, key: Key, event_ts: U64,
    watermark_ts: U64, i_producer_id: RoutingId, i_producer: Producer,
    msg_uid: MsgId, frac_ids: FractionalMessageId, i_seq_id: SeqId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    _invalid_call(); Fail()

  fun ref receive_barrier(input_id: RoutingId, producer: Producer,
    barrier_token: BarrierToken)
  =>
    _invalid_call(); Fail()

  fun ref prepare_for_rollback(token: BarrierToken) =>
    _invalid_call(); Fail()

  fun ref queued(): Array[_Queued] =>
    _invalid_call(); Fail()
    Array[_Queued]

  fun _invalid_call() =>
    @printf[I32]("Invalid call on sink phase %s\n".cstring(), name().cstring())

class InitialSinkPhase is SinkPhase
  fun name(): String => __loc.type_name()

class NormalSinkPhase is SinkPhase
  let _sink: Sink ref

  new create(s: Sink ref) =>
    _sink = s

  fun name(): String => __loc.type_name()

  fun ref process_message[D: Any val](metric_name: String,
    pipeline_time_spent: U64, data: D, key: Key, event_ts: U64,
    watermark_ts: U64, i_producer_id: RoutingId, i_producer: Producer,
    msg_uid: MsgId, frac_ids: FractionalMessageId, i_seq_id: SeqId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    _sink.process_message[D](metric_name, pipeline_time_spent, data, key,
      event_ts, watermark_ts, i_producer_id, i_producer, msg_uid, frac_ids,
      i_seq_id, latest_ts, metrics_id, worker_ingress_ts)

  fun ref prepare_for_rollback(token: BarrierToken) =>
    None

  fun ref receive_barrier(input_id: RoutingId, producer: Producer,
    barrier_token: BarrierToken)
  =>
    _sink.receive_new_barrier(input_id, producer, barrier_token)

  fun ref queued(): Array[_Queued] =>
    Array[_Queued]

type _Queued is (QueuedMessage | QueuedBarrier)

class BarrierSinkPhase is SinkPhase
  let _sink_id: RoutingId
  let _sink: Sink ref
  var _barrier_token: BarrierToken
  let _inputs_blocking: Map[RoutingId, Producer] = _inputs_blocking.create()
  let _queued: Array[_Queued] = _queued.create()

  new create(sink_id: RoutingId, sink: Sink ref, token: BarrierToken) =>
    _sink_id = sink_id
    _sink = sink
    _barrier_token = token

  fun name(): String => __loc.type_name()

  fun ref process_message[D: Any val](metric_name: String,
    pipeline_time_spent: U64, data: D, key: Key, event_ts: U64,
    watermark_ts: U64, i_producer_id: RoutingId, i_producer: Producer,
    msg_uid: MsgId, frac_ids: FractionalMessageId, i_seq_id: SeqId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    if input_blocking(i_producer_id) then
      let msg = TypedQueuedMessage[D](metric_name, pipeline_time_spent,
        data, key, event_ts, watermark_ts, i_producer_id, i_producer, msg_uid,
        frac_ids, i_seq_id, latest_ts, metrics_id, worker_ingress_ts)
      _queued.push(msg)
    else
      _sink.process_message[D](metric_name, pipeline_time_spent, data, key,
        event_ts, watermark_ts, i_producer_id, i_producer, msg_uid, frac_ids,
        i_seq_id, latest_ts, metrics_id, worker_ingress_ts)
    end

  fun ref receive_barrier(input_id: RoutingId, producer: Producer,
    barrier_token: BarrierToken)
  =>
    if input_blocking(input_id) then
      _queued.push(QueuedBarrier(input_id, producer, barrier_token))
    else
      ifdef debug then
        if barrier_token != _barrier_token then
          @printf[I32]("Sink: Expected %s, got %s\n".cstring(),
            _barrier_token.string().cstring(),
            barrier_token.string().cstring())
          Fail()
        end
      end
      let inputs = _sink.inputs()
      if inputs.contains(input_id) then
        _inputs_blocking(input_id) = producer
        _check_completion(inputs)
      else
        @printf[I32]("Failed to find input_id %s in inputs at Sink %s\n"
          .cstring(), input_id.string().cstring(), _sink_id.string().cstring())
        Fail()
      end
    end

  fun ref prepare_for_rollback(token: BarrierToken) =>
    if higher_priority(token) then
      _sink.finish_preparing_for_rollback()
    end

  fun ref queued(): Array[_Queued] =>
    let qd = Array[_Queued]
    for q in _queued.values() do
      qd.push(q)
    end
    qd

  fun ref higher_priority(token: BarrierToken): Bool =>
    token > _barrier_token

  fun input_blocking(id: RoutingId): Bool =>
    _inputs_blocking.contains(id)

  fun ref remove_input(input_id: RoutingId) =>
    """
    Called if an input leaves the system during barrier processing. This should
    only be possible with Sources that are closed (e.g. when a TCPSource
    connection is dropped).
    """
    if _inputs_blocking.contains(input_id) then
      try
        _inputs_blocking.remove(input_id)?
      else
        Unreachable()
      end
    end
    _check_completion(_sink.inputs())

  fun ref _check_completion(inputs: Map[RoutingId, Producer] box) =>
    if inputs.size() == _inputs_blocking.size() then
      _sink.barrier_complete(_barrier_token)
    end

class QueuingSinkPhase is SinkPhase
  let _sink_id: RoutingId
  let _sink: Sink ref
  let _queued: Array[_Queued] = _queued.create()

  new create(sink_id: RoutingId, sink: Sink ref) =>
    _sink_id = sink_id
    _sink = sink

  fun name(): String => __loc.type_name()

  fun ref process_message[D: Any val](metric_name: String,
    pipeline_time_spent: U64, data: D, key: Key, event_ts: U64,
    watermark_ts: U64, i_producer_id: RoutingId, i_producer: Producer,
    msg_uid: MsgId, frac_ids: FractionalMessageId, i_seq_id: SeqId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    let msg = TypedQueuedMessage[D](metric_name, pipeline_time_spent,
      data, key, event_ts, watermark_ts, i_producer_id, i_producer, msg_uid,
      frac_ids, i_seq_id, latest_ts, metrics_id, worker_ingress_ts)
    _queued.push(msg)

  fun ref receive_barrier(input_id: RoutingId, producer: Producer,
    barrier_token: BarrierToken)
  =>
    _queued.push(QueuedBarrier(input_id, producer, barrier_token))

  fun ref prepare_for_rollback(token: BarrierToken) =>
    _sink.finish_preparing_for_rollback()

  fun ref queued(): Array[_Queued] =>
    let qd = Array[_Queued]
    for q in _queued.values() do
      qd.push(q)
    end
    qd
