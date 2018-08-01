/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "collections"
use "net"
use "wallaroo/core/common"
use "wallaroo/core/initialization"
use "wallaroo/core/invariant"
use "wallaroo/core/messages"
use "wallaroo/ent/network"
use "wallaroo/ent/router_registry"
use "wallaroo_labs/collection_helpers"
use "wallaroo_labs/mort"

class Autoscale
  """
  Phases:
    INITIAL:
      _WaitingForAutoscale: Wait for either a grow or shrink autoscale event.

    JOIN (coordinator):
    1) _WaitingForJoiners: Waiting for provided number of workers to connect
    2) _WaitingForJoinerInitialization: Waiting for all joiners to initialize
    3) _WaitingForConnections: Waiting for current workers to connect to
      joiners
    4) _WaitingForJoinMigration: We currently delegate coordination of
      in flight acking and migration back to RouterRegistry. We wait for join
      migration to finish from our side (i.e. we've sent all steps).
      TODO: Handle these remaining phases here.
    5) _WaitingForJoinMigrationAcks: We wait for new workers to ack incoming
      join migration.
    6) _WaitingForResumeTheWorld: Waiting for unmuting procedure to finish.
    7) _WaitingForAutoscale: Autoscale is complete and we are back to our
      initial waiting state.

    JOIN (non-coordinator):
    1) _WaitingToConnectToJoiners: After receiving the addresses for all
      joining workers from the coordinator, we connect to all of them. Once all
      boundaries are set up, we inform the coordinator.
    2) _WaitingForStopTheWorld: We are waiting for the coordinator to tell us
      to begin preparation for migration.
    3) _WaitingForJoinMigration: We currently delegate coordination
      of in flight acking and migration back to RouterRegistry. We wait for
      join migration to finish from our side (i.e. we've sent all steps).
    4) _WaitingForJoinMigrationAcks: We wait for new workers to ack incoming
      join migration.
    5) _WaitingForResumeTheWorld: Waiting for unmuting procedure to finish.
    6) _WaitingForAutoscale: Autoscale is complete and we are back to our
      initial waiting state.

    JOIN (joining worker):
    1) _JoiningWorker: Wait for all steps to be migrated.
    2) _WaitingForAutoscale: Autoscale is complete and we are back to our
      initial waiting state.

    SHRINK (coordinator):
    1) _InitiatingShrink: RouterRegistry currently handles the details. We're
      waiting until all steps have been migrated from leaving workers.
    2) _WaitingForResumeTheWorld: Waiting for unmuting procedure to finish.
    3) _WaitingForAutoscale: Autoscale is complete and we are back to our
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
  let _worker_name: String
  let _router_registry: RouterRegistry ref
  let _connections: Connections
  var _phase: _AutoscalePhase = _EmptyAutoscalePhase

  new create(auth: AmbientAuth, worker_name: String, rr: RouterRegistry ref,
    connections: Connections, is_joining: Bool)
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

  fun ref worker_join(conn: TCPConnection, worker: String,
    worker_count: USize, local_topology: LocalTopology,
    current_worker_count: USize)
  =>
    _phase.worker_join(conn, worker, worker_count, local_topology,
      current_worker_count)

  fun ref wait_for_joiners(conn: TCPConnection, worker: String,
    worker_count: USize, local_topology: LocalTopology,
    current_worker_count: USize)
  =>
    _phase = _WaitingForJoiners(_auth, this, _router_registry, worker_count,
      current_worker_count)
    _phase.worker_join(conn, worker, worker_count, local_topology,
      current_worker_count)

  fun ref wait_for_joiner_initialization(joining_worker_count: USize,
    initialized_workers: _StringSet, current_worker_count: USize)
  =>
    _phase = _WaitingForJoinerInitialization(this, joining_worker_count,
      initialized_workers, current_worker_count)

  fun ref wait_for_connections(new_workers: Array[String] val,
    current_worker_count: USize)
  =>
    _phase = _WaitingForConnections(this, new_workers, current_worker_count)
    // The coordinator should only get here if it has already set up boundaries
    // to the joining workers.
    _phase.worker_connected_to_joining_workers(_worker_name)

  fun ref joining_worker_initialized(worker: String) =>
    _phase.joining_worker_initialized(worker)

  fun ref worker_connected_to_joining_workers(worker: String) =>
    _phase.worker_connected_to_joining_workers(worker)

  fun notify_current_workers_of_joining_addresses(
    new_workers: Array[String] val)
  =>
    _connections.notify_current_workers_of_joining_addresses(new_workers)

  fun notify_joining_workers_of_joining_addresses(
    new_workers: Array[String] val)
  =>
    _connections.notify_joining_workers_of_joining_addresses(new_workers)

  fun ref connect_to_joining_workers(ws: Array[String] val,
    coordinator: String)
  =>
    _phase = _WaitingToConnectToJoiners(_auth, this, _worker_name, ws,
      coordinator)

  fun ref waiting_for_stop_the_world(joining_workers: Array[String] val) =>
    _phase = _WaitingForStopTheWorld(this, joining_workers)

  fun ref waiting_for_migration(joining_workers: Array[String] val) =>
    _phase = _WaitingForMigration(this, joining_workers)

  fun ref stop_the_world_for_join_migration_initiated(
    joining_workers: Array[String] val)
  =>
    _phase.stop_the_world_for_join_migration_initiated()

  fun ref join_migration_initiated(joining_workers: Array[String] val) =>
    _phase.join_migration_initiated()

  fun ref begin_join_migration(joining_workers: Array[String] val) =>
    _phase = _WaitingForJoinMigration(this, _auth, joining_workers
      where is_coordinator = false)
    _router_registry.begin_join_migration(joining_workers)

  fun ref initiate_stop_the_world_for_join_migration(
    joining_workers: Array[String] val)
  =>
    _phase = _WaitingForJoinMigration(this, _auth, joining_workers
      where is_coordinator = true)
    // TODO: For now, we're handing control of the join protocol over to
    // RouterRegistry at this point. Eventually, we should manage the
    // entire protocol.
    _router_registry.initiate_stop_the_world_for_grow_migration(
      joining_workers)

  fun ref stop_the_world_for_join_migration(joining_workers: Array[String] val)
  =>
    _phase = _WaitingForMigration(this, joining_workers)
    // TODO: For now, we're handing control of the join protocol over to
    // RouterRegistry at this point. Eventually, we should manage the
    // entire protocol.
    _router_registry.stop_the_world_for_grow_migration(joining_workers)

  fun ref all_step_migration_complete() =>
    _phase.all_step_migration_complete()

  fun ref send_migration_batch_complete(joining_workers: Array[String] val,
    is_coordinator: Bool)
  =>
    _phase = _WaitingForJoinMigrationAcks(this, _auth, joining_workers,
      is_coordinator)
    for target in joining_workers.values() do
      _router_registry.send_migration_batch_complete_msg(target)
    end

  fun ref receive_join_migration_ack(worker: String) =>
    _phase.receive_join_migration_ack(worker)

  fun ref all_join_migration_acks_received(joining_workers: Array[String] val,
    is_coordinator: Bool)
  =>
    _phase = _WaitingForResumeTheWorld(this, _auth, is_coordinator)
    _router_registry.all_join_migration_acks_received(joining_workers,
      is_coordinator)

  fun ref initiate_shrink(remaining_workers: Array[String] val,
    leaving_workers: Array[String] val)
  =>
    _phase = _InitiatingShrink(this, remaining_workers, leaving_workers)

  fun ref prepare_shrink(remaining_workers: Array[String] val,
    leaving_workers: Array[String] val)
  =>
    _phase = _ShrinkInProgress(this, remaining_workers, leaving_workers)

  fun ref begin_leaving_migration(remaining_workers: Array[String] val) =>
    _phase = _WaitingForLeavingMigration(this, remaining_workers)

  fun ref leaving_worker_finished_migration(worker: String) =>
    _phase.leaving_worker_finished_migration(worker)

  fun ref all_leaving_workers_finished(leaving_workers: Array[String] val) =>
    _phase = _WaitingForResumeTheWorld(this, _auth
      where is_coordinator = false)
    _router_registry.all_leaving_workers_finished(leaving_workers)

  fun ref autoscale_complete() =>
    _phase.autoscale_complete()

  fun ref wait_for_leaving_migration_acks(remaining_workers: Array[String] val)
  =>
    _phase = _WaitingForLeavingMigrationAcks(this, remaining_workers)
    _router_registry.send_leaving_migration_ack_request(remaining_workers)

  fun ref receive_leaving_migration_ack(worker: String) =>
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

  fun ref worker_join(conn: TCPConnection, worker: String,
    worker_count: USize, local_topology: LocalTopology,
    current_worker_count: USize)
  =>
    _invalid_call()

  fun ref joining_worker_initialized(worker: String) =>
    _invalid_call()

  fun ref worker_connected_to_joining_workers(worker: String) =>
    _invalid_call()

  fun ref stop_the_world_for_join_migration_initiated() =>
    _invalid_call()

  fun ref join_migration_initiated() =>
    _invalid_call()

  fun ref all_step_migration_complete() =>
    _invalid_call()

  fun ref receive_join_migration_ack(worker: String) =>
    _invalid_call()

  fun ref leaving_worker_finished_migration(worker: String) =>
    _invalid_call()

  fun ref receive_leaving_migration_ack(worker: String) =>
    _invalid_call()

  fun ref autoscale_complete() =>
    _invalid_call()

  fun ref _invalid_call() =>
    @printf[I32]("Invalid call on autoscale phase %s\n".cstring(),
      name().cstring())
    Fail()

class _EmptyAutoscalePhase is _AutoscalePhase
  fun name(): String => "EmptyAutoscalePhase"

class _WaitingForAutoscale is _AutoscalePhase
  let _autoscale: Autoscale ref

  new create(autoscale: Autoscale ref) =>
    @printf[I32]("AUTOSCALE: Waiting for new autoscale event.\n".cstring())
    _autoscale = autoscale

  fun name(): String => "WaitingForAutoscale"

  fun ref worker_join(conn: TCPConnection, worker: String,
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
  let _connected_joiners: _StringSet = _connected_joiners.create()
  let _initialized_workers: _StringSet = _initialized_workers.create()
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

  fun ref worker_join(conn: TCPConnection, worker: String,
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
      _router_registry.inform_joining_worker(conn, worker, local_topology)
      _connected_joiners.set(worker)
      if _connected_joiners.size() == _joining_worker_count then
        _autoscale.wait_for_joiner_initialization(_joining_worker_count,
          _initialized_workers, _current_worker_count)
      end
    end

  fun ref joining_worker_initialized(worker: String) =>
    // It's possible some workers will be initialized when we're still in
    // this phase. We need to keep track of this to hand off that info to
    // the next phase.
    _initialized_workers.set(worker)
    if _initialized_workers.size() >= _joining_worker_count then
      // We should have already transitioned to the next phase before this.
      Fail()
    end

class _WaitingForJoinerInitialization is _AutoscalePhase
  let _autoscale: Autoscale ref
  let _joining_worker_count: USize
  var _initialized_joining_workers: _StringSet
  let _current_worker_count: USize

  new create(autoscale: Autoscale ref, joining_worker_count: USize,
    initialized_workers: _StringSet, current_worker_count: USize)
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
    @printf[I32](("AUTOSCALE: Waiting for %s joining workers to initialize. " +
      "Already initialized: %s. Current cluster size is %s\n").cstring(),
      _joining_worker_count.string().cstring(),
      _initialized_joining_workers.size().string().cstring(),
      _current_worker_count.string().cstring())

  fun name(): String => "WaitingForJoinerInitialization"

  fun ref joining_worker_initialized(worker: String) =>
    _initialized_joining_workers.set(worker)
    if _initialized_joining_workers.size() == _joining_worker_count then
      let nws = recover trn Array[String] end
      for w in _initialized_joining_workers.values() do
        nws.push(w)
      end
      let new_workers = consume val nws
      _autoscale.notify_joining_workers_of_joining_addresses(new_workers)
      _autoscale.notify_current_workers_of_joining_addresses(new_workers)
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

  fun ref worker_connected_to_joining_workers(worker: String) =>
    """
    Indicates that another worker has connected to joining workers.
    """
    _connected_workers.set(worker)
    if _connected_workers.size() == _connecting_worker_count then
      _autoscale.initiate_stop_the_world_for_join_migration(_new_workers)
    end

class _WaitingToConnectToJoiners is _AutoscalePhase
  let _auth: AmbientAuth
  let _autoscale: Autoscale ref
  let _worker_name: String
  let _joining_workers: Array[String] val
  let _coordinator: String
  let _new_boundaries: _StringSet = _new_boundaries.create()

  new create(auth: AmbientAuth, autoscale: Autoscale ref, worker_name: String,
    joining_workers: Array[String] val, coordinator: String)
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

  fun ref joining_worker_initialized(worker: String) =>
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
      _autoscale.waiting_for_stop_the_world(_joining_workers)
    end

class _WaitingForStopTheWorld is _AutoscalePhase
  let _autoscale: Autoscale ref
  let _joining_workers: Array[String] val

  new create(autoscale: Autoscale ref, joining_workers: Array[String] val) =>
    _autoscale = autoscale
    _joining_workers = joining_workers
    @printf[I32](("AUTOSCALE: Waiting for signal to begin local stop the " +
      "world\n").cstring())

  fun name(): String => "WaitingForStopTheWorld"

  fun ref stop_the_world_for_join_migration_initiated() =>
    _autoscale.stop_the_world_for_join_migration(_joining_workers)

class _WaitingForMigration is _AutoscalePhase
  let _autoscale: Autoscale ref
  let _joining_workers: Array[String] val

  new create(autoscale: Autoscale ref, joining_workers: Array[String] val) =>
    _autoscale = autoscale
    _joining_workers = joining_workers
    @printf[I32]("AUTOSCALE: Waiting for signal to begin migration\n"
      .cstring())

  fun name(): String => "WaitingForMigration"

  fun ref join_migration_initiated() =>
    _autoscale.begin_join_migration(_joining_workers)

class _WaitingForJoinMigration is _AutoscalePhase
  """
  During this phase, we've handed off responsibility for join migration to
  the RouterRegistry.
  """
  let _autoscale: Autoscale ref
  let _auth: AmbientAuth
  let _joining_workers: Array[String] val
  let _is_coordinator: Bool

  new create(autoscale: Autoscale ref, auth: AmbientAuth,
    joining_workers: Array[String] val, is_coordinator: Bool)
  =>
    @printf[I32]("AUTOSCALE: Waiting for join migration to complete.\n"
      .cstring())
    _autoscale = autoscale
    _auth = auth
    _joining_workers = joining_workers
    _is_coordinator = is_coordinator

  fun name(): String => "WaitingForJoinMigration"

  fun ref all_step_migration_complete() =>
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
    joining_workers: Array[String] val, is_coordinator: Bool)
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

  fun ref receive_join_migration_ack(worker: String) =>
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

  fun ref worker_join(conn: TCPConnection, worker: String,
    worker_count: USize, local_topology: LocalTopology,
    current_worker_count: USize)
  =>
    None

  fun ref joining_worker_initialized(worker: String) =>
    None

  fun ref worker_connected_to_joining_workers(worker: String) =>
    None

  fun ref stop_the_world_for_join_migration_initiated() =>
    None

  fun ref join_migration_initiated() =>
    None

//!2
  // fun ref ready_for_join_migration() =>
  //   None

  fun ref autoscale_complete() =>
    _autoscale.mark_autoscale_complete()

/////////////////////////////////////////////////
// SHRINK PHASES
/////////////////////////////////////////////////
class _InitiatingShrink is _AutoscalePhase
  let _autoscale: Autoscale ref
  let _remaining_workers: Array[String] val
  let _leaving_workers: Array[String] val
  let _leaving_workers_waiting_list: _StringSet =
    _leaving_workers_waiting_list.create()

  new create(autoscale: Autoscale ref, remaining_workers: Array[String] val,
    leaving_workers: Array[String] val)
  =>
    @printf[I32]("AUTOSCALE: Initiating shrink.\n".cstring())
    _autoscale = autoscale
    _remaining_workers = remaining_workers
    _leaving_workers = leaving_workers
    for w in _leaving_workers.values() do
      _leaving_workers_waiting_list.set(w)
    end

  fun name(): String => "InitiatingShrink"

  fun ref leaving_worker_finished_migration(worker: String) =>
    @printf[I32]("Leaving worker %s reported migration complete\n".cstring(),
      worker.cstring())
    ifdef debug then
      Invariant(_leaving_workers_waiting_list.size() > 0)
    end
    _leaving_workers_waiting_list.unset(worker)
    if _leaving_workers_waiting_list.size() == 0 then
      _autoscale.all_leaving_workers_finished(_leaving_workers)
    end

class _ShrinkInProgress is _AutoscalePhase
  let _autoscale: Autoscale ref
  let _remaining_workers: Array[String] val
  let _leaving_workers: Array[String] val
  let _leaving_workers_waiting_list: _StringSet =
    _leaving_workers_waiting_list.create()

  new create(autoscale: Autoscale ref, remaining_workers: Array[String] val,
    leaving_workers: Array[String] val)
  =>
    @printf[I32]("AUTOSCALE: Shrink in progress.\n".cstring())
    _autoscale = autoscale
    _remaining_workers = remaining_workers
    _leaving_workers = leaving_workers
    for w in _leaving_workers.values() do
      _leaving_workers_waiting_list.set(w)
    end

  fun name(): String => "ShrinkInProgress"

  fun ref leaving_worker_finished_migration(worker: String) =>
    ifdef debug then
      Invariant(_leaving_workers_waiting_list.size() > 0)
    end
    _leaving_workers_waiting_list.unset(worker)
    if _leaving_workers_waiting_list.size() == 0 then
      _autoscale.all_leaving_workers_finished(_leaving_workers)
    end

class _WaitingForLeavingMigration is _AutoscalePhase
  """
  Used on a leaving worker. Currently the RouterRegistry handles the migration
  details.
  """
  let _autoscale: Autoscale ref
  let _remaining_workers: Array[String] val

  new create(autoscale: Autoscale ref, remaining_workers: Array[String] val) =>
    @printf[I32]("AUTOSCALE: Waiting for leaving migration.\n".cstring())
    _autoscale = autoscale
    _remaining_workers = remaining_workers

  fun name(): String => "WaitingForLeavingMigration"

  fun ref leaving_worker_finished_migration(worker: String) =>
    None

  fun ref all_step_migration_complete() =>
    _autoscale.wait_for_leaving_migration_acks(_remaining_workers)

class _WaitingForLeavingMigrationAcks is _AutoscalePhase
  """
  Wait for remaining workers to ack that we've migrated all steps.
  """
  let _autoscale: Autoscale ref
  let _remaining_workers: Array[String] val
  let _worker_waiting_list: _StringSet = _worker_waiting_list.create()

  new create(autoscale: Autoscale ref, remaining_workers: Array[String] val) =>
    @printf[I32]("AUTOSCALE: Waiting for leaving migration complete acks.\n"
      .cstring())
    _autoscale = autoscale
    _remaining_workers = remaining_workers
    for w in _remaining_workers.values() do
      _worker_waiting_list.set(w)
    end

  fun name(): String => "WaitingForLeavingMigrationAcks"

  fun ref leaving_worker_finished_migration(worker: String) =>
    None

  fun ref receive_leaving_migration_ack(worker: String) =>
    ifdef debug then
      Invariant(
        ArrayHelpers[String].contains[String](_remaining_workers, worker))
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
