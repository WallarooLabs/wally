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
use "wallaroo/core/barrier"
use "wallaroo/core/network"
use "wallaroo/core/checkpoint"
use "wallaroo_labs/collection_helpers"
use "wallaroo_labs/mort"


trait _RecoveryPhase
  fun name(): String

  fun ref start_recovery(workers: Array[WorkerName] val,
    recovery: Recovery ref, with_reconnect: Bool)
  =>
    _invalid_call(); Fail()

  fun ref start_reconnect() =>
    _invalid_call(); Fail()

  fun ref recovery_reconnect_finished() =>
    _invalid_call(); Fail()

  fun ref rollback_prep_complete() =>
    _invalid_call(); Fail()

  fun ref worker_ack_local_keys_rollback(w: WorkerName,
    checkpoint_id: CheckpointId)
  =>
    _invalid_call(); Fail()

  fun ref worker_ack_register_producers(w: WorkerName) =>
    _invalid_call(); Fail()

  fun ref receive_rollback_id(rollback_id: RollbackId) =>
    _invalid_call(); Fail()

  fun ref rollback_barrier_complete(token: CheckpointRollbackBarrierToken) =>
    _invalid_call(); Fail()

  fun ref data_receivers_ack() =>
    _invalid_call(); Fail()

  fun ref ack_recovery_initiated(w: WorkerName) =>
    _invalid_call(); Fail()

  fun ref rollback_complete(worker: WorkerName,
    token: CheckpointRollbackBarrierToken)
  =>
    _invalid_call(); Fail()

  fun ref try_override_recovery(worker: WorkerName,
    rollback_id: RollbackId, recovery: Recovery ref,
    abort_promise: Promise[None])
  =>
    recovery._abort_early(worker)
    abort_promise(None)

  fun _invalid_call() =>
    @printf[I32]("Invalid call on recovery phase %s\n".cstring(),
      name().cstring())

class _AwaitRecovering is _RecoveryPhase
  fun name(): String => "_AwaitRecovering"

  fun ref start_recovery(workers: Array[WorkerName] val,
    recovery: Recovery ref, with_reconnect: Bool)
  =>
    recovery._start_reconnect(workers, with_reconnect)

class _BoundariesReconnect is _RecoveryPhase
  let _recovery_reconnecter: RecoveryReconnecter
  let _workers: Array[WorkerName] val
  let _recovery: Recovery ref
  var _override_worker: WorkerName = ""
  var _highest_rival_rollback_id: RollbackId = 0
  var _abort_promise: (Promise[None] | None) = None

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
    match _abort_promise
    | let p: Promise[None] =>
      p(None)
      _recovery._abort_early(_override_worker)
      return
    end
    _recovery._prepare_rollback()

  fun ref try_override_recovery(worker: WorkerName,
    rollback_id: RollbackId, recovery: Recovery ref,
    abort_promise: Promise[None])
  =>
    @printf[I32](("RECOVERY: Received override recovery message during " +
      "Reconnect Phase. Waiting to cede control until " +
      "boundaries are reconnected.\n").cstring())
    if rollback_id > _highest_rival_rollback_id then
      _highest_rival_rollback_id = rollback_id
      _override_worker = worker
      _abort_promise = abort_promise
    end

class _PrepareRollback is _RecoveryPhase
  let _recovery: Recovery ref

  new create(recovery: Recovery ref) =>
    _recovery = recovery

  fun name(): String => "_PrepareRollback"

  fun ref rollback_prep_complete() =>
    _recovery._rollback_local_keys()

class _RollbackLocalKeys is _RecoveryPhase
  let _recovery: Recovery ref
  let _checkpoint_id: CheckpointId
  let _workers: Array[WorkerName] val
  let _acked_workers: SetIs[WorkerName] = _acked_workers.create()

  new create(recovery: Recovery ref, checkpoint_id: CheckpointId,
    workers: Array[WorkerName] val)
  =>
    _recovery = recovery
    _workers = workers
    _checkpoint_id = checkpoint_id

  fun name(): String => "_RollbackTopology"

  fun ref worker_ack_local_keys_rollback(w: WorkerName, checkpoint_id: CheckpointId)
  =>
    ifdef "checkpoint_trace" then
      @printf[I32]("_RollbackLocalKeys rcvd ack from %s\n".cstring(),
        w.cstring())
    end
    // !TODO!: Should we just ignore misses here (which indicate an
    // overlapping recovery)?
    if checkpoint_id == _checkpoint_id then
      _acked_workers.set(w)
      _check_completion()
    else
      @printf[I32](("_RollbackTopology received topology rollback ack for " +
        "checkpoint %s, but we're waiting for checkpoint %s. Ignoring\n")
        .cstring(), checkpoint_id.string().cstring(),
        _checkpoint_id.string().cstring())
    end

  fun ref _check_completion() =>
    if _workers.size() == _acked_workers.size() then
      _recovery._local_keys_rollback_complete()
    else
      ifdef "checkpoint_trace" then
        @printf[I32]("_RollbackTopology: %s acked out of %s\n".cstring(),
          _acked_workers.size().string().cstring(),
          _workers.size().string().cstring())
      end
    end

