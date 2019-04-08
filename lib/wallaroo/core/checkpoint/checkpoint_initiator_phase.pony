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
    checkpoint_initiator: CheckpointInitiator ref)
  =>
    _invalid_call(); Fail()

  fun ref initiate_checkpoint(checkpoint_group: USize,
    checkpoint_initiator: CheckpointInitiator ref)
  =>
    """
    Currently, we do not allow two checkpoints to be in flight at once. If a
    timer goes off while one is in progress, we ignore it for now. We only
    initiate a checkpoint from _WaitingCheckpointInitiatorPhase.
    """
    None

  fun ref checkpoint_barrier_complete(token: BarrierToken) =>
    _invalid_call(); Fail()

  fun ref event_log_checkpoint_complete(worker: WorkerName,
    checkpoint_id: CheckpointId)
  =>
    _invalid_call(); Fail()

  fun ref event_log_id_written(worker: WorkerName,
    checkpoint_id: CheckpointId)
  =>
    _invalid_call(); Fail()

  fun ref resume_checkpointing_from_rollback() =>
    _invalid_call(); Fail()

  fun ref abort_checkpoint(checkpoint_id: CheckpointId,
    checkpoint_initiator: CheckpointInitiator ref)
  =>
    checkpoint_initiator._abort_checkpoint(checkpoint_id)

  fun ref initiate_rollback(
    recovery_promise: Promise[CheckpointRollbackBarrierToken],
    worker: WorkerName, checkpoint_initiator: CheckpointInitiator ref)
  =>
    checkpoint_initiator.finish_initiating_rollback(recovery_promise, worker)

  fun _invalid_call() =>
    @printf[I32]("Invalid call on checkpoint initiator phase %s\n".cstring(),
      name().cstring())

class _WaitingCheckpointInitiatorPhase is _CheckpointInitiatorPhase
  fun name(): String => "_WaitingCheckpointInitiatorPhase"

  fun ref start_checkpoint_timer(time_until_next_checkpoint: U64,
    checkpoint_initiator: CheckpointInitiator ref)
  =>
    checkpoint_initiator._start_checkpoint_timer(time_until_next_checkpoint)

  fun ref initiate_checkpoint(checkpoint_group: USize,
    checkpoint_initiator: CheckpointInitiator ref)
  =>
    checkpoint_initiator._initiate_checkpoint(checkpoint_group)

  fun ref resume_checkpointing_from_rollback() =>
    None

class _CheckpointingPhase is _CheckpointInitiatorPhase
  let _token: CheckpointBarrierToken
  let _c_initiator: CheckpointInitiator ref
  var _barrier_complete: Bool = false
  var _event_log_checkpoints_complete: Bool = false
  let _acked_workers: SetIs[WorkerName] = _acked_workers.create()

  new create(token: CheckpointBarrierToken,
    c_initiator: CheckpointInitiator ref)
  =>
    _token = token
    _c_initiator = c_initiator

  fun name(): String => "_CheckpointingPhase"

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
      _c_initiator.event_log_write_checkpoint_id(_token.id, _token)
    end

class _WaitingForEventLogIdWrittenPhase is _CheckpointInitiatorPhase
  let _token: CheckpointBarrierToken
  let _c_initiator: CheckpointInitiator ref
  let _acked_workers: SetIs[WorkerName] = _acked_workers.create()

  new create(token: CheckpointBarrierToken,
    c_initiator: CheckpointInitiator ref)
  =>
    _token = token
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
      _c_initiator.checkpoint_complete(_token)
    end

class _RollbackCheckpointInitiatorPhase is _CheckpointInitiatorPhase
  let _c_initiator: CheckpointInitiator ref

  new create(c_initiator: CheckpointInitiator ref) =>
    _c_initiator = c_initiator

  fun name(): String => "_RollbackCheckpointInitiatorPhase"

  fun ref _initiate_checkpoint(checkpoint_group: USize,
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

  fun ref _initiate_checkpoint(checkpoint_group: USize,
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
    worker: WorkerName, checkpoint_initiator: CheckpointInitiator ref)
  =>
    None
