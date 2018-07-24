

use "promises"
use "wallaroo/core/source"
use "wallaroo_labs/mort"


trait BarrierInitiatorPhase
  fun ref initiate_barrier(barrier_token: BarrierToken,
    result_promise: BarrierResultPromise)
  =>
    Fail()

  fun ref initiate_rollback_barrier(barrier_token: BarrierToken,
    result_promise: BarrierResultPromise)
  =>
    Fail()

  fun ref source_registration_complete(s: Source) =>
    Fail()

  fun ready_for_next_token(): Bool =>
    false

  fun higher_priority(t: BarrierToken): Bool =>
    match t
    | let srt: SnapshotRollbackBarrierToken =>
      true
    else
      false
    end

  fun ref barrier_complete(token: BarrierToken) =>
    Fail()

class InitialBarrierInitiatorPhase is BarrierInitiatorPhase

class NormalBarrierInitiatorPhase is BarrierInitiatorPhase
  let _initiator: BarrierInitiator ref

  new create(initiator: BarrierInitiator ref) =>
    _initiator = initiator

  fun ref initiate_barrier(barrier_token: BarrierToken,
    result_promise: BarrierResultPromise)
  =>
    _initiator.initiate_barrier(barrier_token, result_promise)

  fun ready_for_next_token(): Bool =>
    true

  fun ref barrier_complete(token: BarrierToken) =>
    _initiator.next_token()

class SourcePendingBarrierInitiatorPhase is BarrierInitiatorPhase
  """
  In this phase, we queue new barriers and wait to inject them until after
  the pending source has registered with its downstreams.
  """
  let _initiator: BarrierInitiator ref

  new create(initiator: BarrierInitiator ref) =>
    _initiator = initiator

  fun ref initiate_barrier(barrier_token: BarrierToken,
    result_promise: BarrierResultPromise)
  =>
    _initiator.queue_barrier(barrier_token, result_promise)

  fun ref source_registration_complete(s: Source) =>
    _initiator.source_pending_complete(s)

class BlockingBarrierInitiatorPhase is BarrierInitiatorPhase
  let _initiator: BarrierInitiator ref
  let _initial_token: BarrierToken
  let _wait_for_token: BarrierToken

  new create(initiator: BarrierInitiator ref, token: BarrierToken,
    wait_for_token: BarrierToken)
  =>
    _initiator = initiator
    _initial_token = token
    _wait_for_token = wait_for_token

  fun ref initiate_barrier(barrier_token: BarrierToken,
    result_promise: BarrierResultPromise)
  =>
    if (barrier_token == _initial_token) or
      (barrier_token == _wait_for_token)
    then
      _initiator.initiate_barrier(barrier_token, result_promise)
    else
      _initiator.queue_barrier(barrier_token, result_promise)
    end

  fun ref barrier_complete(token: BarrierToken) =>
    if token == _wait_for_token then
      _initiator.next_token()
    end

class RollbackBarrierInitiatorPhase is BarrierInitiatorPhase
  let _initiator: BarrierInitiator ref
  let _token: BarrierToken

  new create(initiator: BarrierInitiator ref, token: BarrierToken) =>
    _initiator = initiator
    _token = token

  fun higher_priority(t: BarrierToken): Bool =>
    t > _token

  fun ref initiate_barrier(barrier_token: BarrierToken,
    result_promise: BarrierResultPromise)
  =>
    if (barrier_token == _token) then
      _initiator.initiate_barrier(barrier_token, result_promise)
    else
      _initiator.queue_barrier(barrier_token, result_promise)
    end

  fun ref barrier_complete(token: BarrierToken) =>
    """
    We are clearing all old barrier info, so we ignore this.
    """
    None

  fun ref rollback_barrier_complete(token: BarrierToken) =>
    if token == _token then
      _initiator.next_token()
    end


