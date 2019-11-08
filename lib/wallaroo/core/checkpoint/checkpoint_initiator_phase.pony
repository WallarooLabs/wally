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
use "wallaroo/core/invariant"
use "wallaroo/core/barrier"
use "wallaroo_labs/collection_helpers"
use "wallaroo_labs/mort"


trait _CheckpointInitiatorPhase
  fun name(): String

  fun ref start_checkpoint_timer(time_until_next_checkpoint: U64,
    checkpoint_group: USize, checkpoint_initiator: CheckpointInitiator ref,
    checkpoint_promise: (Promise[None] | None) = None)
  =>
    _invalid_call(__loc.method_name()); Fail()

  fun ref initiate_checkpoint(checkpoint_group: USize,
    checkpoint_promise: Promise[None],
    checkpoint_initiator: CheckpointInitiator ref)
  =>
    """
    Currently, we do not allow two checkpoints to be in flight at once. If a
    timer goes off while one is in progress, we ignore it for now. We only
    initiate a checkpoint from _WaitingCheckpointInitiatorPhase.
    """
    @printf[I32](("CheckpointInitiator: Attempted to initiate checkpoint in " +
      "phase " + name() + "\n").cstring())
    None

  fun ref checkpoint_barrier_complete(token: BarrierToken) =>
    _invalid_call(__loc.method_name()); Fail()

  fun ref event_log_checkpoint_complete(worker: WorkerName,
    checkpoint_id: CheckpointId)
  =>
    // This is called directly in response to a control message received.
    // But we can't guarantee that this message is not a straggler in the case
    // that we crashed and recovered/are recovering. So we can only log and
    // ignore here.
    _unexpected_call(__loc.method_name())

  fun ref event_log_id_written(worker: WorkerName,
    checkpoint_id: CheckpointId)
  =>
    // This is called directly in response to a control message received.
    // But we can't guarantee that this message is not a straggler in the case
    // that we crashed and recovered/are recovering. So we can only log and
    // ignore here.
    _unexpected_call(__loc.method_name())

  fun ref resume_checkpointing_from_rollback() =>
    // This is called directly in response to a control message received.
    // But we can't guarantee that this message is not a straggler in the case
    // that we crashed and recovered/are recovering. So we can only log and
    // ignore here.
    _unexpected_call(__loc.method_name())

  fun ref abort_checkpoint(checkpoint_id: CheckpointId,
    checkpoint_initiator: CheckpointInitiator ref)
  =>
    checkpoint_initiator._abort_checkpoint(checkpoint_id)

  fun ref initiate_rollback(
    recovery_promise: Promise[CheckpointRollbackBarrierToken],
    worker: WorkerName, checkpoint_initiator: CheckpointInitiator ref,
    rollback_id: RollbackId)
  =>
    checkpoint_initiator.finish_initiating_rollback(recovery_promise, worker,
      rollback_id)

  fun _invalid_call(method_name: String) =>
    @printf[I32]("Invalid call to method %s on checkpoint initiator phase %s\n".cstring(),
      method_name.cstring(), name().cstring())
    Fail()

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
    @printf[I32]("UNEXPECTED CALL to %s on checkpoint initiator phase %s. Ignoring!\n"
      .cstring(), method_name.cstring(), name().cstring())

class _WaitingCheckpointInitiatorPhase is _CheckpointInitiatorPhase
  fun name(): String => "_WaitingCheckpointInitiatorPhase"

  fun ref start_checkpoint_timer(time_until_next_checkpoint: U64,
    checkpoint_group: USize, checkpoint_initiator: CheckpointInitiator ref,
    checkpoint_promise: (Promise[None] | None) = None)
  =>
    checkpoint_initiator._start_checkpoint_timer(time_until_next_checkpoint,
      checkpoint_group, checkpoint_promise)

  fun ref initiate_checkpoint(checkpoint_group: USize,
    checkpoint_promise: Promise[None],
    checkpoint_initiator: CheckpointInitiator ref)
  =>
    checkpoint_initiator._initiate_checkpoint(checkpoint_group,
      checkpoint_promise)

  fun ref resume_checkpointing_from_rollback() =>
    None

class _CheckpointingPhase is _CheckpointInitiatorPhase
  let _token: CheckpointBarrierToken
  let _checkpoint_promise: Promise[None]
  let _c_initiator: CheckpointInitiator ref
  var _barrier_complete: Bool = false
  var _event_log_checkpoints_complete: Bool = false
  let _acked_workers: SetIs[WorkerName] = _acked_workers.create()

  new create(token: CheckpointBarrierToken,
    c_promise: Promise[None], c_initiator: CheckpointInitiator ref)
  =>
    _token = token
    _checkpoint_promise = c_promise
    _c_initiator = c_initiator

  fun name(): String => "_CheckpointingPhase"

  fun ref start_checkpoint_timer(time_until_next_checkpoint: U64,
    checkpoint_group: USize, checkpoint_initiator: CheckpointInitiator ref,
    checkpoint_promise: (Promise[None] | None) = None)
  =>
    // This message is possible in a race immediately after we see
    // "INIT PHASE IV: Cluster is ready to work!".
    // When this checkpoint has finished, the appropriate actor will
    // reset this timer; just log this event and move on.
    _unexpected_call(__loc.method_name())

  fun ref checkpoint_barrier_complete(token: BarrierToken) =>
    ifdef debug then
      Invariant(token == _token)
    end
    _barrier_complete = true
    _check_completion()

  fun ref event_log_checkpoint_complete(worker: WorkerName,
    checkpoint_id: CheckpointId)
  =>
    ifdef "checkpoint_trace" then
      @printf[I32]("_CheckpointingPhase: event_log_checkpoints_complete from %s for %s\n".cstring(),
        worker.cstring(), checkpoint_id.string().cstring())
    end
    ifdef debug then
      Invariant(checkpoint_id == _token.id)
      Invariant(_c_initiator.workers().contains(worker))
    end
    _acked_workers.set(worker)
    ifdef "checkpoint_trace" then
      @printf[I32]("_CheckpointingPhase: acked_workers: %s, workers: %s\n"
        .cstring(), _acked_workers.size().string().cstring(),
        _c_initiator.workers().size().string().cstring())
    end
    if (_acked_workers.size() == _c_initiator.workers().size()) then
      _event_log_checkpoints_complete = true
      _check_completion()
    end

  fun ref _check_completion() =>
    if _barrier_complete and _event_log_checkpoints_complete then
      _c_initiator.event_log_write_checkpoint_id(_token.id, _token,
        _checkpoint_promise)
    end

