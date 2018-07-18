/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "collections"
use "wallaroo/core/common"
use "wallaroo/core/initialization"
use "wallaroo/core/messages"
use "wallaroo/core/source"
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
  let _in_flight_barriers: Map[BarrierToken, BarrierHandler] =
    _in_flight_barriers.create()
  // !@ This is risky because we need to make sure barriers are sent in
  // the same order they're received. Better to peek at the top of a queue
  // probably to determine if we're dealing with the correct barrier.
  let _pending_barriers: Map[BarrierToken, BarrierResultPromise] =
    _pending_barriers.create()
  var _current_barrier_token: BarrierToken = InitialBarrierToken
  let _worker_name: String
  var _barrier_handler: BarrierHandler = WaitingBarrierHandler
  let _connections: Connections
  let _sources: Map[StepId, Source] = _sources.create()
  let _source_ids: Map[USize, StepId] = _source_ids.create()
  let _sinks: SetIs[BarrierReceiver] = _sinks.create()
  let _workers: _StringSet = _workers.create()

  new create(auth: AmbientAuth, worker_name: String, connections: Connections)
  =>
    _auth = auth
    _worker_name = worker_name
    _connections = connections

  fun barrier_in_flight(): Bool =>
    _in_flight_barriers.size() > 0

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

  be register_source(source: Source, source_id: StepId) =>
    _sources(source_id) = source
    _source_ids(digestof source) = source_id

  be unregister_source(source: Source, source_id: StepId) =>
    try
      _sources(source_id)?
      _source_ids(digestof source)?
    else
      Fail()
    end

  be add_worker(w: String) =>
    @printf[I32]("!@ BarrierInitiator: add_worker %s\n".cstring(), w.cstring())
    if _barrier_handler.in_progress() then
      @printf[I32]("add_worker called during %s phase\n"
        .cstring(), _barrier_handler.name().cstring())
      Fail()
    end
    _workers.set(w)

  be remove_worker(w: String) =>
    @printf[I32]("!@ BarrierInitiator: remove_worker %s\n".cstring(), w.cstring())
    if _barrier_handler.in_progress() then
      @printf[I32]("remove_worker called during %s phase\n"
        .cstring(), _barrier_handler.name().cstring())
      Fail()
    end
    _workers.unset(w)

  be initiate_barrier(barrier_token: BarrierToken,
    result_promise: BarrierResultPromise)
  =>
    if _barrier_handler.in_progress() then
      @printf[I32]("initiate_barrier for %s called during %s phase for %s\n"
        .cstring(), barrier_token.string().cstring(),
        _barrier_handler.name().cstring(),
        _current_barrier_token.string().cstring())
      Fail()
    end
    ifdef debug then
      @printf[I32]("Initiating barrier protocol for %s.\n".cstring(),
        barrier_token.string().cstring())
    end
    @printf[I32]("!@ OLD TOKEN: %s, setting to: %s\n".cstring(), _current_barrier_token.string().cstring(), barrier_token.string().cstring())
    _current_barrier_token = barrier_token
    @printf[I32]("!@ SET TO: %s\n".cstring(), _current_barrier_token.string().cstring())
    _barrier_handler = PendingBarrierHandler(_worker_name, this,
      _current_barrier_token, _sinks, _workers, result_promise
      where primary_worker = _worker_name)

    // !@ Clean up this pending barrier approach to handle multiple at once
    _pending_barriers(_current_barrier_token) = result_promise
    try
      if _workers.size() > 1 then
        @printf[I32]("!@ Sending remote initiate barrier for %s\n".cstring(), _current_barrier_token.string().cstring())
        let msg = ChannelMsgEncoder.remote_initiate_barrier(_worker_name,
          _current_barrier_token, _auth)?
        for w in _workers.values() do
          if w != _worker_name then _connections.send_control(w, msg) end
        end
      else
        @printf[I32]("!@ Not sending remote initiate barrier because there's only one worker!\n".cstring())
      end
    else
      Fail()
    end
    @printf[I32]("!@ About to call worker_ack_barrier_start on handler with %s\n".cstring(), _current_barrier_token.string().cstring())
    _barrier_handler.worker_ack_barrier_start(_worker_name,
      _current_barrier_token)

  be remote_initiate_barrier(primary_worker: String,
    barrier_token: BarrierToken)
  =>
    @printf[I32]("!@ remote_initiate_barrier called for %s\n".cstring(), barrier_token.string().cstring())
    if _barrier_handler.in_progress() then
      @printf[I32](("remote_initiate_barrier for %s called during %s phase " +
        "for %s\n").cstring(), barrier_token.string().cstring(),
        _barrier_handler.name().cstring(),
        _current_barrier_token.string().cstring())
      Fail()
    end

    // !@ How do we handle this?  Do we use mergable ids to make sure
    // two don't trigger the same id at different times?
    _current_barrier_token = barrier_token
    _barrier_handler = PendingBarrierHandler(_worker_name, this,
      _current_barrier_token, _sinks, _workers, EmptyBarrierResultPromise(),
      primary_worker)

    try
      let msg = ChannelMsgEncoder.worker_ack_barrier_start(_worker_name,
        _current_barrier_token, _auth)?
      _connections.send_control(primary_worker, msg)
    else
      Fail()
    end

    for s in _sources.values() do
      s.initiate_barrier(_current_barrier_token)
    end

  be worker_ack_barrier_start(w: String, token: BarrierToken) =>
    @printf[I32]("!@ _worker_ack_barrier_start called for %s\n".cstring(), w.cstring())
    _barrier_handler.worker_ack_barrier_start(w, token)

