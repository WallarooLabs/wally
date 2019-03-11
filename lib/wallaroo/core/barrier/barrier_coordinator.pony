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


actor BarrierCoordinator is Initializable
  """
  The BarrierCoordinator is used to trigger a barrier protocol starting from
  all Sources in the system and moving down to the Sinks, which will each ack
  the BarrierCoordinator actor local to its worker.

  Once a Step or Sink receives a barrier, it will block on the input it
  received it on. Once it has received barriers over all inputs, it will
  forward the barrier downstream.

  The details of the barrier protocol depend on the BarrierToken and are
  opaque to the BarrierCoordinator. That means it can be used as part of
  different protocols if they require general barrier processing behavior
  (for example, the checkpointing protocol and the protocol checking that all
  in flight messages have been processed).

  Phases:
    1) _InitialBarrierCoordinatorPhase: Waiting for constructor to complete, at
       which point we transition either to _NormalBarrierCoordinatorPhase or
       _RecoveringBarrierCoordinatorPhase, depending on if we're recovering
    2) _NormalBarrierCoordinatorPhase: Normal barrier processing.
    3) _RecoveringBarrierCoordinatorPhase: Indicates we started in recovery
       mode. We drop all barrier tokens that are not
       CheckpointRollbackBarrierToken.
    4) _SourcePendingBarrierCoordinatorPhase: This phase is initiated if we
       pull a pending new source off the pending queue. In this phase, we
       queue new barriers and wait to inject them until after the pending
       source has registered with its downstreams.
    5) _BlockingBarrierCoordinatorPhase: While processing a "blocking barrier",
       we queue all incoming barriers.
    6) _RollbackBarrierCoordinatorPhase: We transition to this phase in
       response to the injection of a CheckpointRollbackBarrierToken. During
       this phase, we queue all incoming barriers.
  """
  let _auth: AmbientAuth
  let _worker_name: WorkerName

  // The local coordinator is responsible for injecting barriers at the
  // local sources and collecting acks for each barrier from the local sinks.
  let _local_coordinator: LocalBarrierCoordinator

  var _phase: _BarrierCoordinatorPhase = _InitialBarrierCoordinatorPhase

  var _pending: Array[_Pending] = _pending.create()

  let _active_barriers: Map[BarrierToken, _WorkerAckCount] =
    _active_barriers.create()

  let _connections: Connections
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
  var _primary_worker: WorkerName

  var _disposed: Bool = false

  new create(auth: AmbientAuth, worker_name: WorkerName,
    connections: Connections, primary_worker: WorkerName,
    is_recovering: Bool = false)
  =>
    _auth = auth
    _worker_name = worker_name
    _connections = connections
    _primary_worker = primary_worker
    _local_coordinator = LocalBarrierCoordinator(auth, worker_name,
      _primary_worker, this, connections)
    if is_recovering then
      _phase = _RecoveringBarrierCoordinatorPhase(this)
    else
      _phase = _NormalBarrierCoordinatorPhase(this)
    end

  be application_begin_reporting(initializer: LocalTopologyInitializer) =>
    initializer.report_created(this)

  be application_created(initializer: LocalTopologyInitializer) =>
    initializer.report_initialized(this)

  be application_initialized(initializer: LocalTopologyInitializer) =>
    initializer.report_ready_to_work(this)

  be application_ready_to_work(initializer: LocalTopologyInitializer) =>
    None

  be add_worker(w: WorkerName) =>
    if not _disposed then
      ifdef "checkpoint_trace" then
        @printf[I32]("BarrierCoordinator: add_worker %s\n".cstring(),
          w.cstring())
      end
      if _barrier_in_progress() then
        @printf[I32]("add_worker called while barrier is in progress\n"
          .cstring())
        Fail()
      end
      _workers.set(w)
    end

  be remove_worker(w: WorkerName) =>
    if not _disposed then
      ifdef "checkpoint_trace" then
        @printf[I32]("BarrierCoordinator: remove_worker %s\n".cstring(),
          w.cstring())
      end

      if _barrier_in_progress() then
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
    if _barrier_in_progress() then
      _pending.push(_PendingSourceInit(s))
    else
      _initialize_source(s)
    end

  fun ref _initialize_source(s: Source) =>
    _phase = _SourcePendingBarrierCoordinatorPhase(this)
    let promise = Promise[Source]
    promise.next[None](recover this~source_registration_complete() end)
    s.register_downstreams(promise)

  be source_registration_complete(s: Source) =>
    _phase.source_registration_complete(s)

  fun ref source_pending_complete(s: Source) =>
    if not _disposed then
      _phase = _NormalBarrierCoordinatorPhase(this)
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
        | let crt: CheckpointRollbackBarrierToken =>
          // Check if this rollback token is higher priority than a current
          // rollback token, in case one is being processed. If it's not, drop
          // it.
          if _phase.higher_priority(crt) then
            _clear_barriers()
            _phase = _RollbackBarrierCoordinatorPhase(this, crt)
          end
        | let crrt: CheckpointRollbackResumeBarrierToken =>
          // Check if this rollback token is higher priority than a current
          // rollback token, in case one is being processed. If it's not, drop
          // it.
          if _phase.higher_priority(crrt) then
            _clear_barriers()
            _phase = _NormalBarrierCoordinatorPhase(this)
          end
        end

        _phase.initiate_barrier(barrier_token, result_promise)
      else
        ifdef debug then
          Invariant(not _pending_promises.contains(barrier_token))
        end
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
        _phase = _BlockingBarrierCoordinatorPhase(this, barrier_token,
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
      ifdef debug then
        _unknown_barrier_for("forwarded_inject_barrier_fully_acked",
          barrier_token)
      end
    end

  be forwarded_inject_barrier_aborted(barrier_token: BarrierToken) =>
    try
      let promise = _pending_promises.remove(barrier_token)?._2
      promise.reject()
    else
      ifdef debug then
        _unknown_barrier_for("forwarded_inject_barrier_fully_acked",
          barrier_token)
      end
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

      ifdef debug then
        Invariant(not _active_barriers.contains(barrier_token))
        Invariant(not _pending_promises.contains(barrier_token))
      end

      let worker_ack_count = _WorkerAckCount(barrier_token, _workers, this)
      _active_barriers(barrier_token) = worker_ack_count
      _pending_promises(barrier_token) = result_promise

      //////
      // Send barrier to LocalBarrierCoordinators on all workers including
      // this one.
      //////
      _local_coordinator.inject_barrier(barrier_token)
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

  fun _barrier_in_progress(): Bool =>
    (_pending_promises.size() > 0) or (_active_barriers.size() > 0)

  fun ref _clear_barrier(token: BarrierToken) =>
    try
      _active_barriers.remove(token)?
      _pending_promises.remove(token)?
    else
      ifdef debug then
        _unknown_barrier_for("_clear_barrier", token)
      end
    end

  fun ref _clear_barriers() =>
    _local_coordinator.clear_barriers()
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

  fun ref _unknown_barrier_for(call_name: String, barrier_token: BarrierToken)
  =>
    @printf[I32](("%s received at BarrierCoordinator " +
      "for unknown barrier token %s. Did we rollback?\n").cstring(),
      call_name.cstring(), barrier_token.string().cstring())

  // !@ TODO: Can we come up with more descriptive name?
  be remote_initiate_barrier(primary_worker: WorkerName,
    barrier_token: BarrierToken)
  =>
    //!@
    ifdef debug then
      Invariant(_primary_worker != _worker_name)
    end

    match barrier_token
    | let crt: CheckpointRollbackBarrierToken =>
      // Check if this rollback token is higher priority than a current
      // rollback token, in case one is being processed. If it's not, drop
      // it.
      if _phase.higher_priority(crt) then
        _clear_barriers()
        _phase = _RollbackBarrierCoordinatorPhase(this, crt)
      end
    | let crrt: CheckpointRollbackResumeBarrierToken =>
      // Check if this rollback token is higher priority than a current
      // rollback token, in case one is being processed. If it's not, drop
      // it.
      if _phase.higher_priority(crrt) then
        _clear_barriers()
        _phase = _NormalBarrierCoordinatorPhase(this)
      end
    end

    _local_coordinator.inject_barrier(barrier_token)

  be worker_ack_barrier(w: WorkerName, barrier_token: BarrierToken) =>
    _phase.worker_ack_barrier(w, barrier_token)

  fun ref _worker_ack_barrier(w: WorkerName, barrier_token: BarrierToken) =>
    try
      _active_barriers(barrier_token)?.ack(w)
    else
      ifdef debug then
        _unknown_barrier_for("_worker_ack_barrier", barrier_token)
      end
    end

  be worker_abort_barrier(worker: WorkerName, barrier_token: BarrierToken) =>
    if _primary_worker == _worker_name then
      try
        @printf[I32]("Barrier %s aborted by worker %s!\n".cstring(),
          barrier_token.string().cstring(), worker.cstring())
        _pending_promises(barrier_token)?.reject()
      else
        ifdef debug then
          _unknown_barrier_for("abort_barrier", barrier_token)
        end
      end
      _clear_barrier(barrier_token)
      try
        let msg = ChannelMsgEncoder.remote_abort_barrier(_worker_name,
          barrier_token, _auth)?
        for w in _workers.values() do
          if w != _worker_name then _connections.send_control(w, msg) end
        end
      else
        Fail()
      end
    end

  be remote_abort_barrier(barrier_token: BarrierToken) =>
    _local_coordinator.remote_abort_barrier(barrier_token)

  fun ref barrier_fully_acked(barrier_token: BarrierToken) =>
    if not _disposed then
      try
        let promise = _pending_promises(barrier_token)?
        promise(barrier_token)

        let msg = ChannelMsgEncoder.barrier_fully_acked(barrier_token, _auth)?
        for w in _workers.values() do
          if w != _worker_name then _connections.send_control(w, msg) end
        end
      else
        ifdef debug then
          _unknown_barrier_for("barrier_fully_acked", barrier_token)
        end
      end

      _local_coordinator.barrier_fully_acked(barrier_token)

      _clear_barrier(barrier_token)
      _phase.barrier_fully_acked(barrier_token)
    end

  fun ref next_token() =>
    if not _disposed then
      _phase = _NormalBarrierCoordinatorPhase(this)
      if _pending.size() > 0 then
        try
          let next = _pending.shift()?
          match next
          | let p: _PendingSourceInit =>
            _initialize_source(p.source)
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

  be dispose() =>
    @printf[I32]("Shutting down BarrierCoordinator\n".cstring())
    _local_coordinator.dispose()
    _disposed = true

  ////////////////////////////////
  // LOCAL BARRIER COORDINATOR
  ////////////////////////////////
  be register_sink(sink: Sink) =>
    _local_coordinator.register_sink(sink)

  be unregister_sink(sink: Sink) =>
    _local_coordinator.unregister_sink(sink)

  be register_barrier_source(b_source: BarrierSource) =>
    _local_coordinator.register_barrier_source(b_source)

  be register_source(source: Source, source_id: RoutingId) =>
    _local_coordinator.register_source(source, source_id)

  be unregister_source(source: Source, source_id: RoutingId) =>
    _local_coordinator.unregister_source(source, source_id)

  be ack_barrier(s: Sink, barrier_token: BarrierToken) =>
    """
    Called by sinks when they have received barrier barriers on all
    their inputs.
    """
    _phase.ack_barrier(s, barrier_token)

  fun ref _ack_barrier(s: Sink, barrier_token: BarrierToken) =>
    _local_coordinator.ack_barrier(s, barrier_token)

  be abort_barrier(barrier_token: BarrierToken) =>
    """
    Called by a sink that determines a protocol underlying a barrier
    must be aborted.
    """
    _local_coordinator.abort_barrier(barrier_token)

  //!@ Should we rename this to be clearer?
  be remote_barrier_fully_acked(barrier_token: BarrierToken) =>
    """
    Called in response to primary worker for this barrier token sending
    message that this barrier is complete. We can now inform all local
    sources (for example, so they can ack messages up to a checkpoint).
    """
    _local_coordinator.barrier_fully_acked(barrier_token)

class _WorkerAckCount
  let _token: BarrierToken
  let _workers: StringSet = _workers.create()
  let _coordinator: BarrierCoordinator ref

  new create(t: BarrierToken, ws: StringSet, bc: BarrierCoordinator ref) =>
    _token = t
    for w in ws.values() do
      _workers.set(w)
    end
    _coordinator = bc

  fun ref ack(w: WorkerName) =>
    ifdef debug then
      Invariant(_workers.contains(w))
    end

    _workers.unset(w)
    if _workers.size() == 0 then
      _coordinator.barrier_fully_acked(_token)
    end


