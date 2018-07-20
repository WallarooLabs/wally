/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "collections"
use "wallaroo_labs/collection_helpers"
use "wallaroo/core/boundary"
use "wallaroo/core/common"
use "wallaroo/ent/data_receiver"
use "wallaroo/ent/network"
use "wallaroo/ent/router_registry"
use "wallaroo_labs/mort"
use "wallaroo/core/invariant"
use "wallaroo/core/messages"
use "wallaroo/core/topology"


actor RecoveryReplayer
  """
  Phases (if on a recovering worker):
    1) _AwaitingRecoveryReplayStart: Wait for start_recovery_replay() to be
       called. We only enter this phase if we are in recovery mode. Otherwise,
       we go immediately to _ReadyForNormalProcessing.
    2) _WaitingForBoundaryCounts: Wait for every running worker to inform this
       worker of how many boundaries they have incoming to us. We use these
       counts to determine when every incoming boundary has reconnected.
    3) _WaitForReconnections: Wait for every incoming boundary to reconnect.
       If all incoming boundaries are already connected by the time this
       phase begins, immediately move to next phase.
    4) _Replay: Wait for every boundary to send a message indicating replay
       is finished, at which point we can clear deduplication lists and
       inform other workers that they are free to send normal messages.
    5) _ReadyForNormalProcessing: Finished replay

  ASSUMPTION: Recovery replay can happen at most once in the lifecycle of a
    worker.
  """
  let _worker_name: String
  let _auth: AmbientAuth
  var _replay_phase: _ReplayPhase = _EmptyReplayPhase
  // We keep track of all steps so we can tell them when to clear
  // their deduplication lists
  let _steps: SetIs[Step] = _steps.create()

  let _data_receivers: DataReceivers
  let _router_registry: RouterRegistry
  let _cluster: Cluster
  var _recovery: (Recovery | None) = None

  var _reconnected_boundaries: Map[String, SetIs[RoutingId]] =
    _reconnected_boundaries.create()

  new create(auth: AmbientAuth, worker_name: String,
    data_receivers: DataReceivers, router_registry: RouterRegistry,
    cluster: Cluster, is_recovering: Bool = false)
  =>
    _worker_name = worker_name
    _auth = auth
    _data_receivers = data_receivers
    _router_registry = router_registry
    _cluster = cluster
    if not is_recovering then
      _replay_phase = _ReadyForNormalProcessing(this)
    else
      _replay_phase = _AwaitingRecoveryReplayStart(this)
    end
    _data_receivers.subscribe(this)

  be register_step(step: Step) =>
    _steps.set(step)

  be add_expected_boundary_count(worker: String, count: USize) =>
    try
      _replay_phase.add_expected_boundary_count(worker, count)?
    else
      _print_replay_phase_error()
      Fail()
    end

  be data_receiver_added(worker: String, boundary_step_id: RoutingId,
    dr: DataReceiver)
  =>
    try
      _replay_phase.add_reconnected_boundary(worker, boundary_step_id)?
    else
      _print_replay_phase_error()
      Fail()
    end

  be add_boundary_replay_complete(worker: String, boundary_id: RoutingId) =>
    try
      _replay_phase.add_boundary_replay_complete(worker, boundary_id)?
    else
      _print_replay_phase_error()
      Fail()
    end

  fun _print_replay_phase_error() =>
    @printf[I32]("Recovery error while calling method on %s\n".cstring(),
      _replay_phase.name().cstring())
    @printf[I32]("Try restarting the process.\n".cstring())

  //////////////////////////
  // Managing Replay Phases
  //////////////////////////
  be start_recovery_replay(workers: Array[String] val,
    recovery: Recovery)
  =>
    if single_worker(workers) then
      @printf[I32]("|~~ - - Skipping Replay: Only One Worker - - ~~|\n"
        .cstring())
      _replay_phase = _ReadyForNormalProcessing(this)
      recovery.recovery_replay_finished()
      return
    end
    @printf[I32]("|~~ - - Replay Phase 1: Wait for Boundary Counts - - ~~|\n"
      .cstring())
    _recovery = recovery
    let expected_workers: SetIs[String] = expected_workers.create()
    for w in workers.values() do
      if w != _worker_name then expected_workers.set(w) end
    end
    _replay_phase = _WaitingForBoundaryCounts(expected_workers,
      _reconnected_boundaries, this)

    try
      let msg = ChannelMsgEncoder.request_boundary_count(_worker_name, _auth)?
      _cluster.send_control_to_cluster(msg)
    else
      Fail()
    end

  fun single_worker(workers: Array[String] val): Bool =>
    match workers.size()
    | 0 => true
    | 1 =>
      try
        workers(0)? == _worker_name
      else
        true
      end
    else
      false
    end

  fun ref _boundary_reconnected(worker: String, boundary_step_id: RoutingId) =>
    try
      if not _reconnected_boundaries.contains(worker) then
        _reconnected_boundaries(worker) = SetIs[RoutingId]
      end
      _reconnected_boundaries(worker)?.set(boundary_step_id)
    else
      Fail()
    end

  fun ref _wait_for_reconnections(expected_boundaries: Map[String, USize] box,
    reconnected_boundaries: Map[String, SetIs[RoutingId]])
  =>
    @printf[I32]("|~~ - - Replay Phase 2: Wait for Reconnections - - ~~|\n"
      .cstring())
    _replay_phase = _WaitForReconnections(expected_boundaries,
      reconnected_boundaries, this)
    try
      let msg = ChannelMsgEncoder.reconnect_data_port(_worker_name, _auth)?
      _cluster.send_control_to_cluster(msg)
    else
      Fail()
    end

  fun ref _start_replay_phase(expected_boundaries: Map[String, USize] box) =>
    @printf[I32]("|~~ - - Replay Phase 3: Message Replay - - ~~|\n".cstring())
    _replay_phase = _Replay(expected_boundaries, this, _data_receivers)
    // Initializing data receivers will trigger replay over the boundaries
    _data_receivers.start_replay_processing()

  fun ref _end_replay_phase() =>
    @printf[I32]("|~~ - - Replay COMPLETE - - ~~|\n".cstring())
    _replay_phase = _ReadyForNormalProcessing(this)
    //!@
    // _clear_deduplication_lists()
    match _recovery
    | let r: Recovery =>
      r.recovery_replay_finished()
    else
      Fail()
    end

