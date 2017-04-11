use "collections"

// class _BoundaryId is Equatable[_BoundaryId]
//   let name: String
//   let step_id: U128

//   new create(n: String, s_id: U128) =>
//     name = n
//     step_id = s_id

//   fun eq(that: box->_BoundaryId): Bool =>
//     (name == that.name) and (step_id == that.step_id)

//   fun hash(): U64 =>
//     (digestof this).hash()

// interface DataReceiversSubscriber
//   be data_receiver_added(boundary_id: _BoundaryId, dr: DataReceiver)


// actor DataReceivers
//   let _data_receivers: Map[_BoundaryId, DataReceiver] =
//     _data_receivers.create()
//   let _subscribers: SetIs[DataReceiversSubscriber] = _subscribers.create()


//   be subscribe(sub: DataReceiversSubscriber) =>
//     _subscribers.set(sub)

//   be request_data_receiver(sender_name: String, sender_boundary_id: U128,
//     conn: DataChannel)
//   =>
//     """
//     Called when a DataChannel is first created and needs to know the
//     DataReceiver corresponding to the relevant OutgoingBoundary. If this
//     is the first time that OutgoingBoundary has connected to this worker,
//     then we create a new DataReceiver here.
//     """
//     let boundary_id = _BoundaryId(sender_name, sender_boundary_id)
//     let dr =
//       try
//         _data_receivers(boundary_id)
//       else
//         let new_dr = DataReceiver(_auth, _worker_name, sender_name,
//           _connections, this, _alfred)
//         new_dr.update_router(_data_router)
//         _data_receivers(boundary_id) = new_dr
//         new_dr
//       end
//     conn.identify_data_receiver(dr, sender_boundary_id)

//   be add_data_receiver(sender_name: String, sender_boundary_id: U128,
//     data_receiver: DataReceiver)
//   =>
//     _data_receivers(_BoundaryId(sender_name, sender_boundary_id)) =
//       data_receiver
//     data_receiver.update_router(_data_router)

 // be initialize_data_receivers() =>
 //    for dr in _data_receivers.values() do
 //      dr.initialize()
 //    end

 // be update_data_router(dr: DataRouter val) =>
    // for data_receiver in _data_receivers.values() do
    //   data_receiver.update_router(new_data_router)
    // end
