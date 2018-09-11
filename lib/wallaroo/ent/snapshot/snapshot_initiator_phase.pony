use "collections"

use "wallaroo/core/common"
use "wallaroo/core/invariant"
use "wallaroo/ent/barrier"
use "wallaroo_labs/collection_helpers"
use "wallaroo_labs/mort"


trait _SnapshotInitiatorPhase
  fun name(): String

  fun ref snapshot_barrier_complete(token: BarrierToken) =>
    _invalid_call()
    Fail()

  fun ref event_log_snapshot_complete(worker: WorkerName,
    snapshot_id: SnapshotId)
  =>
    _invalid_call()
    Fail()

  fun _invalid_call() =>
    @printf[I32]("Invalid call on snapshot initiator phase %s\n".cstring(),
      name().cstring())

class _WaitingSnapshotInitiatorPhase is _SnapshotInitiatorPhase
  fun name(): String => "_WaitingSnapshotInitiatorPhase"

class _ActiveSnapshotInitiatorPhase is _SnapshotInitiatorPhase
  let _token: SnapshotBarrierToken
  let _s_initiator: SnapshotInitiator ref
  var _barrier_complete: Bool = false
  var _event_log_complete: Bool = false
  let _workers: SetIs[WorkerName] = _workers.create()
  let _acked_workers: SetIs[WorkerName] = _acked_workers.create()

  new create(token: SnapshotBarrierToken, s_initiator: SnapshotInitiator ref,
    workers: _StringSet box)
  =>
    _token = token
    _s_initiator = s_initiator
    for w in workers.values() do
      _workers.set(w)
    end

  fun name(): String => "_ActiveSnapshotInitiatorPhase"

  fun ref snapshot_barrier_complete(token: BarrierToken) =>
    ifdef debug then
      Invariant(token == _token)
    end
    _barrier_complete = true
    _s_initiator.event_log_write_snapshot_id(_token.id)

  fun ref event_log_snapshot_complete(worker: WorkerName,
    snapshot_id: SnapshotId)
  =>
    @printf[I32]("!@ _SnapshotInitiatorPhase: event_log_snapshot_complete from %s for %s\n".cstring(), worker.cstring(), snapshot_id.string().cstring())
    ifdef debug then
      Invariant(snapshot_id == _token.id)
      Invariant(SetHelpers[WorkerName].contains[WorkerName](_workers, worker))
    end
    _acked_workers.set(worker)
    @printf[I32]("!@ _SnapshotInitiatorPhase: acked_workers: %s, workers: %s\n".cstring(), _acked_workers.size().string().cstring(), _workers.size().string().cstring())
    if _acked_workers.size() == _workers.size() then
      _event_log_complete = true
      _s_initiator.snapshot_complete(_token)
    end