interface _RecoveryReplayer
  """
  This only exists for testability.
  """
  fun ref _boundary_reconnected(worker: String, boundary_step_id: RoutingId)
  fun ref _wait_for_reconnections(expected_boundaries: Map[String, USize] box,
    reconnected_boundaries: Map[String, SetIs[RoutingId]])
  fun ref _start_replay_phase(expected_boundaries: Map[String, USize] box)
  fun ref _end_replay_phase()
  //!2
  // fun ref _clear_deduplication_lists()

trait _ReplayPhase
  fun name(): String
  fun ref add_expected_boundary_count(worker: String, count: USize) ? =>
    error
  fun ref add_reconnected_boundary(worker: String, boundary_id: RoutingId) ? =>
    error
  fun ref add_boundary_replay_complete(worker: String, boundary_id: RoutingId) ? =>
    error

class _EmptyReplayPhase is _ReplayPhase
  fun name(): String => "Empty Replay Phase"

class _AwaitingRecoveryReplayStart is _ReplayPhase
  let _replayer: _RecoveryReplayer ref

  new create(replayer: _RecoveryReplayer ref) =>
    _replayer = replayer

  fun name(): String => "Awaiting Recovery Replay Phase"

  fun ref add_reconnected_boundary(worker: String, boundary_step_id: RoutingId) =>
    _replayer._boundary_reconnected(worker, boundary_step_id)

class _ReadyForNormalProcessing is _ReplayPhase
  let _replayer: _RecoveryReplayer ref

  new create(replayer: _RecoveryReplayer ref) =>
    _replayer = replayer

  fun name(): String => "Not Recovery Replaying Phase"

  fun ref add_reconnected_boundary(worker: String, boundary_id: RoutingId) =>
    None

  fun ref add_boundary_replay_complete(worker: String, boundary_id: RoutingId) =>
    //!@ Do we need this anymore?
    None
    // If we experience a replay outside recovery, then we can immediately
    // clear deduplication lists when it's complete
    // _replayer._clear_deduplication_lists()

