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
use "wallaroo/core/checkpoint"
use "wallaroo/core/common"
use "wallaroo/core/initialization"
use "wallaroo/core/messages"
use "wallaroo/core/barrier"
use "wallaroo/core/data_receiver"
use "wallaroo/core/network"
use "wallaroo/core/router_registry"
use "wallaroo_labs/collection_helpers"
use "wallaroo_labs/mort"

actor Recovery
  """
  Phases:
    1) _AwaitRecovering: Waiting for start_recovery() to be called
    2) _BoundariesReconnect: Wait for all boundaries to reconnect.
       It is possible to skip this phase if we are rolling back online because
       of a checkpoint abort.
    3) _PrepareRollback: Have EventLog tell all resilients to prepare for
    4) _RollbackLocalKeys: Roll back topology. Wait for acks from all workers.
       register downstream.
    5) _AwaitRollbackId: We request our rollback id from the
       CheckpointInitiator.
    6) _AwaitRecoveryInitiatedAcks: Wait for all workers to acknowledge
       recovery is about to start. This gives currently recovering workers a
       chance to cede control to us if we're the latest recovering.
    7) _RollbackBarrier: Use barrier to ensure that all old data is cleared
       and all producers and consumers are ready to rollback state.
    8) _AwaitDataReceiversAck: Put DataReceivers in non-recovery mode.
    9) _Rollback: Rollback all state to last safe checkpoint.
    10) _FinishedRecovering: Finished recovery
    11) _RecoveryOverrideAccepted: If recovery was handed off to another worker
  """
  let _self: Recovery tag = this
  let _auth: AmbientAuth
  let _worker_name: WorkerName
  var _recovery_phase: _RecoveryPhase = _AwaitRecovering
  var _workers: Array[WorkerName] val = recover Array[WorkerName] end

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
    router_registry: RouterRegistry, data_receivers: DataReceivers,
    is_recovering: Bool)
  =>
    _auth = auth
    _worker_name = worker_name
    _event_log = event_log
    _recovery_reconnecter = recovery_reconnecter
    _checkpoint_initiator = checkpoint_initiator
    _connections = connections
    _router_registry = router_registry
    _data_receivers = data_receivers
    _checkpoint_initiator.set_recovery(this)

  be update_initializer(initializer: LocalTopologyInitializer) =>
    _initializer = initializer

  be update_checkpoint_id(s_id: CheckpointId) =>
    _checkpoint_id = s_id

  be start_recovery(workers: Array[WorkerName] val,
    with_reconnect: Bool = true)
  =>
    _workers = workers
    _router_registry.stop_the_world()
    _recovery_phase.start_recovery(_workers, this, with_reconnect)

  be recovery_reconnect_finished(abort_promise: (Promise[None] | None)) =>
    _recovery_phase.recovery_reconnect_finished()

  be rollback_prep_complete() =>
    _recovery_phase.rollback_prep_complete()

  be worker_ack_local_keys_rollback(w: WorkerName, s_id: CheckpointId) =>
    _recovery_phase.worker_ack_local_keys_rollback(w, s_id)

  be worker_ack_register_producers(w: WorkerName) =>
    _recovery_phase.worker_ack_register_producers(w)

  be rollback_barrier_fully_acked(token: CheckpointRollbackBarrierToken) =>
    _recovery_phase.rollback_barrier_complete(token)

  be data_receivers_ack() =>
    _recovery_phase.data_receivers_ack()

  be rollback_complete(worker: WorkerName,
    token: CheckpointRollbackBarrierToken)
  =>
    _recovery_phase.rollback_complete(worker, token)

  be recovery_initiated_at_worker(worker: WorkerName, rollback_id: RollbackId)
  =>
    if worker != _worker_name then
      @printf[I32]("Recovery initiation attempted by %s\n".cstring(),
        worker.cstring())
      let promise = Promise[None]
      promise.next[None]({(_: None) =>
        // !TODO!: We should probably ensure DataReceivers has acked an
        // override if that happens before acking.
        try
          @printf[I32]("!@ Sending ack_recovery_initiated to %s\n".cstring(), worker.cstring())
          let msg = ChannelMsgEncoder.ack_recovery_initiated(_worker_name,
            _auth)?
          _connections.send_control(worker, msg)
        else
          Fail()
        end
      })

      _recovery_phase.try_override_recovery(worker, rollback_id, this, promise)
    end

  be ack_recovery_initiated(worker: WorkerName) =>
    _recovery_phase.ack_recovery_initiated(worker)

  fun ref _start_reconnect(workers: Array[WorkerName] val,
    with_reconnect: Bool)
  =>
    if with_reconnect then
      ifdef "resilience" then
        @printf[I32]("|~~ - Recovery Phase: Reconnect - ~~|\n".cstring())
      end
      _recovery_phase = _BoundariesReconnect(_recovery_reconnecter, workers,
        this)
      _recovery_phase.start_reconnect()
    else
      _prepare_rollback()
    end

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
      @printf[I32]("|~~ - Recovery Phase: Await Rollback Id - ~~|\n".cstring())
      _recovery_phase = _AwaitRollbackId(this)
      let promise = Promise[RollbackId]
      promise.next[None](_self~receive_rollback_id())
      _checkpoint_initiator.request_rollback_id(promise)
    else
      _recovery_complete()
    end

  be receive_rollback_id(rollback_id: RollbackId) =>
    _recovery_phase.receive_rollback_id(rollback_id)

  fun ref request_recovery_initiated_acks(rollback_id: RollbackId) =>
    ifdef "resilience" then
      @printf[I32]("|~~ - Recovery Phase: Await Recovery Initiated Acks - ~~|\n".cstring())
      try
        let msg = ChannelMsgEncoder.recovery_initiated(rollback_id,
          _worker_name, _auth)?
        _connections.send_control_to_cluster(msg)
      else
        Fail()
      end
      _recovery_phase = _AwaitRecoveryInitiatedAcks(_workers, this,
        rollback_id)
      _recovery_phase.ack_recovery_initiated(_worker_name)
    else
      _recovery_complete()
    end

  fun ref _recovery_initiated_acks_complete(rollback_id: RollbackId) =>
    ifdef "resilience" then
      @printf[I32]("|~~ - Recovery Phase: Rollback Barrier - ~~|\n".cstring())

      _recovery_phase = _RollbackBarrier(this)

      let promise = Promise[CheckpointRollbackBarrierToken]
      promise.next[None]({(token: CheckpointRollbackBarrierToken) =>
        _self.rollback_barrier_fully_acked(token)
      })
      _checkpoint_initiator.initiate_rollback(promise, _worker_name,
        rollback_id)
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

  fun ref _data_receivers_ack_complete(token: CheckpointRollbackBarrierToken)
  =>
    ifdef "resilience" then
      @printf[I32](("|~~ - Recovery Phase: Rollback " +
        "- ~~| \n").cstring())
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
    end

  fun ref _recovery_complete() =>
    ifdef "resilience" then
      @printf[I32]("|~~ - Recovery COMPLETE - ~~|\n".cstring())
    end
    _router_registry.resume_the_world(_worker_name)
    _data_receivers.recovery_complete()
    _recovery_phase = _FinishedRecovering
    match _initializer
    | let lti: LocalTopologyInitializer =>
      lti.report_recovery_ready_to_work()

      // !TODO!: Do we still want to do this?
      _event_log.quick_initialize(lti)
    else
      Fail()
    end

    _checkpoint_initiator.resume_checkpointing_from_rollback()

  fun ref _abort_early(worker: WorkerName) =>
    """
    If recovery has been initiated at another worker while we were recovering,
    then we finish our boundary connections and then abort, ceding the recovery
    protocol to the other worker.
    """
    _data_receivers.recovery_complete()
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
      // !TODO!: Do we still want to do this?
      _event_log.quick_initialize(lti)
    else
      Fail()
    end
    _recovery_phase = _RecoveryOverrideAccepted
