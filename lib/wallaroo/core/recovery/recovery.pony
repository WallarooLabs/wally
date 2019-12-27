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
use "wallaroo/core/boundary"
use "wallaroo/core/checkpoint"
use "wallaroo/core/common"
use "wallaroo/core/initialization"
use "wallaroo/core/messages"
use "wallaroo/core/barrier"
use "wallaroo/core/data_receiver"
use "wallaroo/core/network"
use "wallaroo/core/registries"
use "wallaroo_labs/collection_helpers"
use "wallaroo_labs/mort"


type RecoveryReason is U16
primitive RecoveryReasons
  fun not_recovering(): U16 => 0
  fun abort_checkpoint(): U16 => 100
  fun crash_recovery(): U16 => 200

  fun has_priority(a: RecoveryReason, b: RecoveryReason): Bool =>
    a > b

  fun is_recovering_worker(r: RecoveryReason): Bool =>
    r == RecoveryReasons.crash_recovery()

  fun string_for(rr: RecoveryReason): String =>
    match rr
    | RecoveryReasons.not_recovering() => "no reason to recover"
    | RecoveryReasons.abort_checkpoint() => "checkpoint abort"
    | RecoveryReasons.crash_recovery() => "crash recovery"
    else
      "unknown recovery reason"
    end

