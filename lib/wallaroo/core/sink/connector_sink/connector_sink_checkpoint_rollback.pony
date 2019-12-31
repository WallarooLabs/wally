/*

Copyright 2019 The Wallaroo Authors.

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

use "wallaroo/core/barrier"
use "wallaroo/core/checkpoint"
use "wallaroo/core/sink"
use cwm = "wallaroo_labs/connector_wire_messages"
use "wallaroo_labs/logging"
use "wallaroo_labs/mort"

/****
Boilerplate: sed -n '/BEGIN LEFT/,/END LEFT/p' connector-sink-2pc-management.dot | grep label | grep -e '->' | sed -e 's:.*label="::' -e 's:".*::' -e 's:\\n.*::g' | sed 's/://' | sort -u | awk 'BEGIN {print "trait _CpRbOps\n  fun name(): String\n";} {printf("  fun ref %s(sink: ConnectorSink ref) =>\n    _invalid_call(__loc.method_name()); Fail()\n\n", $1); }'
Missing: enter()
****/

trait _CpRbOps
  fun name(): String

  fun eq(x: _CpRbOps): Bool =>
    this is x

  fun ref abort_next_checkpoint(sink: ConnectorSink ref) =>
    _invalid_call(__loc.method_name()); Fail()

  fun ref checkpoint_complete(sink: ConnectorSink ref,
    checkpoint_id: CheckpointId)
  =>
    _invalid_call(__loc.method_name()); Fail()

  fun ref conn_ready(sink: ConnectorSink ref) =>
    _invalid_call(__loc.method_name()); Fail()

  fun ref cp_barrier_complete(sink: ConnectorSink ref,
    barrier_token: CheckpointBarrierToken, queued: Array[SinkPhaseQueued])
  =>
    _invalid_call(__loc.method_name()); Fail()

  fun ref enter(sink: ConnectorSink ref) =>
    None

  fun ref phase1_abort(sink: ConnectorSink ref, txn_id: String) =>
    _invalid_call(__loc.method_name()); Fail()

  fun ref phase1_commit(sink: ConnectorSink ref, txn_id: String) =>
    _invalid_call(__loc.method_name()); Fail()

  fun ref prepare_for_rollback(sink: ConnectorSink ref) =>
    _CpRbTransition(this, _CpRbPreparedForRollback, sink)

  fun ref rollback(sink: ConnectorSink ref,
    barrier_token: CheckpointBarrierToken) =>
    _invalid_call(__loc.method_name()); Fail()

  fun ref rollbackresume_barrier_complete(sink: ConnectorSink ref) =>
    _invalid_call(__loc.method_name()); Fail()

  fun _invalid_call(method_name: String) =>
    @l(Log.crit(), Log.conn_sink(),
      "Invalid call to %s on _CpRbOps state %s".cstring(),
      method_name.cstring(), name().cstring())

primitive _CpRbTransition
  fun apply(curr: _CpRbOps, next: _CpRbOps, sink: ConnectorSink ref) =>
    @l(Log.debug(), Log.conn_sink(),
      "CpRbTransition:: %s -> %s".cstring(),
      curr.name().cstring(), next.name().cstring())
    // We must update sink's _cprb pointer before calling .enter()!
    // Otherwise, if .enter() also updates the _cprb pointer, then
    // a pointer update will get clobbered & lost.
    sink._update_cprb_member(next)
    next.enter(sink)
    @l(Log.debug(), Log.conn_sink(),
      "CpRbTransition:: %s -> %s DONE".cstring(),
      curr.name().cstring(), next.name().cstring())

/****
Boilerplate: sed -n '/BEGIN LEFT/,/END LEFT/p' connector-sink-2pc-management.dot | grep -e '->' | awk '{print $1}' | sort -u | grep -v START | awk '{ printf("class _CpRb%s is _CpRbOps\n  fun name(): String => __loc.type_name()\n\n", $1); }'
****/

