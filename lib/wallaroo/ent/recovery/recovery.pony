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
use "wallaroo/ent/data_receiver"
use "wallaroo/ent/network"
use "wallaroo/ent/router_registry"
use "wallaroo/ent/checkpoint"
use "wallaroo_labs/collection_helpers"
use "wallaroo_labs/mort"

actor Recovery
  """
  Phases:
    1) _AwaitRecovering: Waiting for start_recovery() to be called
    2) _BoundariesReconnect: Wait for all boundaries to reconnect.
       rollback.
    3) _PrepareRollback: Have EventLog tell all resilients to prepare for
    4) _RollbackLocalKeys: Roll back topology. Wait for acks from all workers.
       register downstream.
    5) _RollbackBarrier: Use barrier to ensure that all old data is cleared
       and all producers and consumers are ready to rollback state.
    6) _AwaitDataReceiversAck: Put DataReceivers in non-recovery mode.
    7) _AwaitRecoveryInitiatedAcks: Wait for all workers to acknowledge
       recovery is about to start. This gives currently recovering workers a
       chance to cede control to us if we're the latest recovering.
    8) _Rollback: Rollback all state to last safe checkpoint.
    9) _FinishedRecovering: Finished recovery
    10) _RecoveryOverrideAccepted: If recovery was handed off to another worker
  """
  let _self: Recovery tag = this
  let _auth: AmbientAuth
  let _worker_name: WorkerName
  var _recovery_phase: _RecoveryPhase = _AwaitRecovering
  var _workers: Array[WorkerName] val = recover Array[WorkerName] end

  //!@ Can we remove this?
  let _event_log: EventLog
  let _recovery_reconnecter: RecoveryReconnecter
  let _checkpoint_initiator: CheckpointInitiator
  let _connections: Connections
  let _router_registry: RouterRegistry
  var _initializer: (LocalTopologyInitializer | None) = None
  let _data_receivers: DataReceivers
  // The checkpoint id we are recovering to if we're recovering
  var _checkpoint_id: (CheckpointId | None) = None

  new create(auth: AmbientAuth, worker_name: WorkerName, event_log: EventLog,
    recovery_reconnecter: RecoveryReconnecter,
    checkpoint_initiator: CheckpointInitiator, connections: Connections,
    router_registry: RouterRegistry, data_receivers: DataReceivers)
  =>
    _auth = auth
    _worker_name = worker_name
    _event_log = event_log
    _recovery_reconnecter = recovery_reconnecter
    _checkpoint_initiator = checkpoint_initiator
    _connections = connections
    _router_registry = router_registry
    _data_receivers = data_receivers

  be update_initializer(initializer: LocalTopologyInitializer) =>
    _initializer = initializer

  be update_checkpoint_id(s_id: CheckpointId) =>
    _checkpoint_id = s_id

  be start_recovery(initializer: LocalTopologyInitializer,
    workers: Array[WorkerName] val)
  =>
    _workers = workers
    _initializer = initializer
    _router_registry.stop_the_world()
    _recovery_phase.start_recovery(_workers, this)

  be recovery_reconnect_finished() =>
    _recovery_phase.recovery_reconnect_finished()

  be rollback_prep_complete() =>
    _recovery_phase.rollback_prep_complete()

  be worker_ack_local_keys_rollback(w: WorkerName, s_id: CheckpointId) =>
    _recovery_phase.worker_ack_local_keys_rollback(w, s_id)

  be worker_ack_register_producers(w: WorkerName) =>
    _recovery_phase.worker_ack_register_producers(w)

  be rollback_barrier_complete(token: CheckpointRollbackBarrierToken) =>
    _recovery_phase.rollback_barrier_complete(token)

  be data_receivers_ack() =>
    _recovery_phase.data_receivers_ack()

  be rollback_complete(worker: WorkerName,
    token: CheckpointRollbackBarrierToken)
  =>
    _recovery_phase.rollback_complete(worker, token)

  be recovery_initiated_at_worker(worker: WorkerName,
    token: CheckpointRollbackBarrierToken)
  =>
    let overriden = _recovery_phase.try_override_recovery(worker, token,
      this)

    if overriden then
      _recovery_reconnecter.abort_early(worker)
      // !@ We should probably ensure DataReceivers has acked an override if
      // that happens before acking.
      try
        let msg = ChannelMsgEncoder.ack_recovery_initiated(token, _worker_name,
          _auth)?
        _connections.send_control(worker, msg)
      else
        Fail()
      end
    end

  be ack_recovery_initiated(worker: WorkerName,
    token: CheckpointRollbackBarrierToken)
  =>
    _recovery_phase.ack_recovery_initiated(worker, token)

  fun ref _start_reconnect(workers: Array[WorkerName] val) =>
    ifdef "resilience" then
      @printf[I32]("|~~ - Recovery Phase: Reconnect - ~~|\n".cstring())
    end
    _recovery_phase = _BoundariesReconnect(_recovery_reconnecter, workers,
      this)
    _recovery_phase.start_reconnect()

  fun ref _prepare_rollback() =>
    ifdef "resilience" then
      @printf[I32]("|~~ - Recovery Phase: Prepare Rollback - ~~|\n".cstring())
      _event_log.prepare_for_rollback(this, _checkpoint_initiator)

      // Inform cluster to prepare for rollback
      try
        let msg = ChannelMsgEncoder.prepare_for_rollback(_worker_name, _auth)?
        _connections.send_control_to_cluster(msg)
      else
        Fail()
      end

      _recovery_phase = _PrepareRollback(this)
    else
      _recovery_complete()
    end

  fun ref _rollback_local_keys() =>
    ifdef "resilience" then
      @printf[I32]("|~~ - Recovery Phase: Rollback Local Keys - ~~|\n"
        .cstring())
      try
        let checkpoint_id = _checkpoint_id as CheckpointId
        _recovery_phase = _RollbackLocalKeys(this, checkpoint_id, _workers)

        //!@ Tell someone to start rolling back topology
        let promise = Promise[None]
        promise.next[None]({(n: None) =>
          _self.worker_ack_local_keys_rollback(_worker_name, checkpoint_id)
        })
        (_initializer as LocalTopologyInitializer)
          .rollback_local_keys(checkpoint_id, promise)

        // Inform cluster to rollback topology graph
        try
          let msg = ChannelMsgEncoder.rollback_local_keys(_worker_name,
            checkpoint_id, _auth)?
          _connections.send_control_to_cluster(msg)
        else
          Fail()
        end
      else
        Fail()
      end
    else
      _recovery_complete()
    end

  fun ref _local_keys_rollback_complete() =>
    ifdef "resilience" then
      @printf[I32]("|~~ - Recovery Phase: Rollback Barrier - ~~|\n".cstring())
      let promise = Promise[CheckpointRollbackBarrierToken]
      promise.next[None]({(token: CheckpointRollbackBarrierToken) =>
        _self.rollback_barrier_complete(token)
      })
      _checkpoint_initiator.initiate_rollback(promise, _worker_name)

      _recovery_phase = _RollbackBarrier(this)
    else
      _recovery_complete()
    end

  fun ref _rollback_barrier_complete(token: CheckpointRollbackBarrierToken) =>
    ifdef "resilience" then
      @printf[I32]("|~~ - Recovery Phase: AwaitDataReceiversAck - ~~|\n"
        .cstring())
      _data_receivers.rollback_barrier_complete(this)
      _recovery_phase = _AwaitDataReceiversAck(this, token)
    end

  fun ref _data_receivers_ack_complete(token: CheckpointRollbackBarrierToken) =>
    ifdef "resilience" then
      @printf[I32](("|~~ - Recovery Phase: Await Recovery Initiated Acks " +
        "- ~~| \n").cstring())
      _recovery_phase = _AwaitRecoveryInitiatedAcks(token, _workers, this)

      // Inform cluster we've initiated recovery
      try
        let msg = ChannelMsgEncoder.recovery_initiated(token, _worker_name,
          _auth)?
        _connections.send_control_to_cluster(msg)
      else
        Fail()
      end
      _recovery_phase.ack_recovery_initiated(_worker_name, token)
    end

  fun ref _recovery_initiated_acks_complete(
    token: CheckpointRollbackBarrierToken)
  =>
    ifdef "resilience" then
      @printf[I32]("|~~ - Recovery Phase: Rollback - ~~|\n".cstring())

      _recovery_phase = _Rollback(this, token, _workers)
      let promise = Promise[CheckpointRollbackBarrierToken]
      promise.next[None](recover this~rollback_complete(_worker_name) end)
      _event_log.initiate_rollback(token, promise)

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
    _router_registry.resume_the_world(_worker_name)
    _data_receivers.recovery_complete(this)
    _recovery_phase = _FinishedRecovering
    match _initializer
    | let lti: LocalTopologyInitializer =>
      lti.report_recovery_ready_to_work()

      //!@ Do we still want to do this?
      _event_log.quick_initialize(lti)
    else
      Fail()
    end

    _checkpoint_initiator.resume_checkpoint()

  fun ref _abort_early(worker: WorkerName) =>
    """
    If recovery has been initiated at another worker while we were recovering,
    then we finish our boundary connections and then abort, ceding the recovery
    protocol to the other worker.
    """
    _data_receivers.recovery_complete(this)
    @printf[I32]("|~~ - Recovery initiated at %s. Ceding control. - ~~|\n"
      .cstring(), worker.cstring())
    match _initializer
    | let lti: LocalTopologyInitializer =>
      // TODO: This is not really correct. If we cede control to another worker
      // midway through recovery, then we are still in an incomplete state and
      // will only be ready to work once that other worker completes its
      // recovery process. At the moment, the only impact of this is that the
      // message indicating the application is ready to work will be printed
      // to STDOUT too early.
      lti.report_recovery_ready_to_work()
    else
      Fail()
    end
    _recovery_phase = _RecoveryOverrideAccepted
