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
use "wallaroo_labs/logging"
use "wallaroo_labs/mort"
use "wallaroo/core/common"
use "wallaroo/core/invariant"
use "wallaroo/core/topology"
use "wallaroo/core/barrier"
use "wallaroo/core/checkpoint"
use "wallaroo/core/sink/connector_sink"

use @ll[I32](sev_cat: U16, fmt: Pointer[U8] tag, ...)

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

  fun ref queued(): Array[SinkPhaseQueued] =>
    _invalid_call(); Fail()
    Array[SinkPhaseQueued]

  fun ref swap_barrier_to_queued(sink: ConnectorSink ref,
    dont_queue_all_barriers: Bool = false) =>
    _invalid_call(); Fail()

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

  fun ref queued(): Array[SinkPhaseQueued] =>
    Array[SinkPhaseQueued]

type SinkPhaseQueued is (QueuedMessage | QueuedBarrier)

class BarrierSinkPhase is SinkPhase
  let _sink_id: RoutingId
  let _sink: Sink ref
  var _barrier_token: BarrierToken
  let _inputs_blocking: Map[RoutingId, Producer] = _inputs_blocking.create()
  let _queued: Array[SinkPhaseQueued] = _queued.create()
  let _debug: LogSevCat = Log.make_sev_cat(Log.debug(), Log.conn_sink())

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
      @ll(_debug, "BarrierSinkPhase.receive_barrier: queueing %s".cstring(), barrier_token.string().cstring())
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

  fun ref queued(): Array[SinkPhaseQueued] =>
    let qd = Array[SinkPhaseQueued]
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

  fun ref swap_barrier_to_queued(sink: ConnectorSink ref,
    dont_queue_all_barriers: Bool = false) =>
    sink.swap_barrier_to_queued(_queued, dont_queue_all_barriers)

class QueuingSinkPhase is SinkPhase
  let _sink_id: RoutingId
  let _sink: Sink ref
  let _queued: Array[SinkPhaseQueued]
  let _dont_queue_all_barriers: Bool
  let _debug: LogSevCat = Log.make_sev_cat(Log.debug(), Log.conn_sink())

  new create(sink_id: RoutingId, sink: Sink ref,
    q: Array[SinkPhaseQueued] = Array[SinkPhaseQueued].create(),
    dont_queue_all_barriers: Bool = false)
  =>
    _sink_id = sink_id
    _sink = sink
    _queued = q
    _dont_queue_all_barriers = dont_queue_all_barriers

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
    if _dont_queue_all_barriers then
      match barrier_token
      | let x: (AutoscaleResumeBarrierToken |
                CheckpointRollbackBarrierToken |
                CheckpointRollbackResumeBarrierToken) =>
        // TODO XX: What barrels of worms are we opening if we take these
        // barriers out of their message flow order??
        // CheckpointRollback*: state will be discarded, so we're ok?
        // AutoscaleResume*: not sure??
        @ll(_debug, "QueuingSinkPhase.receive_barrier: pass through %s".cstring(), barrier_token.string().cstring())
        _sink.receive_new_barrier(input_id, producer, barrier_token)
      | let x: AutoscaleBarrierToken =>
        // This is the 2nd autoscale barrier while processing an earlier one.
        Fail()
      else
        @ll(_debug, "QueuingSinkPhase.receive_barrier: A queueing %s".cstring(), barrier_token.string().cstring())
        _queued.push(QueuedBarrier(input_id, producer, barrier_token))
      end
    else
      @ll(_debug, "QueuingSinkPhase.receive_barrier: B queueing %s".cstring(), barrier_token.string().cstring())
      _queued.push(QueuedBarrier(input_id, producer, barrier_token))
    end

  fun ref prepare_for_rollback(token: BarrierToken) =>
    _sink.finish_preparing_for_rollback()

  fun ref queued(): Array[SinkPhaseQueued] =>
    let qd = Array[SinkPhaseQueued]
    for q in _queued.values() do
      qd.push(q)
    end
    qd
