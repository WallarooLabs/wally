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
use "net"
use "wallaroo/core/common"
use "wallaroo/core/initialization"
use "wallaroo/core/invariant"
use "wallaroo/core/messages"
use "wallaroo/ent/network"
use "wallaroo/ent/router_registry"
use "wallaroo/ent/checkpoint"
use "wallaroo_labs/collection_helpers"
use "wallaroo_labs/mort"

class Autoscale
  """
  Phases:
    INITIAL:
      _WaitingForAutoscale: Wait for either a grow or shrink autoscale event.

    JOIN (coordinator):
    1) _WaitingForJoiners: Waiting for provided number of workers to connect
    2) _WaitingForCheckpointId: Get checkpoint id to inform new
       workers.
    3) _InjectAutoscaleBarrier: Stop the world and inject barrier to ensure in
       flight messages are finished
    4) _WaitingForJoinerInitialization: Waiting for all joiners to initialize
    5) _WaitingForConnections: Waiting for current workers to connect to
      joiners
    6) _WaitingForJoinMigration: We currently delegate coordination of
      migration back to RouterRegistry. We wait for join
      migration to finish from our side (i.e. we've sent all steps).
      TODO: Handle these remaining phases here.
    7) _WaitingForJoinMigrationAcks: We wait for new workers to ack incoming
      join migration.
    8) _WaitingForResumeTheWorld: Waiting for unmuting procedure to finish.
    9) _WaitingForAutoscale: Autoscale is complete and we are back to our
      initial waiting state.

    JOIN (non-coordinator):
    1) _WaitingToConnectToJoiners: After receiving the addresses for all
      joining workers from the coordinator, we connect to all of them. Once all
      boundaries are set up, we inform the coordinator.
    2) _WaitingForJoinMigration: We currently delegate coordination
      of in flight acking and migration back to RouterRegistry. We wait for
      join migration to finish from our side (i.e. we've sent all steps).
    3) _WaitingForJoinMigrationAcks: We wait for new workers to ack incoming
      join migration.
    4) _WaitingForResumeTheWorld: Waiting for unmuting procedure to finish.
    5) _WaitingForAutoscale: Autoscale is complete and we are back to our
      initial waiting state.

    JOIN (joining worker):
    1) _JoiningWorker: Wait for all steps to be migrated.
    2) _WaitingForAutoscale: Autoscale is complete and we are back to our
      initial waiting state.

    SHRINK (coordinator):
    1) _InjectShrinkAutoscaleBarrier: Stop the world and inject barrier to
       ensure in flight messages are finished
    2) _InitiatingShrink: RouterRegistry currently handles the details. We're
      waiting until all steps have been migrated from leaving workers.
    3) _WaitingForResumeTheWorld: Waiting for unmuting procedure to finish.
    4) _WaitingForAutoscale: Autoscale is complete and we are back to our
      initial waiting state.

    SHRINK (non-coordinator):
    1) _ShrinkInProgress: RouterRegistry currently handles the details. We're
      waiting until all steps have been migrated from leaving workers.
    2) _WaitingForResumeTheWorld: Waiting for unmuting procedure to finish.
    3) _WaitingForAutoscale: Autoscale is complete and we are back to our
      initial waiting state.

    SHRINK (leaving worker):
    1) _WaitingForLeavingMigration: RouterRegistry currently handles the
      details. We're waiting until all steps have been migrated off.
    2) _WaitingForLeavingMigrationAcks: Wait for remaining workers to ack
    3) _ShuttingDown: All steps migrated off and acked, and we're ready to
      shut down.
  """
  let _auth: AmbientAuth
  let _worker_name: WorkerName
  let _router_registry: RouterRegistry ref
  let _connections: Connections
  var _phase: _AutoscalePhase = _EmptyAutoscalePhase

  new create(auth: AmbientAuth, worker_name: WorkerName,
    rr: RouterRegistry ref, connections: Connections, is_joining: Bool)
  =>
    _auth = auth
    _worker_name = worker_name
    _router_registry = rr
    _connections = connections
    if is_joining then
      _phase = _JoiningWorker(this)
    else
      _phase = _WaitingForAutoscale(this)
    end

  fun ref worker_join(conn: TCPConnection, worker: WorkerName,
    worker_count: USize, local_topology: LocalTopology,
    current_worker_count: USize)
  =>
    _phase.worker_join(conn, worker, worker_count, local_topology,
      current_worker_count)

  fun ref wait_for_joiners(conn: TCPConnection, worker: WorkerName,
    worker_count: USize, local_topology: LocalTopology,
    current_worker_count: USize)
  =>
    _phase = _WaitingForJoiners(_auth, this, _router_registry, worker_count,
      current_worker_count)
    _phase.worker_join(conn, worker, worker_count, local_topology,
      current_worker_count)

  fun ref request_checkpoint_id(
    connected_joiners: Map[WorkerName, (TCPConnection, LocalTopology)],
    joining_worker_count: USize, current_worker_count: USize)
  =>
    _phase = _WaitingForCheckpointId(this, _router_registry, connected_joiners,
      joining_worker_count, current_worker_count)
    _router_registry.request_checkpoint_id_for_autoscale()

  fun ref update_checkpoint_id(checkpoint_id: CheckpointId,
    rollback_id: RollbackId)
  =>
    _phase.update_checkpoint_id(checkpoint_id, rollback_id)

  fun ref inject_autoscale_barrier(
    connected_joiners: Map[WorkerName, (TCPConnection, LocalTopology)],
    joining_worker_count: USize, current_worker_count: USize,
    checkpoint_id: CheckpointId, rollback_id: RollbackId)
  =>
    let new_workers = recover iso Array[WorkerName] end
    for w in connected_joiners.keys() do
      new_workers.push(w)
    end
    _phase = _InjectAutoscaleBarrier(this, _router_registry,
      connected_joiners, joining_worker_count, current_worker_count,
      checkpoint_id, rollback_id)
    _router_registry.initiate_stop_the_world_for_grow_migration(
      consume new_workers)

  fun ref grow_autoscale_barrier_complete() =>
    _phase.grow_autoscale_barrier_complete()

  fun ref wait_for_joiner_initialization(joining_worker_count: USize,
    initialized_workers: _StringSet,
    new_state_routing_ids: Map[WorkerName, Map[StateName, RoutingId] val] val,
    new_stateless_partition_routing_ids:
      Map[WorkerName, Map[RoutingId, RoutingId] val] val,
    current_worker_count: USize)
  =>
    _phase = _WaitingForJoinerInitialization(this, joining_worker_count,
      initialized_workers, new_state_routing_ids,
      new_stateless_partition_routing_ids, current_worker_count)

  fun ref wait_for_connections(new_workers: Array[WorkerName] val,
    current_worker_count: USize)
  =>
    _phase = _WaitingForConnections(this, new_workers, current_worker_count)
    // The coordinator should only get here if it has already set up boundaries
    // to the joining workers.
    _phase.worker_connected_to_joining_workers(_worker_name)

  fun ref joining_worker_initialized(worker: WorkerName,
    state_routing_ids: Map[StateName, RoutingId] val,
    stateless_partition_routing_ids: Map[RoutingId, RoutingId] val)
  =>
    _phase.joining_worker_initialized(worker, state_routing_ids,
      stateless_partition_routing_ids)

  fun ref worker_connected_to_joining_workers(worker: WorkerName) =>
    _phase.worker_connected_to_joining_workers(worker)

  fun notify_current_workers_of_joining_addresses(
    new_workers: Array[WorkerName] val,
    new_state_routing_ids: Map[WorkerName, Map[StateName, RoutingId] val] val,
    new_stateless_partition_routing_ids:
      Map[WorkerName, Map[RoutingId, RoutingId] val] val)
  =>
    _connections.notify_current_workers_of_joining_addresses(new_workers,
      new_state_routing_ids, new_stateless_partition_routing_ids)

  fun notify_joining_workers_of_joining_addresses(
    new_workers: Array[WorkerName] val,
    new_state_routing_ids: Map[WorkerName, Map[StateName, RoutingId] val] val,
    new_stateless_partition_routing_ids:
      Map[WorkerName, Map[RoutingId, RoutingId] val] val)
  =>
    _connections.notify_joining_workers_of_joining_addresses(new_workers,
      new_state_routing_ids, new_stateless_partition_routing_ids)

  fun ref connect_to_joining_workers(ws: Array[WorkerName] val,
    coordinator: String)
  =>
    _phase = _WaitingToConnectToJoiners(_auth, this, _worker_name, ws,
      coordinator)

  fun ref waiting_for_migration(joining_workers: Array[WorkerName] val) =>
    _phase = _WaitingForMigration(this, joining_workers)

  fun ref stop_the_world_for_join_migration_initiated(coordinator: WorkerName,
    joining_workers: Array[WorkerName] val)
  =>
    _phase.stop_the_world_for_join_migration_initiated(coordinator,
      joining_workers)

  fun ref join_migration_initiated(joining_workers: Array[WorkerName] val,
    checkpoint_id: CheckpointId)
  =>
    _phase.join_migration_initiated(checkpoint_id)

  fun ref begin_join_migration(joining_workers: Array[WorkerName] val,
    checkpoint_id: CheckpointId)
  =>
    _phase = _WaitingForJoinMigration(this, _auth, joining_workers
      where is_coordinator = false)
    _router_registry.begin_join_migration(joining_workers,
      checkpoint_id)

  fun ref prepare_grow_migration(
    joining_workers: Array[WorkerName] val)
  =>
    _phase = _WaitingForJoinMigration(this, _auth, joining_workers
      where is_coordinator = true)
    // TODO: For now, we're handing control of the join protocol over to
    // RouterRegistry at this point. Eventually, we should manage the
    // entire protocol.
    _router_registry.prepare_join_migration(joining_workers)

  fun ref stop_the_world_for_join_migration(coordinator: WorkerName,
    joining_workers: Array[WorkerName] val)
  =>
    _phase = _WaitingToConnectToJoiners(_auth, this, _worker_name,
      joining_workers, coordinator)
    // TODO: For now, we're handing control of the join protocol over to
    // RouterRegistry at this point. Eventually, we should manage the
    // entire protocol.
    _router_registry.stop_the_world_for_grow_migration(joining_workers)

  fun ref all_key_migration_complete() =>
    _phase.all_key_migration_complete()

  fun ref send_migration_batch_complete(joining_workers: Array[WorkerName] val,
    is_coordinator: Bool)
  =>
    _phase = _WaitingForJoinMigrationAcks(this, _auth, joining_workers,
      is_coordinator)
    for target in joining_workers.values() do
      _router_registry.send_migration_batch_complete_msg(target)
    end

  fun ref receive_join_migration_ack(worker: WorkerName) =>
    _phase.receive_join_migration_ack(worker)

  fun ref all_join_migration_acks_received(
    joining_workers: Array[WorkerName] val, is_coordinator: Bool)
  =>
    _phase = _WaitingForResumeTheWorld(this, _auth, is_coordinator)
    _router_registry.all_join_migration_acks_received(joining_workers,
      is_coordinator)

  fun ref inject_shrink_autoscale_barrier(
    remaining_workers: Array[WorkerName] val,
    leaving_workers: Array[WorkerName] val)
  =>
    _phase = _InjectShrinkAutoscaleBarrier(this, remaining_workers,
      leaving_workers)
    _router_registry.initiate_stop_the_world_for_shrink_migration(
      remaining_workers, leaving_workers)

  fun ref stop_the_world_for_shrink_migration_initiated(
    coordinator: WorkerName, remaining_workers: Array[WorkerName] val,
    leaving_workers: Array[WorkerName] val)
  =>
    _phase.stop_the_world_for_shrink_migration_initiated(coordinator,
      remaining_workers, leaving_workers)

  fun ref stop_the_world_for_shrink_migration(coordinator: WorkerName,
    remaining_workers: Array[WorkerName] val,
    leaving_workers: Array[WorkerName] val)
  =>
    _phase = _ShrinkInProgress(this, remaining_workers, leaving_workers)
    // TODO: For now, we're handing control of the shrink protocol over to
    // RouterRegistry at this point. Eventually, we should manage the
    // entire protocol.
    _router_registry.stop_the_world_for_shrink_migration(
      remaining_workers, leaving_workers)

  fun ref shrink_autoscale_barrier_complete() =>
    _phase.shrink_autoscale_barrier_complete()

  fun ref initiate_shrink(remaining_workers: Array[WorkerName] val,
    leaving_workers: Array[WorkerName] val)
  =>
    _phase = _InitiatingShrink(this, remaining_workers, leaving_workers)
    _router_registry.initiate_shrink(remaining_workers, leaving_workers)

  fun ref begin_leaving_migration(remaining_workers: Array[WorkerName] val) =>
    _phase = _WaitingForLeavingMigration(this, remaining_workers)

  fun ref leaving_worker_finished_migration(worker: WorkerName) =>
    _phase.leaving_worker_finished_migration(worker)

  fun ref all_leaving_workers_finished(leaving_workers: Array[WorkerName] val,
    is_coordinator: Bool = false)
  =>
    _phase = _WaitingForResumeTheWorld(this, _auth, is_coordinator)
    _router_registry.all_leaving_workers_finished(leaving_workers)

  fun ref autoscale_complete() =>
    _phase.autoscale_complete()

  fun ref wait_for_leaving_migration_acks(
    remaining_workers: Array[WorkerName] val)
  =>
    _phase = _WaitingForLeavingMigrationAcks(this, remaining_workers)
    _router_registry.send_leaving_migration_ack_request(remaining_workers)

  fun ref receive_leaving_migration_ack(worker: WorkerName) =>
    _phase.receive_leaving_migration_ack(worker)

  fun ref mark_autoscale_complete() =>
    @printf[I32]("AUTOSCALE: Autoscale is complete.\n".cstring())
    _phase = _WaitingForAutoscale(this)

  fun ref clean_shutdown() =>
    _phase = _ShuttingDown
    _router_registry.clean_shutdown()

  fun send_control(worker: String, msg: Array[ByteSeq] val) =>
    _connections.send_control(worker, msg)

  fun send_control_to_cluster(msg: Array[ByteSeq] val) =>
    _connections.send_control_to_cluster(msg)

  fun send_control_to_cluster_with_exclusions(msg: Array[ByteSeq] val,
    exceptions: Array[String] val)
  =>
    _connections.send_control_to_cluster_with_exclusions(msg, exceptions)

