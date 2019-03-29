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

use "promises"
use "time"
use "wallaroo/core/common"
use "wallaroo/core/barrier"
use "wallaroo/core/checkpoint"
use "wallaroo_labs/mort"


actor AutoscaleInitiator
  let _self: AutoscaleInitiator tag = this
  let _worker_name: WorkerName
  let _barrier_coordinator: BarrierCoordinator
  let _checkpoint_initiator: CheckpointInitiator
  var _current_autoscale_tokens: AutoscaleTokens
  var _autoscale_token_in_progress: Bool = false

  //!@
  var _timers: Timers = Timers

  new create(w_name: WorkerName, barrier_coordinator: BarrierCoordinator,
    checkpoint_initiator: CheckpointInitiator)
  =>
    _worker_name = w_name
    _current_autoscale_tokens = AutoscaleTokens(_worker_name, 0,
      recover Array[WorkerName] end)
    _barrier_coordinator = barrier_coordinator
    _checkpoint_initiator = checkpoint_initiator

  be initiate_autoscale(autoscale_initiate_promise: AutoscaleResultPromise,
    leaving_workers: Array[WorkerName] val = recover Array[WorkerName] end)
  =>
    let promise = Promise[None]
    promise
      .next[None]({(_: None) => _self.inject_autoscale_barrier(
        autoscale_initiate_promise, leaving_workers)})

    _checkpoint_initiator.clear_pending_checkpoints(promise)

  be inject_autoscale_barrier(
    autoscale_initiate_promise: AutoscaleResultPromise,
    leaving_workers: Array[WorkerName] val)
  =>
    @printf[I32]("Checking there are no in flight messages.\n".cstring())
    if _autoscale_token_in_progress then Fail() end
    _autoscale_token_in_progress = true
    let next_id = _current_autoscale_tokens.id + 1
    _current_autoscale_tokens = AutoscaleTokens(_worker_name, next_id,
      leaving_workers)

    let barrier_promise = Promise[BarrierToken]
    barrier_promise
      .next[None](recover this~autoscale_barrier_complete() end)
      .next[None]({(_: None) => autoscale_initiate_promise(None)})

    _barrier_coordinator.inject_blocking_barrier(
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

    //!@
    let t = Timer(_WaitForProducerRegistrations(_barrier_coordinator,
      _current_autoscale_tokens.resume_token, barrier_promise), 3_000_000_000)
    _timers(consume t)

    //!@ Bring back
    // _barrier_coordinator.inject_barrier(_current_autoscale_tokens.resume_token,
    //   barrier_promise)

  be autoscale_barrier_complete(barrier_token: BarrierToken) =>
    if barrier_token != _current_autoscale_tokens.initial_token then Fail() end
    _autoscale_token_in_progress = false

  be autoscale_resume_complete(barrier_token: BarrierToken) =>
    if barrier_token != _current_autoscale_tokens.resume_token then Fail() end
    _autoscale_token_in_progress = false
    _checkpoint_initiator.restart_repeating_checkpoints()

  be dispose() =>
    @printf[I32]("Shutting down AutoscaleInitiator\n".cstring())
    None


class _WaitForProducerRegistrations is TimerNotify
  let _b_coord: BarrierCoordinator
  let _token: BarrierToken
  let _promise: Promise[BarrierToken]

  new iso create(b_coord: BarrierCoordinator, token: BarrierToken,
    promise: Promise[BarrierToken])
  =>
    _b_coord = b_coord
    _token = token
    _promise = promise

  fun ref apply(timer: Timer, count: U64): Bool =>
    _b_coord.inject_barrier(_token, _promise)
    false
