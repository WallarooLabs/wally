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
use "wallaroo/core/barrier"
use "wallaroo/core/boundary"
use "wallaroo/core/checkpoint"
use "wallaroo/core/common"
use "wallaroo/core/initialization"
use "wallaroo/core/invariant"
use "wallaroo/core/messages"
use "wallaroo/core/network"
use "wallaroo_labs/collection_helpers"
use "wallaroo_labs/mort"


trait _RecoveryPhase
  fun name(): String
  fun recovery_reason(): RecoveryReason

  fun ref start_recovery(workers: Array[WorkerName] val,
    recovery: Recovery ref, reason: RecoveryReason)
  =>
    // If a lower priority reason triggers this, then we simply ignore.
    // Otherwise, this should never happen.
    if not RecoveryReasons.has_priority(recovery_reason(), reason) then
      _invalid_call(__loc.method_name()); Fail()
    end

  fun ref start_reconnect() =>
    _invalid_call(__loc.method_name()); Fail()

  fun ref recovery_reconnect_finished() =>
    _invalid_call(__loc.method_name()); Fail()

  fun ref rollback_prep_complete() =>
    _invalid_call(__loc.method_name()); Fail()

  fun ref worker_ack_local_keys_rollback(w: WorkerName,
    checkpoint_id: CheckpointId)
  =>
    // This is called directly in response to a control message received.
    // But we can't guarantee that this message is not a straggler in the case
    // that we crashed during an earlier round of recovery/rollback. So we
    // can only log and ignore here.
    _unexpected_call(__loc.method_name())

  fun ref inform_of_boundaries_map(obs: Map[WorkerName, OutgoingBoundary] val)
  =>
    _invalid_call(__loc.method_name()); Fail()

  fun ref boundary_acked_registering(b: OutgoingBoundary) =>
    _invalid_call(__loc.method_name()); Fail()

  fun ref data_receivers_acked_registering() =>
    _unexpected_call(__loc.method_name())

  fun ref receive_rollback_id(rollback_id: RollbackId) =>
    // This is called directly in response to a control message received.
    // But we can't guarantee that this message is not a straggler in the case
    // that we crashed during an earlier round of recovery/rollback. So we
    // can only log and ignore here.
    _unexpected_call(__loc.method_name())

  fun ref rollback_barrier_complete(token: CheckpointRollbackBarrierToken) =>
    _unexpected_call(__loc.method_name())

  fun ref data_receivers_ack() =>
    _invalid_call(__loc.method_name()); Fail()

  fun ref ack_recovery_initiated(w: WorkerName) =>
    // This is called directly in response to a control message received.
    // But we can't guarantee that this message is not a straggler in the case
    // that we crashed during an earlier round of recovery/rollback. So we
    // can only log and ignore here.
    _unexpected_call(__loc.method_name())

  fun ref data_receivers_acked_accepting_barriers() =>
    _invalid_call(__loc.method_name()); Fail()

  fun ref rollback_complete(worker: WorkerName,
    token: CheckpointRollbackBarrierToken)
  =>
    // This is called directly in response to a control message received.
    // But we can't guarantee that this message is not a straggler in the case
    // that we crashed during an earlier round of recovery/rollback. So we
    // can only log and ignore here.
    _unexpected_call(__loc.method_name())

  fun ref try_override_recovery(worker: WorkerName,
    rollback_id: RollbackId, reason: RecoveryReason, recovery: Recovery ref,
    abort_promise: Promise[None])
  =>
    if not RecoveryReasons.has_priority(recovery_reason(), reason)
    then
      recovery._abort_early(worker)
      abort_promise(None)
    end

  fun _invalid_call(method_name: String) =>
    @printf[I32]("Invalid call to %s on recovery phase %s\n".cstring(),
      method_name.cstring(), name().cstring())

  fun _unexpected_call(method_name: String) =>
    """
    Only call this for phase methods that are called directly in response to
    control messages received. That's because we can't be sure in that case if
    we had crashed and recovered during an earlier recovery/rollback round, in
    which case any control messages related to that earlier round are simply
    outdated. We shouldn't Fail() in this case because we can expect control
    messages to go out of sync in this way in this kind of scenario.

    TODO: All such control messages could be tagged with a rollback id,
    enabling us to determine at the Recovery actor level if we should drop
    such a message or send it to our current phase. This would mean we'd have
    to ignore anything we receive before we get an initial rollback id, which
    takes place after at least one phase that waits for a control message, so
    there are problems to be solved in order to do this safely.
    """
    @printf[I32]("UNEXPECTED CALL to %s on recovery phase %s. Ignoring!\n"
      .cstring(), method_name.cstring(), name().cstring())

  fun _print_phase_transition() =>
    ifdef debug then
      @printf[I32]("_RecoveryPhase transition to %s\n".cstring(),
        name().string().cstring())
    end

