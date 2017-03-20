use "collections"
use "time"
use "wallaroo/boundary"
use "wallaroo/data_channel"
use "wallaroo/fail"
use "wallaroo/network"
use "wallaroo/routing"
use "wallaroo/tcp_source"

actor RouterRegistry
  let _auth: AmbientAuth
  let _worker_name: String
  let _connections: Connections
  var _data_router: (DataRouter val | None) = None
  var _pre_state_data: (Array[PreStateData val] val | None) = None
  let _partition_routers: Map[String, PartitionRouter val] =
    _partition_routers.create()
  var _omni_router: (OmniRouter val | None) = None
  let _data_receivers: Map[String, DataReceiver] = _data_receivers.create()
  let _sources: SetIs[TCPSource] = _sources.create()
  let _data_channel_listeners: SetIs[DataChannelListener] =
    _data_channel_listeners.create()
  let _data_channels: SetIs[DataChannel] = _data_channels.create()
  // All steps that have a PartitionRouter
  let _partition_router_steps: SetIs[PartitionRoutable] =
    _partition_router_steps.create()
  // All steps that have an OmniRouter
  let _omni_router_steps: SetIs[OmniRoutable] = _omni_router_steps.create()
  let _outgoing_boundaries: Map[String, OutgoingBoundary] =
    _outgoing_boundaries.create()

  //////
  // Partition Migration
  //////
  var _migrating: Bool = false
  // Steps migrated out and waiting for acknowledgement
  let _step_waiting_list: SetIs[U128] = _step_waiting_list.create()
  // Workers in running cluster that have been stopped for migration
  let _stopped_worker_waiting_list: _StringSet =
    _stopped_worker_waiting_list.create()
  // Migration targets that have not yet acked migration batch complete
  let _migration_target_ack_list: _StringSet =
    _migration_target_ack_list.create()
  // Used as a proxy for RouterRegistry when muting and unmuting sources
  // and data channel.
  // TODO: Probably change mute()/unmute() interface so we don't need this
  let _dummy_consumer: DummyConsumer = DummyConsumer

  var _stop_the_world_pause: U64

  new create(auth: AmbientAuth, worker_name: String, c: Connections,
    stop_the_world_pause: U64)
  =>
    _auth = auth
    _worker_name = worker_name
    _connections = c
    _stop_the_world_pause = stop_the_world_pause

  fun _worker_count(): USize =>
    _outgoing_boundaries.size() + 1

  be set_data_router(dr: DataRouter val) =>
    _data_router = dr
    _distribute_data_router()

  be set_pre_state_data(psd: Array[PreStateData val] val) =>
    _pre_state_data = psd

  be set_partition_router(state_name: String, pr: PartitionRouter val) =>
    _partition_routers(state_name) = pr

  be set_omni_router(o: OmniRouter val) =>
    _omni_router = o

  be register_data_receiver(sender: String, dr: DataReceiver) =>
    _data_receivers(sender) = dr

  be register_source(tcp_source: TCPSource) =>
    _sources.set(tcp_source)
    _partition_router_steps.set(tcp_source)

  be register_data_channel_listener(dchl: DataChannelListener) =>
    _data_channel_listeners.set(dchl)

  be register_data_channel(dc: DataChannel) =>
    // TODO: These need to be unregistered if they close
    _data_channels.set(dc)

  be register_partition_router_step(pr: PartitionRoutable) =>
    _partition_router_steps.set(pr)

  be register_omni_router_step(o: OmniRoutable) =>
    _omni_router_steps.set(o)

  be register_boundaries(ob: Map[String, OutgoingBoundary] val) =>
    let new_boundaries: Map[String, OutgoingBoundary] trn =
      recover Map[String, OutgoingBoundary] end
    for (worker, boundary) in ob.pairs() do
      if not _outgoing_boundaries.contains(worker) then
        _outgoing_boundaries(worker) = boundary
        new_boundaries(worker) = boundary
      end
    end

    let new_boundaries_sendable: Map[String, OutgoingBoundary] val =
      consume new_boundaries
    for routable in _partition_router_steps.values() do
      routable.add_boundaries(new_boundaries_sendable)
    end
    for routable in _omni_router_steps.values() do
      routable.add_boundaries(new_boundaries_sendable)
    end

  be add_data_receiver(sender_name: String, data_receiver: DataReceiver) =>
    // TODO: Persistent map would be much more efficient here.
    _data_receivers(sender_name) = data_receiver
    let data_receivers: Map[String, DataReceiver] trn =
      recover Map[String, DataReceiver] end
    for (s, dr) in _data_receivers.pairs() do
      data_receivers(s) = dr
    end
    let data_receivers_sendable: Map[String, DataReceiver] val =
      consume data_receivers
    match _data_router
    | let data_router: DataRouter val =>
      data_receiver.update_router(data_router)
      for data_channel_listener in _data_channel_listeners.values() do
        data_channel_listener.update_data_receivers(data_receivers_sendable)
      end
      for data_channel in _data_channels.values() do
        data_channel.update_data_receivers(data_receivers_sendable)
      end
    else
      // This branch should only be taken on initialization
      None
    end

  fun _distribute_data_router() =>
    match _data_router
    | let data_router: DataRouter val =>
      for data_receiver in _data_receivers.values() do
        data_receiver.update_router(data_router)
      end
    else
      Fail()
    end

  be inform_cluster_of_join() =>
    _connections.inform_cluster_of_join()


  //////////////
  // NEW WORKER PARTITION MIGRATION
  //////////////
  be migrate_onto_new_worker(new_worker: String) =>
    """
    Called when a new worker joins the cluster and we are ready to start
    the partition migration process. We first trigger a pause to allow
    in-flight messages to finish processing.
    """
    _migrating = true
    _stop_the_world(new_worker)
    let timers = Timers
    let timer = Timer(PauseBeforeMigrationNotify(this, new_worker),
      _stop_the_world_pause)
    timers(consume timer)

  fun ref _stop_the_world(new_worker: String) =>
    """
    We currently stop all message processing before migrating partitions and
    updating routers/routes.
    """
    @printf[I32]("~~~Stopping message processing for state migration.~~~\n".cstring())
    _migration_target_ack_list.set(new_worker)
    _mute_request(_worker_name)
    _connections.stop_the_world(recover [new_worker] end)

  be resume_the_world() =>
    _resume_the_world()

  fun ref _resume_the_world() =>
    """
    Migration is complete and we're ready to resume message processing
    """
    _resume_all_local()
    _migrating = false
    @printf[I32]("~~~Resuming message processing.~~~\n".cstring())

  be begin_migration(target_worker: String) =>
    """
    Begin partition migration
    """
    if _partition_routers.size() == 0 then
      //no steps have been migrated
      @printf[I32]("Resuming message processing immediately. No partitions to migrate.\n".cstring())
      _resume_the_world()
    end
    @printf[I32]("Migrating partitions to %s\n".cstring(), target_worker.cstring())
    for state_name in _partition_routers.keys() do
      _migrate_partition_steps(state_name, target_worker)
    end

  be step_migration_complete(step_id: U128) =>
    """
    Step with provided step id has been created on another worker.
    """
    _step_waiting_list.unset(step_id)
    if (_step_waiting_list.size() == 0) then
      _send_migration_batch_complete()
    end

  fun _send_migration_batch_complete() =>
    """
    Inform migration target that the entire migration batch has been sent.
    """
    @printf[I32]("--Sending migration batch complete msg to new workers\n".cstring())
    for target in _migration_target_ack_list.values() do
      try
        _outgoing_boundaries(target).send_migration_batch_complete()
      else
        Fail()
      end
    end

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
    _stopped_worker_waiting_list.unset(originating_worker)
    if (_stopped_worker_waiting_list.size() == 0) and _migrating then
      if _migration_target_ack_list.size() == 0 then
        _resume_the_world()
      else
        // We should only unmute ourselves once _migration_target_ack_list is
        // empty, which means we should never reach this line
        Fail()
      end
    end

  be process_migrating_target_ack(target: String) =>
    """
    Called when we receive a migration batch ack from the new worker
    (i.e. migration target) indicating it's ready to receive data messages
    """
    @printf[I32]("--Processing migration batch complete ack from %s\n".cstring(), target.cstring())
    _migration_target_ack_list.unset(target)

    if _migration_target_ack_list.size() == 0 then
      @printf[I32]("--All new workers have acked migration batch complete\n".cstring(), target.cstring())
      _connections.request_cluster_unmute()
      _unmute_request(_worker_name)
    end

  fun _stop_all_local() =>
    """
    Mute all sources and data channel.
    """
    @printf[I32]("Muting any local sources.\n".cstring())
    for source in _sources.values() do
      source.mute(_dummy_consumer)
    end

  fun _resume_all_local() =>
    """
    Unmute all sources and data channel.
    """
    @printf[I32]("Unmuting any local sources.\n".cstring())
    for source in _sources.values() do
      source.unmute(_dummy_consumer)
    end

  be try_to_resume_processing_immediately() =>
    if _step_waiting_list.size() == 0 then
      _send_migration_batch_complete()
    end

  be ack_migration_batch_complete(sender_name: String) =>
    """
    Called when a new (joining) worker needs to ack to worker sender_name that
    it's ready to start receiving messages after migration
    """
    _connections.ack_migration_batch_complete(sender_name)

  fun _migrate_partition_steps(state_name: String, target_worker: String) =>
    """
    Called to initiate migrating partition steps to a target worker in order
    to rebalance.
    """
    try
      @printf[I32]("Migrating steps for %s partition to %s\n".cstring(),
        state_name.cstring(), target_worker.cstring())
      let boundary = _outgoing_boundaries(target_worker)
      let partition_router = _partition_routers(state_name)
      partition_router.rebalance_steps(boundary, target_worker,
        _worker_count(), state_name, this)
    else
      Fail()
    end

  be add_to_step_waiting_list(step_id: U128) =>
    _step_waiting_list.set(step_id)

  /////
  // Step moved off this worker or new step added to another worker
  /////
  be move_step_to_proxy(id: U128, proxy_address: ProxyAddress val) =>
    """
    Called when a stateless step has been migrated off this worker to another
    worker
    """
    _move_step_to_proxy(id, proxy_address)

  be move_stateful_step_to_proxy[K: (Hashable val & Equatable[K] val)](
    id: U128, proxy_address: ProxyAddress val, key: K, state_name: String)
  =>
    """
    Called when a stateful step has been migrated off this worker to another
    worker
    """
    _add_state_proxy_to_partition_router[K](proxy_address, key, state_name)
    _move_step_to_proxy(id, proxy_address)

  fun ref _move_step_to_proxy(id: U128, proxy_address: ProxyAddress val) =>
    """
    Called when a step has been migrated off this worker to another worker
    """
    _remove_step_from_data_router(id)
    _add_proxy_to_omni_router(id, proxy_address)

  be add_state_proxy[K: (Hashable val & Equatable[K] val)](id: U128,
    proxy_address: ProxyAddress val, key: K, state_name: String)
  =>
    """
    Called when a stateful step has been added to another worker
    """
    _add_state_proxy_to_partition_router[K](proxy_address, key, state_name)
    _add_proxy_to_omni_router(id, proxy_address)

  fun ref _add_state_proxy_to_partition_router[
    K: (Hashable val & Equatable[K] val)](proxy_address: ProxyAddress val,
    key: K, state_name: String)
  =>
    try
      let proxy_router = ProxyRouter(_worker_name,
        _outgoing_boundaries(proxy_address.worker), proxy_address, _auth)
      let partition_router =
        _partition_routers(state_name).update_route[K](key, proxy_router)
      _partition_routers(state_name) = partition_router
      for routable in _partition_router_steps.values() do
        routable.update_router(partition_router)
      end
    else
      Fail()
    end

  fun ref _remove_step_from_data_router(id: U128) =>
    try
      match _data_router
      | let dr: DataRouter val =>
        let moving_step = dr.step_for_id(id)

        let new_data_router = dr.remove_route(id)
        for data_receiver in _data_receivers.values() do
          data_receiver.update_router(new_data_router)
        end
        _data_router = new_data_router
      else
        Fail()
      end
    else
      Fail()
    end

  fun ref _add_proxy_to_omni_router(id: U128,
    proxy_address: ProxyAddress val)
  =>
    match _omni_router
    | let o: OmniRouter val =>
      let new_omni_router = o.update_route_to_proxy(id, proxy_address)
      for routable in _omni_router_steps.values() do
        routable.update_omni_router(new_omni_router)
      end
      _omni_router = new_omni_router
    else
      Fail()
    end

  /////
  // Step moved onto this worker
  /////
  be move_proxy_to_step(id: U128, target: ConsumerStep,
    source_worker: String)
  =>
    """
    Called when a stateless step has been migrated to this worker from another
    worker
    """
    _move_proxy_to_step(id, target, source_worker)

  be move_proxy_to_stateful_step[K: (Hashable val & Equatable[K] val)](
    id: U128, target: ConsumerStep, key: K, state_name: String,
    source_worker: String)
  =>
    """
    Called when a stateful step has been migrated to this worker from another
    worker
    """
    try
      match target
      | let step: Step =>
        match _omni_router
        | let omni_router: OmniRouter val =>
          step.update_omni_router(omni_router)
        else
          Fail()
        end
        let partition_router =
          _partition_routers(state_name).update_route[K](key, step)
        for routable in _partition_router_steps.values() do
          routable.update_router(partition_router)
        end
        // Add routes to state computation targets to state step
        match _pre_state_data
        | let psds: Array[PreStateData val] val =>
          for psd in psds.values() do
            if psd.state_name() == state_name then
              match psd.target_id()
              | let tid: U128 =>
                match _data_router
                | let dr: DataRouter val =>
                  let target_router = DirectRouter(dr.step_for_id(tid))
                  step.register_routes(target_router,
                    psd.forward_route_builder())
                else
                  Fail()
                end
              end
            end
          end
        else
          Fail()
        end
        _partition_routers(state_name) = partition_router
      else
        Fail()
      end
    else
      Fail()
    end
    _move_proxy_to_step(id, target, source_worker)
    _connections.notify_cluster_of_new_stateful_step[K](id, key, state_name,
      recover [source_worker] end)

  fun ref _move_proxy_to_step(id: U128, target: ConsumerStep,
    source_worker: String)
  =>
    """
    Called when a step has been migrated to this worker from another worker
    """
    match _data_router
    | let dr: DataRouter val =>
      let new_data_router = dr.add_route(id, target)
      for data_receiver in _data_receivers.values() do
        data_receiver.update_router(new_data_router)
      end
      _data_router = new_data_router
    else
      Fail()
    end

    match _omni_router
    | let o: OmniRouter val =>
      let new_omni_router = o.update_route_to_step(id, target)
      for routable in _omni_router_steps.values() do
        routable.update_omni_router(new_omni_router)
      end
      _omni_router = new_omni_router
    else
      Fail()
    end

class PauseBeforeMigrationNotify is TimerNotify
  let _registry: RouterRegistry
  let _target_worker: String

  new iso create(registry: RouterRegistry, target_worker: String) =>
    _registry = registry
    _target_worker = target_worker

  fun ref apply(timer: Timer, count: U64): Bool =>
    _registry.begin_migration(_target_worker)
    false

// TODO: Replace using this with the badly named SetIs once we address a bug
// in SetIs where unsetting doesn't reduce set size for type SetIs[String]
class _StringSet
  let _map: Map[String, String] = _map.create()

  fun ref set(s: String) =>
    _map(s) = s

  fun ref unset(s: String) =>
    try _map.remove(s) end

  fun size(): USize =>
    _map.size()

  fun values(): MapValues[String, String, HashEq[String],
    this->HashMap[String, String, HashEq[String]]]^
  =>
    _map.values()