///////////////////
// Autoscale Phases
///////////////////
trait _AutoscalePhase
  fun name(): String

  fun ref worker_join(conn: TCPConnection, worker: WorkerName,
    worker_count: USize, local_topology: LocalTopology,
    current_worker_count: USize)
  =>
    _invalid_call()
    Fail()

  fun ref update_checkpoint_id(checkpoint_id: CheckpointId,
    rollback_id: RollbackId)
  =>
    _invalid_call()
    Fail()

  fun ref grow_autoscale_barrier_complete() =>
    _invalid_call()
    Fail()

  fun ref joining_worker_initialized(worker: WorkerName,
    state_routing_ids: Map[StateName, RoutingId] val,
    stateless_partition_routing_ids: Map[RoutingId, RoutingId] val)
  =>
    _invalid_call()
    Fail()

  fun ref worker_connected_to_joining_workers(worker: WorkerName) =>
    _invalid_call()
    Fail()

  fun ref stop_the_world_for_join_migration_initiated(coordinator: WorkerName,
    joining_workers: Array[WorkerName] val)
  =>
    _invalid_call()
    Fail()

  fun ref join_migration_initiated(checkpoint_id: CheckpointId) =>
    _invalid_call()
    Fail()

  fun ref all_key_migration_complete() =>
    _invalid_call()
    Fail()

  fun ref receive_join_migration_ack(worker: WorkerName) =>
    _invalid_call()
    Fail()

  fun ref stop_the_world_for_shrink_migration_initiated(
    coordinator: WorkerName, remaining_workers: Array[WorkerName] val,
    leaving_workers: Array[WorkerName] val)
  =>
    _invalid_call()
    Fail()

  fun ref shrink_autoscale_barrier_complete() =>
    _invalid_call()
    Fail()

  fun ref leaving_worker_finished_migration(worker: WorkerName) =>
    _invalid_call()
    Fail()

  fun ref receive_leaving_migration_ack(worker: WorkerName) =>
    _invalid_call()
    Fail()

  fun ref autoscale_complete() =>
    _invalid_call()
    Fail()

  fun ref _invalid_call() =>
    @printf[I32]("Invalid call on autoscale phase %s\n".cstring(),
      name().cstring())

