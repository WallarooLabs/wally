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
use "wallaroo/core/routing"
use "wallaroo_labs/collection_helpers"
use "wallaroo_labs/mort"
use "wallaroo_labs/string_set"


trait _AutoscalePhase
  fun name(): String

  fun ref worker_join(conn: TCPConnection, worker: WorkerName,
    worker_count: USize, local_topology: LocalTopology,
    current_worker_count: USize)
  =>
    _invalid_call(); Fail()

  fun ref update_checkpoint_id(checkpoint_id: CheckpointId,
    rollback_id: RollbackId)
  =>
    _invalid_call(); Fail()

  fun ref grow_autoscale_barrier_complete() =>
    _invalid_call(); Fail()

  fun ref joining_worker_initialized(worker: WorkerName,
    step_group_routing_ids: Map[RoutingId, RoutingId] val)
  =>
    _invalid_call(); Fail()

  fun ref worker_connected_to_joining_workers(worker: WorkerName) =>
    _invalid_call(); Fail()

  fun ref stop_the_world_for_grow_migration_initiated(coordinator: WorkerName,
    joining_workers: Array[WorkerName] val)
  =>
    _invalid_call(); Fail()

  fun ref grow_migration_initiated(checkpoint_id: CheckpointId) =>
    _invalid_call(); Fail()

  fun ref all_migration_complete() =>
    _invalid_call(); Fail()

  fun ref receive_grow_migration_ack(worker: WorkerName) =>
    _invalid_call(); Fail()

  fun ref worker_completed_migration(w: WorkerName) =>
    _invalid_call(); Fail()

  fun ref pre_register_joining_workers(ws: Array[WorkerName] val) =>
    _invalid_call(); Fail()

  fun ref receive_hash_partitions(hp: Map[RoutingId, HashPartitions] val) =>
    _invalid_call(); Fail()

  fun ref inform_of_producers_list(ps: SetIs[Producer] val) =>
    _invalid_call(); Fail()

  fun ref producer_acked_registering(p: Producer) =>
    _invalid_call(); Fail()

  fun ref inform_of_boundaries_map(bs: Map[WorkerName, OutgoingBoundary] val)
  =>
    _invalid_call(); Fail()

  fun ref boundary_acked_registering(b: OutgoingBoundary) =>
    _invalid_call(); Fail()

  fun ref stop_the_world_for_shrink_migration_initiated(
    coordinator: WorkerName, remaining_workers: Array[WorkerName] val,
    leaving_workers: Array[WorkerName] val)
  =>
    _invalid_call(); Fail()

  fun ref shrink_autoscale_barrier_complete() =>
    _invalid_call(); Fail()

  fun ref leaving_worker_finished_migration(worker: WorkerName) =>
    _invalid_call(); Fail()

  fun ref receive_leaving_migration_ack(worker: WorkerName) =>
    _invalid_call(); Fail()

  fun ref producers_disposed() =>
    _invalid_call(); Fail()

  fun ref autoscale_complete() =>
    _invalid_call(); Fail()

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

  fun ref stop_the_world_for_grow_migration_initiated(coordinator: WorkerName,
    joining_workers: Array[WorkerName] val)
  =>
    _autoscale.stop_the_world_for_grow_migration(coordinator, joining_workers)

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
  let _joining_worker_count: USize
  let _connected_joiners: Map[WorkerName, (TCPConnection, LocalTopology)] =
    _connected_joiners.create()
  var _newstep_group_routing_ids:
    Map[WorkerName, Map[RoutingId, RoutingId] val] iso =
    recover Map[WorkerName, Map[RoutingId, RoutingId] val] end
  let _current_worker_count: USize

  new create(auth: AmbientAuth, autoscale: Autoscale ref,
    joining_worker_count: USize, current_worker_count: USize)
  =>
    _auth = auth
    _autoscale = autoscale
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
  let _connected_joiners: Map[WorkerName, (TCPConnection, LocalTopology)]
  let _joining_worker_count: USize
  let _current_worker_count: USize

  new create(autoscale: Autoscale ref,
    connected_joiners: Map[WorkerName, (TCPConnection, LocalTopology)],
    joining_worker_count: USize, current_worker_count: USize)
  =>
    _autoscale = autoscale
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
  let _connected_joiners: Map[WorkerName, (TCPConnection, LocalTopology)]
  let _initialized_workers: StringSet = _initialized_workers.create()
  var _new_step_group_routing_ids:
    Map[WorkerName, Map[RoutingId, RoutingId] val] iso =
    recover Map[WorkerName, Map[RoutingId, RoutingId] val] end
  let _joining_worker_count: USize
  let _current_worker_count: USize
  let _checkpoint_id: CheckpointId
  let _rollback_id: RollbackId

  new create(autoscale: Autoscale ref,
    connected_joiners: Map[WorkerName, (TCPConnection, LocalTopology)],
    joining_worker_count: USize, current_worker_count: USize,
    checkpoint_id: CheckpointId, rollback_id: RollbackId)
  =>
    _autoscale = autoscale
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
      _autoscale.inform_joining_worker(conn, worker, local_topology,
        _checkpoint_id, _rollback_id)
    end
    let new_step_group_routing_ids:
      Map[WorkerName, Map[RoutingId, RoutingId] val] val =
        (_new_step_group_routing_ids =
          recover Map[WorkerName, Map[RoutingId, RoutingId] val] end)
    _autoscale.wait_for_joiner_initialization(_joining_worker_count,
      _initialized_workers, new_step_group_routing_ids, _current_worker_count)

  fun ref joining_worker_initialized(worker: WorkerName,
    step_group_routing_ids: Map[RoutingId, RoutingId] val)
  =>
    // It's possible some workers will be initialized when we're still in
    // this phase. We need to keep track of this to hand off that info to
    // the next phase.
    _initialized_workers.set(worker)
    _new_step_group_routing_ids(worker) = step_group_routing_ids
    if _initialized_workers.size() >= _joining_worker_count then
      // We should have already transitioned to the next phase before this.
      Fail()
    end

