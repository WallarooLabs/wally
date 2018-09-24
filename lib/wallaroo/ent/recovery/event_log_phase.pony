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
use "wallaroo/ent/barrier"
use "wallaroo/ent/checkpoint"
use "wallaroo_labs/mort"


trait _EventLogPhase
  fun name(): String

  fun ref unregister_resilient(id: RoutingId, resilient: Resilient) =>
    None

  fun ref initiate_checkpoint(checkpoint_id: CheckpointId,
    promise: Promise[CheckpointId], event_log: EventLog ref)
  =>
    _invalid_call()
    Fail()

  fun ref checkpoint_state(resilient_id: RoutingId,
    checkpoint_id: CheckpointId, payload: Array[ByteSeq] val)
  =>
    @printf[I32]("!@ BAD: checkpoint_state() for resilient %s, checkpoint_id %s\n".cstring(), resilient_id.string().cstring(), checkpoint_id.string().cstring())

    _invalid_call()
    Fail()

  fun ref state_checkpointed(resilient_id: RoutingId) =>
    _invalid_call()
    Fail()

  fun ref write_initial_checkpoint_id(checkpoint_id: CheckpointId) =>
    _invalid_call()
    Fail()

  fun ref write_checkpoint_id(checkpoint_id: CheckpointId,
    promise: Promise[CheckpointId])
  =>
    _invalid_call()
    Fail()

  fun ref checkpoint_id_written(checkpoint_id: CheckpointId,
    promise: Promise[CheckpointId])
  =>
    _invalid_call()
    Fail()

  fun ref expect_rollback_count(count: USize) =>
    _invalid_call()
    Fail()

  fun ref ack_rollback(resilient_id: RoutingId) =>
    _invalid_call()
    Fail()

  fun ref complete_early() =>
    _invalid_call()
    Fail()

  fun ref check_completion() =>
    _invalid_call()
    Fail()

  fun _invalid_call() =>
    @printf[I32]("Invalid call on event log phase %s\n".cstring(),
      name().cstring())

class _InitialEventLogPhase is _EventLogPhase
  fun name(): String => "_InitialEventLogPhase"

  fun ref initiate_checkpoint(checkpoint_id: CheckpointId,
    promise: Promise[CheckpointId], event_log: EventLog ref)
  =>
    event_log._initiate_checkpoint(checkpoint_id, promise)

class _WaitingForCheckpointInitiationEventLogPhase is _EventLogPhase
  let _next_checkpoint_id: CheckpointId
  let _event_log: EventLog ref
  let _pending_checkpoint_states:
    Map[CheckpointId, Array[_QueuedCheckpointState]] =
      _pending_checkpoint_states.create()

  new create(next_checkpoint_id: CheckpointId, event_log: EventLog ref) =>
    _next_checkpoint_id = next_checkpoint_id
    _event_log = event_log
    @printf[I32]("!@ Transition to _WaitingForCheckpointInitiationEventLogPhase: checkpoint_id %s\n".cstring(), next_checkpoint_id.string().cstring())

  // TODO: This should only be called once at the beginning of the application
  // lifecycle and needs to be handled elsewhere.
  fun ref write_initial_checkpoint_id(checkpoint_id: CheckpointId) =>
    _event_log._write_initial_checkpoint_id(checkpoint_id)

  fun ref initiate_checkpoint(checkpoint_id: CheckpointId,
    promise: Promise[CheckpointId], event_log: EventLog ref)
  =>
    try
      let pending = _pending_checkpoint_states.insert_if_absent(checkpoint_id,
        Array[_QueuedCheckpointState])?
      event_log._initiate_checkpoint(checkpoint_id, promise, pending)
    else
      Fail()
    end
    //!@
    // if checkpoint_id != _next_checkpoint_id then
    //   @printf[I32]("!@ _WaitingForCheckpointInitiationEventLogPhase: Thought we were on checkpoint %s but really on %s with %s resilients checkpointed\n".cstring(), _next_checkpoint_id.string().cstring(), checkpoint_id.string().cstring(), _checkpointed_resilients.size().string().cstring())
    //   Fail()
    // end

  fun ref checkpoint_state(resilient_id: RoutingId,
    checkpoint_id: CheckpointId, payload: Array[ByteSeq] val)
  =>
    @printf[I32]("!@ _WaitingForCheckpointInitiationEventLogPhase: checkpoint_state() for resilient %s, checkpoint_id %s\n".cstring(), resilient_id.string().cstring(), checkpoint_id.string().cstring())

    try
      let pending = _pending_checkpoint_states.insert_if_absent(checkpoint_id,
        Array[_QueuedCheckpointState])?
      pending.push(_QueuedCheckpointState(resilient_id, payload))
    else
      Fail()
    end

    // @printf[I32]("!@ _WaitingForCheckpointInitiationEventLogPhase: checkpoint_state() for resilient %s, checkpoint_id %s\n".cstring(), resilient_id.string().cstring(), checkpoint_id.string().cstring())

    // ifdef debug then
    //   if checkpoint_id != _next_checkpoint_id then
    //     @printf[I32]("!@ EventLogPhase: checkpoint_state(): rcvd: %s, expected: %s\n".cstring(), checkpoint_id.string().cstring(), _next_checkpoint_id.string().cstring())
    //   end
    //   Invariant(checkpoint_id == _next_checkpoint_id)
    // end
    // ifdef "trace" then
    //   @printf[I32]("Checkpointing state for resilient %s, checkpoint id %s\n"
    //     .cstring(), resilient_id.string().cstring(),
    //     _next_checkpoint_id.string().cstring())
    // end

    // _event_log._checkpoint_state(resilient_id, checkpoint_id, payload)

  // fun ref state_checkpointed(resilient_id: RoutingId) =>
  //   // We might get some successful state checkpoints before we receive the
  //   // initiate_checkpoint message, so we hold on to them for now.
  //   _checkpointed_resilients.set(resilient_id)