class _AwaitRecovering is _RecoveryPhase
  let _initial_recovery_reason: RecoveryReason
  let _recovery_priority_tracker: RecoveryPriorityTracker

  new create(reason: RecoveryReason) =>
    _initial_recovery_reason = reason
    _recovery_priority_tracker = RecoveryPriorityTracker(reason)
    _print_phase_transition()

  fun name(): String => __loc.type_name()
  fun recovery_reason(): RecoveryReason => _initial_recovery_reason

  fun ref start_recovery(workers: Array[WorkerName] val,
    recovery: Recovery ref, reason: RecoveryReason)
  =>
    // We can override the initial recovery reason here, in the case where
    // we started up normally but are aborting a checkpoint, for example.
    recovery._start_reconnect(workers, reason, _recovery_priority_tracker)

  fun ref try_override_recovery(worker: WorkerName,
    rollback_id: RollbackId, reason: RecoveryReason, recovery: Recovery ref,
    abort_promise: Promise[None])
  =>
    if RecoveryReasons.is_recovering_worker(_initial_recovery_reason) then
      // If we're a recovering worker, we need to get through boundary
      // connection and producer registration phases before we cede control.
      _recovery_priority_tracker.try_override(worker, rollback_id, reason,
        recovery, abort_promise)
    else
      if not RecoveryReasons.has_priority(_initial_recovery_reason, reason)
      then
        recovery._abort_early(worker)
        abort_promise(None)
      end
    end

class _BoundariesReconnect is _RecoveryPhase
  let _recovery_reason: RecoveryReason
  let _recovery_reconnecter: RecoveryReconnecter
  let _workers: Array[WorkerName] val
  let _recovery: Recovery ref
  let _recovery_priority_tracker: RecoveryPriorityTracker

  new create(recovery_reconnecter: RecoveryReconnecter,
    workers: Array[WorkerName] val, recovery: Recovery ref,
    reason: RecoveryReason, recovery_priority_tracker: RecoveryPriorityTracker)
  =>
    _recovery_reason = reason
    _recovery_reconnecter = recovery_reconnecter
    _workers = workers
    _recovery = recovery
    _recovery_priority_tracker = recovery_priority_tracker
    _print_phase_transition()

  fun name(): String => __loc.type_name()
  fun recovery_reason(): RecoveryReason => _recovery_reason

  fun ref start_recovery(workers: Array[WorkerName] val,
    recovery: Recovery ref, reason: RecoveryReason)
  =>
    // E.g., immediately after "Online recovery initiated." and
    // "Reconnect Phase 1: Wait for Boundary Counts"
    _unexpected_call(__loc.method_name())

  fun ref start_reconnect() =>
    _recovery_reconnecter.start_recovery_reconnect(_workers, _recovery)

  fun ref recovery_reconnect_finished() =>
    _recovery.request_boundaries_map(_recovery_reason,
      _recovery_priority_tracker)

  fun ref try_override_recovery(worker: WorkerName,
    rollback_id: RollbackId, reason: RecoveryReason, recovery: Recovery ref,
    abort_promise: Promise[None])
  =>
    _recovery_priority_tracker.try_override(worker, rollback_id, reason,
      recovery, abort_promise)

class _WaitingForBoundariesMap is _RecoveryPhase
  let _recovery_reason: RecoveryReason
  let _recovery: Recovery ref
  let _recovery_priority_tracker: RecoveryPriorityTracker

  new create(recovery: Recovery ref, reason: RecoveryReason,
    recovery_priority_tracker: RecoveryPriorityTracker)
  =>
    @printf[I32](("RECOVERY: Waiting for list of Producers\n").cstring())
    _recovery_reason = reason
    _recovery = recovery
    _recovery_priority_tracker = recovery_priority_tracker
    _print_phase_transition()

  fun name(): String => __loc.type_name()
  fun recovery_reason(): RecoveryReason => _recovery_reason

  fun ref inform_of_boundaries_map(obs: Map[WorkerName, OutgoingBoundary] val)
  =>
    let obs_set = SetIs[OutgoingBoundary]
    for b in obs.values() do
      obs_set.set(b)
    end
    _recovery.request_boundaries_to_ack_registering(obs_set, _recovery_reason,
      _recovery_priority_tracker)

  fun ref try_override_recovery(worker: WorkerName,
    rollback_id: RollbackId, reason: RecoveryReason, recovery: Recovery ref,
    abort_promise: Promise[None])
  =>
    _recovery_priority_tracker.try_override(worker, rollback_id, reason,
      recovery, abort_promise)

