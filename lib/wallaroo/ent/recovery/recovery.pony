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
use "wallaroo/ent/snapshot"
use "wallaroo_labs/collection_helpers"
use "wallaroo_labs/mort"

actor Recovery
  """
  Phases:
    1) _AwaitRecovering: Waiting for start_recovery() to be called
    2) _BoundariesReconnect: Wait for all boundaries to reconnect.
    3) _PrepareRollback: Have EventLog tell all resilients to prepare for
       rollback.
    4) _RollbackTopology: Roll back topology. Wait for acks from all workers.
    5) _RegisterProducers: Every producer in the rolled back topology needs to
       register downstream.
    6) _RollbackBarrier: Use barrier to ensure that all old data is cleared
       and all producers and consumers are ready to rollback state.
    7) _AwaitDataReceiversAck: Put DataReceivers in non-recovery mode.
    8) _AwaitRecoveryInitiatedAcks: Wait for all workers to acknowledge
       recovery is about to start. This gives currently recovering workers a
       chance to cede control to us if we're the latest recovering.
    9) _Rollback: Rollback all state to last safe checkpoint.
    10) _FinishedRecovering: Finished recovery
    11) _RecoveryOverrideAccepted: If recovery was handed off to another worker
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
  let _router_registry: RouterRegistry
  var _initializer: (LocalTopologyInitializer | None) = None
  let _data_receivers: DataReceivers
  // The snapshot id we are recovering to if we're recovering
  var _snapshot_id: (SnapshotId | None) = None

  new create(auth: AmbientAuth, worker_name: WorkerName, event_log: EventLog,
    recovery_reconnecter: RecoveryReconnecter,
    snapshot_initiator: SnapshotInitiator, connections: Connections,
    router_registry: RouterRegistry, data_receivers: DataReceivers)
  =>
    _auth = auth
    _worker_name = worker_name
    _event_log = event_log
    _recovery_reconnecter = recovery_reconnecter
    _snapshot_initiator = snapshot_initiator
    _connections = connections
    _router_registry = router_registry
    _data_receivers = data_receivers

  be update_snapshot_id(s_id: SnapshotId) =>
    _snapshot_id = s_id

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

  be worker_ack_topology_rollback(w: WorkerName, s_id: SnapshotId) =>
    _recovery_phase.worker_ack_topology_rollback(w, s_id)

  be worker_ack_register_producers(w: WorkerName) =>
    _recovery_phase.worker_ack_register_producers(w)

  be rollback_barrier_complete(token: SnapshotRollbackBarrierToken) =>
    _recovery_phase.rollback_barrier_complete(token)

  be data_receivers_ack() =>
    _recovery_phase.data_receivers_ack()

  be rollback_complete(worker: WorkerName,
    token: SnapshotRollbackBarrierToken)
  =>
    _recovery_phase.rollback_complete(worker, token)

  be recovery_initiated_at_worker(worker: WorkerName,
    token: SnapshotRollbackBarrierToken)
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
    token: SnapshotRollbackBarrierToken)
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
      _event_log.prepare_for_rollback(this)

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

  fun ref _rollback_prep_complete() =>
    ifdef "resilience" then
      @printf[I32]("|~~ - Recovery Phase: Rollback Topology Graph - ~~|\n"
        .cstring())
      try
        let snapshot_id = _snapshot_id as SnapshotId
        _recovery_phase = _RollbackTopology(this, snapshot_id, _workers)

        //!@ Tell someone to start rolling back topology
        let action = Promise[None]
        action.next[None]({(n: None) =>
          _self.worker_ack_topology_rollback(_worker_name, snapshot_id)
        })
        (_initializer as LocalTopologyInitializer)
          .rollback_topology_graph(snapshot_id, action)

        // Inform cluster to rollback topology graph
        try
          let msg = ChannelMsgEncoder.rollback_topology_graph(_worker_name,
            snapshot_id, _auth)?
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

  fun ref _topology_rollback_complete() =>
    ifdef "resilience" then
      @printf[I32]("|~~ - Recovery Phase: Register Producers - ~~|\n"
        .cstring())
      let action = Promise[None]
      action.next[None]({(n: None) =>
        _self.worker_ack_register_producers(_worker_name)})
      _router_registry.producers_register_downstream(action)

      // Inform cluster to register_producers
      try
        let msg = ChannelMsgEncoder.register_producers(_worker_name, _auth)?
        _connections.send_control_to_cluster(msg)
      else
        Fail()
      end

      _recovery_phase = _RegisterProducers(this, _workers)
    else
      _recovery_complete()
    end

  fun ref _register_producers_complete() =>
    ifdef "resilience" then
      @printf[I32]("|~~ - Recovery Phase: Rollback Barrier - ~~|\n".cstring())
      let action = Promise[SnapshotRollbackBarrierToken]
      action.next[None]({(token: SnapshotRollbackBarrierToken) =>
        _self.rollback_barrier_complete(token)
      })
      _snapshot_initiator.initiate_rollback(action, _worker_name)

      _recovery_phase = _RollbackBarrier(this)
    else
      _recovery_complete()
    end

  fun ref _rollback_barrier_complete(token: SnapshotRollbackBarrierToken) =>
    ifdef "resilience" then
      @printf[I32]("|~~ - Recovery Phase: AwaitDataReceiversAck - ~~|\n"
        .cstring())
      _data_receivers.rollback_barrier_complete(this)
      _recovery_phase = _AwaitDataReceiversAck(this, token)
    end

  fun ref _data_receivers_ack_complete(token: SnapshotRollbackBarrierToken) =>
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
    token: SnapshotRollbackBarrierToken)
  =>
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
    _router_registry.resume_the_world(_worker_name)
    _data_receivers.recovery_complete(this)
    _recovery_phase = _FinishedRecovering
    //!@ Do we still want to do this?
    match _initializer
    | let lti: LocalTopologyInitializer =>
      _event_log.quick_initialize(lti)
    else
      Fail()
    end

    _snapshot_initiator.resume_snapshot()

  fun ref _abort_early(worker: WorkerName) =>
    """
    If recovery has been initiated at another worker while we were recovering,
    then we finish our boundary connections and then abort, ceding the recovery
    protocol to the other worker.
    """
    _data_receivers.recovery_complete(this)
    @printf[I32]("|~~ - Recovery initiated at %s. Ceding control. - ~~|\n"
      .cstring(), worker.cstring())
    _recovery_phase = _RecoveryOverrideAccepted
