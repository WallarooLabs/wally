

use "wallaroo_labs/mort"


trait BarrierInitiatorPhase
  fun ref initiate_barrier(barrier_token: BarrierToken,
    result_promise: BarrierResultPromise)
  =>
    Fail()

  fun ref source_registration_complete() =>
    Fail()

  fun ready_for_next_token(): Bool =>
    false

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

  fun ref source_registration_complete() =>
    _initiator.source_pending_complete()

class BlockingBarrierInitiatorPhase is BarrierInitiatorPhase
  let _initiator: BarrierInitiator ref
  let _initial_token: BarrierToken
  let _wait_for_token: (BarrierToken | None)

  new create(initiator: BarrierInitiator ref, token: BarrierToken,
    wait_for_token: (BarrierToken | None))
  =>
    _initiator = initiator
    _initial_token = token
    _wait_for_token = wait_for_token

  fun ref initiate_barrier(barrier_token: BarrierToken,
    result_promise: BarrierResultPromise)
  =>
    match barrier_token
    | let bt: _wait_for_token =>
      _initiator.initiate_barrier(barrier_token, result_promise)
    else
      _initiator.queue_barrier(barrier_token, result_promise)
    end

  fun ref barrier_complete(token: BarrierToken) =>
    match _wait_for_token
    | let wt: BarrierToken =>
      if token == wt then
        _initiator.next_token()
      end
    else
      _initiator.next_token()
    end

