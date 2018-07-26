
use "collections"
use "promises"
use "wallaroo/core/common"
use "wallaroo/core/invariant"
use "wallaroo/ent/barrier"
use "wallaroo/ent/snapshot"
use "wallaroo_labs/mort"


trait _EventLogPhase
  fun name(): String

  fun ref snapshot_state(resilient_id: RoutingId, snapshot_id: SnapshotId,
    payload: Array[ByteSeq] val)
  =>
    _invalid_call()

  fun ref snapshot_id_written(snapshot_id: SnapshotId) =>
    _invalid_call()

  fun ref ack_rollback(resilient_id: RoutingId) =>
    _invalid_call()

  fun _invalid_call() =>
    @printf[I32]("Invalid call on event log phase %s\n".cstring(),
      name().cstring())
    Fail()

class _InitialEventLogPhase is _EventLogPhase
  fun name(): String => "_InitialEventLogPhase"

class _NormalEventLogPhase is _EventLogPhase
  let _event_log: EventLog ref

  new create(event_log: EventLog ref) =>
    _event_log = event_log

  fun name(): String => "_NormalEventLogPhase"

class _SnapshotEventLogPhase is _EventLogPhase
  let _event_log: EventLog ref
  let _snapshot_id: SnapshotId
  let _token: BarrierToken
  let _action: Promise[BarrierToken]
  let _resilients_pending: SetIs[RoutingId] = _resilients_pending.create()

  new create(event_log: EventLog ref, snapshot_id: SnapshotId,
    token: BarrierToken, action: Promise[BarrierToken],
    resilients: Iterator[RoutingId])
  =>
    _event_log = event_log
    _snapshot_id = snapshot_id
    _token = token
    _action = action
    for r in resilients do
      _resilients_pending.set(r)
    end

  fun name(): String => "_SnapshotEventLogPhase"

  fun ref snapshot_state(resilient_id: RoutingId, snapshot_id: SnapshotId,
    payload: Array[ByteSeq] val)
  =>
    ifdef debug then
      Invariant(snapshot_id == _snapshot_id)
    end
    ifdef "trace" then
      @printf[I32](("Snapshotting state for resilient " + resilient_id.string()
        + "\n").cstring())
    end
    if _resilients_pending.contains(resilient_id) then
      _resilients_pending.unset(resilient_id)
    else
      @printf[I32](("Error writing snapshot to logfile. RoutingId not in " +
        "set of expected resilients!\n").cstring())
      Fail()
    end
    _event_log._snapshot_state(resilient_id, snapshot_id, payload)
    if _resilients_pending.size() == 0 then
      _event_log.write_snapshot_id(snapshot_id)
    end

  fun ref snapshot_id_written(snapshot_id: SnapshotId) =>
    ifdef debug then
      Invariant(snapshot_id == _snapshot_id)
    end
    _action(_token)
    _event_log.snapshot_complete()

class _RollbackEventLogPhase is _EventLogPhase
  let _event_log: EventLog ref
  let _action: Promise[SnapshotRollbackBarrierToken]
  let _token: SnapshotRollbackBarrierToken
  let _resilients_pending: SetIs[RoutingId] = _resilients_pending.create()

  new create(event_log: EventLog ref, token: SnapshotRollbackBarrierToken,
    action: Promise[SnapshotRollbackBarrierToken],
    resilients: Iterator[RoutingId])
  =>
    _event_log = event_log
    _action = action
    _token = token
    for r in resilients do
      _resilients_pending.set(r)
    end

  fun name(): String => "_RollbackEventLogPhase"

  fun ref ack_rollback(resilient_id: RoutingId) =>
    ifdef debug then
      Invariant(_resilients_pending.contains(resilient_id))
    end
    _resilients_pending.unset(resilient_id)
    if _resilients_pending.size() == 0 then
      _action(_token)
      _event_log.rollback_complete()
    end