class _EmptyAutoscalePhase is _AutoscalePhase
  fun name(): String => "EmptyAutoscalePhase"

class _WaitingForAutoscale is _AutoscalePhase
  let _autoscale: Autoscale ref

  new create(autoscale: Autoscale ref) =>
    @printf[I32]("AUTOSCALE: Waiting for new autoscale event.\n".cstring())
    _autoscale = autoscale

  fun name(): String => "WaitingForAutoscale"

  fun ref stop_the_world_for_join_migration_initiated(coordinator: WorkerName,
    joining_workers: Array[WorkerName] val)
  =>
    _autoscale.stop_the_world_for_join_migration(coordinator, joining_workers)

  fun ref stop_the_world_for_shrink_migration_initiated(
    coordinator: WorkerName, remaining_workers: Array[WorkerName] val,
    leaving_workers: Array[WorkerName] val)
  =>
    _autoscale.stop_the_world_for_shrink_migration(coordinator,
      remaining_workers, leaving_workers)

  fun ref worker_join(conn: TCPConnection, worker: WorkerName,
    worker_count: USize, local_topology: LocalTopology,
    current_worker_count: USize)
  =>
    _autoscale.wait_for_joiners(conn, worker, worker_count, local_topology,
      current_worker_count)

/////////////////////////////////////////////////
// GROW PHASES
/////////////////////////////////////////////////
class _WaitingForJoiners is _AutoscalePhase
  let _auth: AmbientAuth
  let _autoscale: Autoscale ref
  let _router_registry: RouterRegistry ref
  let _joining_worker_count: USize
  let _connected_joiners: Map[WorkerName, (TCPConnection, LocalTopology)] =
    _connected_joiners.create()
  //!@
  let _initialized_workers: _StringSet = _initialized_workers.create()
  var _new_state_routing_ids:
    Map[WorkerName, Map[StateName, RoutingId] val] iso =
    recover Map[WorkerName, Map[StateName, RoutingId] val] end
  let _current_worker_count: USize

  new create(auth: AmbientAuth, autoscale: Autoscale ref,
    rr: RouterRegistry ref, joining_worker_count: USize,
    current_worker_count: USize)
  =>
    _auth = auth
    _autoscale = autoscale
    _router_registry = rr
    _joining_worker_count = joining_worker_count
    _current_worker_count = current_worker_count
    @printf[I32](("AUTOSCALE: Waiting for %s joining workers. Current " +
      "cluster size: %s\n").cstring(),
      _joining_worker_count.string().cstring(),
      _current_worker_count.string().cstring())

  fun name(): String => "WaitingForJoiners"

  fun ref worker_join(conn: TCPConnection, worker: WorkerName,
    worker_count: USize, local_topology: LocalTopology,
    current_worker_count: USize)
  =>
    if worker_count != _joining_worker_count then
      @printf[I32]("Join error: Joining worker supplied invalid worker count\n"
        .cstring())
      let error_msg = "All joining workers must supply the same worker " +
        "count. Current pending count is " + _joining_worker_count.string() +
        ". You supplied " + worker_count.string() + "."
      try
        let msg = ChannelMsgEncoder.inform_join_error(error_msg, _auth)?
        conn.writev(msg)
      else
        Fail()
      end
    elseif worker_count < 1 then
      @printf[I32](("Join error: Joining worker supplied a worker count " +
        "less than 1\n").cstring())
      let error_msg = "Joining worker must supply a worker count greater " +
        "than 0."
      try
        let msg = ChannelMsgEncoder.inform_join_error(error_msg, _auth)?
        conn.writev(msg)
      else
        Fail()
      end
    else
      _connected_joiners(worker) = (conn, local_topology)
      if _connected_joiners.size() == _joining_worker_count then
        _autoscale.request_checkpoint_id(_connected_joiners,
          _joining_worker_count, _current_worker_count)
      end
    end

