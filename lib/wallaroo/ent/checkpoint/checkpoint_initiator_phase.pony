/*

Copyright 2018 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "collections"

use "wallaroo/core/common"
use "wallaroo/core/invariant"
use "wallaroo/ent/barrier"
use "wallaroo_labs/collection_helpers"
use "wallaroo_labs/mort"


trait _CheckpointInitiatorPhase
  fun name(): String

  fun ref checkpoint_barrier_complete(token: BarrierToken) =>
    _invalid_call()
    Fail()

  fun ref event_log_checkpoint_complete(worker: WorkerName,
    checkpoint_id: CheckpointId)
  =>
    _invalid_call()
    Fail()

  fun _invalid_call() =>
    @printf[I32]("Invalid call on checkpoint initiator phase %s\n".cstring(),
      name().cstring())

class _WaitingCheckpointInitiatorPhase is _CheckpointInitiatorPhase
  fun name(): String => "_WaitingCheckpointInitiatorPhase"

class _ActiveCheckpointInitiatorPhase is _CheckpointInitiatorPhase
  let _token: CheckpointBarrierToken
  let _c_initiator: CheckpointInitiator ref
  var _barrier_complete: Bool = false
  var _event_log_complete: Bool = false
  let _workers: SetIs[WorkerName] = _workers.create()
  let _acked_workers: SetIs[WorkerName] = _acked_workers.create()

  new create(token: CheckpointBarrierToken,
    c_initiator: CheckpointInitiator ref, workers: _StringSet box)
  =>
    _token = token
    _c_initiator = c_initiator
    for w in workers.values() do
      _workers.set(w)
    end

  fun name(): String => "_ActiveCheckpointInitiatorPhase"

  fun ref checkpoint_barrier_complete(token: BarrierToken) =>
    ifdef debug then
      Invariant(token == _token)
    end
    _barrier_complete = true
    let ws = recover iso Array[WorkerName] end
    for w in _workers.values() do
      ws.push(w)
    end
    _c_initiator.event_log_write_checkpoint_id(_token.id, consume ws)

  fun ref event_log_checkpoint_complete(worker: WorkerName,
    checkpoint_id: CheckpointId)
  =>
    @printf[I32]("!@ _CheckpointInitiatorPhase: event_log_checkpoint_complete from %s for %s\n".cstring(), worker.cstring(), checkpoint_id.string().cstring())
    ifdef debug then
      Invariant(checkpoint_id == _token.id)
      Invariant(SetHelpers[WorkerName].contains[WorkerName](_workers, worker))
    end
    _acked_workers.set(worker)
    @printf[I32]("!@ _CheckpointInitiatorPhase: acked_workers: %s, workers: %s\n".cstring(), _acked_workers.size().string().cstring(), _workers.size().string().cstring())
    if _acked_workers.size() == _workers.size() then
      _event_log_complete = true
      _c_initiator.checkpoint_complete(_token)
    end
