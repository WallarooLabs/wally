/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "collections"
use "promises"
use "wallaroo/core/common"
use "wallaroo/core/initialization"
use "wallaroo/core/invariant"
use "wallaroo/core/messages"
use "wallaroo/core/source"
use "wallaroo/core/source/barrier_source"
use "wallaroo/core/sink"
use "wallaroo/ent/network"
use "wallaroo_labs/mort"


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
  the snapshotting protocol and the protocol checking that all in flight
  messages have been processed).
  """
  let _auth: AmbientAuth
  let _worker_name: String
  var _phase: _BarrierInitiatorPhase = _InitialBarrierInitiatorPhase

  var _pending: Array[_Pending] = _pending.create()
  let _active_barriers: ActiveBarriers = ActiveBarriers

  let _connections: Connections
  var _barrier_source: (BarrierSource | None) = None
  let _sources: Map[RoutingId, Source] = _sources.create()
  let _sinks: SetIs[BarrierReceiver] = _sinks.create()
  let _workers: _StringSet = _workers.create()

  // When we send barriers to a different primary worker, we use this map
  // to call the correct action when those barriers are complete.
  let _pending_actions: Map[BarrierToken, Promise[BarrierToken]] =
    _pending_actions.create()

  // TODO: Currently, we can only inject barriers from one primary worker
  // in the cluster. This is because otherwise they might be injected in
  // parallel at different workers and the barrier protocol relies on the
  // fact that each barrier is injected at all sources before the next
  // barrier.
  var _primary_worker: String

  new create(auth: AmbientAuth, worker_name: String, connections: Connections,
    primary_worker: String)
  =>
    _auth = auth
    _worker_name = worker_name
    _connections = connections
    _primary_worker = primary_worker
    _phase = _NormalBarrierInitiatorPhase(this)

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
    _barrier_source = b_source

  be register_source(source: Source, source_id: RoutingId) =>
    _sources(source_id) = source

  be unregister_source(source: Source, source_id: RoutingId) =>
    @printf[I32]("!@ BarrierInitiator: Unregistering source\n".cstring())
    try
      _sources.remove(source_id)?
    else
      Fail()
    end

  be add_worker(w: String) =>
    @printf[I32]("!@ BarrierInitiator: add_worker %s\n".cstring(), w.cstring())
    if _active_barriers.barrier_in_progress() then
      @printf[I32]("add_worker called while barrier is in progress\n"
        .cstring())
      Fail()
    end
    _workers.set(w)

  be remove_worker(w: String) =>
    @printf[I32]("!@ BarrierInitiator: remove_worker %s\n".cstring(), w.cstring())
    if _active_barriers.barrier_in_progress() then
      @printf[I32]("remove_worker called while barrier is in progress\n"
        .cstring())
      Fail()
    end
    _workers.unset(w)

  be initialize_source(s: Source) =>
    """
    Before a source can register with its downstreams, we need to make sure
    there is no in flight barrier since such registration would change the
    graph and potentially disrupt the barrier protocol.
    """
    if _active_barriers.barrier_in_progress() then
      _pending.push(_PendingSourceInit(s))
    else
      let action = Promise[Source]
      action.next[None](recover this~source_registration_complete() end)
      s.register_downstreams(action)
    end

  be source_registration_complete(s: Source) =>
    _phase.source_registration_complete(s)

  fun ref source_pending_complete(s: Source) =>
    _phase = _NormalBarrierInitiatorPhase(this)
    next_token()

  be inject_barrier(barrier_token: BarrierToken,
    result_promise: BarrierResultPromise)
  =>
    _inject_barrier(barrier_token, result_promise)

  fun ref _inject_barrier(barrier_token: BarrierToken,
    result_promise: BarrierResultPromise)
  =>
    """
    Called to begin the barrier protocol for a new barrier token.
    """
    @printf[I32]("!@ Injecting barrier %s\n".cstring(), barrier_token.string().cstring())
    if _primary_worker == _worker_name then
      // We handle rollback barrier token as a special case. That's because
      // in the presence of a rollback token, we need to cancel all other
      // tokens in flight since we are rolling back to an earlier state of
      // the system. On a successful match here, we transition to the
      // rollback phase.
      match barrier_token
      | let srt: SnapshotRollbackBarrierToken =>
        // Check if this rollback token is higher priority than a current
        // rollback token, in case one is being processed. If it's not, drop
        // it.
        if _phase.higher_priority(srt) then
          _clear_barriers()
          _phase = _RollbackBarrierInitiatorPhase(this, srt)
        end
      end

      _phase.initiate_barrier(barrier_token, result_promise)
    else
      _pending_actions(barrier_token) = result_promise
      try
        let msg = ChannelMsgEncoder.forward_inject_barrier(barrier_token,
          _worker_name, _auth)?
        _connections.send_control(_primary_worker, msg)
      else
        Fail()
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
    @printf[I32]("!@ Injecting blocking barrier %s\n".cstring(), barrier_token.string().cstring())
    if _primary_worker == _worker_name then
      //!@ We need to make sure this gets queued if we're in rollback mode
      _phase = _BlockingBarrierInitiatorPhase(this, barrier_token,
        wait_for_token)
      _phase.initiate_barrier(barrier_token, result_promise)
    else
      _pending_actions(barrier_token) = result_promise
      try
        let msg = ChannelMsgEncoder.forward_inject_blocking_barrier(
          barrier_token, wait_for_token, _worker_name, _auth)?
        _connections.send_control(_primary_worker, msg)
      else
        Fail()
      end
    end

  be forwarded_inject_barrier_complete(barrier_token: BarrierToken) =>
    try
      let action = _pending_actions.remove(barrier_token)?._2
      action(barrier_token)
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
    ifdef debug then
      @printf[I32]("Initiating barrier protocol for %s.\n".cstring(),
        barrier_token.string().cstring())
    end
    //!@
    // _current_barrier_token = barrier_token

    let barrier_handler = PendingBarrierHandler(_worker_name, this,
      barrier_token, _sinks, _workers, result_promise
      where primary_worker = _worker_name)
    try
      _active_barriers.add_barrier(barrier_token, barrier_handler)?
    else
      Fail()
    end

    try
      if _workers.size() > 1 then
        // @printf[I32]("!@ Sending remote initiate barrier for %s\n".cstring(), barrier_token.string().cstring())
        let msg = ChannelMsgEncoder.remote_initiate_barrier(_worker_name,
          barrier_token, _auth)?
        for w in _workers.values() do
          if w != _worker_name then _connections.send_control(w, msg) end
        end
      else
        //!@
        None
        // @printf[I32]("!@ Not sending remote initiate barrier because there's only one worker!\n".cstring())
      end
    else
      Fail()
    end
    // @printf[I32]("!@ About to call worker_ack_barrier_start on handler for %s\n".cstring(), barrier_token.string().cstring())
    _active_barriers.worker_ack_barrier_start(_worker_name, barrier_token)

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
    // @printf[I32]("!@ remote_initiate_barrier called for %s\n".cstring(), barrier_token.string().cstring())

    let next_handler = PendingBarrierHandler(_worker_name, this,
      barrier_token, _sinks, _workers, EmptyBarrierResultPromise(),
      primary_worker)
    try
      _active_barriers.add_barrier(barrier_token, next_handler)?
    else
      Fail()
    end

    try
      let msg = ChannelMsgEncoder.worker_ack_barrier_start(_worker_name,
        barrier_token, _auth)?
      _connections.send_control(primary_worker, msg)
    else
      Fail()
    end

    for s in _sources.values() do
      s.initiate_barrier(barrier_token)
    end

  be worker_ack_barrier_start(w: String, token: BarrierToken) =>
    // @printf[I32]("!@ _worker_ack_barrier_start called for %s\n".cstring(), w.cstring())
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
    acked_sinks: SetIs[BarrierReceiver] val,
    acked_ws: SetIs[String] val, primary_worker: String)
  =>
    let next_handler =
      if primary_worker == _worker_name then
        InProgressPrimaryBarrierHandler(_worker_name, this, barrier_token,
          acked_sinks, acked_ws, _sinks, _workers, result_promise)
      else
        @printf[I32]("!@ Phase transition to SecondaryBarrierHandler for token %s with primary worker being %s\n".cstring(), barrier_token.string().cstring(), primary_worker.cstring())
        InProgressSecondaryBarrierHandler(this, barrier_token, acked_sinks,
          _sinks, primary_worker)
      end
    try
      _active_barriers.update_handler(barrier_token, next_handler)?
    else
      Fail()
    end

    if _barrier_source isnt None then
      try
        @printf[I32]("!@ calling initiate_barrier at BarrierSource\n".cstring())
        (_barrier_source as BarrierSource).initiate_barrier(barrier_token)
      else
        Unreachable()
      end
      @printf[I32]("!@ calling initiate_barrier at %s sources\n".cstring(), _sources.size().string().cstring())
      for s in _sources.values() do
        s.initiate_barrier(barrier_token)
      end
    else
      ifdef debug then
        Invariant(_sources.size() == 0)
      end
    end
    // See if we should finish early
    _active_barriers.check_for_completion(barrier_token)

  be ack_barrier(s: BarrierReceiver, barrier_token: BarrierToken) =>
    """
    Called by sinks when they have received barrier barriers on all
    their inputs.
    """
    _phase.ack_barrier(s, barrier_token, _active_barriers)

  be worker_ack_barrier(w: String, barrier_token: BarrierToken) =>
    // @printf[I32]("!@ Rcvd worker_ack_barrier from %s\n".cstring(), w.cstring())
    _phase.worker_ack_barrier(w, barrier_token, _active_barriers)

  fun ref all_primary_sinks_acked(barrier_token: BarrierToken,
    workers_acked: SetIs[String] val, result_promise: BarrierResultPromise)
  =>
    """
    On the primary initiator, once all sink have acked, we switch to looking
    for all worker acks.
    """
    let next_handler = WorkerAcksBarrierHandler(this, barrier_token, _workers,
      workers_acked, result_promise)
    try
      _active_barriers.update_handler(barrier_token, next_handler)?
    else
      Fail()
    end
    // Add ourself to ack list
    _active_barriers.worker_ack_barrier(_worker_name, barrier_token)

  fun ref all_secondary_sinks_acked(barrier_token: BarrierToken,
    primary_worker: String)
  =>
    """
    On a secondary intiator, when all sinks have acked, we ack back to
    the primary worker that started this barrier in the first place.
    We are finished processing that barrier.
    """
    @printf[I32]("!@ all_secondary_sinks_acked for %s\n".cstring(), barrier_token.string().cstring())
    try
      let msg = ChannelMsgEncoder.worker_ack_barrier(_worker_name,
        barrier_token, _auth)?
      _connections.send_control(primary_worker, msg)
      try
        _active_barriers.remove_barrier(barrier_token)?
      else
        Fail()
      end
      //!@ WHA!?
      // check()
    else
      Fail()
    end

  fun ref all_workers_acked(barrier_token: BarrierToken,
    result_promise: BarrierResultPromise)
  =>
    """
    All in flight acks have been received. Revert to waiting state
    and trigger the BarrierResultPromise.
    """
    // @printf[I32]("!@ all_workers_acked\n".cstring())
    try
      _active_barriers.remove_barrier(barrier_token)?
    else
      Fail()
    end
    barrier_complete(barrier_token, result_promise)

  fun ref barrier_complete(barrier_token: BarrierToken,
    result_promise: BarrierResultPromise)
  =>
    result_promise(barrier_token)
    try
      let msg = ChannelMsgEncoder.barrier_complete(barrier_token, _auth)?
      for w in _workers.values() do
        if w != _worker_name then _connections.send_control(w, msg) end
      end
    else
      Fail()
    end

    if _barrier_source isnt None then
      try
        (_barrier_source as BarrierSource).barrier_complete(barrier_token)
      else
        Fail()
      end
    end
    for s in _sources.values() do
      s.barrier_complete(barrier_token)
    end

    _phase.barrier_complete(barrier_token)

  fun ref next_token() =>
    // @printf[I32]("!@ next_token(): _pending %s\n".cstring(), _pending.size().string().cstring())
    _phase = _NormalBarrierInitiatorPhase(this)
    if _pending.size() > 0 then
      try
        let next = _pending.shift()?
        match next
        | let p: _PendingSourceInit =>
          _phase = _SourcePendingBarrierInitiatorPhase(this)
          let action = Promise[Source]
          action.next[None](recover this~source_registration_complete() end)
          p.source.register_downstreams(action)
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

  be remote_barrier_complete(barrier_token: BarrierToken) =>
    """
    Called in response to primary worker for this barrier token sending
    message that this barrier is complete. We can now inform all local
    sources (for example, so they can ack messages up to a snapshot).
    """
    for s in _sources.values() do
      s.barrier_complete(barrier_token)
    end

  be dispose() =>
    @printf[I32]("Shutting down BarrierInitiator\n".cstring())
    None

  //!@
  // be check() =>
  //   //!@ What sort of bug is this!?
  //   _barrier_handler = WaitingBarrierHandler
  //   @printf[I32]("!@ --- STILL? Switched to %s\n".cstring(), _barrier_handler.name().cstring())

/////////////////////////////////////////////////////////////////////////////
// TODO: Replace using this with the badly named SetIs once we address a bug
// in SetIs where unsetting doesn't reduce set size for type SetIs[String].
class _StringSet
  let _map: Map[String, String] = _map.create()

  fun ref set(s: String) =>
    _map(s) = s

  fun ref unset(s: String) =>
    try _map.remove(s)? end

  fun contains(s: String): Bool =>
    _map.contains(s)

  fun ref clear() =>
    _map.clear()

  fun size(): USize =>
    _map.size()

  fun values(): MapValues[String, String, HashEq[String],
    this->HashMap[String, String, HashEq[String]]]^
  =>
    _map.values()