class _WaitingForBoundariesToAckRegistering is _RecoveryPhase
  let _recovery_reason: RecoveryReason
  let _recovery: Recovery ref
  let _recovery_priority_tracker: RecoveryPriorityTracker
  let _boundaries: SetIs[OutgoingBoundary] = _boundaries.create()
  let _acked_boundaries: SetIs[OutgoingBoundary] =
    _acked_boundaries.create()
  var _data_receivers_acked: Bool = false

  new create(recovery: Recovery ref, boundaries: SetIs[OutgoingBoundary],
    reason: RecoveryReason, recovery_priority_tracker: RecoveryPriorityTracker)
  =>
    @printf[I32](("RECOVERY: Worker waiting for boundaries " +
      "to ack forwarding register messages\n").cstring())
    _recovery_reason = reason
    _recovery = recovery
    _recovery_priority_tracker = recovery_priority_tracker
    for b in boundaries.values() do
      _boundaries.set(b)
    end
    Invariant(_boundaries.size() > 0)
    _print_phase_transition()

  fun name(): String => __loc.type_name()
  fun recovery_reason(): RecoveryReason => _recovery_reason

  fun ref boundary_acked_registering(b: OutgoingBoundary) =>
    _acked_boundaries.set(b)
    _check_complete()

  fun ref data_receivers_acked_registering() =>
    _data_receivers_acked = true
    _check_complete()

  fun ref try_override_recovery(worker: WorkerName,
    rollback_id: RollbackId, reason: RecoveryReason, recovery: Recovery ref,
    abort_promise: Promise[None])
  =>
    _recovery_priority_tracker.try_override(worker, rollback_id, reason,
      recovery, abort_promise)
    if _recovery_priority_tracker.has_override() then
      // If we're overridden here, that means another worker has probably
      // crashed and restarted since we started recovering. We need to
      // start this phase over to rerequest boundary acks.
      _recovery.request_boundaries_to_ack_registering(_boundaries,
        _recovery_reason, _recovery_priority_tracker)
    end

  fun ref _check_complete() =>
    if (_boundaries.size() == _acked_boundaries.size()) and
      _data_receivers_acked
    then
      _recovery._prepare_rollback(_recovery_reason, _recovery_priority_tracker)
    end

class _PrepareRollback is _RecoveryPhase
  let _recovery_reason: RecoveryReason
  let _recovery: Recovery ref

  new create(recovery: Recovery ref, reason: RecoveryReason) =>
    _recovery_reason = reason
    _recovery = recovery
    _print_phase_transition()

  fun name(): String => __loc.type_name()
  fun recovery_reason(): RecoveryReason => _recovery_reason

  fun ref rollback_prep_complete() =>
    _recovery._rollback_local_keys(_recovery_reason)

class _RollbackLocalKeys is _RecoveryPhase
  let _recovery_reason: RecoveryReason
  let _recovery: Recovery ref
  let _checkpoint_id: CheckpointId
  let _workers: Array[WorkerName] val
  let _acked_workers: SetIs[WorkerName] = _acked_workers.create()

  new create(recovery: Recovery ref, checkpoint_id: CheckpointId,
    workers: Array[WorkerName] val, reason: RecoveryReason)
  =>
    _recovery_reason = reason
    _recovery = recovery
    _workers = workers
    _checkpoint_id = checkpoint_id
    _print_phase_transition()

  fun name(): String => __loc.type_name()
  fun recovery_reason(): RecoveryReason => _recovery_reason

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
      _recovery._local_keys_rollback_complete(_recovery_reason)
    else
      ifdef "checkpoint_trace" then
        @printf[I32]("_RollbackTopology: %s acked out of %s\n".cstring(),
          _acked_workers.size().string().cstring(),
          _workers.size().string().cstring())
      end
    end