class _WaitingForCheckpointId is _AutoscalePhase
  let _autoscale: Autoscale ref
  let _router_registry: RouterRegistry ref
  let _connected_joiners: Map[WorkerName, (TCPConnection, LocalTopology)]
  let _joining_worker_count: USize
  let _current_worker_count: USize

  new create(autoscale: Autoscale ref, rr: RouterRegistry ref,
    connected_joiners: Map[WorkerName, (TCPConnection, LocalTopology)],
    joining_worker_count: USize, current_worker_count: USize)
  =>
    _autoscale = autoscale
    _router_registry = rr
    _connected_joiners = connected_joiners
    _joining_worker_count = joining_worker_count
    _current_worker_count = current_worker_count
    @printf[I32](("AUTOSCALE: Waiting for next checkpoint id\n").cstring())

  fun name(): String => "_WaitingForCheckpointId"

  fun ref update_checkpoint_id(checkpoint_id: CheckpointId,
    rollback_id: RollbackId)
  =>
    _autoscale.inject_autoscale_barrier(_connected_joiners,
      _joining_worker_count, _current_worker_count, checkpoint_id,
      rollback_id)

class _InjectAutoscaleBarrier is _AutoscalePhase
  let _autoscale: Autoscale ref
  let _router_registry: RouterRegistry ref
  let _connected_joiners: Map[WorkerName, (TCPConnection, LocalTopology)]
  let _initialized_workers: _StringSet = _initialized_workers.create()
  var _new_state_routing_ids:
    Map[WorkerName, Map[StateName, RoutingId] val] iso =
    recover Map[WorkerName, Map[StateName, RoutingId] val] end
  var _new_stateless_partition_routing_ids:
    Map[WorkerName, Map[RoutingId, RoutingId] val] iso =
      recover Map[WorkerName, Map[RoutingId, RoutingId] val] end
  let _joining_worker_count: USize
  let _current_worker_count: USize
  let _checkpoint_id: CheckpointId
  let _rollback_id: RollbackId

  new create(autoscale: Autoscale ref, rr: RouterRegistry ref,
    connected_joiners: Map[WorkerName, (TCPConnection, LocalTopology)],
    joining_worker_count: USize, current_worker_count: USize,
    checkpoint_id: CheckpointId, rollback_id: RollbackId)
  =>
    _autoscale = autoscale
    _router_registry = rr
    _connected_joiners = connected_joiners
    _joining_worker_count = joining_worker_count
    _current_worker_count = current_worker_count
    _checkpoint_id = checkpoint_id
    _rollback_id = rollback_id
    @printf[I32](("AUTOSCALE: Stopping the world and injecting autoscale " +
      "barrier\n").cstring())

  fun name(): String => "_InjectAutoscaleBarrier"

  fun ref grow_autoscale_barrier_complete() =>
    for (worker, data) in _connected_joiners.pairs() do
      let conn = data._1
      let local_topology = data._2
      _router_registry.inform_joining_worker(conn, worker, local_topology,
        _checkpoint_id, _rollback_id)
    end
    let new_state_routing_ids:
      Map[WorkerName, Map[StateName, RoutingId] val] val =
        (_new_state_routing_ids = recover Map[WorkerName, Map[StateName,
          RoutingId] val] end)
    let new_stateless_partition_routing_ids:
      Map[WorkerName, Map[RoutingId, RoutingId] val] val =
        (_new_stateless_partition_routing_ids =
          recover Map[WorkerName, Map[RoutingId, RoutingId] val] end)
    _autoscale.wait_for_joiner_initialization(_joining_worker_count,
      _initialized_workers, new_state_routing_ids,
      new_stateless_partition_routing_ids, _current_worker_count)

  fun ref joining_worker_initialized(worker: WorkerName,
    state_routing_ids: Map[StateName, RoutingId] val,
    stateless_partition_routing_ids: Map[RoutingId, RoutingId] val)
  =>
    // It's possible some workers will be initialized when we're still in
    // this phase. We need to keep track of this to hand off that info to
    // the next phase.
    _initialized_workers.set(worker)
    _new_state_routing_ids(worker) = state_routing_ids
    _new_stateless_partition_routing_ids(worker) =
      stateless_partition_routing_ids
    if _initialized_workers.size() >= _joining_worker_count then
      // We should have already transitioned to the next phase before this.
      Fail()
    end

