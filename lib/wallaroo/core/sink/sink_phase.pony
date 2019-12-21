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

use @l[I32](severity: LogSeverity, category: LogCategory, fmt: Pointer[U8] tag, ...)

trait SinkPhase
  fun name(): String

  fun ref process_message[D: Any val](metric_name: String,
    pipeline_time_spent: U64, data: D, key: Key, event_ts: U64,
    watermark_ts: U64, i_producer_id: RoutingId, i_producer: Producer,
    msg_uid: MsgId, frac_ids: FractionalMessageId, i_seq_id: SeqId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    _invalid_call(__loc.method_name()); Fail()

  fun ref receive_barrier(input_id: RoutingId, producer: Producer,
    barrier_token: BarrierToken): Bool
  =>
    _invalid_call(__loc.method_name()); Fail(); false

  fun ref queued(): Array[SinkPhaseQueued] =>
    _invalid_call(__loc.method_name()); Fail()
    Array[SinkPhaseQueued]

  fun ref swap_barrier_to_queued(sink: ConnectorSink ref) =>
    _invalid_call(__loc.method_name()); Fail()

  fun ref maybe_use_normal_processor() =>
    None

  fun ref resume_processing_messages(discard_message_type: Bool) =>
    _invalid_call(__loc.method_name()); Fail()

  fun _invalid_call(method_name: String) =>
    @printf[I32]("Invalid call to %s on sink phase %s\n".cstring(),
      method_name.cstring(), name().cstring())

class InitialSinkPhase is SinkPhase
  fun name(): String => __loc.type_name()

class EarlySinkPhase is SinkPhase
  let _sink: Sink ref

  new create(s: Sink ref) =>
    _sink = s
    @printf[I32]("QQQ: new %s\n".cstring(), name().cstring())

  fun name(): String => __loc.type_name()

  fun ref maybe_use_normal_processor() =>
    // We restarted recently, and we haven't yet received one of the
    // lifecycle messages that triggers using the normal processor.
    // But we need the normal processor phase *now*.
    _sink.use_normal_processor()

  fun ref resume_processing_messages(discard_message_type: Bool) =>
    // If we're @ InitialSinkPhase, and we've restarted after a crash,
    // it's possible to hit checkpoint_complete() extremely early in
    // our restart process.  There's nothing to do here.
    None

  fun ref queued(): Array[SinkPhaseQueued] =>
    Array[SinkPhaseQueued]

class NormalSinkPhase is SinkPhase
  let _sink: Sink ref

  new create(s: Sink ref) =>
    _sink = s
    @printf[I32]("QQQ: new %s\n".cstring(), name().cstring())

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

  fun ref receive_barrier(input_id: RoutingId, producer: Producer,
    barrier_token: BarrierToken): Bool
  =>
    _sink.receive_new_barrier(input_id, producer, barrier_token)
    false

  fun ref queued(): Array[SinkPhaseQueued] =>
    Array[SinkPhaseQueued]

  fun ref resume_processing_messages(discard_message_type: Bool) =>
    _sink.resume_processing_messages_queued(discard_message_type)

type SinkPhaseQueued is (QueuedMessage | QueuedBarrier)

class BarrierSinkPhase is SinkPhase
  let _sink_id: RoutingId
  let _sink: Sink ref
  var _barrier_token: BarrierToken
  let _inputs_blocking: Map[RoutingId, Producer] = _inputs_blocking.create()
  let _queued: Array[SinkPhaseQueued] = _queued.create()
  let _completion_notifies_sink: Bool

  new create(sink_id: RoutingId, sink: Sink ref, token: BarrierToken,
    completion_notifies_sink: Bool = true) =>
    _sink_id = sink_id
    _sink = sink
    _barrier_token = token
    _completion_notifies_sink = completion_notifies_sink
    @printf[I32]("QQQ: new %s barrier %s completion_notifies_sink %s\n".cstring(), name().cstring(), _barrier_token.string().cstring(), _completion_notifies_sink.string().cstring())

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
    barrier_token: BarrierToken): Bool
  =>
    if input_blocking(input_id) then
      ifdef debug then
        @printf[I32]("SinkPhase %s: receive_barrier: push %s\n".cstring(), name().cstring(), barrier_token.string().cstring())
      end
      _queued.push(QueuedBarrier(input_id, producer, barrier_token))
      false
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
        false
      end
    end