class _AwaitRollbackId is _RecoveryPhase
  let _recovery_reason: RecoveryReason
  let _recovery: Recovery ref
  var _abort_promise: (Promise[None] | None) = None
  var _highest_rival_rollback_id: RollbackId = 0
  var _override_worker: WorkerName = ""

  new create(recovery: Recovery ref, reason: RecoveryReason) =>
    _recovery_reason = reason
    _recovery = recovery
    _print_phase_transition()

  fun name(): String => __loc.type_name()
  fun recovery_reason(): RecoveryReason => _recovery_reason

  fun ref receive_rollback_id(rollback_id: RollbackId) =>
    _recovery.request_recovery_initiated_acks(rollback_id, _recovery_reason)

  fun ref try_override_recovery(worker: WorkerName,
    rollback_id: RollbackId, reason: RecoveryReason, recovery: Recovery ref,
    abort_promise: Promise[None])
  =>
    if not RecoveryReasons.has_priority(_recovery_reason, reason) then
      abort_promise(None)
      _recovery._abort_early(worker)
    end

class _AwaitRecoveryInitiatedAcks is _RecoveryPhase
  let _recovery_reason: RecoveryReason
  let _workers: Array[WorkerName] val
  let _recovery: Recovery ref
  let _rollback_id: RollbackId
  let _acked_workers: SetIs[WorkerName] = _acked_workers.create()

  new create(workers: Array[WorkerName] val, recovery: Recovery ref,
    rollback_id: RollbackId, reason: RecoveryReason)
  =>
    _recovery_reason = reason
    _workers = workers
    _recovery = recovery
    _rollback_id = rollback_id
    _print_phase_transition()

  fun name(): String => __loc.type_name()
  fun recovery_reason(): RecoveryReason => _recovery_reason

  fun ref ack_recovery_initiated(w: WorkerName) =>
    _acked_workers.set(w)
    check_completion()

  fun ref check_completion() =>
    if _acked_workers.size() == _workers.size() then
      _recovery._recovery_initiated_acks_complete(_rollback_id,
        _recovery_reason)
    end

  fun ref try_override_recovery(worker: WorkerName,
    rollback_id: RollbackId, reason: RecoveryReason, recovery: Recovery ref,
    abort_promise: Promise[None])
  =>
    if RecoveryReasons.has_priority(reason, _recovery_reason) or
       (not RecoveryReasons.has_priority(_recovery_reason, reason) and
         (rollback_id > _rollback_id))
    then
      recovery._abort_early(worker)
      abort_promise(None)
    end

class _WaitForDataReceiversAcceptBarriersAcks is _RecoveryPhase
  let _recovery_reason: RecoveryReason
  let _recovery: Recovery ref
  let _rollback_id: RollbackId

  new create(recovery: Recovery ref, rollback_id: RollbackId,
    reason: RecoveryReason)
  =>
    _recovery_reason = reason
    _recovery = recovery
    _rollback_id = rollback_id
    _print_phase_transition()

  fun name(): String => __loc.type_name()
  fun recovery_reason(): RecoveryReason => _recovery_reason

  fun ref data_receivers_acked_accepting_barriers() =>
    _recovery._data_receivers_accepting_barriers(_rollback_id,
      _recovery_reason)

  fun ref try_override_recovery(worker: WorkerName,
    rollback_id: RollbackId, reason: RecoveryReason, recovery: Recovery ref,
    abort_promise: Promise[None])
  =>
    if RecoveryReasons.has_priority(reason, _recovery_reason) or
       (not RecoveryReasons.has_priority(_recovery_reason, reason) and
         (rollback_id > _rollback_id))
    then
      recovery._abort_early(worker)
      abort_promise(None)
    end

class _RollbackBarrier is _RecoveryPhase
  let _recovery_reason: RecoveryReason
  let _recovery: Recovery ref
  let _rollback_id: RollbackId

  new create(recovery: Recovery ref, rollback_id: RollbackId,
    reason: RecoveryReason)
  =>
    _recovery_reason = reason
    _recovery = recovery
    _rollback_id = rollback_id
    _print_phase_transition()

  fun name(): String => __loc.type_name()
  fun recovery_reason(): RecoveryReason => _recovery_reason

  fun ref rollback_barrier_complete(token: CheckpointRollbackBarrierToken) =>
    _recovery._rollback_barrier_complete(token, _recovery_reason)

  fun ref try_override_recovery(worker: WorkerName,
    rollback_id: RollbackId, reason: RecoveryReason, recovery: Recovery ref,
    abort_promise: Promise[None])
  =>
    if RecoveryReasons.has_priority(reason, _recovery_reason) or
       (not RecoveryReasons.has_priority(_recovery_reason, reason) and
         (rollback_id > _rollback_id))
    then
      recovery._abort_early(worker)
      abort_promise(None)
    end