class _WaitingForJoinerInitialization is _AutoscalePhase
  let _autoscale: Autoscale ref
  let _joining_worker_count: USize
  var _initialized_joining_workers: _StringSet
  let _current_worker_count: USize
  var _new_state_routing_ids:
    Map[WorkerName, Map[StateName, RoutingId] val] iso =
    recover Map[WorkerName, Map[StateName, RoutingId] val] end
  var _new_stateless_partition_routing_ids:
    Map[WorkerName, Map[RoutingId, RoutingId] val] iso =
    recover Map[WorkerName, Map[RoutingId, RoutingId] val] end

  new create(autoscale: Autoscale ref, joining_worker_count: USize,
    initialized_workers: _StringSet,
    new_state_routing_ids: Map[WorkerName, Map[StateName, RoutingId] val] val,
    new_stateless_partition_routing_ids:
      Map[WorkerName, Map[RoutingId, RoutingId] val] val,
    current_worker_count: USize)
  =>
    ifdef debug then
      // When this phase begins, at least one joining worker should still
      // have not notified us it was initialized.
      Invariant(initialized_workers.size() < joining_worker_count)
    end
    _autoscale = autoscale
    _joining_worker_count = joining_worker_count
    _initialized_joining_workers = initialized_workers
    _current_worker_count = current_worker_count
    for (w, sri) in new_state_routing_ids.pairs() do
      _new_state_routing_ids(w) = sri
    end
    for (w, spri) in new_stateless_partition_routing_ids.pairs() do
      _new_stateless_partition_routing_ids(w) = spri
    end
    @printf[I32](("AUTOSCALE: Waiting for %s joining workers to initialize. " +
      "Already initialized: %s. Current cluster size is %s\n").cstring(),
      _joining_worker_count.string().cstring(),
      _initialized_joining_workers.size().string().cstring(),
      _current_worker_count.string().cstring())

  fun name(): String => "WaitingForJoinerInitialization"

  fun ref joining_worker_initialized(worker: WorkerName,
    state_routing_ids: Map[StateName, RoutingId] val,
    stateless_partition_routing_ids: Map[RoutingId, RoutingId] val)
  =>
    _initialized_joining_workers.set(worker)
    _new_state_routing_ids(worker) = state_routing_ids
    _new_stateless_partition_routing_ids(worker) =
      stateless_partition_routing_ids
    if _initialized_joining_workers.size() == _joining_worker_count then
      let nws = recover trn Array[String] end
      for w in _initialized_joining_workers.values() do
        nws.push(w)
      end
      let new_workers = consume val nws
      let new_state_routing_ids:
        Map[WorkerName, Map[StateName, RoutingId] val] val =
          (_new_state_routing_ids = recover Map[WorkerName, Map[StateName,
            RoutingId] val] end)
      let new_stateless_partition_routing_ids:
        Map[WorkerName, Map[RoutingId, RoutingId] val] val =
          (_new_stateless_partition_routing_ids =
            recover Map[WorkerName, Map[RoutingId, RoutingId] val] end)
      _autoscale.notify_joining_workers_of_joining_addresses(new_workers,
        new_state_routing_ids, new_stateless_partition_routing_ids)
      _autoscale.notify_current_workers_of_joining_addresses(new_workers,
        new_state_routing_ids, new_stateless_partition_routing_ids)
      _autoscale.wait_for_connections(new_workers, _current_worker_count)
    end

