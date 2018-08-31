
use "collections"
use "promises"
use "wallaroo/core/common"
use "wallaroo/core/invariant"
use "wallaroo/ent/barrier"
use "wallaroo/ent/snapshot"
use "wallaroo_labs/mort"


trait _EventLogPhase
  fun name(): String

  fun ref initiate_snapshot(snapshot_id: SnapshotId,
    action: Promise[SnapshotId], event_log: EventLog ref)
  =>
    event_log._initiate_snapshot(snapshot_id, action)

  fun ref snapshot_state(resilient_id: RoutingId, snapshot_id: SnapshotId,
    payload: Array[ByteSeq] val)
  =>
    _invalid_call()
    Fail()

  fun ref write_initial_snapshot_id(snapshot_id: SnapshotId) =>
    _invalid_call()
    Fail()

  fun ref write_snapshot_id(snapshot_id: SnapshotId) =>
    _invalid_call()
    Fail()

  fun ref snapshot_id_written(snapshot_id: SnapshotId) =>
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
  let _next_snapshot_id: SnapshotId
  let _event_log: EventLog ref

  new create(next_snapshot_id: SnapshotId, event_log: EventLog ref) =>
    _next_snapshot_id = next_snapshot_id
    _event_log = event_log

  fun ref write_initial_snapshot_id(snapshot_id: SnapshotId) =>
    _event_log._write_snapshot_id(snapshot_id)

  fun ref snapshot_state(resilient_id: RoutingId, snapshot_id: SnapshotId,
    payload: Array[ByteSeq] val)
  =>
    // @printf[I32]("!@ _NormalEventLogPhase: snapshot_state() for snapshot_id %s\n".cstring(), snapshot_id.string().cstring())

    ifdef debug then
      Invariant(snapshot_id == _next_snapshot_id)
    end
    ifdef "trace" then
      @printf[I32]("Snapshotting state for resilient %s, snapshot id %s\n"
        .cstring(), resilient_id.string().cstring(),
        _next_snapshot_id.string().cstring())
    end

    if payload.size() > 0 then
      _event_log._snapshot_state(resilient_id, snapshot_id, payload)
    end

  fun ref snapshot_id_written(snapshot_id: SnapshotId) =>
    None

  fun name(): String => "_NormalEventLogPhase"

class _RecoveringEventLogPhase is _EventLogPhase
  let _event_log: EventLog ref

  new create(event_log: EventLog ref) =>
    _event_log = event_log

  fun name(): String => "_RecoveringEventLogPhase"

  fun ref initiate_snapshot(snapshot_id: SnapshotId,
    action: Promise[SnapshotId], event_log: EventLog ref)
  =>
    @printf[I32]("EventLog: Recovering so ignoring initiate snapshot id %s\n"
      .cstring(), snapshot_id.string().cstring())

  fun ref snapshot_state(resilient_id: RoutingId, snapshot_id: SnapshotId,
    payload: Array[ByteSeq] val)
  =>
    @printf[I32](("EventLog: Recovering so ignoring snapshot state for " +
      "resilient %s\n").cstring(), resilient_id.string().cstring())

class _SnapshotEventLogPhase is _EventLogPhase
  let _event_log: EventLog ref
  let _snapshot_id: SnapshotId
  let _action: Promise[SnapshotId]

  new create(event_log: EventLog ref, snapshot_id: SnapshotId,
    action: Promise[SnapshotId])
  =>
    _event_log = event_log
    _snapshot_id = snapshot_id
    _action = action

  fun name(): String => "_SnapshotEventLogPhase"

  fun ref snapshot_state(resilient_id: RoutingId, snapshot_id: SnapshotId,
    payload: Array[ByteSeq] val)
  =>
    // @printf[I32]("!@ _SnapshotEventLogPhase: snapshot_state()\n".cstring())

    ifdef debug then
      Invariant(snapshot_id == _snapshot_id)
    end
    ifdef "trace" then
      @printf[I32]("Snapshotting state for resilient %s, snapshot id %s\n"
        .cstring(), resilient_id.string().cstring(),
        _snapshot_id.string().cstring())
    end

    if payload.size() > 0 then
      _event_log._snapshot_state(resilient_id, snapshot_id, payload)
    end

  fun ref write_snapshot_id(snapshot_id: SnapshotId) =>
    ifdef debug then
      Invariant(snapshot_id == _snapshot_id)
    end
    _event_log._write_snapshot_id(snapshot_id)

  fun ref snapshot_id_written(snapshot_id: SnapshotId) =>
    // @printf[I32]("!@ _SnapshotEventLogPhase: snapshot_id_written()\n".cstring())
    ifdef debug then
      Invariant(snapshot_id == _snapshot_id)
    end
    _action(snapshot_id)
    _event_log.snapshot_complete(snapshot_id)

class _RollbackEventLogPhase is _EventLogPhase
  let _event_log: EventLog ref
  let _action: Promise[SnapshotRollbackBarrierToken]
  let _token: SnapshotRollbackBarrierToken
  let _resilients_acked: SetIs[RoutingId] = _resilients_acked.create()

  // !@ This indicates we need another phase
  var _rollback_count: USize = 0

  new create(event_log: EventLog ref, token: SnapshotRollbackBarrierToken,
    action: Promise[SnapshotRollbackBarrierToken])
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
    _event_log.rollback_complete(_token.snapshot_id)