class _AwaitDataReceiversAck is _RecoveryPhase
  let _recovery_reason: RecoveryReason
  let _recovery: Recovery ref
  let _token: CheckpointRollbackBarrierToken

  new create(recovery: Recovery ref, token: CheckpointRollbackBarrierToken,
    reason: RecoveryReason)
  =>
    _recovery_reason = reason
    _recovery = recovery
    _token = token
    _print_phase_transition()

  fun name(): String => __loc.type_name()
  fun recovery_reason(): RecoveryReason => _recovery_reason

  fun ref data_receivers_ack() =>
    _recovery._data_receivers_ack_complete(_token, _recovery_reason)

  fun ref try_override_recovery(worker: WorkerName,
    rollback_id: RollbackId, reason: RecoveryReason, recovery: Recovery ref,
    abort_promise: Promise[None])
  =>
    if RecoveryReasons.has_priority(reason, _recovery_reason) or
       (not RecoveryReasons.has_priority(_recovery_reason, reason) and
         (rollback_id > _token.rollback_id))
    then
      recovery._abort_early(worker)
      abort_promise(None)
    end

class _Rollback is _RecoveryPhase
  let _recovery_reason: RecoveryReason
  let _recovery: Recovery ref
  let _token: CheckpointRollbackBarrierToken
  let _workers: Array[WorkerName] box
  let _acked_workers: SetIs[WorkerName] = _acked_workers.create()

  new create(recovery: Recovery ref, token: CheckpointRollbackBarrierToken,
    workers: Array[WorkerName] box, reason: RecoveryReason)
  =>
    _recovery_reason = reason
    _recovery = recovery
    _token = token
    _workers = workers
    _print_phase_transition()

  fun name(): String => __loc.type_name()
  fun recovery_reason(): RecoveryReason => _recovery_reason

  fun ref rollback_complete(worker: WorkerName,
    token: CheckpointRollbackBarrierToken)
  =>
    ifdef debug then
      Invariant(token == _token)
      Invariant(ArrayHelpers[String].contains[String](_workers, worker))
    end
    _acked_workers.set(worker)
    if _acked_workers.size() == _workers.size() then
      _recovery._recovery_complete(token.rollback_id, token.checkpoint_id,
        _recovery_reason)
    end

  fun ref try_override_recovery(worker: WorkerName,
    rollback_id: RollbackId, reason: RecoveryReason, recovery: Recovery ref,
    abort_promise: Promise[None])
  =>
    if RecoveryReasons.has_priority(reason, _recovery_reason) or
       (not RecoveryReasons.has_priority(_recovery_reason, reason) and
         (rollback_id > _token.rollback_id))
    then
      _recovery._abort_early(worker)
      abort_promise(None)
    end

class _NotRecovering is _RecoveryPhase
  fun name(): String => __loc.type_name()
  fun recovery_reason(): RecoveryReason => RecoveryReasons.not_recovering()

  new create() =>
    _print_phase_transition()

  fun ref start_recovery(workers: Array[WorkerName] val,
    recovery: Recovery ref, reason: RecoveryReason)
  =>
    @printf[I32]("Online recovery initiated.\n".cstring())
    recovery._start_reconnect(workers, reason, RecoveryPriorityTracker(reason))

  fun ref recovery_reconnect_finished() =>
    None

  fun ref rollback_prep_complete() =>
    None

  fun ref worker_ack_local_keys_rollback(w: WorkerName, checkpoint_id: CheckpointId)
  =>
    None

  fun ref inform_of_boundaries_map(obs: Map[WorkerName, OutgoingBoundary] val)
  =>
    None

  fun ref boundary_acked_registering(b: OutgoingBoundary) =>
    None

  fun ref data_receivers_acked_registering() =>
    None

  fun ref data_receivers_acked_accepting_barriers() =>
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
    rollback_id: RollbackId, reason: RecoveryReason, recovery: Recovery ref,
    abort_promise: Promise[None])
  =>
    abort_promise(None)

  fun ref ack_recovery_initiated(w: WorkerName) =>
    None