/****
  fun ref prepare_for_rollback(token: BarrierToken) =>
    if higher_priority(token) then
      _sink.finish_preparing_for_rollback()
    end
****/

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

  fun ref _check_completion(inputs: Map[RoutingId, Producer] box): Bool =>
    @printf[I32]("2PC: _check_completion: inputs %lu inputs_blocking %lu %s\n".cstring(), inputs.size(), _inputs_blocking.size(), _barrier_token.string().cstring())
    if inputs.size() == _inputs_blocking.size() then
      if _completion_notifies_sink then
        _sink.barrier_complete(_barrier_token)
      end
      true
    else
      false
    end

  fun ref swap_barrier_to_queued(sink: ConnectorSink ref) =>
    sink.swap_barrier_to_queued(_queued)

  fun ref resume_processing_messages(discard_message_type: Bool) =>
    _sink.resume_processing_messages_queued(discard_message_type)

class QueuingSinkPhase is SinkPhase
  """
  NOTE: This stage is used only by ConnectorSink and does not follow
        the conventions of callbacks used by generic Sinks.
  """
  let _sink_id: RoutingId
  let _sink: Sink ref
  var _queued: Array[SinkPhaseQueued]
  let _forward_tokens: Bool
  var _forward_token_phase: (None|BarrierSinkPhase) = None

  new create(sink_id: RoutingId, sink: Sink ref,
    q: Array[SinkPhaseQueued], forward_tokens: Bool)
  =>
    _sink_id = sink_id
    _sink = sink
    _queued = q
    _forward_tokens = forward_tokens
    @printf[I32]("QQQ: new %s size %lu forward %s\n".cstring(), name().cstring(), q.size(), forward_tokens.string().cstring())

  fun name(): String => __loc.type_name()

  fun ref process_message[D: Any val](metric_name: String,
    pipeline_time_spent: U64, data: D, key: Key, event_ts: U64,
    watermark_ts: U64, i_producer_id: RoutingId, i_producer: Producer,
    msg_uid: MsgId, frac_ids: FractionalMessageId, i_seq_id: SeqId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    // @printf[I32]("QQQ: QueuingSinkPhase: process_message\n".cstring())
    let msg = TypedQueuedMessage[D](metric_name, pipeline_time_spent,
      data, key, event_ts, watermark_ts, i_producer_id, i_producer, msg_uid,
      frac_ids, i_seq_id, latest_ts, metrics_id, worker_ingress_ts)
    _queued.push(msg)

  fun ref receive_barrier(input_id: RoutingId, producer: Producer,
    barrier_token: BarrierToken): Bool
  =>
    @printf[I32]("QQQ: QueuingSinkPhase: receive_barrier\n".cstring())
    if _forward_tokens then
      match _forward_token_phase
      | None =>
        @l(Log.debug(), Log.conn_sink(), "QueuingSinkPhase: receive_barrier: 1st for %s".cstring(), barrier_token.string().cstring())
        let p = BarrierSinkPhase(_sink_id, _sink, barrier_token
          where completion_notifies_sink = false)
        let ret = p.receive_barrier(input_id, producer, barrier_token)
        _forward_token_phase = p
        ret
      | let phase: BarrierSinkPhase =>
        @l(Log.debug(), Log.conn_sink(), "QueuingSinkPhase: receive_barrier: Nth for %s".cstring(), barrier_token.string().cstring())
        let ret = phase.receive_barrier(input_id, producer, barrier_token)
        if ret then
          @l(Log.debug(), Log.conn_sink(), "QueuingSinkPhase: receive_barrier: complete for %s".cstring(), barrier_token.string().cstring())
          _sink.barrier_complete(barrier_token)
          // We may receive multiple unique tokens while we sit waiting
          // to be discarded.  Reset _forward_token_phase so that we'll
          // recognize the next token.
          _forward_token_phase = None
        end
        ret
      end
    else
      ifdef debug then
        @printf[I32]("SinkPhase %s: receive_barrier: push %s\n".cstring(), name().cstring(), barrier_token.string().cstring())
      end
      _queued.push(QueuedBarrier(input_id, producer, barrier_token))
      false
    end

  fun ref queued(): Array[SinkPhaseQueued] =>
    let qd = Array[SinkPhaseQueued]
    for q in _queued.values() do
      qd.push(q)
    end
    qd

  fun ref resume_processing_messages(discard_message_type: Bool) =>
    _sink.resume_processing_messages_queued(discard_message_type)

  fun ref drop_app_msg_queue() =>
    let qd = Array[SinkPhaseQueued]
    for q in _queued.values() do
      match q
      | let qb: QueuedBarrier =>
        qd.push(qb)
      end
    end
    _queued = qd