class _CpRbAbortCheckpoint is _CpRbOps
  var _checkpoint_to_abort: (None | CheckpointBarrierToken)
  var _abort_sent: Bool = false
  let _send_phase1: Bool

  fun name(): String => __loc.type_name()

  new create(checkpoint_to_abort: (None | CheckpointBarrierToken)) =>
    _checkpoint_to_abort = checkpoint_to_abort
    _send_phase1 = match checkpoint_to_abort
      | None =>
        true
      else
        false
      end

  fun ref enter(sink: ConnectorSink ref) =>
    match sink.cprb_check_sink_phase_partial_barrier()
    | None =>
      None
    | let cbt: CheckpointBarrierToken =>
      @l(Log.info(), Log.conn_sink(),
        "_CpRbAbortCheckpoint: detected shear with token %s".cstring(),
          cbt.string().cstring())
      match _checkpoint_to_abort
      | None =>
        // Do not update _checkpoint_to_abort now: we now know that a
        // barrier is in progress, but we cannot act on that knowledge.
        // Instead, do nothing and wait for the token's completion event
        // to arrive.
        None
        // _checkpoint_to_abort = cbt
      | let cpta: CheckpointBarrierToken =>
        if cpta != cbt then
          @l(Log.err(), Log.conn_sink(),
            "Expected %s but partial barrier is %s".cstring(),
            _checkpoint_to_abort.string().cstring(), cbt.string().cstring())
          Fail()
        end
      /**** compiler says this is unreachable:
      | let x: BarrierToken =>
        @l(Log.err(), Log.conn_sink(),
          "Unexpected barrier %s".cstring(), x.string().cstring())
        Fail()
      ****/
      end
    end
    _ChangeSinkPhaseQueueMsgsForwardTokens(sink where shear_risk = true)
    _is_checkpoint_id_known(sink)

  fun ref _is_checkpoint_id_known(sink: ConnectorSink ref) =>
    match _checkpoint_to_abort
    | let cbt: CheckpointBarrierToken =>
      if not _abort_sent then
        // Do not send 2PC commands here.  Though we can assume that
        // ExtConn's TCP connection is still established, we don't know.
        // Downstream processing later will take care of all scenarios.
        let txn_id = sink.cprb_make_txn_id_string(cbt.id)
        sink.cprb_send_abort_to_barrier_coordinator(cbt, txn_id)
        _abort_sent = true
      end
    end

  fun ref abort_next_checkpoint(sink: ConnectorSink ref) =>
    None

  fun ref checkpoint_complete(sink: ConnectorSink ref,
    checkpoint_id: CheckpointId)
  =>
    // This checkpoint is complete, so there's no way that we can
    // abort it later.  We must wait for the next checkpoint to
    // start.
    _checkpoint_to_abort = None

  fun ref phase1_abort(sink: ConnectorSink ref, txn_id: String) =>
    // This is in response to the 2PC Phase1 message that we (probably)
    // sent in _is_checkpoint_id_known().
    // Call _is_checkpoint_id_known(), just in case.
    _is_checkpoint_id_known(sink)

  fun ref cp_barrier_complete(sink: ConnectorSink ref,
    barrier_token: CheckpointBarrierToken, queued: Array[SinkPhaseQueued])
  =>
    _checkpoint_to_abort = barrier_token
    _abort_sent = false
    _is_checkpoint_id_known(sink)

  // The only event that will move us out of _CpRbAbortCheckpoint
  // is prepare_for_rollback; the trait's default implementation is
  // sufficient for us.

  fun ref rollback(sink: ConnectorSink ref,
    barrier_token: CheckpointBarrierToken)
  =>
    // We are very early in the startup process and are recovering.
    // Let's roll back.
    // However, we need to change phase first, and we must avoid shear.
    @l(Log.err(), Log.conn_sink(),
      "TODOTODOTODOTODOTODOTODOTODOTODO early rollback at %s!".cstring(), __loc.type_name().cstring())
    sink.cprb_send_advertise_status(false)
    _ChangeSinkPhaseQueueMsgsForwardTokens(sink where shear_risk = true)
    _CpRbTransition(this, _CpRbRollingBack(barrier_token), sink)

class _CpRbCPGotLocalCommit is _CpRbOps
  let _barrier_token: CheckpointBarrierToken

  new create(barrier_token: CheckpointBarrierToken) =>
    _barrier_token = barrier_token

  fun name(): String => __loc.type_name()

  fun ref enter(sink: ConnectorSink ref) =>
    sink.cprb_send_commit_to_barrier_coordinator(_barrier_token)
    @l(Log.info(), Log.conn_sink(),
      "QQQ: enter: get member 0x%lx this 0x%lx".cstring(), sink._get_cprb_member(), this)
