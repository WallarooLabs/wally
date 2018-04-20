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
  TODO: This is currently a work in progress. We should eventually move the
    protocol logic from RouterRegistry to this class. For the time being, it
    only handles the first two phases of join autoscale events.

  Phases:
    Initial: _WaitingForAutoscale: Wait for wait_for_joiners() to be called to
      initiate autoscale. At that point, we either begin join or shrink
      protocol.

    JOIN (coordinator):
    1) _WaitingForJoiners: Waiting for provided number of workers to connect
    2) _WaitingForJoinerInitialization: Waiting for all joiners to initialize
    3) _WaitingForConnections: Waiting for current workers to connect to
      joiners
    4) _CoordinatorMigrationInProgress: We currently delegate coordination of
      in flight acking and migration back to RouterRegistry. We simply wait to
      be told that autoscale is complete.
      TODO: Handle these remaining phases here.
    5) _WaitingForAutoscale: Autoscale is complete and we are back to our
      initial waiting state.

    JOIN (non-coordinator):
    1) _WaitingToConnectToJoiners: After receiving the addresses for all
      joining workers from the coordinator, we connect to all of them. Once all
      boundaries are set up, we inform the coordinator.
    2) _WaitingForStopTheWorld: We are waiting for the coordinator to tell us
      to beging preparation for migration.
    2) _WaitingForMigration: We are waiting for the coordinator to tell us to
      begin migration.
    3) _NonCoordinatorMigrationInProgress: We currently delegate coordination
      of in flight acking and migration back to RouterRegistry. We simply wait
      to be told that autoscale is complete.
    4) _WaitingForAutoscale: Autoscale is complete and we are back to our
      initial waiting state.

    JOIN (joining worker):
    1) _JoiningWorker: Wait for all steps to be migrated.
    2) _WaitingForAutoscale: Autoscale is complete and we are back to our
      initial waiting state.


    TODO: Handle shrink autoscale phases, which are currently handled by
      RouterRegistry.
    SHRINK (coordinator and non-coordinator):
    1) _ShrinkInProgress: RouterRegistry currently handles the details.
    2) _WaitingForAutoscale: Autoscale is complete and we are back to our
      initial waiting state.

    SHRINK (leaving worker):
    1) _ShrinkInProgress: RouterRegistry currently handles the details.
  """
  let _auth: AmbientAuth
  let _worker_name: String
  let _router_registry: RouterRegistry ref
  let _connections: Connections
  var _phase: AutoscalePhase = _EmptyAutoscalePhase

  new create(auth: AmbientAuth, worker_name: String, rr: RouterRegistry ref,
    connections: Connections, is_joining: Bool)
  =>
    _auth = auth
    _worker_name = worker_name
    _router_registry = rr
    _connections = connections
    if is_joining then
      _phase = _JoiningWorker(this)
      @printf[I32]("!@ Phase is now %s\n".cstring(), _phase.name().cstring())
    else
      _phase = _WaitingForAutoscale(this)
      @printf[I32]("!@ Phase is now %s\n".cstring(), _phase.name().cstring())
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
    @printf[I32]("!@ Phase is now %s\n".cstring(), _phase.name().cstring())
    _phase.worker_join(conn, worker, worker_count, local_topology,
      current_worker_count)

  fun ref wait_for_joiner_initialization(joining_worker_count: USize,
    initialized_workers: SetIs[String], current_worker_count: USize)
  =>
    _phase = _WaitingForJoinerInitialization(this, joining_worker_count,
      initialized_workers, current_worker_count)
    @printf[I32]("!@ Phase is now %s\n".cstring(), _phase.name().cstring())

  fun ref wait_for_connections(new_workers: Array[String] val,
    current_worker_count: USize)
  =>
    @printf[I32]("!@ wait_for_connections\n".cstring())
    _phase = _WaitingForConnections(this, new_workers, current_worker_count)
    @printf[I32]("!@ <><>Phase is now %s\n".cstring(), _phase.name().cstring())
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
    @printf[I32]("!@ Phase is now %s\n".cstring(), _phase.name().cstring())

  fun ref waiting_for_stop_the_world(joining_workers: Array[String] val) =>
    _phase = _WaitingForStopTheWorld(this, joining_workers)
    @printf[I32]("!@ Phase is now %s\n".cstring(), _phase.name().cstring())

  fun ref waiting_for_migration(joining_workers: Array[String] val) =>
    _phase = _WaitingForMigration(this, joining_workers)
    @printf[I32]("!@ Phase is now %s\n".cstring(), _phase.name().cstring())

  fun ref ready_for_join_migration() =>
    _phase.ready_for_join_migration()

  fun ref stop_the_world_for_join_migration_initiated(
    joining_workers: Array[String] val)
  =>
    _phase.stop_the_world_for_join_migration_initiated()

  fun ref join_migration_initiated(joining_workers: Array[String] val) =>
    _phase.join_migration_initiated()

  fun ref begin_join_migration(joining_workers: Array[String] val) =>
    _phase = _NonCoordinatorMigrationInProgress(this)
    @printf[I32]("!@ Phase is now %s\n".cstring(), _phase.name().cstring())
    _router_registry.begin_join_migration(joining_workers)

  fun ref initiate_stop_the_world_for_join_migration(joining_workers:
    Array[String] val)
  =>
    _phase = _CoordinatorMigrationInProgress(this, _auth)
    @printf[I32]("!@ Phase is now %s\n".cstring(), _phase.name().cstring())
    // TODO: For now, we're handing control of the join protocol over to
    // RouterRegistry at this point. Eventually, we should manage the
    // entire protocol.
    _router_registry.initiate_stop_the_world_for_grow_migration(
      joining_workers)

  fun ref stop_the_world_for_join_migration(joining_workers: Array[String] val)
  =>
    _phase = _WaitingForMigration(this, joining_workers)
    @printf[I32]("!@ Phase is now %s\n".cstring(), _phase.name().cstring())
    // TODO: For now, we're handing control of the join protocol over to
    // RouterRegistry at this point. Eventually, we should manage the
    // entire protocol.
    _router_registry.stop_the_world_for_grow_migration(joining_workers)

  fun ref prepare_shrink() =>
    _phase = _ShrinkInProgress(this)
    @printf[I32]("!@ Phase is now %s\n".cstring(), _phase.name().cstring())

  fun ref begin_leaving_migration() =>
    _phase = _ShrinkInProgress(this)
    @printf[I32]("!@ Phase is now %s\n".cstring(), _phase.name().cstring())

  fun ref autoscale_complete() =>
    @printf[I32]("!@ Calling autoscale_complete on phase %s\n".cstring(), _phase.name().cstring())
    _phase.autoscale_complete()

  fun ref mark_autoscale_complete() =>
    @printf[I32]("AUTOSCALE: Autoscale is complete.\n".cstring())
    _phase = _WaitingForAutoscale(this)
    @printf[I32]("!@ Phase is now %s\n".cstring(), _phase.name().cstring())

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
trait AutoscalePhase
  fun name(): String

  fun ref worker_join(conn: TCPConnection, worker: String,
    worker_count: USize, local_topology: LocalTopology,
    current_worker_count: USize)
  =>
    Fail()

  fun ref joining_worker_initialized(worker: String) =>
    Fail()
    // ifdef debug then
    //   @printf[I32](("Joining worker reported as initialized, but we're " +
    //     "not waiting for it. This should mean that either we weren't the " +
    //     "worker contacted for the join or we're also joining.\n").cstring())
    // end

  fun ref worker_connected_to_joining_workers(worker: String) =>
    Fail()

  fun ref stop_the_world_for_join_migration_initiated() =>
    Fail()

  fun ref join_migration_initiated() =>
    Fail()

  fun ref ready_for_join_migration() =>
    Fail()

  fun ref autoscale_complete() =>
    Fail()

class _EmptyAutoscalePhase is AutoscalePhase
  fun name(): String => "EmptyAutoscalePhase"

class _WaitingForAutoscale is AutoscalePhase
  let _autoscale: Autoscale ref

  new create(autoscale: Autoscale ref) =>
    @printf[I32]("AUTOSCALE: Waiting for any autoscale events\n".cstring())
    _autoscale = autoscale

  fun name(): String => "WaitingForAutoscale"

  fun ref worker_join(conn: TCPConnection, worker: String,
    worker_count: USize, local_topology: LocalTopology,
    current_worker_count: USize)
  =>
    _autoscale.wait_for_joiners(conn, worker, worker_count, local_topology,
      current_worker_count)

class _WaitingForJoiners is AutoscalePhase
  let _auth: AmbientAuth
  let _autoscale: Autoscale ref
  let _router_registry: RouterRegistry ref
  let _joining_worker_count: USize
  let _connected_joiners: SetIs[String] = _connected_joiners.create()
  let _initialized_workers: SetIs[String] = _initialized_workers.create()
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

class _WaitingForJoinerInitialization is AutoscalePhase
  let _autoscale: Autoscale ref
  let _joining_worker_count: USize
  var _initialized_joining_workers: SetIs[String]
  let _current_worker_count: USize

  new create(autoscale: Autoscale ref, joining_worker_count: USize,
    initialized_workers: SetIs[String], current_worker_count: USize)
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
      @printf[I32]("!@ WaitingForJoinerInitialization wait_for_connections\n".cstring())
      _autoscale.wait_for_connections(new_workers, _current_worker_count)
    end

class _WaitingForConnections is AutoscalePhase
  let _autoscale: Autoscale ref
  let _new_workers: Array[String] val
  let _connecting_worker_count: USize
  // Keeps track of new boundaries we set up to joining workers
  let _new_boundaries: SetIs[String] = _new_boundaries.create()
  // Keeps track of how many other workers have set up all new boundaries
  // to joining workers.
  let _connected_workers: SetIs[String] = _connected_workers.create()

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
    // if _connecting_worker_count == 0 then
    //   @printf[I32]("!@ Skipping to initiate_stop_the_world_for_grow_migration\n".cstring())
    //   // Single worker cluster. We're ready to migrate already.
    //   _autoscale.initiate_stop_the_world_for_join_migration(_new_workers)
    // else
    //   @printf[I32](("AUTOSCALE: Waiting for %s current workers to connect " +
    //     "to joining workers.\n").cstring(),
    //     _connecting_worker_count.string().cstring())
    // end

  fun name(): String => "WaitingForConnections"

  fun ref worker_connected_to_joining_workers(worker: String) =>
    """
    Indicates that another worker has connected to joining workers.
    """
    _connected_workers.set(worker)
    if _connected_workers.size() == _connecting_worker_count then
      _autoscale.initiate_stop_the_world_for_join_migration(_new_workers)
    end

class _WaitingToConnectToJoiners is AutoscalePhase
  let _auth: AmbientAuth
  let _autoscale: Autoscale ref
  let _worker_name: String
  let _joining_workers: Array[String] val
  let _coordinator: String
  let _new_boundaries: SetIs[String] = _new_boundaries.create()

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

class _WaitingForStopTheWorld is AutoscalePhase
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

class _WaitingForMigration is AutoscalePhase
  let _autoscale: Autoscale ref
  let _joining_workers: Array[String] val
  var _ready_for_migration: Bool = false
  var _migration_initiated: Bool = false

  new create(autoscale: Autoscale ref, joining_workers: Array[String] val) =>
    _autoscale = autoscale
    _joining_workers = joining_workers
    @printf[I32]("AUTOSCALE: Waiting for signal to begin migration\n"
      .cstring())

  fun name(): String => "WaitingForMigration"

  fun ref join_migration_initiated() =>
    _migration_initiated = true
    if _ready_for_migration then
      _autoscale.begin_join_migration(_joining_workers)
    end

  fun ref ready_for_join_migration() =>
    _ready_for_migration = true
    if _migration_initiated then
      _autoscale.begin_join_migration(_joining_workers)
    end

class _JoiningWorker is AutoscalePhase
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

  fun ref ready_for_join_migration() =>
    None

  fun ref autoscale_complete() =>
    _autoscale.mark_autoscale_complete()

class _CoordinatorMigrationInProgress is AutoscalePhase
  """
  During this phase, we've handed off responsibility for autoscale migration to
  the RouterRegistry.
  """
  let _autoscale: Autoscale ref
  let _auth: AmbientAuth

  new create(autoscale: Autoscale ref, auth: AmbientAuth) =>
    @printf[I32]("AUTOSCALE: Coordinator -> Migration in progress.\n"
      .cstring())
    _autoscale = autoscale
    _auth = auth

  fun name(): String => "CoordinatorMigrationInProgress"

  fun ref autoscale_complete() =>
    try
      let msg = ChannelMsgEncoder.autoscale_complete(_auth)?
      _autoscale.send_control_to_cluster(msg)
    else
      Fail()
    end
    _autoscale.mark_autoscale_complete()

class _NonCoordinatorMigrationInProgress is AutoscalePhase
  """
  During this phase, we've handed off responsibility for autoscale migration to
  the RouterRegistry.
  """
  let _autoscale: Autoscale ref

  new create(autoscale: Autoscale ref) =>
    @printf[I32]("AUTOSCALE: Migration in progress.\n".cstring())
    _autoscale = autoscale

  fun name(): String => "NonCoordinatorMigrationInProgress"

  fun ref autoscale_complete() =>
    _autoscale.mark_autoscale_complete()

class _ShrinkInProgress is AutoscalePhase
  let _autoscale: Autoscale ref

  new create(autoscale: Autoscale ref) =>
    _autoscale = autoscale

  fun name(): String => "ShrinkInProgress"

  fun ref autoscale_complete() =>
    _autoscale.mark_autoscale_complete()