class _WaitingForJoinerInitialization is _AutoscalePhase
  let _autoscale: Autoscale ref
  let _joining_worker_count: USize
  var _initialized_joining_workers: StringSet
  let _current_worker_count: USize
  var _new_step_group_routing_ids:
    Map[WorkerName, Map[RoutingId, RoutingId] val] iso =
    recover Map[WorkerName, Map[RoutingId, RoutingId] val] end

  new create(autoscale: Autoscale ref, joining_worker_count: USize,
    initialized_workers: StringSet,
    new_step_group_routing_ids:
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
    for (w, sri) in new_step_group_routing_ids.pairs() do
      _new_step_group_routing_ids(w) = sri
    end
    @printf[I32](("AUTOSCALE: Waiting for %s joining workers to initialize. " +
      "Already initialized: %s. Current cluster size is %s\n").cstring(),
      _joining_worker_count.string().cstring(),
      _initialized_joining_workers.size().string().cstring(),
      _current_worker_count.string().cstring())

  fun name(): String => "WaitingForJoinerInitialization"

  fun ref joining_worker_initialized(worker: WorkerName,
    step_group_routing_ids: Map[RoutingId, RoutingId] val)
  =>
    _initialized_joining_workers.set(worker)
    _new_step_group_routing_ids(worker) = step_group_routing_ids
    if _initialized_joining_workers.size() == _joining_worker_count then
      let nws = recover trn Array[String] end
      for w in _initialized_joining_workers.values() do
        nws.push(w)
      end
      let new_workers = consume val nws
      let new_step_group_routing_ids:
        Map[WorkerName, Map[RoutingId, RoutingId] val] val =
          (_new_step_group_routing_ids =
            recover Map[WorkerName, Map[RoutingId, RoutingId] val] end)
      _autoscale.wait_for_connections(new_workers, new_step_group_routing_ids,
        _current_worker_count)
    end

class _WaitingForConnections is _AutoscalePhase
  let _autoscale: Autoscale ref
  let _new_workers: Array[String] val
  let _connecting_worker_count: USize
  // Keeps track of new boundaries we set up to joining workers
  let _new_boundaries: StringSet = _new_boundaries.create()
  // Keeps track of how many other workers have set up all new boundaries
  // to joining workers.
  let _connected_workers: StringSet = _connected_workers.create()

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
  let _new_boundaries: StringSet = _new_boundaries.create()

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

  fun ref joining_worker_initialized(worker: WorkerName,
    step_group_routing_ids: Map[RoutingId, RoutingId] val)
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
      _autoscale.wait_for_migration(_joining_workers)
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

  fun ref grow_migration_initiated(checkpoint_id: CheckpointId) =>
    _autoscale.begin_grow_migration(_joining_workers, checkpoint_id)

class _WaitingForGrowMigration is _AutoscalePhase
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

  fun name(): String => "WaitingForGrowMigration"

  fun ref all_migration_complete() =>
    @printf[I32]("--Sending migration batch complete msg to new workers\n"
      .cstring())
    _autoscale.send_migration_batch_complete(_joining_workers, _is_coordinator)

class _WaitingForGrowMigrationAcks is _AutoscalePhase
  let _autoscale: Autoscale ref
  let _auth: AmbientAuth
  let _is_coordinator: Bool
  let _joining_workers: Array[String] val
  let _migration_target_ack_list: StringSet =
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

  fun name(): String => "WaitingForGrowMigrationAcks"

  fun ref receive_grow_migration_ack(worker: WorkerName) =>
    _migration_target_ack_list.unset(worker)
    if _migration_target_ack_list.size() == 0 then
      @printf[I32]("--All new workers have acked migration batch complete\n"
        .cstring())
      _autoscale.all_grow_migration_acks_received(_joining_workers,
        _is_coordinator)
    end

class _JoiningWorker is _AutoscalePhase
  """
  A joining worker needs to ensure that all other joiners have been
  initialized, that all keys have been migrated, and that it has
  received the post-migration hash partitions before it can proceed
  to checking that all producers have registered downstream (since
  before these conditions have been met, it's still possible for there to
  be more register_producer calls).
  """
  let _worker_name: WorkerName
  let _autoscale: Autoscale ref
  let _non_joining_workers: SetIs[WorkerName] = _non_joining_workers.create()
  let _completed_migration_workers: SetIs[WorkerName] =
    _completed_migration_workers.create()
  var _joining_workers: (SetIs[WorkerName] | None) = None
  let _registered_joining_workers: SetIs[WorkerName] =
    _registered_joining_workers.create()
  var _hash_partitions: (Map[RoutingId, HashPartitions] val | None) = None

  new create(worker_name: WorkerName, autoscale: Autoscale ref,
    non_joining_workers: Array[WorkerName] val)
  =>
    @printf[I32]("AUTOSCALE: Joining Worker\n".cstring())
    _worker_name = worker_name
    _autoscale = autoscale
    for w in non_joining_workers.values() do
      if w != _worker_name then
        _non_joining_workers.set(w)
      end
    end
    Invariant(_non_joining_workers.size() > 0)

  fun name(): String => "JoiningWorker"

  fun ref worker_join(conn: TCPConnection, worker: WorkerName,
    worker_count: USize, local_topology: LocalTopology,
    current_worker_count: USize)
  =>
    None

  fun ref worker_connected_to_joining_workers(worker: WorkerName) =>
    None

  fun ref stop_the_world_for_grow_migration_initiated(coordinator: WorkerName,
    joining_workers: Array[WorkerName] val)
  =>
    None

  fun ref grow_migration_initiated(checkpoint_id: CheckpointId) =>
    None

  fun ref pre_register_joining_workers(ws: Array[WorkerName] val) =>
    let joining_workers = SetIs[WorkerName]
    for w in ws.values() do
      if w != _worker_name then
        joining_workers.set(w)
      end
    end
    _joining_workers = joining_workers
    _check_complete()

  fun ref joining_worker_initialized(worker: WorkerName,
    step_group_routing_ids: Map[RoutingId, RoutingId] val)
  =>
    Invariant(worker != _worker_name)
    _registered_joining_workers.set(worker)
    _check_complete()

  fun ref receive_hash_partitions(hp: Map[RoutingId, HashPartitions] val) =>
    _hash_partitions = hp
    _check_complete()

  fun ref worker_completed_migration(worker: WorkerName) =>
    _completed_migration_workers.set(worker)
    _check_complete()

  fun ref _check_complete() =>
    if (_non_joining_workers.size() == _completed_migration_workers.size())
    then
      match _joining_workers
      | let jw: SetIs[WorkerName] =>
        match _hash_partitions
        | let hp: Map[RoutingId, HashPartitions] val =>
          if jw.size() == _registered_joining_workers.size() then
            let completion_action = object ref
                fun ref apply() =>
                  _autoscale.ack_all_producers_have_registered(
                    _non_joining_workers)
              end
            _autoscale.update_hash_partitions(hp)
            _autoscale.wait_for_producers_list(completion_action)
          end
        end
      end
    end

class _WaitingForProducersList is _AutoscalePhase
  let _autoscale: Autoscale ref
  let _completion_action: CompletionAction

  new create(autoscale: Autoscale ref, completion_action: CompletionAction) =>
    @printf[I32](("AUTOSCALE: Waiting for list of Producers\n").cstring())
    _autoscale = autoscale
    _completion_action = completion_action

  fun name(): String => "_WaitingForProducersList"

  fun ref worker_join(conn: TCPConnection, worker: WorkerName,
    worker_count: USize, local_topology: LocalTopology,
    current_worker_count: USize)
  =>
    None

  fun ref joining_worker_initialized(worker: WorkerName,
    step_group_routing_ids: Map[RoutingId, RoutingId] val)
  =>
    None

  fun ref worker_connected_to_joining_workers(worker: WorkerName) =>
    None

  fun ref stop_the_world_for_grow_migration_initiated(coordinator: WorkerName,
    joining_workers: Array[WorkerName] val)
  =>
    None

  fun ref grow_migration_initiated(checkpoint_id: CheckpointId) =>
    None

  fun ref inform_of_producers_list(ps: SetIs[Producer] val) =>
    _autoscale.wait_for_producers_to_register(ps, _completion_action)

class _WaitingForProducersToRegister is _AutoscalePhase
  let _autoscale: Autoscale ref
  let _producers: SetIs[Producer] val
  let _acked_producers: SetIs[Producer] = _acked_producers.create()
  let _completion_action: CompletionAction

  new create(autoscale: Autoscale ref, producers: SetIs[Producer] val,
    completion_action: CompletionAction)
  =>
    @printf[I32](("AUTOSCALE: Waiting for Producers " +
      "to register\n").cstring())
    _autoscale = autoscale
    _producers = producers
    Invariant(_producers.size() > 0)
    _completion_action = completion_action

  fun name(): String => "_WaitingForProducersToRegister"

  fun ref worker_join(conn: TCPConnection, worker: WorkerName,
    worker_count: USize, local_topology: LocalTopology,
    current_worker_count: USize)
  =>
    None

  fun ref joining_worker_initialized(worker: WorkerName,
    step_group_routing_ids: Map[RoutingId, RoutingId] val)
  =>
    None

  fun ref worker_connected_to_joining_workers(worker: WorkerName) =>
    None

  fun ref stop_the_world_for_grow_migration_initiated(coordinator: WorkerName,
    joining_workers: Array[WorkerName] val)
  =>
    None

  fun ref grow_migration_initiated(checkpoint_id: CheckpointId) =>
    None

  fun ref producer_acked_registering(p: Producer) =>
    _acked_producers.set(p)
    _check_complete()

  fun ref _check_complete() =>
    if _producers.size() == _acked_producers.size() then
      _autoscale.wait_for_boundaries_map(_completion_action)
    end

class _WaitingForBoundariesMap is _AutoscalePhase
  let _autoscale: Autoscale ref
  let _completion_action: CompletionAction

  new create(autoscale: Autoscale ref, completion_action: CompletionAction) =>
    @printf[I32](("AUTOSCALE: Waiting for list of Producers\n").cstring())
    _autoscale = autoscale
    _completion_action = completion_action

  fun name(): String => "_WaitingForBoundariesMap"

  fun ref worker_join(conn: TCPConnection, worker: WorkerName,
    worker_count: USize, local_topology: LocalTopology,
    current_worker_count: USize)
  =>
    None

  fun ref joining_worker_initialized(worker: WorkerName,
    step_group_routing_ids: Map[RoutingId, RoutingId] val)
  =>
    None

  fun ref worker_connected_to_joining_workers(worker: WorkerName) =>
    None

  fun ref stop_the_world_for_grow_migration_initiated(coordinator: WorkerName,
    joining_workers: Array[WorkerName] val)
  =>
    None

  fun ref grow_migration_initiated(checkpoint_id: CheckpointId) =>
    None

  fun ref inform_of_boundaries_map(obs: Map[WorkerName, OutgoingBoundary] val)
  =>
    _autoscale.request_boundaries_to_ack_registering(obs, _completion_action)

class _WaitingForBoundariesToAckRegistering is _AutoscalePhase
  let _autoscale: Autoscale ref
  let _boundaries: SetIs[OutgoingBoundary] = _boundaries.create()
  let _acked_boundaries: SetIs[OutgoingBoundary] =
    _acked_boundaries.create()
  let _completion_action: CompletionAction

  new create(autoscale: Autoscale ref,
    boundaries: SetIs[OutgoingBoundary],
    completion_action: CompletionAction)
  =>
    @printf[I32](("AUTOSCALE: Worker waiting for boundaries " +
      "to ack forwarding register messages\n").cstring())
    _autoscale = autoscale
    for b in boundaries.values() do
      _boundaries.set(b)
    end
    Invariant(_boundaries.size() > 0)
    _completion_action = completion_action

  fun name(): String => "_WaitingForBoundariesToAckRegistering"

  fun ref worker_join(conn: TCPConnection, worker: WorkerName,
    worker_count: USize, local_topology: LocalTopology,
    current_worker_count: USize)
  =>
    None

  fun ref joining_worker_initialized(worker: WorkerName,
    step_group_routing_ids: Map[RoutingId, RoutingId] val)
  =>
    None

  fun ref worker_connected_to_joining_workers(worker: WorkerName) =>
    None

  fun ref stop_the_world_for_grow_migration_initiated(coordinator: WorkerName,
    joining_workers: Array[WorkerName] val)
  =>
    None

  fun ref grow_migration_initiated(checkpoint_id: CheckpointId) =>
    None

  fun ref boundary_acked_registering(b: OutgoingBoundary) =>
    _acked_boundaries.set(b)
    _check_complete()

  fun ref _check_complete() =>
    if _boundaries.size() == _acked_boundaries.size() then
      _completion_action()
    end


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
  let _leaving_workers_waiting_list: StringSet =
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
  let _leaving_workers_waiting_list: StringSet =
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

  fun ref all_migration_complete() =>
    _autoscale.wait_for_leaving_migration_acks(_remaining_workers)

class _WaitingForLeavingMigrationAcks is _AutoscalePhase
  """
  Wait for remaining workers to ack that we've migrated all steps.
  """
  let _autoscale: Autoscale ref
  let _remaining_workers: Array[WorkerName] val
  let _worker_waiting_list: StringSet = _worker_waiting_list.create()

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

class _ShuttingDown is _AutoscalePhase
  new create() =>
    @printf[I32]("AUTOSCALE: Shutting down.\n".cstring())

  fun name(): String => "ShuttingDown"

  fun ref autoscale_complete() =>
    None

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


/////////////////////////////
interface CompletionAction
  fun ref apply()
