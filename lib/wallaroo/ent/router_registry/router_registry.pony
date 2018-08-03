/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "collections"
use "net"
use "promises"
use "time"
use "wallaroo"
use "wallaroo/core/boundary"
use "wallaroo/core/common"
use "wallaroo/core/data_channel"
use "wallaroo/core/initialization"
use "wallaroo/core/invariant"
use "wallaroo/core/messages"
use "wallaroo/core/metrics"
use "wallaroo/core/routing"
use "wallaroo/core/source"
use "wallaroo/core/topology"
use "wallaroo/ent/autoscale"
use "wallaroo/ent/barrier"
use "wallaroo/ent/data_receiver"
use "wallaroo/ent/network"
use "wallaroo/ent/recovery"
use "wallaroo/ent/snapshot"
use "wallaroo_labs/collection_helpers"
use "wallaroo_labs/messages"
use "wallaroo_labs/mort"
use "wallaroo_labs/query"

//!@ clean this up
type _TargetIdRouterUpdatable is Step

type _RouterSub is (BoundaryUpdatable & RouterUpdatable)

actor RouterRegistry
  let _self: RouterRegistry tag = this

  let _id: RoutingId
  let _auth: AmbientAuth
  let _data_receivers: DataReceivers
  let _worker_name: String
  let _connections: Connections
  let _state_step_creator: StateStepCreator
  let _recovery_file_cleaner: RecoveryFileCleaner
  let _barrier_initiator: BarrierInitiator
  let _snapshot_initiator: SnapshotInitiator
  let _autoscale_initiator: AutoscaleInitiator
  var _data_router: DataRouter
  var _pre_state_data: (Array[PreStateData] val | None) = None
  let _partition_routers: Map[String, PartitionRouter] =
    _partition_routers.create()
  let _stateless_partition_routers: Map[U128, StatelessPartitionRouter] =
    _stateless_partition_routers.create()
  let _data_receiver_map: Map[String, DataReceiver] =
    _data_receiver_map.create()

  //!@
  // TODO: Remove this. This is here to be threaded to joining workers as
  // the primary snapshot initiator worker. We need to enable this role to
  // shift to other workers, and this means we need our SnapshotInitiator
  // to add to the information we send to a joining worker (since it will
  // know who the primary snapshot worker is).
  let _initializer_name: String

  var _local_topology_initializer: (LocalTopologyInitializer | None) = None

  // Map from state name to router for use on the corresponding state steps
  var _target_id_routers: Map[String, TargetIdRouter] =
    _target_id_routers.create()

  var _application_ready_to_work: Bool = false

  ////////////////
  // Subscribers
  // All steps that have a PartitionRouter, registered by partition
  // state name
  let _partition_router_subs: Map[String, SetIs[_RouterSub]] =
    _partition_router_subs.create()
  // All steps that have a StatelessPartitionRouter, registered by
  // partition id
  let _stateless_partition_router_subs:
    Map[U128, SetIs[_RouterSub]] =
      _stateless_partition_router_subs.create()
  // All steps that have a TargetIdRouter (state steps), registered by state
  // name. The StateStepCreator is also registered here.
  let _target_id_router_updatables:
    Map[String, SetIs[_TargetIdRouterUpdatable]] =
      _target_id_router_updatables.create()

  // For anyone who wants to know about every target_id_router
  //!@ clean this up
  let _all_target_id_router_subs: SetIs[StateStepCreator] =
    _all_target_id_router_subs.create()

  // Certain TargetIdRouters need to keep track of changes to particular
  // stateless partition routers. This is true when a state step needs to
  // route outputs to a stateless partition. Map is from partition id to
  // state name of state steps that need to know.
  let _stateless_partition_routers_router_subs:
    Map[U128, _StringSet] =
    _stateless_partition_routers_router_subs.create()
  //
  ////////////////

  let _sources: Map[RoutingId, Source] = _sources.create()
  let _source_listeners: SetIs[SourceListener] = _source_listeners.create()
  // Map from Source digestof value to source id
  let _source_ids: Map[USize, RoutingId] = _source_ids.create()
  let _data_channel_listeners: SetIs[DataChannelListener] =
    _data_channel_listeners.create()
  let _control_channel_listeners: SetIs[TCPListener] =
    _control_channel_listeners.create()
  let _data_channels: SetIs[DataChannel] = _data_channels.create()
  // Boundary builders are used by new TCPSources to create their own
  // individual boundaries to other workers (to allow for increased
  // throughput).
  let _outgoing_boundaries_builders: Map[String, OutgoingBoundaryBuilder] =
    _outgoing_boundaries_builders.create()
  let _outgoing_boundaries: Map[String, OutgoingBoundary] =
    _outgoing_boundaries.create()

  //////
  // Partition Migration
  //////
  var _autoscale: (Autoscale | None) = None

  var _stop_the_world_in_process: Bool = false

  // TODO: Add management of pending steps to Autoscale protocol class
  // Steps migrated out and waiting for acknowledgement
  let _step_waiting_list: SetIs[U128] = _step_waiting_list.create()

  // Workers in running cluster that have been stopped for stop the world
  let _stopped_worker_waiting_list: _StringSet =
    _stopped_worker_waiting_list.create()

  // TODO: Move management of this list to Autoscale class
  var _leaving_workers: Array[String] val = recover Array[String] end

  // Used as a proxy for RouterRegistry when muting and unmuting sources
  // and data channel.
  // TODO: Probably change mute()/unmute() interface so we don't need this
  let _dummy_consumer: DummyConsumer = DummyConsumer

  var _stop_the_world_pause: U64

  var _waiting_to_finish_join: Bool = false

  var _event_log: (EventLog | None) = None

  var _initiated_stop_the_world: Bool = false

  // If this is a worker that joined during an autoscale event, then there
  // is one worker we contacted to join.
  let _contacted_worker: (String | None)

  new create(auth: AmbientAuth, worker_name: String,
    data_receivers: DataReceivers, c: Connections,
    state_step_creator: StateStepCreator,
    recovery_file_cleaner: RecoveryFileCleaner, stop_the_world_pause: U64,
    is_joining: Bool, initializer_name: String,
    barrier_initiator: BarrierInitiator,
    snapshot_initiator: SnapshotInitiator,
    autoscale_initiator: AutoscaleInitiator,
    contacted_worker: (String | None) = None)
  =>
    _auth = auth
    _worker_name = worker_name
    _data_receivers = data_receivers
    _connections = c
    _state_step_creator = state_step_creator
    _state_step_creator.set_router_registry(this)
    _all_target_id_router_subs.set(_state_step_creator)
    _recovery_file_cleaner = recovery_file_cleaner
    _barrier_initiator = barrier_initiator
    _snapshot_initiator = snapshot_initiator
    _autoscale_initiator = autoscale_initiator
    _stop_the_world_pause = stop_the_world_pause
    _connections.register_disposable(this)
    _id = (digestof this).u128()
    _data_receivers.set_router_registry(this)
    _contacted_worker = contacted_worker
    _data_router = DataRouter(_worker_name,
      recover Map[RoutingId, Consumer] end,
      recover LocalStatePartitions end, recover LocalStatePartitionIds end,
      recover Map[RoutingId, StateName] end)
    _initializer_name = initializer_name
    _autoscale = Autoscale(_auth, _worker_name, this, _connections, is_joining)

  fun _worker_count(): USize =>
    _outgoing_boundaries.size() + 1

  be dispose() =>
    None

  be application_ready_to_work() =>
    _application_ready_to_work = true

  be set_data_router(dr: DataRouter) =>
    _data_router = dr
    _distribute_data_router()

  be set_pre_state_data(psd: Array[PreStateData] val) =>
    _pre_state_data = psd

  be set_partition_router(state_name: String, pr: PartitionRouter) =>
    _partition_routers(state_name) = pr

  be set_stateless_partition_router(partition_id: U128,
    pr: StatelessPartitionRouter)
  =>
    _stateless_partition_routers(partition_id) = pr

  be set_target_id_router(state_name: String, t: TargetIdRouter) =>
    _set_target_id_router(state_name, t)

  fun ref _set_target_id_router(state_name: String, t: TargetIdRouter) =>
    var new_router = t.update_boundaries(_outgoing_boundaries)
    for id in new_router.stateless_partition_ids().values() do
      try
        _stateless_partition_routers_router_subs.insert_if_absent(id,
          _StringSet)?
        _stateless_partition_routers_router_subs(id)?.set(state_name)
      else
        Fail()
      end
    end
    _target_id_routers(state_name) = new_router
    _distribute_target_id_router(state_name)

  be set_event_log(e: EventLog) =>
    _event_log = e

  be register_local_topology_initializer(lt: LocalTopologyInitializer) =>
    _local_topology_initializer = lt

  // TODO: We need a new approach to registering all disposable actors.
  // This is a stopgap to register boundaries generated by a Source.
  // See issue #1411.
  be register_disposable(d: DisposableActor) =>
    _connections.register_disposable(d)

  be register_source(source: Source, source_id: RoutingId) =>
    _sources(source_id) = source
    _source_ids(digestof source) = source_id
    _barrier_initiator.register_source(source, source_id)

    if not _stop_the_world_in_process and _application_ready_to_work then
      source.unmute(_dummy_consumer)
    end
    _connections.register_disposable(source)
    _connections.notify_cluster_of_new_source(source_id)

  be unregister_source(source: Source, source_id: RoutingId) =>
    try
      _sources.remove(source_id)?
      _source_ids.remove(digestof source)?
      _barrier_initiator.unregister_source(source, source_id)
       _connections.register_disposable(source)
      // _connections.notify_cluster_of_source_leaving(source_id)
    else
      Fail()
    end

  be register_remote_source(sender: String, source_id: RoutingId) =>
    None

  be register_source_listener(source_listener: SourceListener) =>
    _source_listeners.set(source_listener)
    _connections.register_disposable(source_listener)

  be register_data_channel_listener(dchl: DataChannelListener) =>
    _data_channel_listeners.set(dchl)
    if _waiting_to_finish_join and
      (_control_channel_listeners.size() != 0)
    then
      _inform_contacted_worker_of_initialization()
      _waiting_to_finish_join = false
    end

  be register_control_channel_listener(cchl: TCPListener) =>
    _control_channel_listeners.set(cchl)
    if _waiting_to_finish_join and
      (_data_channel_listeners.size() != 0)
    then
      _inform_contacted_worker_of_initialization()
      _waiting_to_finish_join = false
    end

  be register_data_channel(dc: DataChannel) =>
    // TODO: These need to be unregistered if they close
    _data_channels.set(dc)

  be register_partition_router_subscriber(state_name: String,
    sub: _RouterSub)
  =>
    _register_partition_router_subscriber(state_name, sub)

  fun ref _register_partition_router_subscriber(state_name: String,
    sub: _RouterSub)
  =>
    try
      _partition_router_subs.insert_if_absent(state_name,
        SetIs[_RouterSub])?
      _partition_router_subs(state_name)?.set(sub)
    else
      Fail()
    end

  be unregister_partition_router_subscriber(state_name: String,
    sub: _RouterSub)
  =>
    Invariant(_partition_router_subs.contains(state_name))
    try
      _partition_router_subs(state_name)?.unset(sub)
    else
      Fail()
    end

  be register_stateless_partition_router_subscriber(partition_id: U128,
    sub: _RouterSub)
  =>
    _register_stateless_partition_router_subscriber(partition_id, sub)

  fun ref _register_stateless_partition_router_subscriber(
    partition_id: U128, sub: _RouterSub)
  =>
    try
      if _stateless_partition_router_subs.contains(partition_id) then
        _stateless_partition_router_subs(partition_id)?.set(sub)
      else
        _stateless_partition_router_subs(partition_id) =
          SetIs[_RouterSub]
        _stateless_partition_router_subs(partition_id)?.set(sub)
      end
    else
      Fail()
    end

  be unregister_stateless_partition_router_subscriber(partition_id: U128,
    sub: _RouterSub)
  =>
    Invariant(_stateless_partition_router_subs.contains(partition_id))
    try
      _stateless_partition_router_subs(partition_id)?.unset(sub)
    else
      Fail()
    end

  be register_target_id_router_updatable(state_name: String,
    sub: _TargetIdRouterUpdatable)
  =>
    _register_target_id_router_updatable(state_name, sub)

  fun ref _register_target_id_router_updatable(state_name: String,
    sub: _TargetIdRouterUpdatable)
  =>
    try
      _target_id_router_updatables.insert_if_absent(state_name,
        SetIs[_TargetIdRouterUpdatable])?
      _target_id_router_updatables(state_name)?.set(sub)
    else
      Fail()
    end
    if _target_id_routers.contains(state_name) then
      try
        let target_id_router = _target_id_routers(state_name)?
        sub.update_target_id_router(target_id_router)
      else
        Unreachable()
      end
    end

  be register_boundaries(bs: Map[String, OutgoingBoundary] val,
    bbs: Map[String, OutgoingBoundaryBuilder] val)
  =>
    // Boundaries
    let new_boundaries = recover trn Map[String, OutgoingBoundary] end
    for (worker, boundary) in bs.pairs() do
      if not _outgoing_boundaries.contains(worker) then
        _outgoing_boundaries(worker) = boundary
        new_boundaries(worker) = boundary
      end
    end
    let new_boundaries_sendable: Map[String, OutgoingBoundary] val =
      consume new_boundaries

    for producers in _partition_router_subs.values() do
      for producer in producers.values() do
        match producer
        | let s: Step =>
          s.add_boundaries(new_boundaries_sendable)
        end
      end
    end
    for producers in _stateless_partition_router_subs.values() do
      for producer in producers.values() do
        match producer
        | let s: Step =>
          s.add_boundaries(new_boundaries_sendable)
        end
      end
    end
    for updatables in _target_id_router_updatables.values() do
      for updatable in updatables.values() do
        updatable.add_boundaries(new_boundaries_sendable)
      end
    end
    for step in _data_router.routes().values() do
      match step
      | let s: Step => s.add_boundaries(new_boundaries_sendable)
      end
    end

    // Boundary builders
    let new_boundary_builders =
      recover trn Map[String, OutgoingBoundaryBuilder] end
    for (worker, builder) in bbs.pairs() do
      // Boundary builders should always be registered after the canonical
      // boundary for each builder. The canonical is used on all Steps.
      // Sources use the builders to create a new boundary per source
      // connection.
      if not _outgoing_boundaries.contains(worker) then
        Fail()
      end
      if not _outgoing_boundaries_builders.contains(worker) then
        _outgoing_boundaries_builders(worker) = builder
        new_boundary_builders(worker) = builder
      end
    end

    let new_boundary_builders_sendable:
      Map[String, OutgoingBoundaryBuilder] val =
        consume new_boundary_builders

    for source_listener in _source_listeners.values() do
      source_listener.add_boundary_builders(new_boundary_builders_sendable)
    end

    for source in _sources.values() do
      source.add_boundary_builders(new_boundary_builders_sendable)
    end

  be register_data_receiver(worker: String, dr: DataReceiver) =>
    _data_receiver_map(worker) = dr

  be register_state_step(step: Step, state_name: String, key: Key,
    step_id: RoutingId)
  =>
    _add_routes_to_state_step(step_id, step, key, state_name)

  fun _distribute_data_router() =>
    _data_receivers.update_data_router(_data_router)

  fun ref _distribute_target_id_router(state_name: String) =>
    """
    Distribute the TargetIdRouter used by state steps corresponding to state
    name.
    """
    try
      let target_id_router = _target_id_routers(state_name)?
      _target_id_router_updatables.insert_if_absent(state_name,
        SetIs[_TargetIdRouterUpdatable])?

      for updatable in _target_id_router_updatables(state_name)?.values() do
        updatable.update_target_id_router(target_id_router)
      end

      for sub in _all_target_id_router_subs.values() do
        sub.update_target_id_router(state_name, target_id_router)
      end

      match _local_topology_initializer
      | let lti: LocalTopologyInitializer =>
        lti.update_target_id_router(state_name, target_id_router)
      else
        Fail()
      end
    else
      Fail()
    end

  fun ref _distribute_partition_router(partition_router: PartitionRouter) =>
    let state_name = partition_router.state_name()

    try
      _partition_router_subs.insert_if_absent(state_name,
        SetIs[_RouterSub])?
      for sub in _partition_router_subs(state_name)?.values() do
        sub.update_router(partition_router)
      end
    else
      Fail()
    end

  fun ref _distribute_stateless_partition_router(
    partition_router: StatelessPartitionRouter)
  =>
    let partition_id = partition_router.partition_id()

    try
      if not _stateless_partition_router_subs.contains(partition_id) then
        _stateless_partition_router_subs(partition_id) =
          SetIs[_RouterSub]
      end
      for sub in
        _stateless_partition_router_subs(partition_id)?.values()
      do
        sub.update_router(partition_router)
      end
    else
      Fail()
    end

    if _stateless_partition_routers_router_subs.contains(partition_id) then
      try
        let state_names =
          _stateless_partition_routers_router_subs(partition_id)?
        for state_name in state_names.values() do
          try
            let target_id_router = _target_id_routers(state_name)?
            _target_id_routers(state_name) = target_id_router.
              update_stateless_partition_router(partition_id, partition_router)
            _distribute_target_id_router(state_name)
          else
            // We should have already registered this TargetIdRouter at startup
            Fail()
          end
        end
      else
        Unreachable()
      end
    end

  fun ref _remove_worker(worker: String) =>
    try
      _data_receiver_map.remove(worker)?
    else
      Fail()
    end
    _distribute_boundary_removal(worker)

  fun ref _distribute_boundary_removal(worker: String) =>
    for subs in _partition_router_subs.values() do
      for sub in subs.values() do
        match sub
        | let r: BoundaryUpdatable =>
          r.remove_boundary(worker)
        end
      end
    end
    for subs in _stateless_partition_router_subs.values() do
      for sub in subs.values() do
        match sub
        | let r: BoundaryUpdatable =>
          r.remove_boundary(worker)
        end
      end
    end
    for updatables in _target_id_router_updatables.values() do
      for updatable in updatables.values() do
        updatable.remove_boundary(worker)
      end
    end

    for source in _sources.values() do
      source.remove_boundary(worker)
    end
    for source_listener in _source_listeners.values() do
      source_listener.remove_boundary(worker)
    end

    match _local_topology_initializer
    | let lt: LocalTopologyInitializer =>
      lt.remove_boundary(worker)
    else
      Fail()
    end

  fun _distribute_boundary_builders() =>
    let boundary_builders =
      recover trn Map[String, OutgoingBoundaryBuilder] end
    for (worker, builder) in _outgoing_boundaries_builders.pairs() do
      boundary_builders(worker) = builder
    end

    let boundary_builders_to_send = consume val boundary_builders

    for source_listener in _source_listeners.values() do
      source_listener.update_boundary_builders(boundary_builders_to_send)
    end

  be create_partition_routers_from_blueprints(workers: Array[String] val,
    partition_blueprints: Map[String, PartitionRouterBlueprint] val)
  =>
    let obs_trn = recover trn Map[String, OutgoingBoundary] end
    for (w, ob) in _outgoing_boundaries.pairs() do
      obs_trn(w) = ob
    end
    let obs = consume val obs_trn
    for (s, b) in partition_blueprints.pairs() do
      let next_router = b.build_router(_worker_name, workers, obs, _auth)
      _distribute_partition_router(next_router)
      _partition_routers(s) = next_router
    end

  be create_stateless_partition_routers_from_blueprints(
    partition_blueprints: Map[U128, StatelessPartitionRouterBlueprint] val)
  =>
    let obs_trn = recover trn Map[String, OutgoingBoundary] end
    for (w, ob) in _outgoing_boundaries.pairs() do
      obs_trn(w) = ob
    end
    let obs = consume val obs_trn
    for (id, b) in partition_blueprints.pairs() do
      let next_router = b.build_router(_worker_name, obs, _auth)
      _distribute_stateless_partition_router(next_router)
      _stateless_partition_routers(id) = next_router
    end

  be create_target_id_routers_from_blueprint(
    target_id_router_blueprints: Map[String, TargetIdRouterBlueprint] val,
    local_sinks: Map[RoutingId, Consumer] val,
    lti: LocalTopologyInitializer)
  =>
    let obs_trn = recover trn Map[String, OutgoingBoundary] end
    for (w, ob) in _outgoing_boundaries.pairs() do
      obs_trn(w) = ob
    end
    let obs = consume val obs_trn
    for (state_name, tidr) in target_id_router_blueprints.pairs() do
      let new_target_id_router = tidr.build_router(_worker_name, obs,
        local_sinks, _auth)
      _set_target_id_router(state_name, new_target_id_router)
      lti.update_target_id_router(state_name, new_target_id_router)
    end
    lti.initialize_join_initializables()

  be report_status(code: ReportStatusCode) =>
    match code
    | BoundaryCountStatus =>
      @printf[I32]("RouterRegistry knows about %s boundaries\n"
        .cstring(), _outgoing_boundaries.size().string().cstring())
    end
    for source in _sources.values() do
      source.report_status(code)
    end
    for boundary in _outgoing_boundaries.values() do
      boundary.report_status(code)
    end

  fun ref clean_shutdown() =>
    _recovery_file_cleaner.clean_recovery_files()

  /////////////////////////////////////////////////////////////////////////////
  // STOP THE WORLD
  /////////////////////////////////////////////////////////////////////////////
  fun ref initiate_stop_the_world() =>
    _initiated_stop_the_world = true
    _stop_the_world_in_process = true

  fun ref initiate_stop_the_world_for_grow_migration(
    new_workers: Array[String] val)
  =>
    initiate_stop_the_world()
    try
      let msg = ChannelMsgEncoder.initiate_stop_the_world_for_join_migration(
        new_workers, _auth)?
      _connections.send_control_to_cluster_with_exclusions(msg, new_workers)
    else
      Fail()
    end
    _stop_the_world_for_grow_migration(new_workers)
    @printf[I32]("!@ setting up migration action\n".cstring())

    let action = Promise[None]
    action.next[None]({(_: None) =>
      _self.initiate_join_migration(new_workers)})
    _autoscale_initiator.initiate_autoscale(action)

  fun ref stop_the_world_for_grow_migration(new_workers: Array[String] val) =>
    """
    Called when new workers join the cluster and we are ready to start
    the partition migration process. We first check that all
    in-flight messages have finished processing.
    """
    _stop_the_world_in_process = true
    _stop_the_world_for_grow_migration(new_workers)

  fun ref _stop_the_world_for_grow_migration(new_workers: Array[String] val) =>
    """
    We currently stop all message processing before migrating partitions and
    updating routers/routes.
    """
    @printf[I32]("~~~Stopping message processing for state migration.~~~\n"
      .cstring())
    _mute_request(_worker_name)
    _connections.stop_the_world(new_workers)

  fun ref _stop_the_world_for_shrink_migration() =>
    """
    We currently stop all message processing before migrating partitions and
    updating routers/routes.
    """
    @printf[I32]("~~~Stopping message processing for leaving workers.~~~\n"
      .cstring())
    _mute_request(_worker_name)
    _connections.stop_the_world()

  fun ref _try_resume_the_world() =>
    @printf[I32]("!@ _try_resume_the_world\n".cstring())
    if _initiated_stop_the_world then
      //!@ Do we need this here? We don't know the state name anymore.
      // Since we don't need all steps to be up to date on the TargetIdRouter
      // during migrations, we wait on the worker that initiated stop the
      // world to distribute it until here to avoid unnecessary messaging.
      // _distribute_target_id_router()

      let action = Promise[None]
      action.next[None]({(_: None) => _self.initiate_autoscale_complete()})
      _autoscale_initiator.initiate_autoscale_resume_acks(action)

      // We are done with this round of leaving workers
      _leaving_workers = recover Array[String] end
    else
      @printf[I32]("!@ but I didn't initiate\n".cstring())
    end

  be resume_the_world(initiator: String) =>
    """
    Stop the world is complete and we're ready to resume message processing
    """
    _resume_the_world(initiator)

  fun ref _resume_the_world(initiator: String) =>
    _initiated_stop_the_world = false
    _stop_the_world_in_process = false
    _resume_all_local()
    @printf[I32]("~~~Resuming message processing.~~~\n".cstring())

  be remote_mute_request(originating_worker: String) =>
    """
    A remote worker requests that we mute all sources and data channel.
    """
    _mute_request(originating_worker)

  fun ref _mute_request(originating_worker: String) =>
    _stopped_worker_waiting_list.set(originating_worker)
    _stop_all_local()

  be remote_unmute_request(originating_worker: String) =>
    """
    A remote worker requests that we unmute all sources and data channel.
    """
    _unmute_request(originating_worker)

  fun ref _unmute_request(originating_worker: String) =>
    if _stopped_worker_waiting_list.size() > 0 then
      _stopped_worker_waiting_list.unset(originating_worker)
      if (_stopped_worker_waiting_list.size() == 0) then
        _try_resume_the_world()
      end
    end

  fun _stop_all_local() =>
    """
    Mute all sources and data channel.
    """
    ifdef debug then
      @printf[I32]("RouterRegistry muting any local sources.\n".cstring())
    end
    for source in _sources.values() do
      source.mute(_dummy_consumer)
    end

  fun _resume_all_local() =>
    """
    Unmute all sources and data channel.
    """
    ifdef debug then
      @printf[I32]("RouterRegistry unmuting any local sources.\n".cstring())
    end
    for source in _sources.values() do
      source.unmute(_dummy_consumer)
    end

  fun _resume_all_remote() =>
    try
      let msg = ChannelMsgEncoder.resume_the_world(_worker_name, _auth)?
      _connections.send_control_to_cluster(msg)
    else
      Fail()
    end

  fun ref try_to_resume_processing_immediately() =>
    if _step_waiting_list.size() == 0 then
      try
        (_autoscale as Autoscale).all_step_migration_complete()
      else
        Fail()
      end
    end

  /////////////////////////////////////////////////////////////////////////////
  // JOINING WORKER
  /////////////////////////////////////////////////////////////////////////////
  be worker_join(conn: TCPConnection, worker: String,
    worker_count: USize, local_topology: LocalTopology,
    current_worker_count: USize)
  =>
    try
      (_autoscale as Autoscale).worker_join(conn, worker, worker_count,
        local_topology, current_worker_count)
    else
      Fail()
    end

  be connect_to_joining_workers(ws: Array[String] val, coordinator: String) =>
    try
      (_autoscale as Autoscale).connect_to_joining_workers(ws, coordinator)
    else
      Fail()
    end

  be joining_worker_initialized(worker: String) =>
    try
      (_autoscale as Autoscale).joining_worker_initialized(worker)
    else
      Fail()
    end

  fun inform_joining_worker(conn: TCPConnection, worker: String,
    local_topology: LocalTopology)
  =>
    let state_blueprints =
      recover iso Map[String, PartitionRouterBlueprint] end
    for (w, r) in _partition_routers.pairs() do
      state_blueprints(w) = r.blueprint()
    end

    let stateless_blueprints =
      recover iso Map[U128, StatelessPartitionRouterBlueprint] end
    for (id, r) in _stateless_partition_routers.pairs() do
      stateless_blueprints(id) = r.blueprint()
    end

    let tidr_blueprints = recover iso Map[String, TargetIdRouterBlueprint] end
    for (state_name, tidr) in _target_id_routers.pairs() do
      tidr_blueprints(state_name) = tidr.blueprint()
    end

    _connections.inform_joining_worker(conn, worker, local_topology,
      _initializer_name, consume state_blueprints,
      consume stateless_blueprints, consume tidr_blueprints)

  be inform_contacted_worker_of_initialization() =>
    _inform_contacted_worker_of_initialization()

  fun ref _inform_contacted_worker_of_initialization() =>
    match _contacted_worker
    | let cw: String =>
      if (_data_channel_listeners.size() != 0) and
         (_control_channel_listeners.size() != 0)
      then
        _connections.inform_contacted_worker_of_initialization(cw)
      else
        _waiting_to_finish_join = true
      end
    else
      Fail()
    end

  be inform_worker_of_boundary_count(target_worker: String) =>
    // There is one boundary per source plus the canonical boundary
    let count = _sources.size() + 1
    _connections.inform_worker_of_boundary_count(target_worker, count)

  be reconnect_source_boundaries(target_worker: String) =>
    for source in _sources.values() do
      source.reconnect_boundary(target_worker)
    end

  /////////////////////////////////////////////////////////////////////////////
  // NEW WORKER PARTITION MIGRATION
  /////////////////////////////////////////////////////////////////////////////
  be report_connected_to_joining_worker(connected_worker: String) =>
    try
      (_autoscale as Autoscale).worker_connected_to_joining_workers(
        connected_worker)
    else
      Fail()
    end

  be remote_stop_the_world_for_join_migration_request(
    joining_workers: Array[String] val)
  =>
    """
    Only one worker is contacted by all joining workers to indicate that a
    join is requested. That worker, when it's ready to stop the world in
    preparation for migration, sends a message to all other current workers,
    telling them to it's time to stop the world. This behavior is called when
    that message is received.
    """
    try
      (_autoscale as Autoscale).stop_the_world_for_join_migration_initiated(
        joining_workers)
    else
      Fail()
    end

  be remote_join_migration_request(joining_workers: Array[String] val) =>
    """
    Only one worker is contacted by all joining workers to indicate that a
    join is requested. That worker, when it's ready to begin step migration,
    then sends a message to all other current workers, telling them to begin
    migration to the joining workers as well. This behavior is called when
    that message is received.
    """
    if not ArrayHelpers[String].contains[String](joining_workers, _worker_name)
    then
      try
        (_autoscale as Autoscale).join_migration_initiated(joining_workers)
      else
        Fail()
      end
    end

  be initiate_autoscale_complete() =>
    try
      (_autoscale as Autoscale).autoscale_complete()
    else
      Fail()
    end
    _resume_all_remote()
    _resume_the_world(_worker_name)

  be autoscale_complete() =>
    try
      (_autoscale as Autoscale).autoscale_complete()
    else
      Fail()
    end

  be initiate_join_migration(target_workers: Array[String] val) =>
    @printf[I32]("!@ initiate_join_migration\n".cstring())
    // Update BarrierInitiator about new workers
    for w in target_workers.values() do
      _barrier_initiator.add_worker(w)
      _snapshot_initiator.add_worker(w)
    end

    // Inform other current workers to begin migration
    try
      let msg =
        ChannelMsgEncoder.initiate_join_migration(target_workers, _auth)?
      _connections.send_control_to_cluster_with_exclusions(msg, target_workers)
    else
      Fail()
    end
    begin_join_migration(target_workers)

  fun ref begin_join_migration(target_workers: Array[String] val) =>
    """
    Begin partition migration to joining workers
    """
    if _partition_routers.size() == 0 then
      //no steps have been migrated
      @printf[I32](("Resuming message processing immediately. No partitions " +
        "to migrate.\n").cstring())
      _resume_the_world(_worker_name)
    end
    @printf[I32]("!@ begin_join_migration to %s workers\n".cstring(), target_workers.size().string().cstring())
    for w in target_workers.values() do
      @printf[I32]("Migrating partitions to %s\n".cstring(), w.cstring())
    end
    var had_steps_to_migrate = false
    for state_name in _partition_routers.keys() do
      let had_steps_to_migrate_for_this_state =
        _migrate_partition_steps(state_name, target_workers)
      if had_steps_to_migrate_for_this_state then
        had_steps_to_migrate = true
      end
    end
    if not had_steps_to_migrate then
      try_to_resume_processing_immediately()
    end

  be step_migration_complete(step_id: RoutingId) =>
    """
    Step with provided step id has been created on another worker.
    """
    _step_waiting_list.unset(step_id)
    if (_step_waiting_list.size() == 0) then
      try
        (_autoscale as Autoscale).all_step_migration_complete()
      else
        Fail()
      end
    end

  fun send_migration_batch_complete_msg(target: String) =>
    """
    Inform migration target that the entire migration batch has been sent.
    """
    try
      _outgoing_boundaries(target)?.send_migration_batch_complete()
    else
      Fail()
    end

  be process_migrating_target_ack(target: String) =>
    """
    Called when we receive a migration batch ack from the new worker
    (i.e. migration target) indicating it's ready to receive data messages
    """
    @printf[I32]("--Processing migration batch complete ack from %s\n"
      .cstring(), target.cstring())
    try
      (_autoscale as Autoscale).receive_join_migration_ack(target)
    else
      Fail()
    end

  fun ref all_join_migration_acks_received(joining_workers: Array[String] val,
    is_coordinator: Bool)
  =>
    if is_coordinator then
      let hash_partitions_trn = recover trn Map[String, HashPartitions] end
      for (state_name, pr) in _partition_routers.pairs() do
        hash_partitions_trn(state_name) = pr.hash_partitions()
      end
      let hash_partitions = consume val hash_partitions_trn
      try
        let msg = ChannelMsgEncoder.announce_hash_partitions_grow(_worker_name,
          joining_workers, hash_partitions, _auth)?
        for w in joining_workers.values() do
          _connections.send_control(w, msg)
        end
      else
        Fail()
      end
    end
    _connections.request_cluster_unmute()
    _unmute_request(_worker_name)

  be update_partition_routers_after_grow(joining_workers: Array[String] val,
    hash_partitions: Map[String, HashPartitions] val)
  =>
    """
    Called on joining workers after migration is complete and they've been
    informed of all hash partitions.
    """
    for (state_name, pr) in _partition_routers.pairs() do
      var new_pr = pr.update_boundaries(_auth, _outgoing_boundaries)
      try
        new_pr = new_pr.update_hash_partitions(hash_partitions(state_name)?)
        _distribute_partition_router(new_pr)
        _partition_routers(state_name) = new_pr
      else
        Fail()
      end
    end

  be ack_migration_batch_complete(sender_name: String) =>
    """
    Called when a new (joining) worker needs to ack to worker sender_name that
    it's ready to start receiving messages after migration
    """
    _connections.ack_migration_batch_complete(sender_name)

  fun ref _migrate_partition_steps(state_name: String,
    target_workers: Array[String] val): Bool
  =>
    """
    Called to initiate migrating partition steps to a target worker in order
    to rebalance. Return false if there were no steps to migrate.
    """
    try
      for w in target_workers.values() do
        @printf[I32]("Migrating steps for %s partition to %s\n".cstring(),
          state_name.cstring(), w.cstring())
      end

      let sorted_target_workers =
        ArrayHelpers[String].sorted[String](target_workers)

      let tws = recover trn Array[(String, OutgoingBoundary)] end
      for w in sorted_target_workers.values() do
        let boundary = _outgoing_boundaries(w)?
        tws.push((w, boundary))
      end
      let partition_router = _partition_routers(state_name)?
      // Simultaneously calculate new partition router and initiate individual
      // step migration. We get the new router back as well as a Bool
      // indicating whether any steps were migrated.
      (let new_partition_router, let had_steps_to_migrate) =
        partition_router.rebalance_steps_grow(_auth, consume tws, this)
      // TODO: It could be if had_steps_to_migrate is false then we don't
      // need to distribute the router because it didn't change. Investigate.
      _distribute_partition_router(new_partition_router)
      _partition_routers(state_name) = new_partition_router
      had_steps_to_migrate
    else
      Fail()
      false
    end

  fun ref _migrate_all_partition_steps(state_name: String,
    target_workers: Array[(String, OutgoingBoundary)] val,
    leaving_workers: Array[String] val): Bool
  =>
    """
    Called to initiate migrating all partition steps the set of remaining
    workers. Return false if there is nothing to migrate.
    """
    try
      @printf[I32]("Migrating steps for %s partition to %d workers\n"
        .cstring(), state_name.cstring(), target_workers.size())
      let partition_router = _partition_routers(state_name)?
      partition_router.rebalance_steps_shrink(target_workers, leaving_workers,
        this)
    else
      Fail()
      false
    end

  fun ref add_to_step_waiting_list(step_id: RoutingId) =>
    _step_waiting_list.set(step_id)

  /////////////////////////////////////////////////////////////////////////////
  // SHRINK TO FIT
  /////////////////////////////////////////////////////////////////////////////
  be initiate_shrink(remaining_workers: Array[String] val,
    leaving_workers: Array[String] val)
  =>
    """
    This should only be called on the worker contacted via an external
    message to initiate a shrink.
    """
    try
      (_autoscale as Autoscale).initiate_shrink(remaining_workers,
        leaving_workers)
    else
      Fail()
    end
    if ArrayHelpers[String].contains[String](leaving_workers, _worker_name)
    then
      // Since we're one of the leaving workers, we're handing off
      // responsibility for the shrink to one of the remaining workers.
      try
        let shrink_initiator = remaining_workers(0)?
        let msg = ChannelMsgEncoder.initiate_shrink(remaining_workers,
          leaving_workers, _auth)?
        _connections.send_control(shrink_initiator, msg)
      else
        Fail()
      end
    else
      @printf[I32]("~~~Initiating shrink~~~\n".cstring())
      @printf[I32]("-- Remaining workers: \n".cstring())
      for w in remaining_workers.values() do
        @printf[I32]("-- -- %s\n".cstring(), w.cstring())
      end

      @printf[I32]("-- Leaving workers: \n".cstring())
      for w in leaving_workers.values() do
        @printf[I32]("-- -- %s\n".cstring(), w.cstring())
      end
      _stop_the_world_in_process = true
      initiate_stop_the_world()
      _stop_the_world_for_shrink_migration()
      try
        let msg = ChannelMsgEncoder.prepare_shrink(remaining_workers,
          leaving_workers, _auth)?
        for w in remaining_workers.values() do
          _connections.send_control(w, msg)
        end
      else
        Fail()
      end
      _prepare_shrink(remaining_workers, leaving_workers)

      let action = Promise[None]
      action.next[None]({(_: None) =>
        _self.announce_leaving_migration(remaining_workers, leaving_workers)})
      _autoscale_initiator.initiate_autoscale(action)
    end

  be prepare_shrink(remaining_workers: Array[String] val,
    leaving_workers: Array[String] val)
  =>
    """
    One worker is contacted via external message to begin autoscale
    shrink. That worker then informs every other worker to prepare for
    shrink. This behavior is called in response to receiving that message
    from the contacted worker.
    """
    try
      (_autoscale as Autoscale).prepare_shrink(remaining_workers,
        leaving_workers)
    else
      Fail()
    end
    _prepare_shrink(remaining_workers, leaving_workers)

  fun ref _prepare_shrink(remaining_workers: Array[String] val,
    leaving_workers: Array[String] val)
  =>
    if not _stop_the_world_in_process then
      _stop_the_world_in_process = true
      _stop_the_world_for_shrink_migration()
    end

    for (p_id, router) in _stateless_partition_routers.pairs() do
      let new_router = router.calculate_shrink(remaining_workers)
      _distribute_stateless_partition_router(new_router)
      _stateless_partition_routers(p_id) = new_router
    end

  be begin_leaving_migration(remaining_workers: Array[String] val,
    leaving_workers: Array[String] val)
  =>
    """
    This should only be called on a worker designated to leave the cluster
    as part of shrink to fit.
    """
    @printf[I32]("Beginning process of leaving cluster.\n".cstring())
    try
      (_autoscale as Autoscale).begin_leaving_migration(remaining_workers)
    else
      Fail()
    end

    _leaving_workers = leaving_workers
    if _partition_routers.size() == 0 then
      @printf[I32](("No partitions to migrate.\n").cstring())
      try
        (_autoscale as Autoscale).all_step_migration_complete()
      else
        Fail()
      end
      return
    end

    let sorted_remaining_workers =
      ArrayHelpers[String].sorted[String](remaining_workers)

    let rws_trn = recover trn Array[(String, OutgoingBoundary)] end
    for w in sorted_remaining_workers.values() do
      try
        let boundary = _outgoing_boundaries(w)?
        rws_trn.push((w, boundary))
      else
        Fail()
      end
    end
    let rws = consume val rws_trn
    if rws.size() == 0 then Fail() end

    @printf[I32]("Migrating all partitions to %d remaining workers\n"
      .cstring(), remaining_workers.size())

    var had_steps_to_migrate = false
    for state_name in _partition_routers.keys() do
      let steps_to_migrate_for_this_state =
        _migrate_all_partition_steps(state_name, rws, leaving_workers)
      if steps_to_migrate_for_this_state then
        had_steps_to_migrate = true
      end
    end
    if not had_steps_to_migrate then
      try_to_resume_processing_immediately()
    end

  be announce_leaving_migration(remaining_workers: Array[String] val,
    leaving_workers: Array[String] val)
  =>
    try
      let msg = ChannelMsgEncoder.begin_leaving_migration(remaining_workers,
        leaving_workers, _auth)?
      for w in leaving_workers.values() do
        if w == _worker_name then
          // Leaving workers shouldn't be managing the shrink process.
          Fail()
        else
          _connections.send_control(w, msg)?
        end
      end
    else
      Fail()
    end

  be disconnect_from_leaving_worker(worker: String) =>
    _connections.disconnect_from(worker)
    try
      _remove_worker(worker)
      _outgoing_boundaries.remove(worker)?
      _outgoing_boundaries_builders.remove(worker)?
    else
      Fail()
    end

    _distribute_boundary_builders()

    try
      (_autoscale as Autoscale).leaving_worker_finished_migration(worker)
    else
      Fail()
    end

  fun ref send_leaving_migration_ack_request(
    remaining_workers: Array[String] val)
  =>
    try
      let msg = ChannelMsgEncoder.leaving_migration_ack_request(_worker_name,
        _auth)?
      for w in remaining_workers.values() do
        _connections.send_control(w, msg)
      end
    else
      Fail()
    end

  be receive_leaving_migration_ack(worker: String) =>
    try
      (_autoscale as Autoscale).receive_leaving_migration_ack(worker)
    else
      Fail()
    end

  fun ref all_leaving_workers_finished(leaving_workers: Array[String] val) =>
    for w in leaving_workers.values() do
      _barrier_initiator.remove_worker(w)
      _snapshot_initiator.remove_worker(w)
    end
    for (state_name, pr) in _partition_routers.pairs() do
      let new_pr = pr.recalculate_hash_partitions_for_shrink(leaving_workers)
      _partition_routers(state_name) = new_pr
      //!@ Do we need to keep distributing like this?
      _distribute_partition_router(new_pr)
    end
    _connections.request_cluster_unmute()
    _unmute_request(_worker_name)

  /////////////////////////////////////////////////////////////////////////////
  // Step moved off this worker or new step added to another worker
  /////////////////////////////////////////////////////////////////////////////
  fun ref move_stateful_step_to_proxy(id: RoutingId, step: Step,
    proxy_address: ProxyAddress, key: Key, state_name: String)
  =>
    """
    Called when a stateful step has been migrated off this worker to another
    worker
    """
    _remove_all_routes_to_step(id, step)
    _move_step_to_proxy(id, state_name, key, proxy_address)

  fun ref _remove_all_routes_to_step(id: RoutingId, step: Step) =>
    for source in _sources.values() do
      source.remove_route_to_consumer(id, step)
    end
    _data_router.remove_routes_to_consumer(id, step)

  fun ref _move_step_to_proxy(id: U128, state_name: String, key: Key,
    proxy_address: ProxyAddress)
  =>
    """
    Called when a step has been migrated off this worker to another worker
    """
    _remove_step_from_data_router(state_name, key)
    //!@
    // _add_proxy_to_target_id_router(id, proxy_address)

  be add_state_proxy(id: RoutingId, proxy_address: ProxyAddress, key: Key,
    state_name: String)
  =>
    """
    Called when a stateful step has been added to another worker
    """
    //!@
    // _add_proxy_to_target_id_router(id, proxy_address)

  fun ref _remove_step_from_data_router(state_name: String, key: Key) =>
    let new_data_router = _data_router.remove_keyed_route(state_name, key)
    _data_router = new_data_router
    _distribute_data_router()

