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
use "promises"
use "wallaroo/core/boundary"
use "wallaroo/core/checkpoint"
use "wallaroo/core/common"
use "wallaroo/core/initialization"
use "wallaroo/core/invariant"
use "wallaroo/core/messages"
use "wallaroo/core/network"
use "wallaroo/core/router_registry"
use "wallaroo/core/routing"
use "wallaroo_labs/collection_helpers"
use "wallaroo_labs/mort"
use "wallaroo_labs/string_set"

actor Autoscale
  """
  Phases:
    INITIAL:
      _WaitingForAutoscale: Wait for either a grow or shrink autoscale event.

    ////////////////////
    // GROW AUTOSCALE
    ////////////////////
    I. COORDINATOR:
    1) _WaitingForJoiners: Waiting for provided number of workers to connect
    2) _WaitingForCheckpointId: Get checkpoint id to inform new
       workers.
    3) _InjectAutoscaleBarrier: Stop the world and inject barrier to ensure in
       flight messages are finished
    4) _WaitingForJoinerInitialization: Waiting for all joiners to initialize
    5) _WaitingForConnections: Waiting for current workers to connect to
      joiners
    6) GOTO IV.1

    II. NON-COORDINATOR:
    1) _WaitingToConnectToJoiners: After receiving the addresses for all
      joining workers from the coordinator, we connect to all of them. Once all
      boundaries are set up, we inform the coordinator.
    2) GOTO IV.1

    III. JOINING WORKER:
    1) _JoiningWorker: Wait for all other joiners to be initialized, all keys
      to have been migrated, and all post-migration hash partitions to have
      arrived.
    2) GOTO IV.3

    IV. AFTER GROW MIGRATION BEGINS:
    1) _WaitingForGrowMigration: We currently delegate coordination of
      migration back to RouterRegistry. We wait for join
      migration to finish from our side (i.e. we've sent all steps).
      TODO: Handle these remaining phases here.
    2) _WaitingForGrowMigrationAcks: We wait for new workers to ack incoming
      join migration.
    3) _WaitingForProducerList: Wait for list of current producers so we can
      make sure they all register downstream.
    4) _WaitingForProducersToRegister: Wait for all producers to ack having
      registered downstream as producers.
    5) _WaitingForBoundariesMap: Wait for map of current boundaries so we can
      make sure they all register downstream.
    6) _WaitingForBoundariesToAckRegistering: Wait for all boundaires to ack
      sending register_producer messages downstream. [We rely on causal
      message ordering here. Since we're requesting acks from boundaries
      after all their upstream producers, we know these acks will be sent
      after the boundaries have forwarded any register_producer messages.]
    7) _WaitingForResumeTheWorld: Waiting for unmuting procedure to finish.
    8) _WaitingForAutoscale: Autoscale is complete and we are back to our
      initial waiting state.

    ////////////////////
    // SHRINK AUTOSCALE
    ////////////////////
    V. COORDINATOR:
    1) _InjectShrinkAutoscaleBarrier: Stop the world and inject barrier to
       ensure in flight messages are finished
    2) _InitiatingShrink: RouterRegistry currently handles the details. We're
      waiting until all steps have been migrated from leaving workers.
    3) _WaitingForResumeTheWorld: Waiting for unmuting procedure to finish.
    4) _WaitingForAutoscale: Autoscale is complete and we are back to our
      initial waiting state.

    VI. NON-COORDINATOR:
    1) _ShrinkInProgress: RouterRegistry currently handles the details. We're
      waiting until all steps have been migrated from leaving workers.
    2) _WaitingForResumeTheWorld: Waiting for unmuting procedure to finish.
    3) _WaitingForAutoscale: Autoscale is complete and we are back to our
      initial waiting state.

    VII. LEAVING WORKER:
    1) _WaitingForLeavingMigration: RouterRegistry currently handles the
      details. We're waiting until all steps have been migrated off.
    2) _WaitingForLeavingMigrationAcks: Wait for remaining workers to ack
    3) _ShuttingDown: All steps migrated off and acked, and we're ready to
      shut down.
  """
  let _auth: AmbientAuth
  let _worker_name: WorkerName
  let _autoscale_barrier_initiator: AutoscaleBarrierInitiator
  //!@<- Replace with relevant interface
  let _router_registry: RouterRegistry
  let _connections: Connections
  let _initializer_name: WorkerName
  let _checkpoint_initiator: CheckpointInitiator
  var _phase: _AutoscalePhase = _EmptyAutoscalePhase

  let _self: Autoscale tag = this

  new create(auth: AmbientAuth, worker_name: WorkerName,
    autoscale_barrier_initiator: AutoscaleBarrierInitiator,
    rr: RouterRegistry, connections: Connections, is_joining: Bool,
    initializer_name: WorkerName, checkpoint_initiator: CheckpointInitiator,
    // Only a joining worker will pass in this list of non-joining workers
    non_joining_workers: (Array[WorkerName] val | None) = None)
  =>
    _auth = auth
    _worker_name = worker_name
    _autoscale_barrier_initiator = autoscale_barrier_initiator
    _router_registry = rr
    _connections = connections
    _initializer_name = initializer_name
    _checkpoint_initiator = checkpoint_initiator
    if is_joining then
      match non_joining_workers
      | let ws: Array[WorkerName] val =>
        _phase = _JoiningWorker(_worker_name, this, ws)
      else
        Fail()
      end
    else
      _phase = _WaitingForAutoscale(this)
    end
    _router_registry.set_autoscale(this)

  /////////////////////////////////////////////////////////////////////////////
  /////////////////////////////////////////////////////////////////////////////
  //
  // GROW AUTOSCALE
  //
  /////////////////////////////////////////////////////////////////////////////
  /////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////
  // BEFORE MIGRATION.
  // COORDINATOR
  //////////////////////////////////

  be worker_join(conn: TCPConnection, worker: WorkerName,
    worker_count: USize, local_topology: LocalTopology,
    current_worker_count: USize)
  =>
    """
    Called when joining worker initially tells us it's joining. If we're
    waiting for autoscale, this will put us into join.
    """
    _phase.worker_join(conn, worker, worker_count, local_topology,
      current_worker_count)

  be update_checkpoint_id_for_autoscale(ids: (CheckpointId, RollbackId)) =>
    """
    Called in response to request to CheckpointInitiator to get the
    latest checkpoint and rollback ids.
    """
    (let checkpoint_id, let rollback_id) = ids
    _phase.update_checkpoint_id(checkpoint_id, rollback_id)

  be grow_autoscale_barrier_complete() =>
    """
    Called when the initial join autoscale barrier is complete.
    """
    _phase.grow_autoscale_barrier_complete()

  be joining_worker_initialized(worker: WorkerName,
    step_group_routing_ids: Map[RoutingId, RoutingId] val)
  =>
    """
    Called in response to joining worker completing initialization.
    """
    _router_registry.add_joining_worker_to_routers(worker,
      step_group_routing_ids)

    _phase.joining_worker_initialized(worker, step_group_routing_ids)

  be report_connected_to_joining_worker(connected_worker: WorkerName) =>
    """
    Called by non-coordinators to inform us they've connected to joining
    workers.
    """
    _phase.worker_connected_to_joining_workers(connected_worker)

  //////////////////////////////////
  // BEFORE MIGRATION.
  // NON-COORDINATORS
  //////////////////////////////////

  be remote_stop_the_world_for_grow_migration_request(coordinator: WorkerName,
    joining_workers: Array[WorkerName] val)
  =>
    """
    Sent by coordinator to tell us to stop the world in preparation of
    migration.
    """
    _phase.stop_the_world_for_grow_migration_initiated(coordinator,
      joining_workers)

  be connect_to_joining_workers(ws: Array[WorkerName] val,
    new_step_group_routing_ids:
      Map[WorkerName, Map[RoutingId, RoutingId] val] val,
    coordinator: WorkerName)
  =>
    """
    Called when we're informed about joining workers by the coordinator. This
    puts a non-coordinator in the first autoscale phase.
    """
    _phase = _WaitingToConnectToJoiners(_auth, this, _worker_name, ws,
      coordinator)

  be remote_grow_migration_request(joining_workers: Array[WorkerName] val,
    checkpoint_id: CheckpointId)
  =>
    """
    Sent by the coordinator to tell us to begin migrating to joining workers.
    """
    if not ArrayHelpers[WorkerName].contains[WorkerName](joining_workers,
      _worker_name)
    then
      _phase.grow_migration_initiated(checkpoint_id)
    end

  //////////////////////////////////
  // JOINERS
  //////////////////////////////////

  be pre_register_joining_workers(ws: Array[WorkerName] val) =>
    """
    When the coordinator initiates join migration, it tells all joining
    workers about the other joining workers. This behavior is called when a
    on a joining worker when it receives this message.
    """
    _phase.pre_register_joining_workers(ws)

  be receive_hash_partitions(
    hash_partitions: Map[RoutingId, HashPartitions] val)
  =>
    """
    When the coordinator is finished migrating state and is waiting for
    migration acks, it tells all joiners about the new hash partitions. A
    joiner needs to update its hash partitions before it can ack migration
    batches.
    """
    _phase.receive_hash_partitions(hash_partitions)

  be worker_completed_migration_batch(worker: WorkerName) =>
    """
    Called after a worker has sent all state for a given grow
    migration. Received when a joiner is ready to ack sender_name that it's
    ready to receive data messages (after it's received migration batch from
    that worker, updated hash partitions, and has ensured its producers have
    registered downstream).
    """
    _phase.worker_completed_migration(worker)

  be ready_to_resume_the_world() =>
    """
    When we are ready to resume processing, we inject the autoscale resume
    barrier.
    """
    let promise = Promise[None]
    promise.next[None]({(_: None) =>
      _self.autoscale_resume_barrier_complete()})
    _autoscale_barrier_initiator.initiate_autoscale_resume_acks(promise)

  be autoscale_resume_barrier_complete() =>
    _phase.autoscale_complete()
    _router_registry.resume_the_world(_worker_name)

  //////////////////////////////////////////////
  // AFTER MIGRATION HAS COMPLETED.
  // COORDINATOR, NON-COORDINATORS, AND JOINERS
  //////////////////////////////////////////////

  be all_migration_complete() =>
    _phase.all_migration_complete()

  be receive_grow_migration_ack(target_worker: WorkerName) =>
    """
    Called when a joining worker is acking the migration batch we sent to it
    and is ready to receive data messages.
    """
    ifdef debug then
      @printf[I32]("--Processing migration batch complete ack from %s\n"
        .cstring(), target_worker.cstring())
    end
    _phase.receive_grow_migration_ack(target_worker)

  be inform_of_producers_list(producers: SetIs[Producer] val) =>
    _phase.inform_of_producers_list(producers)

  be producer_acked_registering(p: Producer) =>
    """
    When we receive all join migration acks, we send a promise to each
    producer for it to ack registering downstream (right now they just
    immediately ack).
    """
    _phase.producer_acked_registering(p)

  be inform_of_boundaries_map(
    boundaries: Map[WorkerName, OutgoingBoundary] val)
  =>
    _phase.inform_of_boundaries_map(boundaries)

  be boundary_acked_registering(b: OutgoingBoundary) =>
    """
    When we receive all producer register downstream acks, we send a promise
    to each boundary for it to ack registering downstream. The boundary
    requests an ack from the DataReceiver, and then acks to us.
    """
    _phase.boundary_acked_registering(b)

  be autoscale_complete() =>
    """
    For coordinator, this is called when the autoscale resume barrier is
    complete. The coordinator then sends an autoscale_complete message to
    non-coordinators, which causes this to be called for them.
    """
    _phase.autoscale_complete()