//!@
  // fun ref checkpoint_id_written(checkpoint_id: CheckpointId) =>
  //   _event_log.update_normal_event_log_checkpoint_id(checkpoint_id)

  fun name(): String => "_WaitingForCheckpointInitiationEventLogPhase"

class _CheckpointEventLogPhase is _EventLogPhase
  let _event_log: EventLog ref
  let _checkpoint_id: CheckpointId
  let _promise: Promise[CheckpointId]

  let _resilients: SetIs[RoutingId] = _resilients.create()
  let _checkpointed_resilients: SetIs[RoutingId] =
    _checkpointed_resilients.create()

  new create(event_log: EventLog ref, checkpoint_id: CheckpointId,
    promise: Promise[CheckpointId],
    resilients: Map[RoutingId, Resilient])
  =>
    _event_log = event_log
    _checkpoint_id = checkpoint_id
    _promise = promise
    for id in resilients.keys() do
      _resilients.set(id)
    end

    @printf[I32]("!@ Transition to _CheckpointEventLogPhase: checkpoint_id %s with %s resilients already checkpointed and %s total\n".cstring(), checkpoint_id.string().cstring(), _checkpointed_resilients.size().string().cstring(), _resilients.size().string().cstring())

  fun name(): String => "_CheckpointEventLogPhase"

  fun ref unregister_resilient(id: RoutingId, resilient: Resilient) =>
    if not _checkpointed_resilients.contains(id) then
      _resilients.unset(id)
    end
    check_completion()

  fun ref checkpoint_state(resilient_id: RoutingId,
    checkpoint_id: CheckpointId, payload: Array[ByteSeq] val)
  =>
    @printf[I32]("!@ _CheckpointEventLogPhase: checkpoint_state() for resilient %s, checkpoint_id %s\n".cstring(), resilient_id.string().cstring(), checkpoint_id.string().cstring())

    ifdef debug then
      Invariant(checkpoint_id == _checkpoint_id)
    end
    ifdef "trace" then
      @printf[I32]("Checkpointing state for resilient %s, checkpoint id %s\n"
        .cstring(), resilient_id.string().cstring(),
        _checkpoint_id.string().cstring())
    end

    _event_log._checkpoint_state(resilient_id, checkpoint_id, payload)

  fun ref state_checkpointed(resilient_id: RoutingId) =>
    _checkpointed_resilients.set(resilient_id)
    check_completion()

  fun ref check_completion() =>
    @printf[I32]("!@ _CheckpointEventLogPhase: check_completion() with %s checkpointed and %s total\n".cstring(), _checkpointed_resilients.size().string().cstring(), _resilients.size().string().cstring())
    if _checkpointed_resilients.size() == _resilients.size() then
      _promise(_checkpoint_id)
      _event_log.state_checkpoints_complete(_checkpoint_id)
    end

