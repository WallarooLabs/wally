/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "promises"
use "wallaroo/core/common"
use "wallaroo/core/initialization"
use "wallaroo/core/messages"
use "wallaroo/ent/barrier"
use "wallaroo/ent/network"
use "wallaroo/ent/snapshot"
use "wallaroo_labs/collection_helpers"
use "wallaroo_labs/mort"

actor Recovery
  """
  Phases:
    1) _AwaitRecovering: Waiting for start_recovery() to be called
    2) _BoundariesReconnect: Wait for all boundaries to reconnect.
    3) _PrepareRollback: Use barrier to ensure that all old data is cleared
       and all producers and consumers are ready to rollback state.
    4) _Rollback: Rollback all state to last safe checkpoint.
    5) _FinishedRecovering: Finished recovery
  """
  let _self: Recovery tag = this
  let _auth: AmbientAuth
  let _worker_name: WorkerName
  var _recovery_phase: _RecoveryPhase = _AwaitRecovering
  var _workers: Array[WorkerName] val = recover Array[WorkerName] end

  //!@ Can we remove this?
  let _event_log: EventLog
  let _recovery_reconnecter: RecoveryReconnecter
  let _snapshot_initiator: SnapshotInitiator
  let _connections: Connections
  var _initializer: (LocalTopologyInitializer | None) = None

  new create(auth: AmbientAuth, worker_name: WorkerName, event_log: EventLog,
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
    workers: Array[WorkerName] val)
  =>
    //!@ Not sure we need to thread workers through anymore
    let other_workers = recover trn Array[WorkerName] end
    for w in workers.values() do
      if w != _worker_name then other_workers.push(w) end
    end
    _workers = consume other_workers

    _initializer = initializer
    _recovery_phase.start_recovery(_workers, this)

  be recovery_reconnect_finished() =>
    _recovery_phase.recovery_reconnect_finished()

  be rollback_prep_complete(token: SnapshotRollbackBarrierToken) =>
    _recovery_phase.rollback_prep_complete(token)

  be rollback_complete(worker: WorkerName,
    token: SnapshotRollbackBarrierToken)
  =>
    _recovery_phase.rollback_complete(worker, token)

  be recovery_initiated_at_worker(worker: WorkerName,
    token: SnapshotRollbackBarrierToken)
  =>
    _recovery_phase.try_override_recovery(worker, token, this)

  fun ref _start_reconnect(workers: Array[WorkerName] val) =>
    ifdef "resilience" then
      @printf[I32]("|~~ - Recovery Phase: Reconnect - ~~|\n".cstring())
    end
    _recovery_phase = _BoundariesReconnect(_recovery_reconnecter, workers,
      this)
    _recovery_phase.start_reconnect()

  fun ref _initiate_rollback() =>
    ifdef "resilience" then
      @printf[I32]("|~~ - Recovery Phase: Prepare Rollback - ~~|\n".cstring())

      _recovery_phase = _PrepareRollback(this)
      let action = Promise[SnapshotRollbackBarrierToken]
      action.next[None]({(token: SnapshotRollbackBarrierToken) =>
        // Inform cluster we've initiated recovery
        try
          let msg = ChannelMsgEncoder.recovery_initiated(token, _worker_name,
            _auth)?
          _connections.send_control_to_cluster(msg)
        else
          Fail()
        end
        _self.rollback_prep_complete(token)
      })
      _snapshot_initiator.initiate_rollback(action)
    else
      _recovery_complete()
    end

  fun ref _rollback_prep_complete(token: SnapshotRollbackBarrierToken) =>
    ifdef "resilience" then
      @printf[I32]("|~~ - Recovery Phase: Rollback - ~~|\n".cstring())
      _recovery_phase = _Rollback(this, token, _workers)
      let action = Promise[SnapshotRollbackBarrierToken]
      action.next[None](recover this~rollback_complete(_worker_name) end)
      _event_log.initiate_rollback(token, action)

      try
        let msg = ChannelMsgEncoder.event_log_initiate_rollback(token,
          _worker_name, _auth)?
        for w in _workers.values() do
          _connections.send_control(w, msg)
        end
      else
        Fail()
      end
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
      _event_log.quick_initialize(lti)
    else
      Fail()
    end

  fun ref _abort_early(worker: WorkerName) =>
    """
    If recovery has been initiated at another worker while we were recovering,
    then we finish our boundary connections and then abort, ceding the recovery
    protocol to the other worker.
    """
    @printf[I32]("|~~ - Recovery initiated at %s. Ceding control. - ~~|\n"
      .cstring(), worker.cstring())
    _recovery_phase = _FinishedRecovering