/****
    if _barrier_token.id == 5 then
      @l(Log.info(), Log.conn_sink(),
        "QQQ: DISCONNECT HACK".cstring())
      sink.cprb_inject_hard_close()
    end
****/

  fun ref checkpoint_complete(sink: ConnectorSink ref,
    checkpoint_id: CheckpointId)
  =>
    if checkpoint_id != _barrier_token.id then
      @l(Log.crit(), Log.conn_sink(),
        "checkpoint_complete got id %lu but expected %lu".cstring(),
        checkpoint_id, _barrier_token.id)
      Fail()
    end
    let txn_id = sink.cprb_make_txn_id_string(_barrier_token.id)
    sink.cprb_send_2pc_phase2(txn_id, true)

    if sink._get_cprb_member() is this then
      _CpRbTransition(this, _CpRbWaitingForCheckpoint, sink)
    else
      @l(Log.info(), Log.conn_sink(),
        "QQQ: Control inversion: the Phase 2 send command failed, and we have already made a CpRb state transition.".cstring())
      @l(Log.info(), Log.conn_sink(),
        "QQQ: foo: get member 0x%lx this 0x%lx".cstring(), sink._get_cprb_member(), this)
      // No explicit transition here -- use the transition already specified
    end

  fun ref abort_next_checkpoint(sink: ConnectorSink ref) =>
    // Do not send 2PC commands here.  Though we can assume that
    // ExtConn's TCP connection is still established, we don't know.
    // Downstream processing later will take care of all scenarios.
    //
    // We don't know the global commit/abort status of _barrier_token yet.
    // So do not pass it along to _CpRbAbortCheckpoint.
    _CpRbTransition(this, _CpRbAbortCheckpoint(None), sink)

class _CpRbCPStarts is _CpRbOps
  let _barrier_token: CheckpointBarrierToken
  let _queued: Array[SinkPhaseQueued]

  new create(barrier_token: CheckpointBarrierToken,
    queued: Array[SinkPhaseQueued])
  =>
    _barrier_token = barrier_token
    _queued = queued

  fun name(): String => __loc.type_name()

  fun ref enter(sink: ConnectorSink ref) =>
    sink.swap_barrier_to_queued(where queue = _queued, forward_tokens = true)
    sink.cprb_send_2pc_phase1(_barrier_token)

  fun ref abort_next_checkpoint(sink: ConnectorSink ref) =>
    _CpRbTransition(this, _CpRbAbortCheckpoint(_barrier_token), sink)

  fun ref phase1_abort(sink: ConnectorSink ref, txn_id: String) =>
    let expected_txn_id = sink.cprb_make_txn_id_string(_barrier_token.id)
    if txn_id != expected_txn_id then
      @l(Log.crit(), Log.conn_sink(),
        "Got txn_id %s but expected %s".cstring(),
        txn_id.cstring(), expected_txn_id.cstring())
      Fail()
    end
    // Do not send 2PC commands here.  Though we can assume that
    // ExtConn's TCP connection is still established, we don't know.
    // Downstream processing later will take care of all scenarios.
    _CpRbTransition(this, _CpRbAbortCheckpoint(_barrier_token), sink)

  fun ref phase1_commit(sink: ConnectorSink ref, txn_id: String) =>
    let expected_txn_id = sink.cprb_make_txn_id_string(_barrier_token.id)
    if txn_id != expected_txn_id then
      @l(Log.crit(), Log.conn_sink(),
        "Got txn_id %s but expected %s".cstring(),
        txn_id.cstring(), expected_txn_id.cstring())
      Fail()
    end
    _CpRbTransition(this, _CpRbCPGotLocalCommit(_barrier_token), sink)

