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
use "wallaroo/ent/barrier"
use "wallaroo/ent/network"
use "wallaroo/ent/snapshot"
use "wallaroo_labs/collection_helpers"
use "wallaroo_labs/mort"


trait _RecoveryPhase
  fun name(): String

  fun ref start_recovery(workers: Array[WorkerName] val,
    recovery: Recovery ref)
  =>
    _invalid_call()
    Fail()

  fun ref start_reconnect() =>
    _invalid_call()
    Fail()

  fun ref recovery_reconnect_finished() =>
    _invalid_call()
    Fail()

  fun ref rollback_prep_complete() =>
    _invalid_call()
    Fail()

  fun ref worker_ack_topology_rollback(w: WorkerName, snapshot_id: SnapshotId)
  =>
    _invalid_call()
    Fail()

  fun ref worker_ack_register_producers(w: WorkerName) =>
    _invalid_call()
    Fail()

  fun ref rollback_barrier_complete(token: SnapshotRollbackBarrierToken) =>
    _invalid_call()
    Fail()

  fun ref data_receivers_ack() =>
    _invalid_call()
    Fail()

  fun ref ack_recovery_initiated(w: WorkerName,
    token: SnapshotRollbackBarrierToken)
  =>
    _invalid_call()
    Fail()

  fun ref rollback_complete(worker: WorkerName,
    token: SnapshotRollbackBarrierToken)
  =>
    _invalid_call()
    Fail()

  fun ref try_override_recovery(worker: WorkerName,
    token: SnapshotRollbackBarrierToken, recovery: Recovery ref): Bool
  =>
    recovery._abort_early(worker)
    true

  fun _invalid_call() =>
    @printf[I32]("Invalid call on recovery phase %s\n".cstring(),
      name().cstring())

class _AwaitRecovering is _RecoveryPhase
  fun name(): String => "_AwaitRecovering"

  fun ref start_recovery(workers: Array[WorkerName] val,
    recovery: Recovery ref)
  =>
    recovery._start_reconnect(workers)

class _BoundariesReconnect is _RecoveryPhase
  let _recovery_reconnecter: RecoveryReconnecter
  let _workers: Array[WorkerName] val
  let _recovery: Recovery ref
  var _override_received: Bool = false
  var _override_worker: WorkerName = ""

  new create(recovery_reconnecter: RecoveryReconnecter,
    workers: Array[WorkerName] val, recovery: Recovery ref)
  =>
    _recovery_reconnecter = recovery_reconnecter
    _workers = workers
    _recovery = recovery

  fun name(): String => "_BoundariesReconnect"

  fun ref start_reconnect() =>
    _recovery_reconnecter.start_recovery_reconnect(_workers, _recovery)

  fun ref recovery_reconnect_finished() =>
    if not _override_received then
      _recovery._prepare_rollback()
    else
      _recovery._abort_early(_override_worker)
    end

  fun ref try_override_recovery(worker: WorkerName,
    token: SnapshotRollbackBarrierToken, recovery: Recovery ref): Bool
  =>
    _override_received = true
    _override_worker = worker
    true

class _PrepareRollback is _RecoveryPhase
  let _recovery: Recovery ref

  new create(recovery: Recovery ref) =>
    _recovery = recovery

  fun name(): String => "_PrepareRollback"

  fun ref rollback_prep_complete() =>
    _recovery._rollback_prep_complete()

class _RollbackTopology is _RecoveryPhase
  let _recovery: Recovery ref
  let _snapshot_id: SnapshotId
  let _workers: Array[WorkerName] val
  let _acked_workers: SetIs[WorkerName] = _acked_workers.create()

  new create(recovery: Recovery ref, snapshot_id: SnapshotId,
    workers: Array[WorkerName] val)
  =>
    _recovery = recovery
    _workers = workers
    _snapshot_id = snapshot_id

  fun name(): String => "_RollbackTopology"

  fun ref worker_ack_topology_rollback(w: WorkerName, snapshot_id: SnapshotId)
  =>
    @printf[I32]("!@ _RollbackTopology rcvd ack from %s\n".cstring(), w.cstring())
    //!@ Should we just ignore misses here (which indicate an overlapping
    // recovery)?
    if snapshot_id == _snapshot_id then
      _acked_workers.set(w)
      _check_completion()
    else
      @printf[I32](("_RollbackTopology received topology rollback ack for " +
        "snapshot %s, but we're waiting for snapshot %s. Ignoring\n")
        .cstring(), snapshot_id.string().cstring(),
        _snapshot_id.string().cstring())
    end

  fun ref _check_completion() =>
    if _workers.size() == _acked_workers.size() then
      _recovery._topology_rollback_complete()
    //!@
    else
      @printf[I32]("!@ _RollbackTopology: %s acked out of %s\n".cstring(), _acked_workers.size().string().cstring(), _workers.size().string().cstring())
    end

