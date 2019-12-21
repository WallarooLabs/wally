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
Boilerplate: sed -n '/BEGIN LEFT/,/END LEFT/p' connector-sink-2pc-management.dot | grep label | grep -e '->' | sed -e 's:.*label="::' -e 's:".*::' -e 's:\\n.*::g' | sed 's/://' | sort -u | awk 'BEGIN {print "trait _CpRbOps\n  fun name(): String\n";} {printf("  fun ref %s(sink: ConnectorSink ref):\n    _CpRbOps ref\n  =>\n    _invalid_call(__loc.method_name()); Fail(); this\n\n", $1); }'
Missing: enter()
****/

trait _CpRbOps
  fun name(): String

  fun ref abort_next_checkpoint(sink: ConnectorSink ref):
    _CpRbOps ref
  =>
    _invalid_call(__loc.method_name()); Fail(); this

  fun ref checkpoint_complete(sink: ConnectorSink ref,
    checkpoint_id: CheckpointId): _CpRbOps ref
  =>
    _invalid_call(__loc.method_name()); Fail(); this

  fun ref conn_ready(sink: ConnectorSink ref):
    _CpRbOps ref
  =>
    _invalid_call(__loc.method_name()); Fail(); this

  fun ref cp_barrier_complete(sink: ConnectorSink ref,
    barrier_token: CheckpointBarrierToken, queued: Array[SinkPhaseQueued]):
    _CpRbOps ref
  =>
    _invalid_call(__loc.method_name()); Fail(); this

  fun ref enter(sink: ConnectorSink ref) =>
    None

  fun ref phase1_abort(sink: ConnectorSink ref, txn_id: String):
    _CpRbOps ref
  =>
    _invalid_call(__loc.method_name()); Fail(); this

  fun ref phase1_commit(sink: ConnectorSink ref, txn_id: String):
    _CpRbOps ref
  =>
    _invalid_call(__loc.method_name()); Fail(); this

  fun ref prepare_for_rollback(sink: ConnectorSink ref):
    _CpRbOps ref
  =>
    _CpRbTransition(this, _CpRbPreparedForRollback, sink)

  fun ref rollback(sink: ConnectorSink ref,
    barrier_token: CheckpointBarrierToken): _CpRbOps ref
  =>
    _invalid_call(__loc.method_name()); Fail(); this

  fun ref rollbackresume_barrier_complete(sink: ConnectorSink ref):
    _CpRbOps ref
  =>
    _invalid_call(__loc.method_name()); Fail(); this

  fun _invalid_call(method_name: String) =>
    @l(Log.crit(), Log.conn_sink(),
      "Invalid call to %s on _CpRbOps state %s".cstring(),
      method_name.cstring(), name().cstring())

primitive _CpRbTransition
  fun apply(curr: _CpRbOps, next: _CpRbOps, sink: ConnectorSink ref)
    : _CpRbOps
  =>
    @l(Log.debug(), Log.conn_sink(),
      "CpRbTransition:: %s -> %s".cstring(),
      curr.name().cstring(), next.name().cstring())
    next.enter(sink)
    next

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
    _ChangeSinkPhaseDropAllQueuedMsgs(sink)
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

  fun ref abort_next_checkpoint(sink: ConnectorSink ref):
    _CpRbOps ref
  =>
    this

  fun ref checkpoint_complete(sink: ConnectorSink ref,
    checkpoint_id: CheckpointId): _CpRbOps ref
  =>
    // This checkpoint is complete, so there's no way that we can
    // abort it later.  We must wait for the next checkpoint to
    // start.
    _checkpoint_to_abort = None
    this

  fun ref phase1_abort(sink: ConnectorSink ref, txn_id: String):
    _CpRbOps ref
  =>
    // This is in response to the 2PC Phase1 message that we (probably)
    // sent in _is_checkpoint_id_known().
    // Call _is_checkpoint_id_known(), just in case.
    _is_checkpoint_id_known(sink)
    this

  fun ref cp_barrier_complete(sink: ConnectorSink ref,
    barrier_token: CheckpointBarrierToken, queued: Array[SinkPhaseQueued]):
    _CpRbOps ref
  =>
    _checkpoint_to_abort = barrier_token
    _abort_sent = false
    _is_checkpoint_id_known(sink)
    this

  // The only event that will move us out of _CpRbAbortCheckpoint
  // is prepare_for_rollback; the trait's default implementation is
  // sufficient for us.