//!@
  // fun ref _add_proxy_to_target_id_router(id: RoutingId,
  //   proxy_address: ProxyAddress)
  // =>
  //   match _target_id_router
  //   | let o: TargetIdRouter =>
  //     _target_id_router = o.update_route_to_proxy(id, proxy_address.worker)
  //   else
  //     Fail()
  //   end

  /////////////////////////////////////////////////////////////////////////////
  // Step moved onto this worker
  /////////////////////////////////////////////////////////////////////////////
  be receive_immigrant_step(subpartition: StateSubpartitions,
    runner_builder: RunnerBuilder, reporter: MetricsReporter iso,
    recovery_replayer: RecoveryReconnecter, msg: StepMigrationMsg)
  =>
    let outgoing_boundaries = recover iso Map[String, OutgoingBoundary] end
    for (k, v) in _outgoing_boundaries.pairs() do
      outgoing_boundaries(k) = v
    end

    match _event_log
    | let event_log: EventLog =>
      try
        let target_id_router = _target_id_routers(msg.state_name())?
        let step = Step(_auth, runner_builder(where event_log = event_log,
          auth = _auth), consume reporter, msg.step_id(),
          event_log, recovery_replayer,
          consume outgoing_boundaries, _state_step_creator
          where target_id_router = target_id_router)
        step.receive_state(msg.state())
        msg.update_router_registry(this, step)
      else
        Fail()
      end
    else
      Fail()
    end

  fun ref move_proxy_to_stateful_step(id: RoutingId, target: Consumer,
    key: Key, state_name: String, source_worker: String)
  =>
    """
    Called when a stateful step has been migrated to this worker from another
    worker
    """
    _add_routes_to_state_step(id, target, key, state_name)
    _connections.notify_cluster_of_new_stateful_step(id, key, state_name,
      recover [source_worker] end)

  fun ref _add_routes_to_state_step(id: RoutingId, target: Consumer, key: Key,
    state_name: String)
  =>
    try
      match target
      | let step: Step =>
        _register_target_id_router_updatable(state_name, step)
        _data_router = _data_router.add_keyed_route(id, state_name, key, step)
        _distribute_data_router()
        let partition_router =
          _partition_routers(state_name)?.update_route(id, key, step)?
        _distribute_partition_router(partition_router)
        _partition_routers(state_name) = partition_router
      else
        Fail()
      end
    else
      Fail()
    end
    _move_proxy_to_step(id, target)

  fun ref _move_proxy_to_step(id: U128, target: Consumer)
  =>
    """
    Called when a step has been migrated to this worker from another worker
    """
    None
    //!@
    // match _target_id_router
    // | let o: TargetIdRouter =>
    //   _target_id_router = o.update_route_to_consumer(id, target)
    // else
    //   Fail()
    // end

  //!@
  fun ref _outgoing_boundaries_sorted(): Array[(String, OutgoingBoundary)] val
  =>
    let keys = Array[String]
    for k in _outgoing_boundaries.keys() do
      keys.push(k)
    end

    let sorted_keys = Sort[Array[String], String](keys)

    let diff = recover trn Array[(String, OutgoingBoundary)] end
    for sorted_key in sorted_keys.values() do
      try
        diff.push((sorted_key, _outgoing_boundaries(sorted_key)?))
      else
        Fail()
      end
    end
    consume diff

  /////////////////////////////////////////////////////////////////////////////
  // EXTERNAL QUERIES
  /////////////////////////////////////////////////////////////////////////////
  be partition_query(conn: TCPConnection) =>
    let msg = ExternalMsgEncoder.partition_query_response(
      _partition_routers, _stateless_partition_routers)
    conn.writev(msg)

  be partition_count_query(conn: TCPConnection) =>
    let msg = ExternalMsgEncoder.partition_count_query_response(
      _partition_routers, _stateless_partition_routers)
    conn.writev(msg)

  be cluster_status_query_not_initialized(conn: TCPConnection) =>
    let msg = ExternalMsgEncoder.cluster_status_query_reponse_not_initialized()
    conn.writev(msg)

  be cluster_status_query(worker_names: Array[String] val,
    conn: TCPConnection)
  =>
    let msg = ExternalMsgEncoder.cluster_status_query_response(
      worker_names.size(), worker_names, _stop_the_world_in_process)
    conn.writev(msg)

  be source_ids_query(conn: TCPConnection) =>
    let ids = recover iso Array[String] end
    for s_id in _source_ids.values() do
      ids.push(s_id.string())
    end
    let msg = ExternalMsgEncoder.source_ids_query_response(
      consume ids)
    conn.writev(msg)

  be state_entity_query(conn: TCPConnection) =>
    let msg = ExternalMsgEncoder.state_entity_query_response(
      _partition_routers)
    conn.writev(msg)

  be stateless_partition_query(conn: TCPConnection) =>
    let msg = ExternalMsgEncoder.stateless_partition_query_response(
      _stateless_partition_routers)
    conn.writev(msg)

  be state_entity_count_query(conn: TCPConnection) =>
    let msg = ExternalMsgEncoder.state_entity_count_query_response(
      _partition_routers)
    conn.writev(msg)

  be stateless_partition_count_query(conn: TCPConnection) =>
    let msg = ExternalMsgEncoder.stateless_partition_count_query_response(
      _stateless_partition_routers)
    conn.writev(msg)

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
