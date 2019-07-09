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
use "wallaroo/core/common"
use "wallaroo/core/sink"
use "wallaroo/core/source"
use "wallaroo_labs/mort"


trait _BarrierCoordinatorPhase
  fun name(): String

  fun ref initiate_barrier(barrier_token: BarrierToken,
    result_promise: BarrierResultPromise)
  =>
    _invalid_call(); Fail()

  fun ref source_registration_complete(s: Source) =>
    _invalid_call(); Fail()

  fun ready_for_next_token(): Bool =>
    false

  fun higher_priority(t: BarrierToken): Bool =>
    """
    If this is called on any phase other than RollbackBarrierCoordinatorPhase,
    then this is the only rollback token being processed and it is thus
    higher priority than any other tokens in progress.
    """
    match t
    | let srt: CheckpointRollbackBarrierToken =>
      true
    else
      false
    end

  fun ref ack_barrier(s: Sink, barrier_token: BarrierToken) =>
    _invalid_call(); Fail()

  fun ref worker_ack_barrier(w: WorkerName, barrier_token: BarrierToken) =>
    _invalid_call(); Fail()

  fun ref barrier_fully_acked(token: BarrierToken) =>
    _invalid_call(); Fail()

  fun _invalid_call() =>
    @printf[I32]("Invalid call on barrier initiator phase %s\n".cstring(),
      name().cstring())

class _InitialBarrierCoordinatorPhase is _BarrierCoordinatorPhase
  fun name(): String => "_InitialBarrierCoordinatorPhase"

class _NormalBarrierCoordinatorPhase is _BarrierCoordinatorPhase
  let _coordinator: BarrierCoordinator ref

  new create(coordinator: BarrierCoordinator ref) =>
    _coordinator = coordinator

  fun name(): String =>
    "_NormalBarrierCoordinatorPhase"

  fun ref initiate_barrier(barrier_token: BarrierToken,
    result_promise: BarrierResultPromise)
  =>
      ifdef "checkpoint_trace" then
        @printf[I32]("Normal: Initiating barrier %s!\n".cstring(),
          barrier_token.string().cstring())
      end
    _coordinator.initiate_barrier(barrier_token, result_promise)

  fun ref ack_barrier(s: Sink, barrier_token: BarrierToken) =>
    _coordinator._ack_barrier(s, barrier_token)

  fun ref worker_ack_barrier(w: WorkerName, barrier_token: BarrierToken) =>
    _coordinator._worker_ack_barrier(w, barrier_token)

  fun ready_for_next_token(): Bool =>
    true

  fun ref barrier_fully_acked(token: BarrierToken) =>
    ifdef "checkpoint_trace" then
      @printf[I32]("Normal: Fully acked barrier %s!\n".cstring(),
        token.string().cstring())
    end
    _coordinator.next_token()

class _RecoveringBarrierCoordinatorPhase is _BarrierCoordinatorPhase
  let _coordinator: BarrierCoordinator ref

  new create(coordinator: BarrierCoordinator ref) =>
    _coordinator = coordinator

  fun name(): String =>
    "_RecoveringBarrierCoordinatorPhase"

  fun ref initiate_barrier(barrier_token: BarrierToken,
    result_promise: BarrierResultPromise)
  =>
    match barrier_token
    | let rbt: CheckpointRollbackBarrierToken =>
      _received_rollback_token("initiate_barrier", barrier_token)
    else
      @printf[I32](("Barrier Initiator recovering so ignoring non-rollback " +
        "barrier\n").cstring())
    end

  fun ref ack_barrier(s: Sink, barrier_token: BarrierToken) =>
    match barrier_token
    | let rbt: CheckpointRollbackBarrierToken =>
      _coordinator._ack_barrier(s, barrier_token)
    else
      @printf[I32](("Barrier Initiator recovering so ignoring " +
        "ack_barrier for %s\n").cstring(), barrier_token.string().cstring())
    end

  fun ref worker_ack_barrier(w: String, barrier_token: BarrierToken) =>
    match barrier_token
    | let rbt: CheckpointRollbackBarrierToken =>
      _coordinator._worker_ack_barrier(w, barrier_token)
    else
      @printf[I32](("Barrier Initiator recovering so ignoring old " +
        "worker_ack_barrier for %s\n").cstring(),
        barrier_token.string().cstring())
    end

  fun ready_for_next_token(): Bool =>
    true

  fun _received_rollback_token(call_name: String, token: BarrierToken) =>
    @printf[I32](("%s received at " +
      "_RecoveringBarrierCoordinatorPhase for %s. We should have already " +
      "transitioned to _RollbackBarrierCoordinatorPhase.\n").cstring(),
      token.string().cstring(), call_name.cstring())
    Fail()

