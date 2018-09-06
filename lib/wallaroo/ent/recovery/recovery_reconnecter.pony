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


actor RecoveryReconnecter
  """
  Phases (if on a recovering worker):
    1) _AwaitingRecoveryReconnectStart: Wait for start_recovery_reconnect() to
       be called. We only enter this phase if we are in recovery mode.
       Otherwise, we go immediately to _ReadyForNormalProcessing.
    2) _WaitingForBoundaryCounts: Wait for every running worker to inform this
       worker of how many boundaries they have incoming to us. We use these
       counts to determine when every incoming boundary has reconnected.
    3) _WaitForReconnections: Wait for every incoming boundary to reconnect.
       If all incoming boundaries are already connected by the time this
       phase begins, immediately move to next phase.
    4) _ReadyForNormalProcessing: Finished reconnect

  ASSUMPTION: Recovery reconnect can happen at most once in the lifecycle of a
    worker.
  """
  let _worker_name: WorkerName
  let _data_service: String
  let _auth: AmbientAuth
  var _reconnect_phase: _ReconnectPhase = _EmptyReconnectPhase
  // We keep track of all steps so we can tell them when to clear
  // their deduplication lists
  let _steps: SetIs[Step] = _steps.create()

  let _data_receivers: DataReceivers
  let _router_registry: RouterRegistry
  let _cluster: Cluster
  var _recovery: (Recovery | None) = None

  var _reconnected_boundaries: Map[WorkerName, SetIs[RoutingId]] =
    _reconnected_boundaries.create()

  new create(auth: AmbientAuth, worker_name: WorkerName, data_service: String,
    data_receivers: DataReceivers, router_registry: RouterRegistry,
    cluster: Cluster, is_recovering: Bool = false)
  =>
    _worker_name = worker_name
    _data_service = data_service
    _auth = auth
    _data_receivers = data_receivers
    _router_registry = router_registry
    _cluster = cluster
    if is_recovering then
      _reconnect_phase = _AwaitingRecoveryReconnectStart(this)
    else
      _reconnect_phase = _ReadyForNormalProcessing(this)
    end
    _data_receivers.subscribe(this)

  be register_step(step: Step) =>
    _steps.set(step)

  be abort_early(worker: WorkerName) =>
    @printf[I32](
      "|~~ -- RecoveryReconnecter ceding control to worker %s -- ~~\n"
        .cstring(), worker.cstring())
    _reconnect_phase = _ReadyForNormalProcessing(this)

  be add_expected_boundary_count(worker: WorkerName, count: USize) =>
    _reconnect_phase.add_expected_boundary_count(worker, count)

  be data_receiver_added(worker: WorkerName, boundary_step_id: RoutingId,
    dr: DataReceiver)
  =>
    try
      _reconnect_phase.add_reconnected_boundary(worker, boundary_step_id)?
    else
      @printf[I32](("RecoveryReconnecter: Tried to add boundary for unknown " +
        "worker %s.\n").cstring(), worker.cstring())
      Fail()
    end

  //////////////////////////
  // Managing Reconnect Phases
  //////////////////////////
  be start_recovery_reconnect(workers: Array[WorkerName] val,
    recovery: Recovery)
  =>
    @printf[I32]("!@ RecoveryReconnecter start_recovery_reconnect with workers\n".cstring())
    //!@
    for w in workers.values() do
      @printf[I32]("!@ -- %s\n".cstring(), w.cstring())
    end

    if single_worker(workers) then
      @printf[I32]("|~~ -- Skipping Reconnect: Only One Worker -- ~~|\n"
        .cstring())
      _reconnect_phase = _ReadyForNormalProcessing(this)
      recovery.recovery_reconnect_finished()
      return
    end
    @printf[I32]("|~~ -- Reconnect Phase 1: Wait for Boundary Counts -- ~~|\n"
      .cstring())
    _recovery = recovery
    let expected_workers: SetIs[WorkerName] = expected_workers.create()
    for w in workers.values() do
      if w != _worker_name then
        @printf[I32]("!@ RecoveryReconnecter: SETTING expected worker %s\n".cstring(), w.cstring())
        expected_workers.set(w)
      end
    end
    _reconnect_phase = _WaitingForBoundaryCounts(expected_workers,
      _reconnected_boundaries, this)

    try
      let msg = ChannelMsgEncoder.request_boundary_count(_worker_name, _auth)?
      _cluster.send_control_to_cluster(msg)
    else
      Fail()
    end

  fun single_worker(workers: Array[WorkerName] val): Bool =>
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

  fun ref _boundary_reconnected(worker: WorkerName,
    boundary_step_id: RoutingId)
  =>
    try
      if not _reconnected_boundaries.contains(worker) then
        _reconnected_boundaries(worker) = SetIs[RoutingId]
      end
      _reconnected_boundaries(worker)?.set(boundary_step_id)
    else
      Fail()
    end

  fun ref _wait_for_reconnections(
    expected_boundaries: Map[WorkerName, USize] box,
    reconnected_boundaries: Map[WorkerName, SetIs[RoutingId]])
  =>
    @printf[I32]("|~~ -- Reconnect Phase 2: Wait for Reconnections -- ~~|\n"
      .cstring())
    _reconnect_phase = _WaitForReconnections(expected_boundaries,
      reconnected_boundaries, this)
    try
      let msg = ChannelMsgEncoder.reconnect_data_port(_worker_name,
        _data_service, _auth)?
      _cluster.send_control_to_cluster(msg)
    else
      Fail()
    end

  fun ref _reconnect_complete() =>
    @printf[I32]("|~~ -- Reconnect COMPLETE -- ~~|\n".cstring())
    _reconnect_phase = _ReadyForNormalProcessing(this)
    match _recovery
    | let r: Recovery =>
      r.recovery_reconnect_finished()
    else
      Fail()
    end