/////////////////////////////////////////////////
// HELPERS FOR GROW (CALLED BY AUTOSCALE PHASES)
/////////////////////////////////////////////////

  ///////////////////
  // COORDINATOR
  ///////////////////
  fun ref wait_for_joiners(conn: TCPConnection, worker: WorkerName,
    worker_count: USize, local_topology: LocalTopology,
    current_worker_count: USize)
  =>
    _phase = _WaitingForJoiners(_auth, this, worker_count,
      current_worker_count)
    _phase.worker_join(conn, worker, worker_count, local_topology,
      current_worker_count)

  fun ref request_checkpoint_id(
    connected_joiners: Map[WorkerName, (TCPConnection, LocalTopology)],
    joining_worker_count: USize, current_worker_count: USize)
  =>
    _phase = _WaitingForCheckpointId(this, connected_joiners,
      joining_worker_count, current_worker_count)
    let promise = Promise[(CheckpointId, RollbackId)]
    promise.next[None](_self~update_checkpoint_id_for_autoscale())
    _checkpoint_initiator.lookup_checkpoint_id(promise)

  fun ref inject_autoscale_barrier(
    connected_joiners: Map[WorkerName, (TCPConnection, LocalTopology)],
    joining_worker_count: USize, current_worker_count: USize,
    checkpoint_id: CheckpointId, rollback_id: RollbackId)
  =>
    let new_workers_iso = recover iso Array[WorkerName] end
    for w in connected_joiners.keys() do
      new_workers_iso.push(w)
    end
    let new_workers = consume val new_workers_iso
    _phase = _InjectAutoscaleBarrier(this, connected_joiners,
      joining_worker_count, current_worker_count, checkpoint_id, rollback_id)

    try
      let msg = ChannelMsgEncoder.initiate_stop_the_world_for_grow_migration(
        _worker_name, new_workers, _auth)?
      _connections.send_control_to_cluster_with_exclusions(msg, new_workers)
    else
      Fail()
    end

    let promise = Promise[None]
    promise.next[None]({(_: None) =>
      _self.grow_autoscale_barrier_complete()})
    _autoscale_barrier_initiator.initiate_autoscale(promise
      where joining_workers = new_workers)

    _router_registry.initiate_stop_the_world_for_grow_migration(new_workers)

  fun inform_joining_worker(conn: TCPConnection, worker: WorkerName,
    local_topology: LocalTopology, checkpoint_id: CheckpointId,
    rollback_id: RollbackId)
  =>
    _connections.inform_joining_worker(conn, worker, local_topology,
      checkpoint_id, rollback_id, _initializer_name)

  fun ref wait_for_joiner_initialization(joining_worker_count: USize,
    initialized_workers: StringSet,
    new_step_group_routing_ids:
      Map[WorkerName, Map[RoutingId, RoutingId] val] val,
    current_worker_count: USize)
  =>
    _phase = _WaitingForJoinerInitialization(this, joining_worker_count,
      initialized_workers, new_step_group_routing_ids, current_worker_count)

  fun ref wait_for_connections(
    new_workers: Array[WorkerName] val,
    new_step_group_routing_ids:
      Map[WorkerName, Map[RoutingId, RoutingId] val] val,
    current_worker_count: USize)
  =>
    _phase = _WaitingForConnections(this, new_workers, current_worker_count)

    _connections.notify_current_workers_of_joining_addresses(new_workers,
      new_step_group_routing_ids)
    _connections.notify_joining_workers_of_joining_addresses(new_workers,
      new_step_group_routing_ids)
    // The coordinator should only get here if it has already set up boundaries
    // to the joining workers.
    _phase.worker_connected_to_joining_workers(_worker_name)

  fun ref wait_for_migration(joining_workers: Array[WorkerName] val) =>
    _phase = _WaitingForMigration(this, joining_workers)

  fun ref ack_all_producers_have_registered(
    non_joining_workers: SetIs[WorkerName])
  =>
    _phase = _WaitingForResumeTheWorld(this, _auth, false)
    for w in non_joining_workers.values() do
      _connections.worker_completed_migration_batch(w)
    end

  fun ref update_hash_partitions(hp: Map[RoutingId, HashPartitions] val) =>
    _router_registry.update_hash_partitions(hp)

  ///////////////////
  // NON-COORDINATOR
  ///////////////////

  fun ref stop_the_world_for_grow_migration(coordinator: WorkerName,
    joining_workers: Array[WorkerName] val)
  =>
    _phase = _WaitingToConnectToJoiners(_auth, this, _worker_name,
      joining_workers, coordinator)
    // TODO: For now, we're handing control of the join protocol over to
    // RouterRegistry at this point. Eventually, we should manage the
    // entire protocol.
    _router_registry.stop_the_world_for_grow_migration(joining_workers)

  fun ref begin_grow_migration(joining_workers: Array[WorkerName] val,
    checkpoint_id: CheckpointId)
  =>
    _phase = _WaitingForGrowMigration(this, _auth, joining_workers
      where is_coordinator = false)
    _router_registry.begin_grow_migration(joining_workers,
      checkpoint_id)

  //////////
  // COORDINATOR & NON-COORDINATOR
  //////////

  fun ref all_grow_migration_acks_received(
    joining_workers: Array[WorkerName] val, is_coordinator: Bool)
  =>
    let completion_action = object ref
        let a: Autoscale ref = this
        fun ref apply() =>
          a.complete_grow(joining_workers, is_coordinator)
      end

    wait_for_producers_list(completion_action)

  fun ref wait_for_producers_list(completion_action: CompletionAction)
  =>
    _phase = _WaitingForProducersList(this, completion_action)
    let promise = Promise[SetIs[Producer] val]
    promise.next[None](_self~inform_of_producers_list())
    _router_registry.list_producers(promise)

  fun ref wait_for_producers_to_register(producers: SetIs[Producer] val,
    completion_action: CompletionAction)
  =>
    _phase = _WaitingForProducersToRegister(this, producers, completion_action)
    for p in producers.values() do
      let promise = Promise[Producer]
      promise.next[None](_self~producer_acked_registering())
      p.ack_immediately(promise)
    end

  fun ref wait_for_boundaries_map(completion_action: CompletionAction)
  =>
    _phase = _WaitingForBoundariesMap(this, completion_action)
    let promise = Promise[Map[WorkerName, OutgoingBoundary] val]
    promise.next[None](_self~inform_of_boundaries_map())
    _router_registry.list_boundaries(promise)

  fun ref prepare_grow_migration(joining_workers: Array[WorkerName] val) =>
    _phase = _WaitingForGrowMigration(this, _auth, joining_workers
      where is_coordinator = true)
    // TODO: For now, we're handing control of the join protocol over to
    // RouterRegistry at this point. Eventually, we should manage the
    // entire protocol.
    _router_registry.prepare_grow_migration(joining_workers)

  fun ref request_boundaries_to_ack_registering(
    boundaries_map: Map[WorkerName, OutgoingBoundary] val,
    completion_action: CompletionAction)
  =>
    let obs = SetIs[OutgoingBoundary]
    for b in boundaries_map.values() do
      obs.set(b)
    end
    _phase = _WaitingForBoundariesToAckRegistering(this, obs,
      completion_action)
    for ob in obs.values() do
      let promise = Promise[OutgoingBoundary]
      promise.next[None](_self~boundary_acked_registering())
      ob.ack_immediately(promise)
    end

  fun ref mark_autoscale_complete() =>
    @printf[I32]("AUTOSCALE: Autoscale is complete.\n".cstring())
    _phase = _WaitingForAutoscale(this)

  fun ref send_migration_batch_complete(joining_workers: Array[WorkerName] val,
    is_coordinator: Bool)
  =>
    _phase = _WaitingForGrowMigrationAcks(this, _auth, joining_workers,
      is_coordinator)
    if is_coordinator then
      _router_registry.inform_joining_workers_of_hash_partitions(
        joining_workers)
    end
    for target in joining_workers.values() do
      _router_registry.send_migration_batch_complete_msg(target)
    end

  fun ref complete_grow(
    joining_workers: Array[WorkerName] val, is_coordinator: Bool)
  =>
    _phase = _WaitingForResumeTheWorld(this, _auth, is_coordinator)
    _router_registry.complete_grow(joining_workers, is_coordinator)

  /////////////////
  // COMMON
  /////////////////
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


  /////////////////////////////////////////////////////////////////////////////
  /////////////////////////////////////////////////////////////////////////////
  //
  // SHRINK TO FIT
  //
  /////////////////////////////////////////////////////////////////////////////
  /////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////
  // COORDINATOR
  //////////////////////////////////

  be inject_shrink_autoscale_barrier(remaining_workers: Array[WorkerName] val,
    leaving_workers: Array[WorkerName] val)
  =>
    """
    This is called in response to an external message initiating shrink
    (or, in theory, from an internal initiation of shrink). Currently we
    only support external triggers. That trigger can be sent to any worker.
    """
    _phase = _InjectShrinkAutoscaleBarrier(this, remaining_workers,
      leaving_workers)

    try
      let msg = ChannelMsgEncoder.initiate_stop_the_world_for_shrink_migration(
        _worker_name, remaining_workers, leaving_workers, _auth)?
      _connections.send_control_to_cluster(msg)
    else
      Fail()
    end

    let promise = Promise[None]
    promise.next[None]({(_: None) =>
      _self.shrink_autoscale_barrier_complete()})
    _autoscale_barrier_initiator.initiate_autoscale(promise
      where leaving_workers = leaving_workers)

    _router_registry.initiate_stop_the_world_for_shrink_migration(
      remaining_workers, leaving_workers)

  be shrink_autoscale_barrier_complete() =>
    _phase.shrink_autoscale_barrier_complete()

  //////////////////////////////////
  // NON-COORDINATOR
  //////////////////////////////////

  be remote_stop_the_world_for_shrink_migration_request(
    coordinator: WorkerName, remaining_workers: Array[WorkerName] val,
    leaving_workers: Array[WorkerName] val)
  =>
    """
    Received when coordinator informs the cluster we should stop the world.
    """
    _phase.stop_the_world_for_shrink_migration_initiated(coordinator,
      remaining_workers, leaving_workers)

  be prepare_shrink(remaining_workers: Array[WorkerName] val,
    leaving_workers: Array[WorkerName] val)
  =>
    """
    During initiate_shrink, the coordinator sends all non-coordinators
    a prepare_shrink message.
    """
    _router_registry.prepare_shrink(remaining_workers, leaving_workers)

  //////////////////////////////////////////////
  // AFTER WE START WAITING TO RESUME THE WORLD
  // COORDINATOR + NON-COORDINATOR
  //////////////////////////////////////////////

  be disconnect_from_leaving_worker(worker: WorkerName) =>
    """
    When a leaver requests a migration batch ack, we ack immediately and
    then call this to disconnect.
    """
    _router_registry.disconnect_from_leaving_worker(worker)

  be leaving_worker_finished_migration(worker: WorkerName) =>
    """
    Called once we have disconnected from this worker
    """
    _phase.leaving_worker_finished_migration(worker)

  //////////////////////////////////////////////
  // LEAVER
  //////////////////////////////////////////////

  be prepare_leaving_migration(remaining_workers: Array[WorkerName] val,
    leaving_workers: Array[WorkerName] val)
  =>
    """
    During initiate_shrink, the coordinator sends all leavers
    a BeginLeavingMigration message, which causes this behavior to
    be called.
    Within this behavior, we request the checkpoint id with a promise
    that will trigger the begin_leaving_migration behavior.
    """
    let lookup_next_checkpoint_id = Promise[CheckpointId]
    lookup_next_checkpoint_id.next[None](
      _self~begin_leaving_migration(remaining_workers, leaving_workers))
    _checkpoint_initiator.lookup_next_checkpoint_id(lookup_next_checkpoint_id)

  be begin_leaving_migration(remaining_workers: Array[WorkerName] val,
    leaving_workers: Array[WorkerName] val, next_checkpoint_id: CheckpointId)
  =>
    """
    This is called when the prepare_leaving_migration request to
    CheckpointInitiator for checkpoint_id promise completes. In this
    behavior, we hand control for migrating state over to RouterRegistry.
    TODO: Handle migration more directly ourselves.
    """
    _phase = _WaitingForLeavingMigration(this, remaining_workers)
    _router_registry.begin_leaving_migration(remaining_workers,
      leaving_workers, next_checkpoint_id)

  be receive_leaving_migration_ack(worker: WorkerName) =>
    """
    Called when a worker is acking having received all state we migrated.
    """
    _phase.receive_leaving_migration_ack(worker)