class _WaitingForConnections is _AutoscalePhase
  let _autoscale: Autoscale ref
  let _new_workers: Array[String] val
  let _connecting_worker_count: USize
  // Keeps track of new boundaries we set up to joining workers
  let _new_boundaries: _StringSet = _new_boundaries.create()
  // Keeps track of how many other workers have set up all new boundaries
  // to joining workers.
  let _connected_workers: _StringSet = _connected_workers.create()

  new create(autoscale: Autoscale ref, new_workers: Array[String] val,
    current_worker_count: USize)
  =>
    _autoscale = autoscale
    _new_workers = new_workers
    // We know that we have created boundaries to all joining workers in the
    // last phase, so we are only waiting for the other workers to do so as
    // well.
    _connecting_worker_count = current_worker_count
    @printf[I32](("AUTOSCALE: Waiting for %s current workers to connect " +
      "to joining workers.\n").cstring(),
      _connecting_worker_count.string().cstring())

  fun name(): String => "WaitingForConnections"

  fun ref worker_connected_to_joining_workers(worker: WorkerName) =>
    """
    Indicates that another worker has connected to joining workers.
    """
    _connected_workers.set(worker)
    if _connected_workers.size() == _connecting_worker_count then
      _autoscale.prepare_grow_migration(_new_workers)
    end

class _WaitingToConnectToJoiners is _AutoscalePhase
  let _auth: AmbientAuth
  let _autoscale: Autoscale ref
  let _worker_name: WorkerName
  let _joining_workers: Array[WorkerName] val
  let _coordinator: WorkerName
  let _new_boundaries: _StringSet = _new_boundaries.create()

  new create(auth: AmbientAuth, autoscale: Autoscale ref,
    worker_name: WorkerName, joining_workers: Array[WorkerName] val,
    coordinator: String)
  =>
    _auth = auth
    _autoscale = autoscale
    _worker_name = worker_name
    _joining_workers = joining_workers
    _coordinator = coordinator
    ifdef debug then
      Invariant(_joining_workers.size() > 0)
    end
    @printf[I32]("AUTOSCALE: Waiting to connect to %s joining workers\n"
      .cstring(), _joining_workers.size().string().cstring())

  fun name(): String => "WaitingToConnectToJoiners"

  //!@ What do we do here with state_routing_ids?
  fun ref joining_worker_initialized(worker: WorkerName,
    state_routing_ids: Map[StateName, RoutingId] val,
    stateless_partition_routing_ids: Map[RoutingId, RoutingId] val)
  =>
    _new_boundaries.set(worker)
    ifdef debug then
      Invariant(
        ArrayHelpers[String].contains[String](_joining_workers, worker))
      Invariant(_new_boundaries.size() <= _joining_workers.size())
    end
    if _new_boundaries.size() == _joining_workers.size() then
      try
        let msg = ChannelMsgEncoder.connected_to_joining_workers(_worker_name,
          _auth)?
        _autoscale.send_control(_coordinator, msg)
      else
        Fail()
      end
      _autoscale.waiting_for_migration(_joining_workers)
    end

class _WaitingForMigration is _AutoscalePhase
  let _autoscale: Autoscale ref
  let _joining_workers: Array[WorkerName] val

  new create(autoscale: Autoscale ref, joining_workers: Array[WorkerName] val)
  =>
    _autoscale = autoscale
    _joining_workers = joining_workers
    @printf[I32]("AUTOSCALE: Waiting for signal to begin migration\n"
      .cstring())

  fun name(): String => "WaitingForMigration"

  fun ref join_migration_initiated(checkpoint_id: CheckpointId) =>
    _autoscale.begin_join_migration(_joining_workers, checkpoint_id)