class _SourcePendingBarrierCoordinatorPhase is _BarrierCoordinatorPhase
  """
  In this phase, we queue new barriers and wait to inject them until after
  the pending source has registered with its downstreams.
  """
  let _coordinator: BarrierCoordinator ref

  new create(coordinator: BarrierCoordinator ref) =>
    _coordinator = coordinator

  fun name(): String =>
    "_SourcePendingBarrierCoordinatorPhase"

  fun ref initiate_barrier(barrier_token: BarrierToken,
    result_promise: BarrierResultPromise)
  =>
    _coordinator.queue_barrier(barrier_token, result_promise)

  fun ref source_registration_complete(s: Source) =>
    _coordinator.source_pending_complete(s)

class _BlockingBarrierCoordinatorPhase is _BarrierCoordinatorPhase
  let _coordinator: BarrierCoordinator ref
  let _initial_token: BarrierToken
  let _wait_for_token: BarrierToken

  new create(coordinator: BarrierCoordinator ref, token: BarrierToken,
    wait_for_token: BarrierToken)
  =>
    _coordinator = coordinator
    _initial_token = token
    _wait_for_token = wait_for_token

  fun name(): String =>
    "_BlockingBarrierCoordinatorPhase"

  fun ref initiate_barrier(barrier_token: BarrierToken,
    result_promise: BarrierResultPromise)
  =>
    if (barrier_token == _initial_token) or
      (barrier_token == _wait_for_token)
    then
      ifdef "checkpoint_trace" then
        @printf[I32]("BlockPhase: Initiating barrier %s!\n".cstring(),
          barrier_token.string().cstring())
      end
      _coordinator.initiate_barrier(barrier_token, result_promise)
    else
      ifdef "checkpoint_trace" then
        @printf[I32]("BlockPhase: Queuing barrier %s!\n".cstring(),
          barrier_token.string().cstring())
      end
      // TODO: We need to ensure that we don't queue checkpoints when we're
      // rolling back. This is a crude way to test that.
      if not (_wait_for_token > barrier_token) then
        _coordinator.queue_barrier(barrier_token, result_promise)
      end
    end

  fun ref ack_barrier(s: Sink, barrier_token: BarrierToken) =>
    _coordinator._ack_barrier(s, barrier_token)

  fun ref worker_ack_barrier(w: WorkerName, barrier_token: BarrierToken) =>
    _coordinator._worker_ack_barrier(w, barrier_token)

  fun ref barrier_fully_acked(token: BarrierToken) =>
    ifdef "checkpoint_trace" then
      @printf[I32]("BlockPhase: Fully acked barrier %s!\n".cstring(),
        token.string().cstring())
    end
    if token == _wait_for_token then
      _coordinator.next_token()
    end

class _RollbackBarrierCoordinatorPhase is _BarrierCoordinatorPhase
  let _coordinator: BarrierCoordinator ref
  let _token: BarrierToken

  new create(coordinator: BarrierCoordinator ref, token: BarrierToken) =>
    _coordinator = coordinator
    _token = token

  fun name(): String =>
    "_RollbackBarrierCoordinatorPhase"

  fun higher_priority(t: BarrierToken): Bool =>
    t > _token

  fun ref initiate_barrier(barrier_token: BarrierToken,
    result_promise: BarrierResultPromise)
  =>
    if (barrier_token == _token) then
      _coordinator.initiate_barrier(barrier_token, result_promise)
    else
      // !TODO!: Is it safe to queue barriers that arrive after the rollback
      // token? Or should we be dropping all barriers until rollback is
      // complete?
      _coordinator.queue_barrier(barrier_token, result_promise)
    end

  fun ref barrier_fully_acked(token: BarrierToken) =>
    """
    We are clearing all old barrier info, so we ignore this.
    """
    None

  fun ref rollback_barrier_fully_acked(token: BarrierToken) =>
    if token == _token then
      _coordinator.next_token()
    end

  ////////////////////////////
  // Managing active barriers
  //
  // We drop any barrier-related activity unless it's related to our
  // current rollback token. By the time the rollback token is acked at
  // all sinks, we know that no more past activity will arrive.
  /////////////////////////////
  fun ref ack_barrier(s: Sink, barrier_token: BarrierToken) =>
    if barrier_token == _token then
      _coordinator._ack_barrier(s, barrier_token)
    end

  fun ref worker_ack_barrier(w: String, barrier_token: BarrierToken)
  =>
    if barrier_token == _token then
      _coordinator._worker_ack_barrier(w, barrier_token)
    end