////////////////////////////////////////////////////
// HELPERS FOR SHRINK (CALLED BY AUTOSCALE PHASES)
////////////////////////////////////////////////////

  ///////////////
  // COORDINATOR
  ///////////////
  fun ref initiate_shrink(remaining_workers: Array[WorkerName] val,
    leaving_workers: Array[WorkerName] val)
  =>
    _phase = _InitiatingShrink(this, remaining_workers, leaving_workers)
    _router_registry.initiate_shrink(remaining_workers, leaving_workers)

  fun ref all_leaving_workers_finished(leaving_workers: Array[WorkerName] val,
    is_coordinator: Bool = false)
  =>
    _phase = _WaitingForResumeTheWorld(this, _auth, is_coordinator)
    _router_registry.all_leaving_workers_finished(leaving_workers)

  ///////////////////
  // NON-COORDINATOR
  ///////////////////
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

  //////////////
  // LEAVER
  //////////////
  fun ref wait_for_leaving_migration_acks(
    remaining_workers: Array[WorkerName] val)
  =>
    _phase = _WaitingForLeavingMigrationAcks(this, remaining_workers)
    try
      let msg = ChannelMsgEncoder.leaving_migration_ack_request(_worker_name,
        _auth)?
      for w in remaining_workers.values() do
        _connections.send_control(w, msg)
      end
    else
      Fail()
    end