class _WaitingForJoinMigration is _AutoscalePhase
  """
  During this phase, we've handed off responsibility for join migration to
  the RouterRegistry.
  """
  let _autoscale: Autoscale ref
  let _auth: AmbientAuth
  let _joining_workers: Array[WorkerName] val
  let _is_coordinator: Bool

  new create(autoscale: Autoscale ref, auth: AmbientAuth,
    joining_workers: Array[WorkerName] val, is_coordinator: Bool)
  =>
    @printf[I32]("AUTOSCALE: Waiting for join migration to complete.\n"
      .cstring())
    _autoscale = autoscale
    _auth = auth
    _joining_workers = joining_workers
    _is_coordinator = is_coordinator

  fun name(): String => "WaitingForJoinMigration"

  fun ref all_key_migration_complete() =>
    @printf[I32]("--Sending migration batch complete msg to new workers\n"
      .cstring())
    _autoscale.send_migration_batch_complete(_joining_workers, _is_coordinator)

class _WaitingForJoinMigrationAcks is _AutoscalePhase
  let _autoscale: Autoscale ref
  let _auth: AmbientAuth
  let _is_coordinator: Bool
  let _joining_workers: Array[String] val
  let _migration_target_ack_list: _StringSet =
    _migration_target_ack_list.create()

  new create(autoscale: Autoscale ref, auth: AmbientAuth,
    joining_workers: Array[WorkerName] val, is_coordinator: Bool)
  =>
    @printf[I32]("AUTOSCALE: Waiting for join migration acks.\n"
      .cstring())
    _autoscale = autoscale
    _auth = auth
    _is_coordinator = is_coordinator
    _joining_workers = joining_workers
    for w in joining_workers.values() do
      _migration_target_ack_list.set(w)
    end

  fun name(): String => "WaitingForJoinMigrationAcks"

  fun ref receive_join_migration_ack(worker: WorkerName) =>
    _migration_target_ack_list.unset(worker)
    if _migration_target_ack_list.size() == 0 then
      @printf[I32]("--All new workers have acked migration batch complete\n"
        .cstring())
      _autoscale.all_join_migration_acks_received(_joining_workers,
        _is_coordinator)
    end

class _JoiningWorker is _AutoscalePhase
  let _autoscale: Autoscale ref

  new create(autoscale: Autoscale ref) =>
    @printf[I32]("AUTOSCALE: Joining Worker\n".cstring())
    _autoscale = autoscale

  fun name(): String => "JoiningWorker"

  fun ref worker_join(conn: TCPConnection, worker: WorkerName,
    worker_count: USize, local_topology: LocalTopology,
    current_worker_count: USize)
  =>
    None

  fun ref joining_worker_initialized(worker: WorkerName,
    state_routing_ids: Map[StateName, RoutingId] val,
    stateless_partition_routing_ids: Map[RoutingId, RoutingId] val)
  =>
    None

  fun ref worker_connected_to_joining_workers(worker: WorkerName) =>
    None

  fun ref stop_the_world_for_join_migration_initiated(coordinator: WorkerName,
    joining_workers: Array[WorkerName] val)
  =>
    None

  fun ref join_migration_initiated(checkpoint_id: CheckpointId) =>
    None

//!2
  // fun ref ready_for_join_migration() =>
  //   None

  fun ref autoscale_complete() =>
    _autoscale.mark_autoscale_complete()

/////////////////////////////////////////////////
// SHRINK PHASES
/////////////////////////////////////////////////
class _InjectShrinkAutoscaleBarrier is _AutoscalePhase
  let _autoscale: Autoscale ref
  let _remaining_workers: Array[WorkerName] val
  let _leaving_workers: Array[WorkerName] val

  new create(autoscale: Autoscale ref,
    remaining_workers: Array[WorkerName] val,
    leaving_workers: Array[WorkerName] val)
  =>
    @printf[I32](("AUTOSCALE: Stopping the world and injecting shrink " +
      "autoscale barrier.\n").cstring())
    _autoscale = autoscale
    _remaining_workers = remaining_workers
    _leaving_workers = leaving_workers

  fun name(): String => "_InjectShrinkAutoscaleBarrier"

  fun ref shrink_autoscale_barrier_complete() =>
    _autoscale.initiate_shrink(_remaining_workers, _leaving_workers)

class _InitiatingShrink is _AutoscalePhase
  let _autoscale: Autoscale ref
  let _remaining_workers: Array[WorkerName] val
  let _leaving_workers: Array[WorkerName] val
  let _leaving_workers_waiting_list: _StringSet =
    _leaving_workers_waiting_list.create()

  new create(autoscale: Autoscale ref,
    remaining_workers: Array[WorkerName] val,
    leaving_workers: Array[WorkerName] val)
  =>
    @printf[I32]("AUTOSCALE: Initiating shrink.\n".cstring())
    _autoscale = autoscale
    _remaining_workers = remaining_workers
    _leaving_workers = leaving_workers
    for w in _leaving_workers.values() do
      _leaving_workers_waiting_list.set(w)
    end

  fun name(): String => "InitiatingShrink"

  fun ref leaving_worker_finished_migration(worker: WorkerName) =>
    @printf[I32]("Leaving worker %s reported migration complete\n".cstring(),
      worker.cstring())
    ifdef debug then
      Invariant(_leaving_workers_waiting_list.size() > 0)
    end
    _leaving_workers_waiting_list.unset(worker)
    if _leaving_workers_waiting_list.size() == 0 then
      _autoscale.all_leaving_workers_finished(_leaving_workers, true)
    end

