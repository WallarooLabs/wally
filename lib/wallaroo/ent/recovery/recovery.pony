/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "promises"
use "wallaroo/ent/network"
use "wallaroo_labs/mort"
use "wallaroo/core/initialization"
use "wallaroo/core/messages"
use "wallaroo/ent/snapshot"

actor Recovery
  """
  Phases:
    1) _AwaitRecovering: Waiting for start_recovery() to be called
    2) _BoundariesReconnect: Wait for all boundaries to reconnect.
    3) _Rollback: Rollback all state to last safe checkpoint.
    4) _FinishedRecovering: Finished recovery
  """
  let _self: Recovery tag = this
  let _auth: AmbientAuth
  let _worker_name: String
  var _recovery_phase: _RecoveryPhase = _AwaitRecovering
  var _workers: Array[String] val = recover Array[String] end

  //!@ Can we remove this?
  let _event_log: EventLog
  let _recovery_reconnecter: RecoveryReconnecter
  let _snapshot_initiator: SnapshotInitiator
  let _connections: Connections
  var _initializer: (LocalTopologyInitializer | None) = None

  new create(auth: AmbientAuth, worker_name: String, event_log: EventLog,
    recovery_reconnecter: RecoveryReconnecter,
    snapshot_initiator: SnapshotInitiator, connections: Connections)
  =>
    _auth = auth
    _worker_name = worker_name
    _event_log = event_log
    _recovery_reconnecter = recovery_reconnecter
    _snapshot_initiator = snapshot_initiator
    _connections = connections

  be start_recovery(
    initializer: LocalTopologyInitializer,
    workers: Array[String] val)
  =>
    //!@ Not sure we need to thread workers through anymore
    let other_workers = recover trn Array[String] end
    for w in workers.values() do
      if w != _worker_name then other_workers.push(w) end
    end
    _workers = consume other_workers

    _initializer = initializer
    _recovery_phase.start_recovery(_workers, this)

  be recovery_reconnect_finished() =>
    _recovery_phase.recovery_reconnect_finished()

  be rollback_complete(snapshot_id: SnapshotId) =>
    _recovery_phase.rollback_complete(snapshot_id)

  fun ref _start_reconnect(workers: Array[String] val) =>
    ifdef "resilience" then
      @printf[I32]("|~~ - Recovery Phase: Reconnect - ~~|\n".cstring())
    end
    _recovery_phase = _BoundariesReconnect(_recovery_reconnecter, workers,
      this)
    _recovery_phase.start_reconnect()

  fun ref _initiate_rollback() =>
    ifdef "resilience" then
      @printf[I32]("|~~ - Recovery Phase: Rollback - ~~|\n".cstring())

      _recovery_phase = _Rollback(this)
      let action = Promise[SnapshotId]
      action.next[None](recover this~rollback_complete() end)
      _snapshot_initiator.initiate_rollback(action)
    else
      _recovery_complete()
    end

  fun ref _recovery_complete() =>
    ifdef "resilience" then
      @printf[I32]("|~~ - Recovery COMPLETE - ~~|\n".cstring())
    end
    _recovery_phase = _FinishedRecovering
    //!@ Do we still want to do this?
    match _initializer
    | let lti: LocalTopologyInitializer =>
      _event_log.start_pipeline_logging(lti)
    else
      Fail()
    end

trait _RecoveryPhase
  fun name(): String

  fun ref start_recovery(workers: Array[String] val, recovery: Recovery ref) =>
    _invalid_call()

  fun ref start_reconnect() =>
    _invalid_call()

  fun ref recovery_reconnect_finished() =>
    _invalid_call()

  fun ref rollback_complete(snapshot_id: SnapshotId) =>
    _invalid_call()

  fun _invalid_call() =>
    @printf[I32]("Invalid call on recovery phase %s\n".cstring(),
      name().cstring())
    Fail()

class _AwaitRecovering is _RecoveryPhase
  fun name(): String => "_AwaitRecovering"

  fun ref start_recovery(workers: Array[String] val, recovery: Recovery ref) =>
    recovery._start_reconnect(workers)

class _BoundariesReconnect is _RecoveryPhase
  let _recovery_reconnecter: RecoveryReconnecter
  let _workers: Array[String] val
  let _recovery: Recovery ref

  new create(recovery_reconnecter: RecoveryReconnecter,
    workers: Array[String] val, recovery: Recovery ref)
  =>
    _recovery_reconnecter = recovery_reconnecter
    _workers = workers
    _recovery = recovery

  fun name(): String => "_BoundariesReconnect"

  fun ref start_reconnect() =>
    _recovery_reconnecter.start_recovery_reconnect(_workers, _recovery)

  fun ref recovery_reconnect_finished() =>
    _recovery._initiate_rollback()

class _Rollback is _RecoveryPhase
  let _recovery: Recovery ref

  new create(recovery: Recovery ref) =>
    _recovery = recovery

  fun name(): String => "_Rollback"

  fun ref rollback_complete(snapshot_id: SnapshotId) =>
    _recovery._recovery_complete()

class _FinishedRecovering is _RecoveryPhase
  fun name(): String => "_FinishedRecovering"

