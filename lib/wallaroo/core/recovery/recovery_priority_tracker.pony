use "promises"
use "wallaroo/core/boundary"
use "wallaroo/core/checkpoint"
use "wallaroo/core/common"
use "wallaroo_labs/mort"


class RecoveryPriorityTracker
  let _initial_recovery_reason: RecoveryReason
  var _override_worker: (WorkerName | None) = None
  var _highest_rival_rollback_id: RollbackId = 0
  var _abort_promise: (Promise[None] | None) = None

  new create(reason: RecoveryReason) =>
    _initial_recovery_reason = reason

  fun ref try_override(worker: WorkerName, rollback_id: RollbackId,
    reason: RecoveryReason, recovery: Recovery ref,
    abort_promise: Promise[None])
  =>
    if RecoveryReasons.has_priority(reason, _initial_recovery_reason) or
       (not RecoveryReasons.has_priority(_initial_recovery_reason, reason) and
         (rollback_id > _highest_rival_rollback_id))
    then
      @printf[I32](("RECOVERY: Waiting to cede control until " +
        "boundaries are reconnected and producers are registered.\n")
        .cstring())
      _highest_rival_rollback_id = rollback_id
      _override_worker = worker
      _abort_promise = abort_promise
    end

  fun has_override(): Bool =>
    match _abort_promise
    | let p: Promise[None] => true
    else
      false
    end

  fun initiate_abort(recovery: Recovery ref) =>
    match _override_worker
    | let ow: WorkerName =>
      match _abort_promise
      | let p: Promise[None] => p(None)
      else
        Fail()
      end
      recovery._abort_early(ow)
    else
      Fail()
    end