class _CpRbCPGotLocalCommit is _CpRbOps
  let _barrier_token: CheckpointBarrierToken

  new create(barrier_token: CheckpointBarrierToken) =>
    _barrier_token = barrier_token

  fun name(): String => __loc.type_name()

  fun ref enter(sink: ConnectorSink ref) =>
    sink.cprb_send_commit_to_barrier_coordinator(_barrier_token)
    if _barrier_token.id == 5 then
      @l(Log.info(), Log.conn_sink(),
        "QQQ: DISCONNECT HACK".cstring())
      sink.cprb_inject_hard_close()
    end

  fun ref checkpoint_complete(sink: ConnectorSink ref,
    checkpoint_id: CheckpointId): _CpRbOps ref
  =>
    if checkpoint_id != _barrier_token.id then
      @l(Log.crit(), Log.conn_sink(),
        "checkpoint_complete got id %lu but expected %lu".cstring(),
        checkpoint_id, _barrier_token.id)
      Fail()
    end
    let txn_id = sink.cprb_make_txn_id_string(_barrier_token.id)
    sink.cprb_send_2pc_phase2(txn_id, true)

    _CpRbTransition(this, _CpRbWaitingForCheckpoint, sink)

  fun ref abort_next_checkpoint(sink: ConnectorSink ref):
    _CpRbOps ref
  =>
    // Do not send 2PC commands here.  Though we can assume that
    // ExtConn's TCP connection is still established, we don't know.
    // Downstream processing later will take care of all scenarios.
    _CpRbTransition(this, _CpRbAbortCheckpoint(_barrier_token), sink)

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

  fun ref abort_next_checkpoint(sink: ConnectorSink ref):
    _CpRbOps ref
  =>
    _CpRbTransition(this, _CpRbAbortCheckpoint(_barrier_token), sink)

  fun ref phase1_abort(sink: ConnectorSink ref, txn_id: String):
    _CpRbOps ref
  =>
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

  fun ref phase1_commit(sink: ConnectorSink ref, txn_id: String):
    _CpRbOps ref
  =>
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

  fun ref conn_ready(sink: ConnectorSink ref): _CpRbOps =>
    _CpRbTransition(this, _CpRbWaitingForCheckpoint, sink)

  fun ref prepare_for_rollback(sink: ConnectorSink ref):
    _CpRbOps ref
  =>
    _invalid_call(__loc.method_name()); Fail(); this

class _CpRbPreparedForRollback is _CpRbOps
  fun name(): String => __loc.type_name()

  fun ref enter(sink: ConnectorSink ref) =>
    sink.swap_barrier_to_queued(where forward_tokens = true)
    sink.cprb_inject_hard_close()

  fun ref abort_next_checkpoint(sink: ConnectorSink ref):
    _CpRbOps ref
  =>
    this

  fun ref rollback(sink: ConnectorSink ref,
    barrier_token: CheckpointBarrierToken): _CpRbOps ref
  =>
    _CpRbTransition(this, _CpRbRollingBack(barrier_token), sink)

class _CpRbRolledBack is _CpRbOps
  fun name(): String => __loc.type_name()

  fun ref enter(sink: ConnectorSink ref) =>
    _ChangeSinkPhaseDropAllQueuedMsgs(sink)

  fun ref abort_next_checkpoint(sink: ConnectorSink ref):
    _CpRbOps ref
  =>
    // We turned advertise_status on when we entered; this message tells
    // us that it's off.  We need it on again.
    sink.cprb_send_advertise_status(true)
    this

  fun ref prepare_for_rollback(sink: ConnectorSink ref): _CpRbOps =>
    _CpRbTransition(this, _CpRbPreparedForRollback, sink)

  fun ref rollbackresume_barrier_complete(sink: ConnectorSink ref):
    _CpRbOps ref
  =>
    _ChangeSinkPhaseDropAllQueuedMsgs(sink)
    _CpRbTransition(this, _CpRbWaitingForCheckpoint, sink)