class _WaitingForBoundaryCounts is _ReplayPhase
  let _expected_workers: SetIs[String]
  let _expected_boundaries: Map[String, USize] = _expected_boundaries.create()
  var _reconnected_boundaries: Map[String, SetIs[RoutingId]]
  let _replayer: _RecoveryReplayer ref

  new create(expected_workers: SetIs[String],
    reconnected_boundaries: Map[String, SetIs[RoutingId]],
    replayer: _RecoveryReplayer ref)
  =>
    _expected_workers = expected_workers
    _reconnected_boundaries = reconnected_boundaries
    _replayer = replayer

  fun name(): String => "Waiting for Boundary Counts Phase"

  fun ref add_expected_boundary_count(worker: String, count: USize) =>
    ifdef debug then
      // This should only be called once per worker
      Invariant(not _expected_boundaries.contains(worker))
    end
    _expected_boundaries(worker) = count
    if not _reconnected_boundaries.contains(worker) then
      _reconnected_boundaries(worker) = SetIs[U128]
    end
    if SetHelpers[String].forall(_expected_workers,
      {(w: String)(_expected_boundaries): Bool =>
        _expected_boundaries.contains(w)})
    then
      _replayer._wait_for_reconnections(_expected_boundaries,
        _reconnected_boundaries)
    end

  fun ref add_reconnected_boundary(worker: String, boundary_id: RoutingId) ? =>
    _reconnected_boundaries(worker)?.set(boundary_id)

class _WaitForReconnections is _ReplayPhase
  let _expected_boundaries: Map[String, USize] box
  var _reconnected_boundaries: Map[String, SetIs[RoutingId]]
  let _replayer: _RecoveryReplayer ref

  new create(expected_boundaries: Map[String, USize] box,
    reconnected_boundaries: Map[String, SetIs[RoutingId]],
    replayer: _RecoveryReplayer ref)
  =>
    _expected_boundaries = expected_boundaries
    _reconnected_boundaries = reconnected_boundaries
    _replayer = replayer
    if _all_boundaries_reconnected() then
      _replayer._start_replay_phase(_expected_boundaries)
    end

  fun name(): String => "Wait for Reconnections Phase"

  fun ref add_reconnected_boundary(worker: String, boundary_id: RoutingId) ? =>
    _reconnected_boundaries(worker)?.set(boundary_id)
    if _all_boundaries_reconnected() then
      _replayer._start_replay_phase(_expected_boundaries)
    end

  fun _all_boundaries_reconnected(): Bool =>
    CheckCounts[RoutingId](_expected_boundaries, _reconnected_boundaries)

class _Replay is _ReplayPhase
  let _expected_boundaries: Map[String, USize] box
  var _replay_completes: Map[String, SetIs[RoutingId]] =
    _replay_completes.create()
  let _replayer: _RecoveryReplayer ref
  let _data_receivers: DataReceivers

  new create(expected_boundaries: Map[String, USize] box,
    replayer: _RecoveryReplayer ref, data_receivers: DataReceivers)
  =>
    _expected_boundaries = expected_boundaries
    for w in _expected_boundaries.keys() do
      _replay_completes(w) = SetIs[RoutingId]
    end
    _replayer = replayer
    _data_receivers = data_receivers

  fun name(): String => "Replay Phase"

  fun ref add_boundary_replay_complete(worker: String, boundary_id: RoutingId) ? =>
    _replay_completes(worker)?.set(boundary_id)
    if _all_replays_complete(_replay_completes) then
      _data_receivers.start_normal_message_processing()
      _replayer._end_replay_phase()
    end

  fun _all_replays_complete(replay_completes: Map[String, SetIs[U128]]):
    Bool
  =>
    CheckCounts[RoutingId](_expected_boundaries, _replay_completes)

primitive CheckCounts[Counted]
  fun apply(expected_counts: Map[Key, USize] box,
    counted: Map[Key, SetIs[Counted]] box): Bool
  =>
    try
      for (key, count) in expected_counts.pairs() do
        ifdef debug then
          Invariant(counted(key)?.size() <= count)
        end
        if counted(key)?.size() < count then
          return false
        end
      end
      return true
    else
      Fail()
      return false
    end