class _WaitingForEventLogIdWrittenPhase is _CheckpointInitiatorPhase
  let _token: CheckpointBarrierToken
  let _checkpoint_promise: Promise[None]
  let _c_initiator: CheckpointInitiator ref
  let _acked_workers: SetIs[WorkerName] = _acked_workers.create()

  new create(token: CheckpointBarrierToken,
    c_promise: Promise[None], c_initiator: CheckpointInitiator ref)
  =>
    _token = token
    _checkpoint_promise = c_promise
    _c_initiator = c_initiator

  fun name(): String => "_WaitingForEventLogIdWrittenPhase"

  fun ref event_log_id_written(worker: WorkerName,
    checkpoint_id: CheckpointId)
  =>
    ifdef "checkpoint_trace" then
      @printf[I32]("_WaitingForEventLogIdWrittenPhase: event_log_id_written from %s for %s\n".cstring(),
        worker.cstring(), checkpoint_id.string().cstring())
    end
    ifdef debug then
      Invariant(checkpoint_id == _token.id)
      Invariant(_c_initiator.workers().contains(worker))
    end
    _acked_workers.set(worker)
    ifdef "checkpoint_trace" then
      @printf[I32]("_WaitingForEventLogIdWrittenPhase: acked_workers: %s, workers: %s\n".cstring(),
        _acked_workers.size().string().cstring(),
        _c_initiator.workers().size().string().cstring())
    end
    if (_acked_workers.size() == _c_initiator.workers().size()) then
      _c_initiator.checkpoint_complete(_token, _checkpoint_promise)
    end

class _RollbackCheckpointInitiatorPhase is _CheckpointInitiatorPhase
  let _c_initiator: CheckpointInitiator ref

  new create(c_initiator: CheckpointInitiator ref) =>
    _c_initiator = c_initiator

  fun name(): String => "_RollbackCheckpointInitiatorPhase"

  fun ref start_checkpoint_timer(time_until_next_checkpoint: U64,
    checkpoint_group: USize, checkpoint_initiator: CheckpointInitiator ref,
    checkpoint_promise: (Promise[None] | None) = None)
  =>
    """
    We're rolling back, so we should not initiate a new checkpoint yet.
    """
    None

   fun ref initiate_checkpoint(checkpoint_group: USize,
    checkpoint_promise: Promise[None],
    checkpoint_initiator: CheckpointInitiator ref)
  =>
    """
    We're rolling back, so we should not initiate a new checkpoint yet.
    """
    None

  fun ref checkpoint_barrier_complete(token: BarrierToken) =>
    """
    We're rolling back. Ignore all current checkpoint activity.
    """
    None

  fun ref event_log_checkpoint_complete(worker: WorkerName,
    checkpoint_id: CheckpointId)
  =>
    """
    We're rolling back. Ignore all current checkpoint activity.
    """
    None

  fun ref event_log_id_written(worker: WorkerName,
    checkpoint_id: CheckpointId)
  =>
    """
    We're rolling back. Ignore all current checkpoint activity.
    """
    None

  fun ref resume_checkpointing_from_rollback() =>
    _c_initiator.wait_for_next_checkpoint()

  fun ref abort_checkpoint(checkpoint_id: CheckpointId,
    checkpoint_initiator: CheckpointInitiator ref)
  =>
    None

class _DisposedCheckpointInitiatorPhase is _CheckpointInitiatorPhase
  fun name(): String => "_DisposedCheckpointInitiatorPhase"

  fun ref initiate_checkpoint(checkpoint_group: USize,
    checkpoint_promise: Promise[None],
    checkpoint_initiator: CheckpointInitiator ref)
  =>
    None

  fun ref checkpoint_barrier_complete(token: BarrierToken) =>
    None

  fun ref event_log_checkpoint_complete(worker: WorkerName,
    checkpoint_id: CheckpointId)
  =>
    None

  fun ref event_log_id_written(worker: WorkerName,
    checkpoint_id: CheckpointId)
  =>
    None

  fun ref abort_checkpoint(checkpoint_id: CheckpointId,
    checkpoint_initiator: CheckpointInitiator ref)
  =>
    None

  fun ref initiate_rollback(
    recovery_promise: Promise[CheckpointRollbackBarrierToken],
    worker: WorkerName, checkpoint_initiator: CheckpointInitiator ref,
    rollback_id: RollbackId)
  =>
    None