class _AwaitRollbackId is _RecoveryPhase
  let _recovery: Recovery ref
  var _abort_promise: (Promise[None] | None) = None
  var _highest_rival_rollback_id: RollbackId = 0
  var _override_worker: WorkerName = ""

  new create(recovery: Recovery ref) =>
    _recovery = recovery

  fun name(): String => "_AwaitRollbackId"

  fun ref receive_rollback_id(rollback_id: RollbackId) =>
    match _abort_promise
    | let p: Promise[None] =>
      if _highest_rival_rollback_id > rollback_id then
        p(None)
        _recovery._abort_early(_override_worker)
        return
      end
    end
    _recovery.request_recovery_initiated_acks(rollback_id)

  fun ref try_override_recovery(worker: WorkerName,
    rollback_id: RollbackId, recovery: Recovery ref,
    abort_promise: Promise[None])
  =>
    @printf[I32](("RECOVERY: Received override recovery message during " +
      "_AwaitRollbackId. Waiting to cede control until " +
      "we determine if we have priority.\n").cstring())
    if rollback_id > _highest_rival_rollback_id then
      _highest_rival_rollback_id = rollback_id
      _abort_promise = abort_promise
      _override_worker = worker
    end

class _AwaitRecoveryInitiatedAcks is _RecoveryPhase
  let _workers: Array[WorkerName] val
  let _recovery: Recovery ref
  let _rollback_id: RollbackId
  let _acked_workers: SetIs[WorkerName] = _acked_workers.create()

  new create(workers: Array[WorkerName] val, recovery: Recovery ref,
    rollback_id: RollbackId)
  =>
    _workers = workers
    _recovery = recovery
    _rollback_id = rollback_id

  fun name(): String => "_AwaitRecoveryInitiatedAcks"

  fun ref ack_recovery_initiated(w: WorkerName) =>
    _acked_workers.set(w)
    check_completion()

  fun ref check_completion() =>
    if _acked_workers.size() == _workers.size() then
      _recovery._recovery_initiated_acks_complete(_rollback_id)
    end

  fun ref try_override_recovery(worker: WorkerName,
    rollback_id: RollbackId, recovery: Recovery ref,
    abort_promise: Promise[None])
  =>
    if rollback_id > _rollback_id then
      recovery._abort_early(worker)
      abort_promise(None)
    end

class _RollbackBarrier is _RecoveryPhase
  let _recovery: Recovery ref

  new create(recovery: Recovery ref) =>
    _recovery = recovery

  fun name(): String => "_RollbackBarrier"

  fun ref rollback_barrier_complete(token: CheckpointRollbackBarrierToken) =>
    _recovery._rollback_barrier_complete(token)

class _AwaitDataReceiversAck is _RecoveryPhase
  let _recovery: Recovery ref
  let _token: CheckpointRollbackBarrierToken

  new create(recovery: Recovery ref, token: CheckpointRollbackBarrierToken) =>
    _recovery = recovery
    _token = token

  fun name(): String => "_AwaitDataReceiversAck"

  fun ref data_receivers_ack() =>
    _recovery._data_receivers_ack_complete(_token)

  fun ref try_override_recovery(worker: WorkerName,
    rollback_id: RollbackId, recovery: Recovery ref,
    abort_promise: Promise[None])
  =>
    if rollback_id > _token.rollback_id then
      recovery._abort_early(worker)
      abort_promise(None)
    end

class _Rollback is _RecoveryPhase
  let _recovery: Recovery ref
  let _token: CheckpointRollbackBarrierToken
  let _workers: Array[WorkerName] box
  let _acked_workers: SetIs[WorkerName] = _acked_workers.create()

  new create(recovery: Recovery ref, token: CheckpointRollbackBarrierToken,
    workers: Array[WorkerName] box)
  =>
    _recovery = recovery
    _token = token
    _workers = workers

  fun name(): String => "_Rollback"

  fun ref rollback_complete(worker: WorkerName,
    token: CheckpointRollbackBarrierToken)
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
    rollback_id: RollbackId, recovery: Recovery ref,
    abort_promise: Promise[None])
  =>
    if rollback_id > _token.rollback_id then
      _recovery._abort_early(worker)
      abort_promise(None)
    end

class _FinishedRecovering is _RecoveryPhase
  fun name(): String => "_FinishedRecovering"

  fun ref start_recovery(workers: Array[WorkerName] val,
    recovery: Recovery ref, with_reconnect: Bool)
  =>
    @printf[I32]("Online recovery initiated.\n".cstring())
    recovery._start_reconnect(workers, with_reconnect)

  fun ref recovery_reconnect_finished() =>
    None

  fun ref try_override_recovery(worker: WorkerName,
    rollback_id: RollbackId, recovery: Recovery ref,
    abort_promise: Promise[None])
  =>
    abort_promise(None)

class _RecoveryOverrideAccepted is _RecoveryPhase
  fun name(): String => "_RecoveryOverrideAccepted"

  fun ref start_recovery(workers: Array[WorkerName] val,
    recovery: Recovery ref, with_reconnect: Bool)
  =>
    @printf[I32]("Online recovery initiated.\n".cstring())
    recovery._start_reconnect(workers, with_reconnect)

  fun ref recovery_reconnect_finished() =>
    None

  fun ref rollback_prep_complete() =>
    None

  fun ref worker_ack_local_keys_rollback(w: WorkerName, checkpoint_id: CheckpointId)
  =>
    None

  fun ref worker_ack_register_producers(w: WorkerName) =>
    None

  fun ref rollback_barrier_complete(token: CheckpointRollbackBarrierToken) =>
    None

  fun ref data_receivers_ack() =>
    None

  fun ref rollback_complete(worker: WorkerName,
    token: CheckpointRollbackBarrierToken)
  =>
    None

  fun ref receive_rollback_id(rollback_id: RollbackId) =>
    None

  fun ref try_override_recovery(worker: WorkerName,
    rollback_id: RollbackId, recovery: Recovery ref,
    abort_promise: Promise[None])
  =>
    abort_promise(None)

  fun ref ack_recovery_initiated(w: WorkerName) =>
    None