class _ShrinkInProgress is _AutoscalePhase
  let _autoscale: Autoscale ref
  let _remaining_workers: Array[WorkerName] val
  let _leaving_workers: Array[WorkerName] val
  let _leaving_workers_waiting_list: _StringSet =
    _leaving_workers_waiting_list.create()

  new create(autoscale: Autoscale ref,
    remaining_workers: Array[WorkerName] val,
    leaving_workers: Array[WorkerName] val)
  =>
    @printf[I32]("AUTOSCALE: Shrink in progress.\n".cstring())
    _autoscale = autoscale
    _remaining_workers = remaining_workers
    _leaving_workers = leaving_workers
    for w in _leaving_workers.values() do
      _leaving_workers_waiting_list.set(w)
    end

  fun name(): String => "ShrinkInProgress"

  fun ref leaving_worker_finished_migration(worker: WorkerName) =>
    ifdef debug then
      Invariant(_leaving_workers_waiting_list.size() > 0)
    end
    _leaving_workers_waiting_list.unset(worker)
    if _leaving_workers_waiting_list.size() == 0 then
      _autoscale.all_leaving_workers_finished(_leaving_workers, false)
    end

class _WaitingForLeavingMigration is _AutoscalePhase
  """
  Used on a leaving worker. Currently the RouterRegistry handles the migration
  details.
  """
  let _autoscale: Autoscale ref
  let _remaining_workers: Array[String] val

  new create(autoscale: Autoscale ref,
    remaining_workers: Array[WorkerName] val)
  =>
    @printf[I32]("AUTOSCALE: Waiting for leaving migration.\n".cstring())
    _autoscale = autoscale
    _remaining_workers = remaining_workers

  fun name(): String => "WaitingForLeavingMigration"

  fun ref leaving_worker_finished_migration(worker: WorkerName) =>
    None

  fun ref all_key_migration_complete() =>
    _autoscale.wait_for_leaving_migration_acks(_remaining_workers)

class _WaitingForLeavingMigrationAcks is _AutoscalePhase
  """
  Wait for remaining workers to ack that we've migrated all steps.
  """
  let _autoscale: Autoscale ref
  let _remaining_workers: Array[WorkerName] val
  let _worker_waiting_list: _StringSet = _worker_waiting_list.create()

  new create(autoscale: Autoscale ref,
    remaining_workers: Array[WorkerName] val)
  =>
    @printf[I32]("AUTOSCALE: Waiting for leaving migration complete acks.\n"
      .cstring())
    _autoscale = autoscale
    _remaining_workers = remaining_workers
    for w in _remaining_workers.values() do
      _worker_waiting_list.set(w)
    end

  fun name(): String => "WaitingForLeavingMigrationAcks"

  fun ref leaving_worker_finished_migration(worker: WorkerName) =>
    None

  fun ref receive_leaving_migration_ack(worker: WorkerName) =>
    ifdef debug then
      Invariant(
        ArrayHelpers[WorkerName].contains[WorkerName](_remaining_workers,
          worker))
    end
    _worker_waiting_list.unset(worker)
    if _worker_waiting_list.size() == 0 then
      _autoscale.clean_shutdown()
    end

/////////////////////////////////////////////////
// SHARED PHASES
/////////////////////////////////////////////////
class _WaitingForResumeTheWorld is _AutoscalePhase
  let _autoscale: Autoscale ref
  let _auth: AmbientAuth
  let _is_coordinator: Bool

  new create(autoscale: Autoscale ref, auth: AmbientAuth,
    is_coordinator: Bool)
  =>
    @printf[I32]("AUTOSCALE: Waiting for resume the world.\n".cstring())
    _autoscale = autoscale
    _auth = auth
    _is_coordinator = is_coordinator

  fun name(): String => "WaitingForResumeTheWorld"

  fun ref autoscale_complete() =>
    if _is_coordinator then
      try
        let msg = ChannelMsgEncoder.autoscale_complete(_auth)?
        _autoscale.send_control_to_cluster(msg)
      else
        Fail()
      end
    end
    _autoscale.mark_autoscale_complete()

class _ShuttingDown is _AutoscalePhase
  new create() =>
    @printf[I32]("AUTOSCALE: Shutting down.\n".cstring())

  fun name(): String => "ShuttingDown"

  fun ref autoscale_complete() =>
    None


/////////////////////////////////////////////////////////////////////////////
// TODO: Replace using this with the badly named SetIs once we address a bug
// in SetIs where unsetting doesn't reduce set size for type SetIs[String].
class _StringSet
  let _map: Map[String, String] = _map.create()

  fun ref set(s: String) =>
    _map(s) = s

  fun ref unset(s: String) =>
    try _map.remove(s)? end

  fun ref clear() =>
    _map.clear()

  fun size(): USize =>
    _map.size()

  fun values(): MapValues[String, String, HashEq[String],
    this->HashMap[String, String, HashEq[String]]]^
  =>
    _map.values()