class _CpRbRollingBack is _CpRbOps
  let _barrier_token: CheckpointBarrierToken

  fun name(): String => __loc.type_name()

  new create(barrier_token: CheckpointBarrierToken) =>
    _barrier_token = barrier_token

  fun ref enter(sink: ConnectorSink ref) =>
    _ChangeSinkPhaseDropAllQueuedMsgs(sink)
    sink.cprb_send_rollback_info(_barrier_token)
    sink.cprb_send_advertise_status(true)

  fun ref abort_next_checkpoint(sink: ConnectorSink ref):
    _CpRbOps ref
  =>
    // We turned advertise_status on when we entered; this message tells
    // us that it's off.  We need it on again.
    sink.cprb_send_advertise_status(true)
    // To avoid deadlock, resend rollback_info, just in case.
    sink.cprb_send_rollback_info(_barrier_token)
    this

  fun ref conn_ready(sink: ConnectorSink ref): _CpRbOps =>
    _CpRbTransition(this, _CpRbRolledBack, sink)

  fun ref rollbackresume_barrier_complete(sink: ConnectorSink ref): _CpRbOps =>
    _CpRbTransition(this, _CpRbRollingBackResumed(_barrier_token), sink)

class _CpRbRollingBackResumed is _CpRbOps
  let _barrier_token: CheckpointBarrierToken

  fun name(): String => __loc.type_name()

  new create(barrier_token: CheckpointBarrierToken) =>
    _barrier_token = barrier_token

  fun ref conn_ready(sink: ConnectorSink ref): _CpRbOps =>
    _ChangeSinkPhaseDropAllQueuedMsgs(sink)
    _CpRbTransition(this, _CpRbWaitingForCheckpoint, sink)

  fun ref abort_next_checkpoint(sink: ConnectorSink ref):
    _CpRbOps ref
  =>
    // We turned advertise_status on when we entered; this message tells
    // us that it's off.  We need it on again.
    sink.cprb_send_advertise_status(true)
    // To avoid deadlock, resend rollback_info, just in case.
    sink.cprb_send_rollback_info(_barrier_token)
    this

  fun ref cp_barrier_complete(sink: ConnectorSink ref,
    barrier_token: CheckpointBarrierToken, queued: Array[SinkPhaseQueued]):
    _CpRbOps ref
  =>
    // This checkpoint is the one that is triggered immediately after
    // rollback is complete.  Our sink phase has prevented any new
    // output to reach the sink.  Ack now.
    sink.cprb_send_commit_to_barrier_coordinator(_barrier_token)
    this

class _CpRbWaitingForCheckpoint is _CpRbOps
  fun name(): String => __loc.type_name()

  fun ref enter(sink: ConnectorSink ref) =>
    sink.resume_processing_messages_queued()

  fun ref abort_next_checkpoint(sink: ConnectorSink ref):
    _CpRbOps ref
  =>
    _CpRbTransition(this, _CpRbAbortCheckpoint(None), sink)

  fun ref cp_barrier_complete(sink: ConnectorSink ref,
    barrier_token: CheckpointBarrierToken, queued: Array[SinkPhaseQueued]):
    _CpRbOps ref
  =>
    _CpRbTransition(this, _CpRbCPStarts(barrier_token, queued), sink)

  fun ref prepare_for_rollback(sink: ConnectorSink ref): _CpRbOps =>
    _CpRbTransition(this, _CpRbPreparedForRollback, sink)

primitive _ChangeSinkPhaseDropAllQueuedMsgs
  fun apply(sink: ConnectorSink ref) =>
    // Change sink phase, dropping all queued messages
    sink.swap_barrier_to_queued(where forward_tokens = true)