class _RegisterProducers is _RecoveryPhase
  let _recovery: Recovery ref
  let _workers: Array[WorkerName] val
  let _acked_workers: SetIs[WorkerName] = _acked_workers.create()

  new create(recovery: Recovery ref, workers: Array[WorkerName] val) =>
    _recovery = recovery
    _workers = workers

  fun name(): String => "_RegisterProducers"

  fun ref worker_ack_register_producers(w: WorkerName) =>
    _acked_workers.set(w)
    _check_completion()

  fun ref _check_completion() =>
    if _workers.size() == _acked_workers.size() then
      _recovery._register_producers_complete()
    //!@
    else
      @printf[I32]("!@ _RegisterProducers: %s acked out of %s\n".cstring(), _acked_workers.size().string().cstring(), _workers.size().string().cstring())
    end

class _RollbackBarrier is _RecoveryPhase
  let _recovery: Recovery ref

  new create(recovery: Recovery ref) =>
    _recovery = recovery

  fun name(): String => "_RollbackBarrier"

  fun ref rollback_barrier_complete(token: SnapshotRollbackBarrierToken) =>
    _recovery._rollback_barrier_complete(token)

class _AwaitDataReceiversAck is _RecoveryPhase
  let _recovery: Recovery ref
  let _token: SnapshotRollbackBarrierToken

  new create(recovery: Recovery ref, token: SnapshotRollbackBarrierToken) =>
    _recovery = recovery
    _token = token

  fun name(): String => "_AwaitDataReceiversAck"

  fun ref data_receivers_ack() =>
    _recovery._data_receivers_ack_complete(_token)

class _AwaitRecoveryInitiatedAcks is _RecoveryPhase
  let _workers: Array[WorkerName] val
  let _token: SnapshotRollbackBarrierToken
  let _recovery: Recovery ref
  let _acked_workers: SetIs[WorkerName] = _acked_workers.create()

  new create(token: SnapshotRollbackBarrierToken,
    workers: Array[WorkerName] val, recovery: Recovery ref)
  =>
    _token = token
    _workers = workers
    _recovery = recovery

  fun name(): String => "_AwaitRecoveryInitiatedAcks"

  fun ref ack_recovery_initiated(w: WorkerName,
    token: SnapshotRollbackBarrierToken)
  =>
    if token != _token then
      Fail()
    end
    _acked_workers.set(w)
    if _acked_workers.size() == _workers.size() then
      _recovery._recovery_initiated_acks_complete(_token)
    end

class _Rollback is _RecoveryPhase
  let _recovery: Recovery ref
  let _token: SnapshotRollbackBarrierToken
  let _workers: Array[WorkerName] box
  let _acked_workers: SetIs[WorkerName] = _acked_workers.create()

  new create(recovery: Recovery ref, token: SnapshotRollbackBarrierToken,
    workers: Array[WorkerName] box)
  =>
    _recovery = recovery
    _token = token
    _workers = workers

  fun name(): String => "_Rollback"

  fun ref rollback_complete(worker: WorkerName,
    token: SnapshotRollbackBarrierToken)
  =>
    ifdef debug then
      Invariant(token == _token)
      Invariant(ArrayHelpers[String].contains[String](_workers, worker))
    end
    _acked_workers.set(worker)
    if _acked_workers.size() == _workers.size() then
      _recovery._recovery_complete()
    end

  fun ref try_override_recovery(worker: WorkerName,
    token: SnapshotRollbackBarrierToken, recovery: Recovery ref): Bool
  =>
    if token > _token then
      _recovery._abort_early(worker)
      true
    else
      false
    end

class _FinishedRecovering is _RecoveryPhase
  fun name(): String => "_FinishedRecovering"

  fun ref recovery_reconnect_finished() =>
    None

  fun ref try_override_recovery(worker: WorkerName,
    token: SnapshotRollbackBarrierToken, recovery: Recovery ref): Bool
  =>
    true

class _RecoveryOverrideAccepted is _RecoveryPhase
  fun name(): String => "_RecoveryOverrideAccepted"

  fun ref recovery_reconnect_finished() =>
    None

  fun ref rollback_prep_complete() =>
    None

  fun ref worker_ack_topology_rollback(w: WorkerName, snapshot_id: SnapshotId)
  =>
    None

  fun ref rollback_barrier_complete(token: SnapshotRollbackBarrierToken) =>
    None

  fun ref data_receivers_ack() =>
    None

  fun ref rollback_complete(worker: WorkerName,
    token: SnapshotRollbackBarrierToken)
  =>
    None

  fun ref try_override_recovery(worker: WorkerName,
    token: SnapshotRollbackBarrierToken, recovery: Recovery ref): Bool
  =>
    true

  fun ref ack_recovery_initiated(w: WorkerName,
    token: SnapshotRollbackBarrierToken)
  =>
    None
