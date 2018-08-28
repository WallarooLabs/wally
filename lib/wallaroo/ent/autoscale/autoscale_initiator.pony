/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "promises"
use "wallaroo/core/common"
use "wallaroo/ent/barrier"
use "wallaroo_labs/mort"


actor AutoscaleInitiator
  let _worker_name: WorkerName
  let _barrier_initiator: BarrierInitiator
  var _current_autoscale_tokens: AutoscaleTokens
  var _autoscale_token_in_progress: Bool = false

  new create(w_name: WorkerName, barrier_initiator: BarrierInitiator) =>
    _worker_name = w_name
    _current_autoscale_tokens = AutoscaleTokens(_worker_name, 0)
    _barrier_initiator = barrier_initiator

  be initiate_autoscale(autoscale_initiate_promise: AutoscaleResultPromise)
  =>
    @printf[I32]("Checking there are no in flight messages.\n".cstring())
    if _autoscale_token_in_progress then Fail() end
    _autoscale_token_in_progress = true
    let next_id = _current_autoscale_tokens.id + 1
    _current_autoscale_tokens = AutoscaleTokens(_worker_name, next_id)

    let barrier_promise = Promise[BarrierToken]
    barrier_promise
      .next[None](recover this~autoscale_barrier_complete() end)
      .next[None]({(_: None) => autoscale_initiate_promise(None)})

    _barrier_initiator.inject_blocking_barrier(
      _current_autoscale_tokens.initial_token, barrier_promise,
      _current_autoscale_tokens.resume_token)

  be initiate_autoscale_resume_acks(
    autoscale_resume_promise: AutoscaleResultPromise)
  =>
    @printf[I32]("Attempting to resume in flight messages.\n".cstring())
    if _autoscale_token_in_progress then Fail() end
    _autoscale_token_in_progress = true
    let barrier_promise = Promise[BarrierToken]
    barrier_promise
      .next[None](recover this~autoscale_resume_complete() end)
      .next[None]({(_: None) => autoscale_resume_promise(None)})

    _barrier_initiator.inject_barrier(_current_autoscale_tokens.resume_token,
      barrier_promise)

  be autoscale_barrier_complete(barrier_token: BarrierToken) =>
    if barrier_token != _current_autoscale_tokens.initial_token then Fail() end
    _autoscale_token_in_progress = false

  be autoscale_resume_complete(barrier_token: BarrierToken) =>
    if barrier_token != _current_autoscale_tokens.resume_token then Fail() end
    _autoscale_token_in_progress = false

  be dispose() =>
    @printf[I32]("Shutting down AutoscaleInitiator\n".cstring())
    None
