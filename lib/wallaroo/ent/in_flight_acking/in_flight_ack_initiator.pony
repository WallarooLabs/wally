/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "promises"
use "wallaroo/ent/barrier"
use "wallaroo_labs/mort"


actor InFlightAckInitiator
  let _worker_name: String
  let _barrier_initiator: BarrierInitiator
  var _current_in_flight_token: (InFlightAckBarrierToken |
    InFlightAckResumeBarrierToken)
  var _in_flight_acks_in_progress: Bool = false

  new create(w_name: String, barrier_initiator: BarrierInitiator) =>
    _worker_name = w_name
    _current_in_flight_token = InFlightAckBarrierToken(_worker_name, 0)
    _barrier_initiator = barrier_initiator

  be initiate_in_flight_acks(in_flight_promise: InFlightAckResultPromise)
  =>
    @printf[I32]("Checking there are no in flight messages.\n".cstring())
    if _in_flight_acks_in_progress then Fail() end
    _in_flight_acks_in_progress = true
    let next_id = _current_in_flight_token.id() + 1
    _current_in_flight_token = InFlightAckBarrierToken(_worker_name, next_id)

    let barrier_promise = Promise[BarrierToken]
    barrier_promise
      .next[None](recover this~in_flight_acks_complete() end)
      .next[None]({(_: None) => in_flight_promise(None)})

    _barrier_initiator.initiate_barrier(_current_in_flight_token,
      barrier_promise)

  be initiate_in_flight_resume_acks(
    in_flight_promise: InFlightAckResultPromise)
  =>
    @printf[I32]("Attempting to resume in flight messages.\n".cstring())
    if _in_flight_acks_in_progress then Fail() end
    _in_flight_acks_in_progress = true
    let next_id = _current_in_flight_token.id() + 1
    _current_in_flight_token = InFlightAckResumeBarrierToken(_worker_name,
      next_id)

    let barrier_promise = Promise[BarrierToken]
    barrier_promise
      .next[None](recover this~in_flight_acks_complete() end)
      .next[None]({(_: None) => in_flight_promise(None)})

    _barrier_initiator.initiate_barrier(_current_in_flight_token,
      barrier_promise)

  be in_flight_acks_complete(barrier_token: BarrierToken) =>
    match barrier_token
    | let ifa: (InFlightAckBarrierToken | InFlightAckResumeBarrierToken) =>
      if _current_in_flight_token != ifa then Fail() end
      _in_flight_acks_in_progress = false
    else
      Fail()
    end
