use "collections"
use "wallaroo/boundary"
use "wallaroo/data_channel"
use "wallaroo/fail"
use "wallaroo/network"
use "wallaroo/routing"

actor RouterRegistry
  let _auth: AmbientAuth
  let _connections: Connections
  var _data_router: (DataRouter val | None) = None
  let _partition_routers: Map[String, PartitionRouter val] =
    _partition_routers.create()
  var _omni_router: (OmniRouter val | None) = None
  let _data_receivers: Map[String, DataReceiver] = _data_receivers.create()
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

  new create(auth: AmbientAuth, c: Connections) =>
    _auth = auth
    _connections = c

  fun _worker_count(): USize =>
    _outgoing_boundaries.size() + 1

  be set_data_router(dr: DataRouter val) =>
    _data_router = dr

  be set_partition_router(state_name: String, pr: PartitionRouter val) =>
    _partition_routers(state_name) = pr

  be set_omni_router(o: OmniRouter val) =>
    _omni_router = o

  be register_data_receiver(sender: String, dr: DataReceiver) =>
    _data_receivers(sender) = dr

  be register_data_channel_listener(dchl: DataChannelListener) =>
    _data_channel_listeners.set(dchl)

  be register_data_channel(dc: DataChannel) =>
    // TODO: These need to be unregistered if they close
    _data_channels.set(dc)

  be register_partition_router_step(pr: PartitionRoutable) =>
    _partition_router_steps.set(pr)

  be register_omni_router_step(o: OmniRoutable) =>
    _omni_router_steps.set(o)

  // TODO: Call this when a new worker is added to cluster
  be register_boundaries(ob: Map[String, OutgoingBoundary] val) =>
    let new_boundaries: Map[String, OutgoingBoundary] trn =
      recover Map[String, OutgoingBoundary] end
    for (state_name, boundary) in ob.pairs() do
      if not _outgoing_boundaries.contains(state_name) then
        _outgoing_boundaries(state_name) = boundary
        new_boundaries(state_name) = boundary
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
      Fail()
    end

  be migrate_partition_steps(state_name: String, target_worker: String) =>
    """
    Called to initiate migrating partition steps to a target worker in order
    to rebalance.
    """
    try
      let boundary = _outgoing_boundaries(target_worker)
      let partition_router = _partition_routers(state_name)
      partition_router.rebalance_steps(boundary, target_worker,
        _worker_count(), state_name, this)
    else
      Fail()
    end

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
      let proxy_router = ProxyRouter(proxy_address.worker,
        _outgoing_boundaries(state_name), proxy_address, _auth)
      try
        let partition_router =
          _partition_routers(state_name).update_route[K](key, proxy_router)
        _partition_routers(state_name) = partition_router
        for routable in _partition_router_steps.values() do
          routable.update_router(partition_router)
        end
      else
        Fail()
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

        for routable in _omni_router_steps.values() do
          routable.remove_route_for(moving_step)
        end
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
        let partition_router =
          _partition_routers(state_name).update_route[K](key, step)
        for routable in _partition_router_steps.values() do
          routable.update_router(partition_router)
        end
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
