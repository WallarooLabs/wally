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

  fun ref rollback_prep_complete(token: SnapshotRollbackBarrierToken) =>
    _invalid_call()
    Fail()

  fun ref rollback_complete(worker: WorkerName,
    token: SnapshotRollbackBarrierToken)
  =>
    _invalid_call()
    Fail()

  fun ref try_override_recovery(worker: WorkerName,
    token: SnapshotRollbackBarrierToken, recovery: Recovery ref)
  =>
    recovery._abort_early(worker)

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
      _recovery._initiate_rollback()
    else
      _recovery._abort_early(_override_worker)
    end

  fun ref try_override_recovery(worker: WorkerName,
    token: SnapshotRollbackBarrierToken, recovery: Recovery ref)
  =>
    _override_received = true
    _override_worker = worker

class _PrepareRollback is _RecoveryPhase
  let _recovery: Recovery ref

  new create(recovery: Recovery ref) =>
    _recovery = recovery

  fun name(): String => "_PrepareRollback"

  fun ref rollback_prep_complete(token: SnapshotRollbackBarrierToken) =>
    _recovery._rollback_prep_complete(token)

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
    token: SnapshotRollbackBarrierToken, recovery: Recovery ref)
  =>
    if token > _token then
      _recovery._abort_early(worker)
    end

class _FinishedRecovering is _RecoveryPhase
  fun name(): String => "_FinishedRecovering"
