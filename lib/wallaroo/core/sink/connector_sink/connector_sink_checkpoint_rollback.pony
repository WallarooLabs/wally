/*

Copyright 2019-2020 The Wallaroo Authors.

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

trait _CpRbOps
  """
  aka, "checkpoint/rollback operations".

  This trait describes the FSM used to manage high-level operation of
  this sink and Wallaroo's overall status (e.g., starting, rolling back,
  running) together with _ExtConnOps's mid-level management of the TCP
  connection.  See the FSM state diagram on the lefthand side of
  connector-sink-2pc-management.png.
  """

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
    barrier_token: CheckpointBarrierToken)
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
    let debug: LogSevCat = Log.make_sev_cat(Log.debug(), Log.conn_sink())

    @ll(debug, "CpRbTransition:: %s -> %s".cstring(),
      curr.name().cstring(), next.name().cstring())
    // We must update sink's _cprb pointer before calling .enter()!
    // Otherwise, if .enter() also updates the _cprb pointer, then
    // a pointer update will get clobbered & lost.
    sink._update_cprb_member(next)
    next.enter(sink)
    @ll(debug, "CpRbTransition:: %s -> %s DONE".cstring(),
      curr.name().cstring(), next.name().cstring())

class _CpRbAbortCheckpoint is _CpRbOps
  let _debug: LogSevCat = Log.make_sev_cat(Log.debug(), Log.conn_sink())
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
    sink.cprb_send_advertise_status(false)
    _ChangeSinkPhaseQueueMsgsForwardTokens(sink)
    _abort_if_checkpoint_id_known(sink)

  fun ref _abort_if_checkpoint_id_known(sink: ConnectorSink ref) =>
    match _checkpoint_to_abort
    | let cbt: CheckpointBarrierToken =>
      if not _abort_sent then
        // Do not send 2PC commands here.  Though we can assume that
        // ExtConn's TCP connection is still established, we don't
        // actually know the connection's state. Downstream processing
        // later will take care of all scenarios.
        let txn_id = sink.cprb_make_txn_id_string(cbt.id)
        sink.cprb_send_abort_to_barrier_coordinator(cbt, txn_id)
        _abort_sent = true
      end
    end

  fun ref checkpoint_complete(sink: ConnectorSink ref,
    checkpoint_id: CheckpointId)
  =>
    // This checkpoint is complete, so there's no way that we can
    // abort it later.  We must wait for the next checkpoint to
    // start.
    _checkpoint_to_abort = None

  fun ref phase1_abort(sink: ConnectorSink ref, txn_id: String) =>
    // This is in response to the 2PC Phase1 message that we (probably)
    // sent in _abort_if_checkpoint_id_known().
    // Call _abort_if_checkpoint_id_known(), just in case.
    _abort_if_checkpoint_id_known(sink)

  fun ref cp_barrier_complete(sink: ConnectorSink ref,
    barrier_token: CheckpointBarrierToken)
  =>
    _checkpoint_to_abort = barrier_token
    _abort_sent = false
    _abort_if_checkpoint_id_known(sink)

  // The only event that will move us out of _CpRbAbortCheckpoint
  // is prepare_for_rollback; the trait's default implementation is
  // sufficient for us.

  fun ref rollback(sink: ConnectorSink ref,
    barrier_token: CheckpointBarrierToken)
  =>
    @ll(_debug, "Rollback: at %s!".cstring(), __loc.type_name().cstring())
    sink.cprb_send_advertise_status(false)
    _ChangeSinkPhaseQueueMsgsForwardTokens(sink)
    _CpRbTransition(this, _CpRbRollingBack(barrier_token, true), sink)

class _CpRbCPGotLocalCommit is _CpRbOps
  let _debug: LogSevCat = Log.make_sev_cat(Log.debug(), Log.conn_sink())
  let _barrier_token: CheckpointBarrierToken

  new create(barrier_token: CheckpointBarrierToken) =>
    _barrier_token = barrier_token

  fun name(): String => __loc.type_name()

  fun ref enter(sink: ConnectorSink ref) =>
    sink.cprb_send_commit_to_barrier_coordinator(_barrier_token)

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
        "Control inversion: the Phase 2 send command failed, and we have already made a CpRb state transition.".cstring())
      // No explicit transition here -- use the transition already specified
    end

  fun ref abort_next_checkpoint(sink: ConnectorSink ref) =>
    // Do not send 2PC commands here.  Though we can assume that
    // ExtConn's TCP connection is still established, we don't
    // actually know the connection's state. Downstream processing
    // later will take care of all scenarios.
    //
    // We don't know the global commit/abort status of _barrier_token yet.
    // So do not pass it along to _CpRbAbortCheckpoint.
    _CpRbTransition(this, _CpRbAbortCheckpoint(None), sink)

class _CpRbCPStarts is _CpRbOps
  let _debug: LogSevCat = Log.make_sev_cat(Log.debug(), Log.conn_sink())
  let _barrier_token: CheckpointBarrierToken

  new create(barrier_token: CheckpointBarrierToken) =>
    _barrier_token = barrier_token

  fun name(): String => __loc.type_name()

  fun ref enter(sink: ConnectorSink ref) =>
    _ChangeSinkPhaseQueueMsgsForwardTokens(sink)
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
    // ExtConn's TCP connection is still established, we don't
    // actually know the connection's state. Downstream processing
    // later will take care of all scenarios.
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
  let _debug: LogSevCat = Log.make_sev_cat(Log.debug(), Log.conn_sink())
  var _cp_barrier_token: (None | CheckpointBarrierToken) = None

  fun name(): String => __loc.type_name()

  fun ref enter(sink: ConnectorSink ref) =>
    // ConnectorSink.create() has already set up the queuing phase
    None

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
    @ll(_debug,
      "State _CpRbInit event checkpoint_complete: ignore".cstring())
    this

  fun ref conn_ready(sink: ConnectorSink ref) =>
    match _cp_barrier_token
    | let cp: CheckpointBarrierToken =>
      // A CheckpointBarrierToken arrived in this state before we were
      // connected to the sink.  We've not ack'ed that barrier until
      // we are connected.  Now we are connected, so it's time to ack.
      @ll(_debug, "_CpRbInit.conn_ready: acking %s".cstring(), cp.string().cstring())
      sink.cprb_send_commit_to_barrier_coordinator(cp)
    end
    _CpRbTransition(this, _CpRbWaitingForCheckpoint, sink)

  fun ref cp_barrier_complete(sink: ConnectorSink ref,
    barrier_token: CheckpointBarrierToken)
  =>
    if barrier_token.id == 1 then
      // Don't delay processing of the first checkpoint.
      sink.cprb_send_commit_to_barrier_coordinator(barrier_token)
    else
      // We haven't connected to a sink yet, so don't ack this barrier.
      // Instead, remember it, and we'll ack it when the sink is connected.
      _cp_barrier_token = barrier_token
    end

  fun ref prepare_for_rollback(sink: ConnectorSink ref) =>
    // We are very early in the startup process and are recovering.
    // Let's prepare to roll back.
    @ll(_debug,
      "State _CpRbInit event prepare_for_rollback: transition to _CpRbPreparedForRollback".cstring())
    sink.cprb_send_advertise_status(false)

    // However, we need to change phase first, because we're queuing
    // but without forwarding tokens, and we need forwarding tokens now.
    // Switch to normal processing, and then we'll change it to queuing
    // via the state transition.
    sink.open_valve()

    _CpRbTransition(this, _CpRbPreparedForRollback, sink)

  fun ref rollback(sink: ConnectorSink ref,
    barrier_token: CheckpointBarrierToken)
  =>
    // We are very early in the startup process and are recovering.
    // Let's roll back.

    @ll(_debug, "Rollback: at %s!".cstring(), __loc.type_name().cstring())
    sink.cprb_send_advertise_status(false)

    // However, we need to change phase first, because we're queuing
    // but without forwarding tokens, and we need forwarding tokens now.
    // Switch to normal processing, and then immediately change it again.
    sink.open_valve()
    _ChangeSinkPhaseQueueMsgsForwardTokens(sink)

    _CpRbTransition(this, _CpRbRollingBack(barrier_token, true), sink)

class _CpRbPreparedForRollback is _CpRbOps
  let _debug: LogSevCat = Log.make_sev_cat(Log.debug(), Log.conn_sink())
  let _shear_risk: Bool

  new create(shear_risk: Bool = false) =>
    _shear_risk = shear_risk

  fun name(): String => __loc.type_name()

  fun ref enter(sink: ConnectorSink ref) =>
    sink.cprb_send_advertise_status(false)
    _ChangeSinkPhaseQueueMsgsForwardTokens(sink)
    sink.cprb_inject_hard_close()

  fun ref cp_barrier_complete(sink: ConnectorSink ref,
    barrier_token: CheckpointBarrierToken)
  =>
    // Sneaky timer + barrier race.
    // Ignore it: we're waiting for rollback.
    @ll(_debug,
      "cp_barrier_complete: sneaky timer + barrier race for %s".cstring(), barrier_token.string().cstring())
    this

  fun ref rollback(sink: ConnectorSink ref,
    barrier_token: CheckpointBarrierToken)
  =>
    _CpRbTransition(this, _CpRbRollingBack(barrier_token, false), sink)

  fun ref rollbackresume_barrier_complete(sink: ConnectorSink ref) =>
    // We arrive here by an interesting race: 1. prepare_for_rollback,
    // 2. rollback, then 3. a 2nd prepare_for_rollback gets us to this
    // FSM state.  However, the rollback @ step 2 has proceeded far
    // enough that a RollbackResumeBarrierToken starts flowing through
    // the system.  The events that triggered step 3 do not remove the
    // RollbackResumeBarrierToken from the system.  This method is when
    // that RollbackResumeBarrierToken has finished at this sink.
    @l(Log.info(), Log.conn_sink(), "Ignoring rollbackresume_barrier_complete event".cstring())
    this

class _CpRbRollingBack is _CpRbOps
  let _debug: LogSevCat = Log.make_sev_cat(Log.debug(), Log.conn_sink())
  let _barrier_token: CheckpointBarrierToken
  let _force_close: Bool

  fun name(): String => __loc.type_name()

  new create(barrier_token: CheckpointBarrierToken, force_close: Bool) =>
    _barrier_token = barrier_token
    _force_close = force_close

  fun ref enter(sink: ConnectorSink ref) =>
    if _force_close then
      @l(Log.debug(), Log.conn_sink(), "_CpRbRollingBack: force close".cstring())
      sink.cprb_inject_hard_close()
    end

    sink.cprb_send_advertise_status(false)

    sink.cprb_drop_app_msgs()
    // Reset ConnectorSink2PC's txn_id state (used for sanity checking)
    sink.cprb_twopc_clear_txn_id()

    _ChangeSinkPhaseQueueMsgsForwardTokens(sink)

    sink.cprb_send_rollback_info(_barrier_token)

  fun ref rollback(sink: ConnectorSink ref,
    barrier_token: CheckpointBarrierToken)
  =>
    _CpRbTransition(this, _CpRbRollingBack(barrier_token, false), sink)

  fun ref rollbackresume_barrier_complete(sink: ConnectorSink ref) =>
    _CpRbTransition(this, _CpRbRollingBackResumed(_barrier_token), sink)

class _CpRbRollingBackResumed is _CpRbOps
  let _debug: LogSevCat = Log.make_sev_cat(Log.debug(), Log.conn_sink())
  let _barrier_token: CheckpointBarrierToken

  fun name(): String => __loc.type_name()

  new create(barrier_token: CheckpointBarrierToken) =>
    _barrier_token = barrier_token

  fun ref enter(sink: ConnectorSink ref) =>
    sink.cprb_send_advertise_status(true)

  fun ref conn_ready(sink: ConnectorSink ref) =>
    _CpRbTransition(this, _CpRbWaitingForCheckpoint, sink)

  fun ref abort_next_checkpoint(sink: ConnectorSink ref) =>
    // The _ExtConnOps turned advertise_status off when this message was
    // sent.  This state needs it on again.
    sink.cprb_send_advertise_status(true)

    // To avoid deadlock, resend rollback_info, just in case.
    sink.cprb_send_rollback_info(_barrier_token)

  fun ref cp_barrier_complete(sink: ConnectorSink ref,
    barrier_token: CheckpointBarrierToken)
  =>
    // TODO: PreparedForRollback will force the sink's TCP connection closed.
    // If that connection was connected but still going through the 2PC
    // intro stuff, then we will sabotage that connection's work.
    // With Pony runtime backpressure in use, then the amount of wasted
    // work (e.g., busy looping of new checkpoint + instant abort) ought to
    // be avoided but perhaps sometimes possible.
    @l(Log.info(), Log.conn_sink(),
      "Checkpoint %s arrived at _CpRbRollingBackResumed.cp_barrier_complete, aborting it".cstring(),
        barrier_token.string().cstring())
    let txn_id = sink.cprb_make_txn_id_string(barrier_token.id)
    sink.cprb_send_abort_to_barrier_coordinator(barrier_token, txn_id)

    _CpRbTransition(this, _CpRbPreparedForRollback, sink)

  fun ref rollback(sink: ConnectorSink ref,
    barrier_token: CheckpointBarrierToken)
  =>
    _CpRbTransition(this, _CpRbRollingBack(barrier_token, false), sink)

class _CpRbWaitingForCheckpoint is _CpRbOps
  let _debug: LogSevCat = Log.make_sev_cat(Log.debug(), Log.conn_sink())
  fun name(): String => __loc.type_name()

  fun ref enter(sink: ConnectorSink ref) =>
    sink.open_valve()

  fun ref abort_next_checkpoint(sink: ConnectorSink ref) =>
    _CpRbTransition(this, _CpRbAbortCheckpoint(None), sink)

  fun ref cp_barrier_complete(sink: ConnectorSink ref,
    barrier_token: CheckpointBarrierToken)
  =>
    _CpRbTransition(this, _CpRbCPStarts(barrier_token), sink)

  fun ref prepare_for_rollback(sink: ConnectorSink ref) =>
    _CpRbTransition(this, _CpRbPreparedForRollback(where shear_risk=true), sink)

  fun ref rollback(sink: ConnectorSink ref,
    barrier_token: CheckpointBarrierToken)
  =>
    @ll(_debug, "Rollback: at %s!".cstring(), __loc.type_name().cstring())
    sink.cprb_send_advertise_status(false)
    _ChangeSinkPhaseQueueMsgsForwardTokens(sink)
    _CpRbTransition(this, _CpRbRollingBack(barrier_token, true), sink)

primitive _ChangeSinkPhaseQueueMsgsForwardTokens
  fun apply(sink: ConnectorSink ref) =>
    sink.cprb_close_valve()
