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

use "collections"
use "promises"
use "wallaroo/core/common"
use "wallaroo/core/initialization"
use "wallaroo/core/invariant"
use "wallaroo/core/messages"
use "wallaroo/core/network"
use "wallaroo/core/source"
use "wallaroo/core/source/barrier_source"
use "wallaroo/core/sink"
use "wallaroo_labs/mort"
use "wallaroo_labs/string_set"


actor BarrierInitiator is Initializable
  """
  The BarrierInitiator is used to trigger a barrier protocol starting from
  all Sources in the system and moving down to the Sinks, which will each ack
  the BarrierInitiator actor local to its worker.

  Once a Step or Sink receives a barrier, it will block on the input it
  received it on. Once it has received barriers over all inputs, it will
  forward the barrier downstream.

  The BarrierInitiator can manage one barrier protocol at a time. The details
  of the protocol depend on the BarrierToken and are opaque to the
  BarrierInitiator. That means it can be used as part of different protocols
  if they require general barrier processing behavior (for example,
  the checkpointing protocol and the protocol checking that all in flight
  messages have been processed).
  """
  let _auth: AmbientAuth
  let _worker_name: String
  var _phase: _BarrierInitiatorPhase = _InitialBarrierInitiatorPhase

  var _pending: Array[_Pending] = _pending.create()
  let _active_barriers: ActiveBarriers = ActiveBarriers

  let _connections: Connections
  var _barrier_sources: SetIs[BarrierSource] = _barrier_sources.create()
  let _sources: Map[RoutingId, Source] = _sources.create()
  let _sinks: SetIs[Sink] = _sinks.create()
  let _workers: StringSet = _workers.create()

  // When we send barriers to a different primary worker, we use this map
  // to call the correct promise when those barriers are complete.
  let _pending_promises: Map[BarrierToken, BarrierResultPromise] =
    _pending_promises.create()

  // TODO: Currently, we can only inject barriers from one primary worker
  // in the cluster. This is because otherwise they might be injected in
  // parallel at different workers and the barrier protocol relies on the
  // fact that each barrier is injected at all sources before the next
  // barrier.
  var _primary_worker: String

  var _disposed: Bool = false

  new create(auth: AmbientAuth, worker_name: String, connections: Connections,
    primary_worker: String, is_recovering: Bool = false)
  =>
    _auth = auth
    _worker_name = worker_name
    _connections = connections
    _primary_worker = primary_worker
    if is_recovering then
      _phase = _RecoveringBarrierInitiatorPhase(this)
    else
      _phase = _NormalBarrierInitiatorPhase(this)
    end

  be application_begin_reporting(initializer: LocalTopologyInitializer) =>
    initializer.report_created(this)

  be application_created(initializer: LocalTopologyInitializer) =>
    initializer.report_initialized(this)

  be application_initialized(initializer: LocalTopologyInitializer) =>
    initializer.report_ready_to_work(this)

  be application_ready_to_work(initializer: LocalTopologyInitializer) =>
    None

  be register_sink(sink: Sink) =>
    _sinks.set(sink)

  be unregister_sink(sink: Sink) =>
    _sinks.unset(sink)

  be register_barrier_source(b_source: BarrierSource) =>
    _barrier_sources.set(b_source)

  be register_source(source: Source, source_id: RoutingId) =>
    _sources(source_id) = source

  be unregister_source(source: Source, source_id: RoutingId) =>
    try
      _sources.remove(source_id)?
    else
      Fail()
    end

  be add_worker(w: String) =>
    if not _disposed then
      ifdef "checkpoint_trace" then
        @printf[I32]("BarrierInitiator: add_worker %s\n".cstring(),
          w.cstring())
      end
      if _active_barriers.barrier_in_progress() then
        @printf[I32]("add_worker called while barrier is in progress\n"
          .cstring())
        Fail()
      end
      _workers.set(w)
    end

  be remove_worker(w: String) =>
    if not _disposed then
      ifdef "checkpoint_trace" then
        @printf[I32]("BarrierInitiator: remove_worker %s\n".cstring(),
          w.cstring())
      end

      if _active_barriers.barrier_in_progress() then
        @printf[I32]("remove_worker called while barrier is in progress\n"
          .cstring())
        Fail()
      end
      _workers.unset(w)
    end

  be initialize_source(s: Source) =>
    """
    Before a source can register with its downstreams, we need to make sure
    there is no in flight barrier since such registration would change the
    graph and potentially disrupt the barrier protocol.
    """
    if _active_barriers.barrier_in_progress() then
      _pending.push(_PendingSourceInit(s))
    else
      let promise = Promise[Source]
      promise.next[None](recover this~source_registration_complete() end)
      s.register_downstreams(promise)
    end

  be source_registration_complete(s: Source) =>
    _phase.source_registration_complete(s)

  fun ref source_pending_complete(s: Source) =>
    if not _disposed then
      _phase = _NormalBarrierInitiatorPhase(this)
      next_token()
    end

  be inject_barrier(barrier_token: BarrierToken,
    result_promise: BarrierResultPromise)
  =>
    if not _disposed then
      _inject_barrier(barrier_token, result_promise)
    end

  fun ref _inject_barrier(barrier_token: BarrierToken,
    result_promise: BarrierResultPromise)
  =>
    """
    Called to begin the barrier protocol for a new barrier token.
    """
    if not _disposed then
      ifdef "checkpoint_trace" then
        @printf[I32]("Injecting barrier %s\n".cstring(),
          barrier_token.string().cstring())
      end
      if _primary_worker == _worker_name then
        // We handle rollback barrier token as a special case. That's because
        // in the presence of a rollback token, we need to cancel all other
        // tokens in flight since we are rolling back to an earlier state of
        // the system. On a successful match here, we transition to the
        // rollback phase.
        match barrier_token
        | let srt: CheckpointRollbackBarrierToken =>
          // Check if this rollback token is higher priority than a current
          // rollback token, in case one is being processed. If it's not, drop
          // it.
          if _phase.higher_priority(srt) then
            _clear_barriers()
            _phase = _RollbackBarrierInitiatorPhase(this, srt)
          end
        | let srrt: CheckpointRollbackResumeBarrierToken =>
          // Check if this rollback token is higher priority than a current
          // rollback token, in case one is being processed. If it's not, drop
          // it.
          if _phase.higher_priority(srrt) then
            _clear_barriers()
            _phase = _NormalBarrierInitiatorPhase(this)
          end
        end

        _phase.initiate_barrier(barrier_token, result_promise)
      else
        _pending_promises(barrier_token) = result_promise
        try
          let msg = ChannelMsgEncoder.forward_inject_barrier(barrier_token,
            _worker_name, _auth)?
          _connections.send_control(_primary_worker, msg)
        else
          Fail()
        end
      end
    end

  be inject_blocking_barrier(barrier_token: BarrierToken,
    result_promise: BarrierResultPromise, wait_for_token: BarrierToken)
  =>
    """
    Called when no barriers should be processed after this one
    is injected. Normal barrier processing is resumed either when
    this one is complete or, if `wait_for_token` is specified, once
    the specified token is received.
    """
    if not _disposed then
      ifdef "checkpoint_trace" then
        @printf[I32]("Injecting blocking barrier %s\n".cstring(),
          barrier_token.string().cstring())
      end
      if _primary_worker == _worker_name then
        // We handle rollback barrier token as a special case. That's because
        // in the presence of a rollback token, we need to cancel all other
        // tokens in flight since we are rolling back to an earlier state of
        // the system. On a successful match here, we transition to the
        // rollback phase.
        match barrier_token
        | let srt: CheckpointRollbackBarrierToken =>
          // Check if this rollback token is higher priority than a current
          // rollback token, in case one is being processed. If it's not, drop
          // it.
          if _phase.higher_priority(srt) then
            _clear_barriers()
          end
        end

        //!TODO!: We need to make sure this gets queued if we're in rollback
        //mode
        _phase = _BlockingBarrierInitiatorPhase(this, barrier_token,
          wait_for_token)
        _phase.initiate_barrier(barrier_token, result_promise)
      else
        _pending_promises(barrier_token) = result_promise
        try
          let msg = ChannelMsgEncoder.forward_inject_blocking_barrier(
            barrier_token, wait_for_token, _worker_name, _auth)?
          _connections.send_control(_primary_worker, msg)
        else
          Fail()
        end
      end
    end

  be forwarded_inject_barrier_fully_acked(barrier_token: BarrierToken) =>
    try
      let promise = _pending_promises.remove(barrier_token)?._2
      promise(barrier_token)
    else
      Fail()
    end

  fun ref queue_barrier(barrier_token: BarrierToken,
    result_promise: BarrierResultPromise)
  =>
    _pending.push(_PendingBarrier(barrier_token, result_promise))

  fun ref initiate_barrier(barrier_token: BarrierToken,
    result_promise: BarrierResultPromise)
  =>
    if not _disposed then
      ifdef debug then
        @printf[I32]("Initiating barrier protocol for %s.\n".cstring(),
          barrier_token.string().cstring())
      end

      let barrier_handler = PendingBarrierHandler(_worker_name, this,
        barrier_token, _sinks, _workers, result_promise
        where primary_worker = _worker_name)
      try
        _active_barriers.add_barrier(barrier_token, barrier_handler)?
      else
        Fail()
      end

      if _workers.size() > 1 then
        try
          let msg = ChannelMsgEncoder.remote_initiate_barrier(_worker_name,
            barrier_token, _auth)?
          for w in _workers.values() do
            if w != _worker_name then _connections.send_control(w, msg) end
          end
        else
          Fail()
        end
      end
      _active_barriers.worker_ack_barrier_start(_worker_name, barrier_token)
    end

  fun ref _clear_barriers() =>
    _clear_active_barriers()
    _clear_pending_barriers()

  fun ref _clear_active_barriers() =>
    _active_barriers.clear()

  fun ref _clear_pending_barriers() =>
    """
    Called when we're rolling back and we need to clear all pending barriers
    in the system. We need to keep requests from our sources for
    initialization.
    """
    let only_pending_sources = Array[_Pending]
    for p in _pending.values() do
      match p
      | let psi: _PendingSourceInit =>
        only_pending_sources.push(psi)
      end
    end
    _pending = only_pending_sources

  be remote_initiate_barrier(primary_worker: String,
    barrier_token: BarrierToken)
  =>
    if not _disposed then
      // If we're in recovery mode, we might need to collect some rollback
      // acks before we receive a remote_initiate_barrier.
      var pending_acks: (PendingRollbackBarrierAcks | None) = None

      // We handle rollback barrier token as a special case. That's because
      // in the presence of a rollback token, we need to cancel all other
      // tokens in flight since we are rolling back to an earlier state of
      // the system. On a successful match here, we transition to the
      // rollback phase.
      match barrier_token
      | let srt: CheckpointRollbackBarrierToken =>
        // Check if this rollback token is higher priority than a current
        // rollback token, in case one is being processed. If it's not, drop
        // it.
        if _phase.higher_priority(srt) then
          _clear_barriers()
          pending_acks = _phase.pending_rollback_barrier_acks()
          ifdef "checkpoint_trace" then
            @printf[I32]("Switching to _RollbackBarrierInitiatorPhase for %s\n"
              .cstring(), srt.string().cstring())
          end
          _phase = _RollbackBarrierInitiatorPhase(this, srt)
        end
      | let srrt: CheckpointRollbackResumeBarrierToken =>
        // Check if this rollback token is higher priority than a current
        // rollback token, in case one is being processed. If it's not, drop
        // it.
        if _phase.higher_priority(srrt) then
          _clear_barriers()
          _phase = _NormalBarrierInitiatorPhase(this)
        end
      end

      let next_handler = PendingBarrierHandler(_worker_name, this,
        barrier_token, _sinks, _workers, EmptyBarrierResultPromise(),
        primary_worker)
      try
        _active_barriers.add_barrier(barrier_token, next_handler)?
      else
        Fail()
      end

      match pending_acks
      | let pa: PendingRollbackBarrierAcks =>
        ifdef "checkpoint_trace" then
          @printf[I32]("Flushing PendingRollbackBarrierAcks\n".cstring())
        end
        pa.flush(barrier_token, _active_barriers)
      end

      try
        let msg = ChannelMsgEncoder.worker_ack_barrier_start(_worker_name,
          barrier_token, _auth)?
        _connections.send_control(primary_worker, msg)
      else
        Fail()
      end
    end

  be worker_ack_barrier_start(w: String, token: BarrierToken) =>
    _phase.worker_ack_barrier_start(w, token, _active_barriers)

  fun confirm_start_barrier(barrier_token: BarrierToken) =>
    try
      // Send our start ack to all secondary workers for this barrier.
      let msg = ChannelMsgEncoder.worker_ack_barrier_start(_worker_name,
        barrier_token, _auth)?
      for w in _workers.values() do
        if w != _worker_name then _connections.send_control(w, msg) end
      end
    else
      Fail()
    end

  fun ref start_barrier(barrier_token: BarrierToken,
    result_promise: BarrierResultPromise,
    acked_sinks: SetIs[Sink] val,
    acked_ws: SetIs[String] val, primary_worker: String)
  =>
    if not _disposed then
      let next_handler =
        if primary_worker == _worker_name then
          InProgressPrimaryBarrierHandler(_worker_name, this, barrier_token,
            acked_sinks, acked_ws, _sinks, _workers, result_promise)
        else
          ifdef "checkpoint_trace" then
            @printf[I32]("Phase transition to SecondaryBarrierHandler for token %s with primary worker being %s\n".cstring(), barrier_token.string().cstring(), primary_worker.cstring())
          end
          InProgressSecondaryBarrierHandler(this, barrier_token, acked_sinks,
            _sinks, primary_worker)
        end
      try
        _active_barriers.update_handler(barrier_token, next_handler)?
      else
        Fail()
      end

      ifdef "checkpoint_trace" then
        @printf[I32]("Calling initiate_barrier at %s BarrierSources\n"
          .cstring(), _barrier_sources.size().string().cstring())
      end
      for b_source in _barrier_sources.values() do
        b_source.initiate_barrier(barrier_token)
      end

      ifdef "checkpoint_trace" then
        @printf[I32]("Calling initiate_barrier at %s sources\n".cstring(),
          _sources.size().string().cstring())
      end
      for s in _sources.values() do
        s.initiate_barrier(barrier_token)
      end

      // See if we should finish early
      _active_barriers.check_for_completion(barrier_token)
    end

  be ack_barrier(s: Sink, barrier_token: BarrierToken) =>
    """
    Called by sinks when they have received barrier barriers on all
    their inputs.
    """
    ifdef "checkpoint_trace" then
      @printf[I32]("BarrierInitiator: ack_barrier on %s\n".cstring(),
        _phase.name().cstring())
    end
    _phase.ack_barrier(s, barrier_token, _active_barriers)

  be abort_barrier(s: Sink, barrier_token: BarrierToken) =>
    """
    Called by a sink that determines a protocol underlying a barrier
    must be aborted.
    """
    _active_barriers.abort_barrier(s, barrier_token)

  be worker_ack_barrier(w: String, barrier_token: BarrierToken) =>
    _phase.worker_ack_barrier(w, barrier_token, _active_barriers)

  fun ref all_primary_sinks_acked(barrier_token: BarrierToken,
    workers_acked: SetIs[String] val, result_promise: BarrierResultPromise)
  =>
    """
    On the primary initiator, once all sink have acked, we switch to looking
    for all worker acks.
    """
    if not _disposed then
      let next_handler = WorkerAcksBarrierHandler(this, barrier_token,
        _workers, workers_acked, result_promise)
      try
        _active_barriers.update_handler(barrier_token, next_handler)?
      else
        Fail()
      end
      // Add ourself to ack list
      _active_barriers.worker_ack_barrier(_worker_name, barrier_token)
    end

  fun ref all_secondary_sinks_acked(barrier_token: BarrierToken,
    primary_worker: String)
  =>
    """
    On a secondary intiator, when all sinks have acked, we ack back to
    the primary worker that started this barrier in the first place.
    We are finished processing that barrier.
    """
    if not _disposed then
      ifdef "checkpoint_trace" then
        @printf[I32]("all_secondary_sinks_acked for %s\n".cstring(),
          barrier_token.string().cstring())
      end
      try
        let msg = ChannelMsgEncoder.worker_ack_barrier(_worker_name,
          barrier_token, _auth)?
        _connections.send_control(primary_worker, msg)
        try
          _active_barriers.remove_barrier(barrier_token)?
        else
          Fail()
        end
      else
        Fail()
      end
    end

  fun ref all_workers_acked(barrier_token: BarrierToken,
    result_promise: BarrierResultPromise)
  =>
    """
    All in flight acks have been received. Revert to waiting state
    and trigger the BarrierResultPromise.
    """
    try
      _active_barriers.remove_barrier(barrier_token)?
    else
      Fail()
    end
    barrier_fully_acked(barrier_token, result_promise)

  fun ref abort_pending_barrier(barrier_token: BarrierToken) =>
    try
      _pending_promises(barrier_token)?.reject()
    else
      Fail()
    end

  fun ref barrier_fully_acked(barrier_token: BarrierToken,
    result_promise: BarrierResultPromise)
  =>
    if not _disposed then
      result_promise(barrier_token)
      try
        let msg = ChannelMsgEncoder.barrier_fully_acked(barrier_token, _auth)?
        for w in _workers.values() do
          if w != _worker_name then _connections.send_control(w, msg) end
        end
      else
        Fail()
      end

      for b_source in _barrier_sources.values() do
        b_source.barrier_fully_acked(barrier_token)
      end
      for s in _sources.values() do
        s.barrier_fully_acked(barrier_token)
      end
      for s in _sinks.values() do
        s.barrier_fully_acked(barrier_token)
      end

      _phase.barrier_fully_acked(barrier_token)
    end

  fun ref next_token() =>
    if not _disposed then
      _phase = _NormalBarrierInitiatorPhase(this)
      if _pending.size() > 0 then
        try
          let next = _pending.shift()?
          match next
          | let p: _PendingSourceInit =>
            _phase = _SourcePendingBarrierInitiatorPhase(this)
            let promise = Promise[Source]
            promise.next[None](recover this~source_registration_complete() end)
            p.source.register_downstreams(promise)
            return
          | let p: _PendingBarrier =>
            _inject_barrier(p.token, p.promise)
            if (_phase.ready_for_next_token() and (_pending.size() > 0))
            then
              next_token()
            end
          end
        else
          Unreachable()
        end
      end
    end

  be remote_barrier_fully_acked(barrier_token: BarrierToken) =>
    """
    Called in response to primary worker for this barrier token sending
    message that this barrier is complete. We can now inform all local
    sources (for example, so they can ack messages up to a checkpoint).
    """
    for s in _sources.values() do
      s.barrier_fully_acked(barrier_token)
    end

  be dispose() =>
    @printf[I32]("Shutting down BarrierInitiator\n".cstring())
    _disposed = true