interface _RecoveryReconnecter
  """
  This only exists for testability.
  """
  fun ref _boundary_reconnected(worker: WorkerName,
    boundary_step_id: RoutingId)
  fun ref _wait_for_reconnections(
    expected_boundaries: Map[WorkerName, USize] box,
    reconnected_boundaries: Map[WorkerName, SetIs[RoutingId]])
  fun ref _reconnect_complete()

trait _ReconnectPhase
  fun name(): String
  fun ref add_expected_boundary_count(worker: WorkerName, count: USize) =>
    _invalid_call()
    Fail()

  fun ref add_reconnected_boundary(worker: WorkerName,
    boundary_id: RoutingId) ?
  =>
    _invalid_call()
    Fail()

  fun ref add_boundary_reconnect_complete(worker: WorkerName,
    boundary_id: RoutingId)
  =>
    _invalid_call()
    Fail()

  fun _invalid_call() =>
    @printf[I32]("Invalid call on recovery reconnecter phase %s\n".cstring(),
      name().cstring())

class _EmptyReconnectPhase is _ReconnectPhase
  fun name(): String => "Empty Reconnect Phase"

class _AwaitingRecoveryReconnectStart is _ReconnectPhase
  let _reconnecter: _RecoveryReconnecter ref

  new create(reconnecter: _RecoveryReconnecter ref) =>
    _reconnecter = reconnecter

  fun name(): String => "Awaiting Recovery Reconnect Phase"

  fun ref add_reconnected_boundary(worker: WorkerName,
    boundary_step_id: RoutingId)
  =>
    _reconnecter._boundary_reconnected(worker, boundary_step_id)

class _ReadyForNormalProcessing is _ReconnectPhase
  let _reconnecter: _RecoveryReconnecter ref

  new create(reconnecter: _RecoveryReconnecter ref) =>
    _reconnecter = reconnecter

  fun name(): String => "Not Recovery Reconnecting Phase"

  fun ref add_reconnected_boundary(worker: WorkerName, boundary_id: RoutingId)
  =>
    None

  fun ref add_boundary_reconnect_complete(worker: WorkerName,
    boundary_id: RoutingId)
  =>
    //!@ Do we need this anymore?
    None
    // If we experience a reconnect outside recovery, then we can immediately
    // clear deduplication lists when it's complete
    // _reconnecter._clear_deduplication_lists()

class _WaitingForBoundaryCounts is _ReconnectPhase
  let _expected_workers: SetIs[WorkerName]
  let _expected_boundaries: Map[WorkerName, USize] =
    _expected_boundaries.create()
  var _reconnected_boundaries: Map[WorkerName, SetIs[RoutingId]]
  let _reconnecter: _RecoveryReconnecter ref

  new create(expected_workers: SetIs[WorkerName],
    reconnected_boundaries: Map[WorkerName, SetIs[RoutingId]],
    reconnecter: _RecoveryReconnecter ref)
  =>
    _expected_workers = expected_workers
    _reconnected_boundaries = reconnected_boundaries
    _reconnecter = reconnecter

  fun name(): String => "Waiting for Boundary Counts Phase"

  fun ref add_expected_boundary_count(worker: WorkerName, count: USize) =>
    @printf[I32]("!@ add_expected_boundary_count: w: %s, c: %s\n".cstring(), worker.cstring(), count.string().cstring())
    ifdef debug then
      // This should only be called once per worker
      Invariant(not _expected_boundaries.contains(worker))
    end
    _expected_boundaries(worker) = count
    if not _reconnected_boundaries.contains(worker) then
      _reconnected_boundaries(worker) = SetIs[RoutingId]
    end
    if SetHelpers[WorkerName].forall(_expected_workers,
      {(w: WorkerName)(_expected_boundaries): Bool =>
        _expected_boundaries.contains(w)})
    then
      _reconnecter._wait_for_reconnections(_expected_boundaries,
        _reconnected_boundaries)
    end

  fun ref add_reconnected_boundary(worker: WorkerName,
    boundary_id: RoutingId) ?
  =>
    _reconnected_boundaries.insert_if_absent(worker, SetIs[RoutingId])?
      .set(boundary_id)

class _WaitForReconnections is _ReconnectPhase
  let _expected_boundaries: Map[WorkerName, USize] box
  var _reconnected_boundaries: Map[WorkerName, SetIs[RoutingId]]
  let _reconnecter: _RecoveryReconnecter ref

  new create(expected_boundaries: Map[WorkerName, USize] box,
    reconnected_boundaries: Map[WorkerName, SetIs[RoutingId]],
    reconnecter: _RecoveryReconnecter ref)
  =>
    _expected_boundaries = expected_boundaries
    _reconnected_boundaries = reconnected_boundaries
    _reconnecter = reconnecter
    if _all_boundaries_reconnected() then
      _reconnecter._reconnect_complete()
    end

  fun name(): String => "Wait for Reconnections Phase"

  fun ref add_reconnected_boundary(worker: WorkerName,
    boundary_id: RoutingId) ?
  =>
    _reconnected_boundaries(worker)?.set(boundary_id)
    if _all_boundaries_reconnected() then
      _reconnecter._reconnect_complete()
    end

  fun _all_boundaries_reconnected(): Bool =>
    CheckCounts[RoutingId](_expected_boundaries, _reconnected_boundaries)

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