class _CpRbInit is _CpRbOps
  fun name(): String => __loc.type_name()

  fun ref enter(sink: ConnectorSink ref) =>
    sink.swap_barrier_to_queued(where forward_tokens = false)

  fun ref abort_next_checkpoint(sink: ConnectorSink ref) =>
    // Oops, the sink connected but didn't finish protocol intro stuff
    // before it was disconnected.  Try again.
    sink.cprb_send_advertise_status(false)
    this

  fun ref checkpoint_complete(sink: ConnectorSink ref,
    checkpoint_id: CheckpointId)
  =>
    // We are very early in the startup process and are recovering.
    // Ignore it.
    @l(Log.debug(), Log.conn_sink(),
      "State _CpRbInit event checkpoint_complete: ignore".cstring())
    this

  fun ref conn_ready(sink: ConnectorSink ref) =>
    _CpRbTransition(this, _CpRbWaitingForCheckpoint, sink)

  fun ref prepare_for_rollback(sink: ConnectorSink ref) =>
    // We are very early in the startup process and are recovering.
    // Let's prepare to roll back.
    @l(Log.debug(), Log.conn_sink(),
      "State _CpRbInit event prepare_for_rollback: transition to _CpRbPreparedForRollback".cstring())
    sink.cprb_send_advertise_status(false)
    _CpRbTransition(this, _CpRbPreparedForRollback, sink)

  fun ref rollback(sink: ConnectorSink ref,
    barrier_token: CheckpointBarrierToken)
  =>
    // We are very early in the startup process and are recovering.
    // Let's roll back.
    // However, we need to change phase first, and we must avoid shear.
    @l(Log.err(), Log.conn_sink(),
      "TODOTODOTODOTODOTODOTODOTODOTODO early rollback at %s!".cstring(), __loc.type_name().cstring())
    sink.cprb_send_advertise_status(false)
    _ChangeSinkPhaseQueueMsgsForwardTokens(sink where shear_risk = true)
    _CpRbTransition(this, _CpRbRollingBack(barrier_token), sink)

class _CpRbPreparedForRollback is _CpRbOps
  fun name(): String => __loc.type_name()

  fun ref enter(sink: ConnectorSink ref) =>
    _ChangeSinkPhaseQueueMsgsForwardTokens(sink)
    sink.cprb_inject_hard_close()

  fun ref abort_next_checkpoint(sink: ConnectorSink ref) =>
    None

  fun ref cp_barrier_complete(sink: ConnectorSink ref,
    barrier_token: CheckpointBarrierToken, queued: Array[SinkPhaseQueued])
  =>
    // Sneaky timer + barrier race.
    // Ignore it: we're waiting for rollback.
    @l(Log.err(), Log.conn_sink(),
      "TODOTODOTODOTODOTODOTODOTODOTODO Sneaky timer + barrier race for %s".cstring(), barrier_token.string().cstring())
    this

  fun ref rollback(sink: ConnectorSink ref,
    barrier_token: CheckpointBarrierToken)
  =>
    _CpRbTransition(this, _CpRbRollingBack(barrier_token), sink)

class _CpRbRollingBack is _CpRbOps
  let _barrier_token: CheckpointBarrierToken

  fun name(): String => __loc.type_name()

  new create(barrier_token: CheckpointBarrierToken) =>
    _barrier_token = barrier_token

  fun ref enter(sink: ConnectorSink ref) =>
    // Any kind of token may arrive now that the RollbackBarrierToken
    // has arrived.  In fact, some tokens might be queued right now.
    // Ignore any queued app messages, fetch the queued tokens, then
    // switch to the unconditional QueuedSinkPhase.
    sink.cprb_queuing_barrier_drop_app_msgs()
    // Reset ConnectorSink2PC's txn_id state (used for sanity checking)
    sink.cprb_twopc_clear_txn_id()

    // Handle shear scenario in these two steps
    let queued = sink.cprb_get_phase_queued()
    sink.swap_barrier_to_queued(where queue = queued, forward_tokens = false)

    sink.cprb_send_rollback_info(_barrier_token)
    // Don't change advertise_status here: wait until after rollback is
    // complete.  Then, when we send advertise=true, we might be notified
    // right away because the connection is already ready.
    // sink.cprb_send_advertise_status(true)

  fun ref abort_next_checkpoint(sink: ConnectorSink ref) =>
    // We turned advertise_status on when we entered; this message tells
    // us that it's off.  We need it on again.
    sink.cprb_send_advertise_status(true)
    // To avoid deadlock, resend rollback_info, just in case.
    sink.cprb_send_rollback_info(_barrier_token)

  fun ref rollbackresume_barrier_complete(sink: ConnectorSink ref) =>
    _CpRbTransition(this, _CpRbRollingBackResumed(_barrier_token), sink)

