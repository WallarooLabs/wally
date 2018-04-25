/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "collections"
use "wallaroo/core/common"
use "wallaroo/core/data_channel"
use "wallaroo/ent/network"
use "wallaroo/ent/recovery"
use "wallaroo/ent/router_registry"
use "wallaroo/core/topology"
use "wallaroo_labs/mort"


interface DataReceiversSubscriber
  be data_receiver_added(sender_name: String, boundary_step_id: StepId,
    dr: DataReceiver)

actor DataReceivers
  let _auth: AmbientAuth
  let _connections: Connections
  let _worker_name: String

  var _initialized: Bool = false

  let _data_receivers: Map[BoundaryId, DataReceiver] =
    _data_receivers.create()
  var _data_router: DataRouter =
    DataRouter(recover Map[StepId, Consumer] end, recover Map[Key, Step] end)
  let _subscribers: SetIs[DataReceiversSubscriber tag] = _subscribers.create()

  var _router_registry: (RouterRegistry | None) = None

  new create(auth: AmbientAuth, connections: Connections, worker_name: String,
    is_recovering: Bool = false)
  =>
    _auth = auth
    _connections = connections
    _worker_name = worker_name
    if not is_recovering then
      _initialized = true
    end

  be set_router_registry(rr: RouterRegistry) =>
    _router_registry = rr

  be subscribe(sub: DataReceiversSubscriber tag) =>
    _subscribers.set(sub)

  fun _inform_subscribers(b_id: BoundaryId, dr: DataReceiver) =>
    for sub in _subscribers.values() do
      sub.data_receiver_added(b_id.name, b_id.step_id, dr)
    end

  be request_data_receiver(sender_name: String, sender_boundary_id: U128,
    conn: DataChannel)
  =>
    """
    Called when a DataChannel is first created and needs to know the
    DataReceiver corresponding to the relevant OutgoingBoundary. If this
    is the first time that OutgoingBoundary has connected to this worker,
    then we create a new DataReceiver here.
    """
    let boundary_id = BoundaryId(sender_name, sender_boundary_id)
    let dr =
      try
        _data_receivers(boundary_id)?
      else
        let new_dr = DataReceiver(_auth, _worker_name, sender_name,
          _initialized)
        match _router_registry
        | let rr: RouterRegistry =>
          rr.register_data_receiver(sender_name, new_dr)
        else
          Fail()
        end
        new_dr.update_router(_data_router)
        _data_receivers(boundary_id) = new_dr
        _connections.register_disposable(new_dr)
        new_dr
      end
    conn.identify_data_receiver(dr, sender_boundary_id)
    _inform_subscribers(boundary_id, dr)

  be start_replay_processing() =>
    for dr in _data_receivers.values() do
      dr.start_replay_processing()
    end

  be start_normal_message_processing() =>
    _initialized = true
    for dr in _data_receivers.values() do
      dr.start_normal_message_processing()
    end

  be update_data_router(dr: DataRouter) =>
    _data_router = dr
    for data_receiver in _data_receivers.values() do
      data_receiver.update_router(_data_router)
    end
