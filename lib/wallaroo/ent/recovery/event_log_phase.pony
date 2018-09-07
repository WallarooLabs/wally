/*

Copyright 2018 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

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

  fun ref initiate_checkpoint(checkpoint_id: CheckpointId,
    action: Promise[CheckpointId], event_log: EventLog ref)
  =>
    event_log._initiate_checkpoint(checkpoint_id, action)

  fun ref checkpoint_state(resilient_id: RoutingId, checkpoint_id: CheckpointId,
    payload: Array[ByteSeq] val)
  =>
    _invalid_call()
    Fail()

  fun ref write_initial_checkpoint_id(checkpoint_id: CheckpointId) =>
    _invalid_call()
    Fail()

  fun ref write_checkpoint_id(checkpoint_id: CheckpointId) =>
    _invalid_call()
    Fail()

  fun ref checkpoint_id_written(checkpoint_id: CheckpointId) =>
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

  fun _invalid_call() =>
    @printf[I32]("Invalid call on event log phase %s\n".cstring(),
      name().cstring())

class _InitialEventLogPhase is _EventLogPhase
  fun name(): String => "_InitialEventLogPhase"

class _NormalEventLogPhase is _EventLogPhase
  let _next_checkpoint_id: CheckpointId
  let _event_log: EventLog ref

  new create(next_checkpoint_id: CheckpointId, event_log: EventLog ref) =>
    _next_checkpoint_id = next_checkpoint_id
    _event_log = event_log

  fun ref write_initial_checkpoint_id(checkpoint_id: CheckpointId) =>
    _event_log._write_checkpoint_id(checkpoint_id)

  fun ref checkpoint_state(resilient_id: RoutingId, checkpoint_id: CheckpointId,
    payload: Array[ByteSeq] val)
  =>
    // @printf[I32]("!@ _NormalEventLogPhase: checkpoint_state() for checkpoint_id %s\n".cstring(), checkpoint_id.string().cstring())

    ifdef debug then
      Invariant(checkpoint_id == _next_checkpoint_id)
    end
    ifdef "trace" then
      @printf[I32]("Checkpointing state for resilient %s, checkpoint id %s\n"
        .cstring(), resilient_id.string().cstring(),
        _next_checkpoint_id.string().cstring())
    end

    if payload.size() > 0 then
      _event_log._checkpoint_state(resilient_id, checkpoint_id, payload)
    end

  fun ref checkpoint_id_written(checkpoint_id: CheckpointId) =>
    None

  fun name(): String => "_NormalEventLogPhase"

class _RecoveringEventLogPhase is _EventLogPhase
  let _event_log: EventLog ref

  new create(event_log: EventLog ref) =>
    _event_log = event_log

  fun name(): String => "_RecoveringEventLogPhase"

  fun ref initiate_checkpoint(checkpoint_id: CheckpointId,
    action: Promise[CheckpointId], event_log: EventLog ref)
  =>
    @printf[I32]("EventLog: Recovering so ignoring initiate checkpoint id %s\n"
      .cstring(), checkpoint_id.string().cstring())

  fun ref checkpoint_state(resilient_id: RoutingId, checkpoint_id: CheckpointId,
    payload: Array[ByteSeq] val)
  =>
    @printf[I32](("EventLog: Recovering so ignoring checkpoint state for " +
      "resilient %s\n").cstring(), resilient_id.string().cstring())

class _CheckpointEventLogPhase is _EventLogPhase
  let _event_log: EventLog ref
  let _checkpoint_id: CheckpointId
  let _action: Promise[CheckpointId]

  new create(event_log: EventLog ref, checkpoint_id: CheckpointId,
    action: Promise[CheckpointId])
  =>
    _event_log = event_log
    _checkpoint_id = checkpoint_id
    _action = action

  fun name(): String => "_CheckpointEventLogPhase"

  fun ref checkpoint_state(resilient_id: RoutingId, checkpoint_id: CheckpointId,
    payload: Array[ByteSeq] val)
  =>
    // @printf[I32]("!@ _CheckpointEventLogPhase: checkpoint_state()\n".cstring())

    ifdef debug then
      Invariant(checkpoint_id == _checkpoint_id)
    end
    ifdef "trace" then
      @printf[I32]("Checkpointing state for resilient %s, checkpoint id %s\n"
        .cstring(), resilient_id.string().cstring(),
        _checkpoint_id.string().cstring())
    end

    if payload.size() > 0 then
      _event_log._checkpoint_state(resilient_id, checkpoint_id, payload)
    end

  fun ref write_checkpoint_id(checkpoint_id: CheckpointId) =>
    ifdef debug then
      Invariant(checkpoint_id == _checkpoint_id)
    end
    _event_log._write_checkpoint_id(checkpoint_id)

  fun ref checkpoint_id_written(checkpoint_id: CheckpointId) =>
    // @printf[I32]("!@ _CheckpointEventLogPhase: checkpoint_id_written()\n".cstring())
    ifdef debug then
      Invariant(checkpoint_id == _checkpoint_id)
    end
    _action(checkpoint_id)
    _event_log.checkpoint_complete(checkpoint_id)

class _RollbackEventLogPhase is _EventLogPhase
  let _event_log: EventLog ref
  let _action: Promise[CheckpointRollbackBarrierToken]
  let _token: CheckpointRollbackBarrierToken
  let _resilients_acked: SetIs[RoutingId] = _resilients_acked.create()

  // !@ This indicates we need another phase
  var _rollback_count: USize = 0

  new create(event_log: EventLog ref, token: CheckpointRollbackBarrierToken,
    action: Promise[CheckpointRollbackBarrierToken])
  =>
    _event_log = event_log
    _action = action
    _token = token

  fun name(): String => "_RollbackEventLogPhase"

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
    _action(_token)
    _event_log.rollback_complete(_token.checkpoint_id)