class _CpRbRollingBackResumed is _CpRbOps
  let _barrier_token: CheckpointBarrierToken

  fun name(): String => __loc.type_name()

  new create(barrier_token: CheckpointBarrierToken) =>
    _barrier_token = barrier_token

  fun ref enter(sink: ConnectorSink ref) =>
    sink.cprb_send_advertise_status(true)

  fun ref conn_ready(sink: ConnectorSink ref) =>
    //// @l(Log.err(), Log.conn_sink(), "TODOTODOTODOTODOTODOTODOTODOTODO any app action, such as unmuting?".cstring())
    _CpRbTransition(this, _CpRbWaitingForCheckpoint, sink)

  fun ref abort_next_checkpoint(sink: ConnectorSink ref) =>
    // We turned advertise_status on when we entered; this message tells
    // us that it's off.  We need it on again.
    sink.cprb_send_advertise_status(true)
    // To avoid deadlock, resend rollback_info, just in case.
    sink.cprb_send_rollback_info(_barrier_token)

  fun ref checkpoint_complete(sink: ConnectorSink ref,
    checkpoint_id: CheckpointId)
  =>
    Fail() ; Fail() ; Fail()
    Fail() ; Fail() ; Fail()
    Fail() ; Fail() ; Fail()
    Fail() ; Fail() ; Fail()
    Fail() ; Fail() ; Fail()
    // This checkpoint is the one that is triggered immediately after
    // rollback is complete.  Our sink phase has prevented any new
    // output to reach the sink.
    // Nothing to do here: with no output to sink, there's no need for
    // a 2PC round.
    @l(Log.info(), Log.conn_sink(),
      "No 2PC activity during CheckpointId %lu at %s.%s".cstring(),
        checkpoint_id, __loc.type_name().cstring(), __loc.method_name().cstring())

  fun ref cp_barrier_complete(sink: ConnectorSink ref,
    barrier_token: CheckpointBarrierToken, queued: Array[SinkPhaseQueued])
  =>
    Fail() ; Fail() ; Fail()
    Fail() ; Fail() ; Fail()
    Fail() ; Fail() ; Fail()
    Fail() ; Fail() ; Fail()
    Fail() ; Fail() ; Fail()
    // This checkpoint is the one that is triggered immediately after
    // rollback is complete.  Our sink phase has prevented any new
    // output to reach the sink.
    // Ack now with current token, because our state's token may be quite old.
    sink.cprb_send_commit_to_barrier_coordinator(barrier_token)
    @l(Log.info(), Log.conn_sink(),
      "No 2PC activity during CheckpointId %lu at %s.%s".cstring(),
        barrier_token.id, __loc.type_name().cstring(), __loc.method_name().cstring())

class _CpRbWaitingForCheckpoint is _CpRbOps
  fun name(): String => __loc.type_name()

  fun ref enter(sink: ConnectorSink ref) =>
    sink.resume_processing_messages_queued()

  fun ref abort_next_checkpoint(sink: ConnectorSink ref) =>
    _CpRbTransition(this, _CpRbAbortCheckpoint(None), sink)

  fun ref checkpoint_complete(sink: ConnectorSink ref,
    checkpoint_id: CheckpointId)
  =>
    // This checkpoint is the one that is triggered immediately after
    // the last rollback was complete and started during
    // RollingBackResumed.  Our sink phase has prevented any new output
    // to reach the sink during that last rollback. There was no 2PC
    // round during that last checkpoint
    @l(Log.info(), Log.conn_sink(),
      "No PC activity during CheckpointId %lu at %s.%s".cstring(),
        checkpoint_id, __loc.type_name().cstring(), __loc.method_name().cstring())

  fun ref cp_barrier_complete(sink: ConnectorSink ref,
    barrier_token: CheckpointBarrierToken, queued: Array[SinkPhaseQueued])
  =>
    _CpRbTransition(this, _CpRbCPStarts(barrier_token, queued), sink)

  fun ref prepare_for_rollback(sink: ConnectorSink ref) =>
    _CpRbTransition(this, _CpRbPreparedForRollback, sink)

  fun ref rollback(sink: ConnectorSink ref,
    barrier_token: CheckpointBarrierToken)
  =>
    // We are very early in the startup process and are recovering.
    // Let's roll back.
    // However, we need to change phase first, and we must avoid shear.
    @l(Log.err(), Log.conn_sink(),
      "TODOTODOTODOTODOTODOTODOTODOTODO early rollback at %s!".cstring(), __loc.type_name().cstring())
    sink.cprb_send_advertise_status(false)
    _ChangeSinkPhaseQueueMsgsForwardTokens(sink where shear_risk = true)
    _CpRbTransition(this, _CpRbRollingBack(barrier_token), sink)

primitive _ChangeSinkPhaseQueueMsgsForwardTokens
  fun apply(sink: ConnectorSink ref, shear_risk: Bool = false) =>
    sink.swap_barrier_to_queued(where forward_tokens = true, shear_risk = shear_risk)