class _WaitingForWriteIdEventLogPhase is _EventLogPhase
  let _event_log: EventLog ref
  let _checkpoint_id: CheckpointId

  new create(event_log: EventLog ref, checkpoint_id: CheckpointId) =>
    _event_log = event_log
    _checkpoint_id = checkpoint_id
    @printf[I32]("!@ Transition to _WaitingForWriteIdEventLogPhase: checkpoint_id %s\n".cstring(), checkpoint_id.string().cstring())

  fun name(): String => "_WaitingForWriteIdEventLogPhase"

  fun ref write_checkpoint_id(checkpoint_id: CheckpointId,
    promise: Promise[CheckpointId])
  =>
    ifdef debug then
      Invariant(checkpoint_id == _checkpoint_id)
    end
    _event_log._write_checkpoint_id(checkpoint_id, promise)

  fun ref checkpoint_id_written(checkpoint_id: CheckpointId,
    promise: Promise[CheckpointId])
  =>
    // @printf[I32]("!@ _CheckpointEventLogPhase: checkpoint_id_written()\n".cstring())
    ifdef debug then
      Invariant(checkpoint_id == _checkpoint_id)
    end
    promise(checkpoint_id)
    _event_log.checkpoint_id_written(checkpoint_id)

class _RecoveringEventLogPhase is _EventLogPhase
  let _event_log: EventLog ref

  new create(event_log: EventLog ref) =>
    _event_log = event_log

  fun name(): String => "_RecoveringEventLogPhase"

  fun ref initiate_checkpoint(checkpoint_id: CheckpointId,
    promise: Promise[CheckpointId], event_log: EventLog ref)
  =>
    @printf[I32]("EventLog: Recovering so ignoring initiate checkpoint id %s\n"
      .cstring(), checkpoint_id.string().cstring())

  fun ref checkpoint_state(resilient_id: RoutingId,
    checkpoint_id: CheckpointId, payload: Array[ByteSeq] val)
  =>
    @printf[I32](("EventLog: Recovering so ignoring checkpoint state for " +
      "resilient %s\n").cstring(), resilient_id.string().cstring())

class _RollbackEventLogPhase is _EventLogPhase
  let _event_log: EventLog ref
  let _promise: Promise[CheckpointRollbackBarrierToken]
  let _token: CheckpointRollbackBarrierToken
  let _resilients_acked: SetIs[RoutingId] = _resilients_acked.create()

  // !@ This indicates we need another phase
  var _rollback_count: USize = 0

  new create(event_log: EventLog ref, token: CheckpointRollbackBarrierToken,
    promise: Promise[CheckpointRollbackBarrierToken])
  =>
    _event_log = event_log
    _promise = promise
    _token = token

  fun name(): String => "_RollbackEventLogPhase"

  fun ref initiate_checkpoint(checkpoint_id: CheckpointId,
    promise: Promise[CheckpointId], event_log: EventLog ref)
  =>
    @printf[I32](("EventLog: Rolling back so ignoring initiate checkpoint " +
      "id %s\n").cstring(), checkpoint_id.string().cstring())

  fun ref expect_rollback_count(count: USize) =>
    _rollback_count = count

  fun ref ack_rollback(resilient_id: RoutingId) =>
    // @printf[I32]("!@ EventLogPhase: ack_rollback for %s\n".cstring(), resilient_id.string().cstring())
    ifdef debug then
      Invariant(not _resilients_acked.contains(resilient_id))
    end
    // @printf[I32]("!@ resilients acked when ack received: %s\n".cstring(), _resilients_acked.size().string().cstring())
    _resilients_acked.set(resilient_id)
    if _resilients_acked.size() == _rollback_count then
      _complete()
    end

  fun ref complete_early() =>
    _complete()

  fun ref _complete() =>
    _promise(_token)
    _event_log.rollback_complete(_token.checkpoint_id)

class _DisposedEventLogPhase is _EventLogPhase
  fun name(): String => "_DisposedRollbackEventLogPhase"

  fun ref initiate_checkpoint(checkpoint_id: CheckpointId,
    promise: Promise[CheckpointId], event_log: EventLog ref)
  =>
    None

  fun ref checkpoint_state(resilient_id: RoutingId,
    checkpoint_id: CheckpointId, payload: Array[ByteSeq] val)
  =>
    None

  fun ref state_checkpointed(resilient_id: RoutingId) =>
    None

  fun ref write_initial_checkpoint_id(checkpoint_id: CheckpointId) =>
    None

  fun ref write_checkpoint_id(checkpoint_id: CheckpointId,
    promise: Promise[CheckpointId])
  =>
    None

  fun ref checkpoint_id_written(checkpoint_id: CheckpointId,
    promise: Promise[CheckpointId])
  =>
    None

  fun ref expect_rollback_count(count: USize) =>
    None

  fun ref ack_rollback(resilient_id: RoutingId) =>
    None

  fun ref complete_early() =>
    None

  fun ref check_completion() =>
    None

class _QueuedCheckpointState
  let resilient_id: RoutingId
  let payload: Array[ByteSeq] val

  new create(resilient_id': RoutingId, payload': Array[ByteSeq] val) =>
    resilient_id = resilient_id'
    payload = payload'