actor Recovery
  """
  Phases:
    1) _AwaitRecovering: Waiting for start_recovery() to be called
    2) _BoundariesReconnect: Wait for all boundaries to reconnect.
       It is possible to skip this phase if we are rolling back online because
       of a checkpoint abort, in which case we go directly to _PrepareRollback.
    3) _WaitingForBoundariesMap: Wait for map of current boundaries so we can
      make sure they all register downstream.
    4) _WaitingForBoundariesToAckRegistering: Wait for all boundaires to ack
      sending register_producer messages downstream. [We rely on causal
      message ordering here. Since we're requesting acks from boundaries
      after all their upstream producers, we know these acks will be sent
      after the boundaries have forwarded any register_producer messages.]
    5) _PrepareRollback: Have EventLog tell all resilients to prepare for
    6) _RollbackLocalKeys: Roll back topology. Wait for acks from all workers.
       register downstream.
    7) _AwaitRollbackId: We request our rollback id from the
       CheckpointInitiator.
    8) _AwaitRecoveryInitiatedAcks: Wait for all workers to acknowledge
       recovery is about to start. This gives currently recovering workers a
       chance to cede control to us if we're the latest recovering.
    9) _WaitForDataReceiversAcceptBarriersAcks: We are now ready to tell
       all DataReceivers they can process barriers.
    10) _RollbackBarrier: Use barrier to ensure that all old data is cleared
       and all producers and consumers are ready to rollback state.
    11) _AwaitDataReceiversAck: Put DataReceivers in non-recovery mode.
    12) _Rollback: Rollback all state to last safe checkpoint.
    13) _NotRecovering: Either finished recovery or was never recovering
    14) _RecoveryOverrideAccepted: If recovery was handed off to another worker
  """
  let _self: Recovery tag = this
  let _auth: AmbientAuth
  let _worker_name: WorkerName
  var _recovery_phase: _RecoveryPhase
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
    if is_recovering then
      _recovery_phase = _AwaitRecovering(RecoveryReasons.crash_recovery())
    else
      _recovery_phase = _NotRecovering
    end
    _checkpoint_initiator.set_recovery(this)

  be update_initializer(initializer: LocalTopologyInitializer) =>
    _initializer = initializer

  be update_checkpoint_id(s_id: CheckpointId) =>
    _checkpoint_id = s_id

  be start_recovery(workers: Array[WorkerName] val,
    reason: RecoveryReason)
  =>
    @printf[I32]("|~~ - Starting recovery for %s - ~~|\n".cstring(),
      RecoveryReasons.string_for(reason).cstring())
    _workers = workers
    // In case we died while another worker was recovering, we should send
    // every worker our corresponding boundary count.
    for w in _workers.values() do
      _router_registry.inform_worker_of_boundary_count(w)
    end
    _router_registry.stop_the_world()
    _recovery_phase.start_recovery(_workers, this, reason)

  be recovery_reconnect_finished(abort_promise: (Promise[None] | None)) =>
    _recovery_phase.recovery_reconnect_finished()

  be inform_of_boundaries_map(
    boundaries: Map[WorkerName, OutgoingBoundary] val)
  =>
    _recovery_phase.inform_of_boundaries_map(boundaries)

  be boundary_acked_registering(b: OutgoingBoundary) =>
    """
    When we receive all producer register downstream acks, we send a promise
    to each boundary for it to ack registering downstream. The boundary
    requests an ack from the DataReceiver, and then acks to us. We also do
    this the other way, having all DataReceivers request punctuation acks from
    their corresponding incoming boundaries.
    """
    _recovery_phase.boundary_acked_registering(b)

  be data_receivers_acked_registering(n: None) =>
    _recovery_phase.data_receivers_acked_registering()

  be rollback_prep_complete() =>
    _recovery_phase.rollback_prep_complete()

  be worker_ack_local_keys_rollback(w: WorkerName, s_id: CheckpointId) =>
    _recovery_phase.worker_ack_local_keys_rollback(w, s_id)

  be data_receivers_acked_accepting_barriers() =>
    _recovery_phase.data_receivers_acked_accepting_barriers()

  be rollback_barrier_fully_acked(token: CheckpointRollbackBarrierToken) =>
    _recovery_phase.rollback_barrier_complete(token)

  be data_receivers_ack() =>
    _recovery_phase.data_receivers_ack()

  be rollback_complete(worker: WorkerName,
    token: CheckpointRollbackBarrierToken)
  =>
    _recovery_phase.rollback_complete(worker, token)

  be recovery_initiated_at_worker(worker: WorkerName, rollback_id: RollbackId,
    reason: RecoveryReason)
  =>
    if worker != _worker_name then
      @printf[I32]("Recovery initiation attempted by %s\n".cstring(),
        worker.cstring())
      let promise = Promise[None]
      promise.next[None]({(_: None) =>
        // !TODO!: We should probably ensure DataReceivers has acked an
        // override if that happens before acking.
        try
          let msg = ChannelMsgEncoder.ack_recovery_initiated(_worker_name,
            _auth)?
          _connections.send_control(worker, msg)
        else
          Fail()
        end
      })

      _recovery_phase.try_override_recovery(worker, rollback_id, reason, this,
        promise)
    end

  be ack_recovery_initiated(worker: WorkerName) =>
    _recovery_phase.ack_recovery_initiated(worker)

  fun ref _start_reconnect(workers: Array[WorkerName] val,
    reason: RecoveryReason, recovery_priority_tracker: RecoveryPriorityTracker)
  =>
    var should_reconnect_boundaries = false
    match reason
    | RecoveryReasons.crash_recovery() =>
      ifdef "resilience" then
        @printf[I32]("|~~ - Rolling back for crash recovery - ~~|\n".cstring())
        @printf[I32]("|~~ - Recovery Phase: Reconnect - ~~|\n".cstring())
      end
      if workers.size() > 1 then
        should_reconnect_boundaries = true
      end
    | RecoveryReasons.abort_checkpoint() =>
      ifdef "resilience" then
        @printf[I32]("|~~ - Rolling back for aborted checkpoint. Skipping reconnect phases. - ~~|\n".cstring())
      end
    else
      @printf[I32]("Invalid reason %s for recovery!\n".cstring(),
        reason.string().cstring())
      Fail()
    end

    if should_reconnect_boundaries then
      _recovery_phase = _BoundariesReconnect(_recovery_reconnecter, workers,
        this, reason, recovery_priority_tracker)
      _recovery_phase.start_reconnect()
    else
      _prepare_rollback(reason, recovery_priority_tracker)
    end

  fun ref request_boundaries_map(reason: RecoveryReason,
    recovery_priority_tracker: RecoveryPriorityTracker)
  =>
    _recovery_phase = _WaitingForBoundariesMap(this, reason,
      recovery_priority_tracker)
    let promise = Promise[Map[WorkerName, OutgoingBoundary] val]
    promise.next[None](_self~inform_of_boundaries_map())
    _router_registry.list_boundaries(promise)

  fun ref request_boundaries_to_ack_registering(
    obs: SetIs[OutgoingBoundary], reason: RecoveryReason,
    recovery_priority_tracker: RecoveryPriorityTracker)
  =>
    _recovery_phase = _WaitingForBoundariesToAckRegistering(this, obs,
      reason, recovery_priority_tracker)
    for ob in obs.values() do
      let promise = Promise[OutgoingBoundary]
      promise.next[None](_self~boundary_acked_registering())
      ob.ack_immediately(promise)
    end
    let promise = Promise[None]
    promise.next[None](_self~data_receivers_acked_registering())
    _data_receivers.request_boundary_punctuation_acks(promise)

  fun ref _prepare_rollback(reason: RecoveryReason,
    recovery_priority_tracker: RecoveryPriorityTracker)
  =>
    ifdef "resilience" then
      if recovery_priority_tracker.has_override() then
        recovery_priority_tracker.initiate_abort(this)
      else
        @printf[I32]("|~~ - Recovery Phase: Prepare Rollback - ~~|\n"
          .cstring())
        _event_log.prepare_for_rollback(this, _checkpoint_initiator)

        // Inform cluster to prepare for rollback
        try
          let msg = ChannelMsgEncoder.prepare_for_rollback(_worker_name, _auth)?
          _connections.send_control_to_cluster(msg)
        else
          Fail()
        end

        _recovery_phase = _PrepareRollback(this, reason)
      end
    else
      _recovery_complete(0, 0, reason)
    end

  fun ref _rollback_local_keys(reason: RecoveryReason) =>
    ifdef "resilience" then
      @printf[I32]("|~~ - Recovery Phase: Rollback Local Keys - ~~|\n"
        .cstring())
      try
        let checkpoint_id = _checkpoint_id as CheckpointId
        _recovery_phase = _RollbackLocalKeys(this, checkpoint_id, _workers,
          reason)

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
      _recovery_complete(0, 0, reason)
    end

  fun ref _local_keys_rollback_complete(reason: RecoveryReason) =>
    ifdef "resilience" then
      @printf[I32]("|~~ - Recovery Phase: Await Rollback Id - ~~|\n".cstring())
      _recovery_phase = _AwaitRollbackId(this, reason)
      let promise = Promise[RollbackId]
      promise.next[None](_self~receive_rollback_id())
      _checkpoint_initiator.request_rollback_id(promise)
    else
      _recovery_complete(0, 0, reason)
    end

  be receive_rollback_id(rollback_id: RollbackId) =>
    _recovery_phase.receive_rollback_id(rollback_id)

  fun ref request_recovery_initiated_acks(rollback_id: RollbackId,
    reason: RecoveryReason)
  =>
    ifdef "resilience" then
      @printf[I32]("|~~ - Recovery Phase: Await Recovery Initiated Acks - ~~|\n".cstring())
      try
        let msg = ChannelMsgEncoder.recovery_initiated(rollback_id,
          _worker_name, reason, _auth)?
        _connections.send_control_to_cluster(msg)
      else
        Fail()
      end
      _recovery_phase = _AwaitRecoveryInitiatedAcks(_workers, this,
        rollback_id, reason)
      _recovery_phase.ack_recovery_initiated(_worker_name)
    else
      _recovery_complete(0, 0, reason)
    end

  fun ref _recovery_initiated_acks_complete(rollback_id: RollbackId,
    reason: RecoveryReason)
  =>
    ifdef "resilience" then
      @printf[I32]("|~~ - Recovery Phase: Waiting for DataReceivers to Ack Accepting Barriers - ~~|\n".cstring())

      _recovery_phase = _WaitForDataReceiversAcceptBarriersAcks(this,
        rollback_id, reason)

      let promise = Promise[None]
      promise.next[None]({(_: None) =>
        _self.data_receivers_acked_accepting_barriers()
      })
      _data_receivers.start_accepting_barriers(promise, rollback_id)
    else
      _recovery_complete(0, 0, reason)
    end

  fun ref _data_receivers_accepting_barriers(rollback_id: RollbackId,
    reason: RecoveryReason)
  =>
    ifdef "resilience" then
      @printf[I32]("|~~ - Recovery Phase: Rollback Barrier - ~~|\n".cstring())

      _recovery_phase = _RollbackBarrier(this, rollback_id, reason)

      let promise = Promise[CheckpointRollbackBarrierToken]
      promise.next[None]({(token: CheckpointRollbackBarrierToken) =>
        _self.rollback_barrier_fully_acked(token)
      })
      _checkpoint_initiator.initiate_rollback(promise, _worker_name,
        rollback_id)
    else
      _recovery_complete(0, 0, reason)
    end

  fun ref _rollback_barrier_complete(token: CheckpointRollbackBarrierToken,
    reason: RecoveryReason)
  =>
    ifdef "resilience" then
      @printf[I32]("|~~ - Recovery Phase: AwaitDataReceiversAck - ~~|\n"
        .cstring())
      _data_receivers.rollback_barrier_complete(this)
      _recovery_phase = _AwaitDataReceiversAck(this, token, reason)
    end

  fun ref _data_receivers_ack_complete(token: CheckpointRollbackBarrierToken,
    reason: RecoveryReason)
  =>
    ifdef "resilience" then
      @printf[I32](("|~~ - Recovery Phase: Rollback " +
        "- ~~| \n").cstring())
      _recovery_phase = _Rollback(this, token, _workers, reason)

      let promise = Promise[CheckpointRollbackBarrierToken]
      promise.next[None](recover this~rollback_complete(_worker_name) end)
      _event_log.initiate_rollback(token, promise)

      try
        let msg = ChannelMsgEncoder.event_log_initiate_rollback(token,
          _worker_name, _auth)?
        for w in _workers.values() do
          if w != _worker_name then
            _connections.send_control(w, msg)
          end
        end
      else
        Fail()
      end
    end

  fun ref _recovery_complete(rollback_id: RollbackId,
    checkpoint_id: CheckpointId, reason: RecoveryReason)
  =>
    ifdef "resilience" then
      @printf[I32]("|~~ - Recovery COMPLETE - ~~|\n".cstring())
    end
    _router_registry.resume_the_world(_worker_name)
    _data_receivers.recovery_complete()
    _recovery_phase = _NotRecovering
    match _initializer
    | let lti: LocalTopologyInitializer =>
      lti.report_recovery_ready_to_work()

      // !TODO!: Do we still want to do this?
      _event_log.quick_initialize(lti)
    else
      Fail()
    end

    _checkpoint_initiator.resume_checkpointing_from_rollback(rollback_id,
      checkpoint_id)

  fun ref _abort_early(worker: WorkerName) =>
    """
    If recovery has been initiated at another worker while we were recovering,
    then we finish our boundary connections and then abort, ceding the recovery
    protocol to the other worker.
    """
    match _initializer
    | let lti: LocalTopologyInitializer =>
      lti.abort_recovery_early()
    else
      Fail()
    end
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
    _recovery_phase = _NotRecovering