//!@
  // fun ref _worker_ack_barrier_start(w: String, token: BarrierToken) =>
  //   @printf[I32]("!@ _worker_ack_barrier_start called for %s\n".cstring(), w.cstring())
  //   if not _workers.contains(w) then Fail() end
  //   _workers_ready.set(w)
  //   // !@ Eventually we need this on a per-token basis
  //   if _workers_ready.size() == _workers.size() then
  //     try
  //       @printf[I32]("!@ workers ready count: %s\n".cstring(), _workers_ready.size().string().cstring())
  //       _send_barrier(token, _pending_barriers.remove(token)?._2)
  //       _workers_ready.clear()
  //     else
  //       Fail()
  //     end
  //   end

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
    if primary_worker == _worker_name then
      _barrier_handler = InProgressPrimaryBarrierHandler(_worker_name, this,
        barrier_token, acked_sinks, acked_ws, _sinks, _workers,
        result_promise)
    else
      _barrier_handler = InProgressSecondaryBarrierHandler(this,
        barrier_token, acked_sinks, _sinks, primary_worker)
    end

    @printf[I32]("!@ calling initiate_barrier at %s sources\n".cstring(), _sources.size().string().cstring())
    //!@
    if (_sources.size() == 0) and (_workers.size() == 1) then
      @printf[I32]("!@ initiate_barrier FINISH EARLY\n".cstring())
      //!@ FINISH EARLY
      all_workers_acked(_current_barrier_token, result_promise)
    else
      for s in _sources.values() do
        s.initiate_barrier(_current_barrier_token)
      end
    end

  be ack_barrier(s: BarrierReceiver, barrier_token: BarrierToken) =>
    """
    Called by sinks when they have received barrier barriers on all
    their inputs.
    """
    _barrier_handler.ack_barrier(s, barrier_token)

  be worker_ack_barrier(w: String, barrier_token: BarrierToken) =>
    @printf[I32]("!@ Rcvd worker_ack_barrier from %s\n".cstring(), w.cstring())
    _barrier_handler.worker_ack_barrier(w, barrier_token)

  fun ref all_primary_sinks_acked(barrier_token: BarrierToken,
    workers_acked: SetIs[String] val, result_promise: BarrierResultPromise)
  =>
    """
    On the primary initiator, once all sink have acked, we switch to looking
    for all worker acks.
    """
    @printf[I32]("!@ Switching to WorkerAcksBarrierHandler\n".cstring())
    _barrier_handler = WorkerAcksBarrierHandler(this,
      barrier_token, _workers, workers_acked, result_promise)

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
      _barrier_handler = WaitingBarrierHandler
      //!@ WHA!?
      check()
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
    @printf[I32]("!@ all_workers_acked\n".cstring())
    _barrier_handler = WaitingBarrierHandler
    @printf[I32]("!@ --- Switched to %s\n".cstring(), _barrier_handler.name().cstring())
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
    for s in _sources.values() do
      s.barrier_complete(barrier_token)
    end

    //!@
    check()

  be remote_barrier_complete(barrier_token: BarrierToken) =>
    """
    Called in response to primary worker for this barrier token sending
    message that this barrier is complete. We can now inform all local
    sources (for example, so they can ack messages up to a snapshot).
    """
    for s in _sources.values() do
      s.barrier_complete(barrier_token)
    end

  //!@
  be check() =>
    //!@ What sort of bug is this!?
    _barrier_handler = WaitingBarrierHandler
    @printf[I32]("!@ --- STILL? Switched to %s\n".cstring(), _barrier_handler.name().cstring())

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
