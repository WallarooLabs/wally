/*

Copyright (C) 2016-2019, Wallaroo Labs
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/

use "wallaroo/core/barrier"
use "wallaroo/core/checkpoint"
use "wallaroo_labs/connector_protocol"
use cwm = "wallaroo_labs/connector_wire_messages"
use "wallaroo_labs/logging"
use "wallaroo_labs/mort"

class ConnectorSink2PC
  var state: TwoPCFsmState = TwoPCFsmStart
  var txn_id: String = ""
  var txn_id_at_close: String = ""
  var barrier_token_initial: CheckpointBarrierToken = CheckpointBarrierToken(0)
  var barrier_token: CheckpointBarrierToken = barrier_token_initial
  var barrier_token_at_close: CheckpointBarrierToken = barrier_token_initial
  var last_offset: USize = 0
  var current_offset: USize = 0
  var current_txn_end_offset: USize = 0
  let stream_name: String
  var notify1_sent: Bool = false
  let _twopc_debug: U16 = Log.make_sev_cat(Log.debug(), Log.twopc())
  let _twopc_info: U16 = Log.make_sev_cat(Log.info(), Log.twopc())
  let _twopc_err: U16 = Log.make_sev_cat(Log.err(), Log.twopc())

  new create(stream_name': String) =>
    stream_name = stream_name'

  fun ref update_offset(encoded1_len: USize) =>
    current_offset = current_offset + encoded1_len

  fun ref reset_state() =>
    state = TwoPCFsmStart
    txn_id = ""
    barrier_token = CheckpointBarrierToken(0)
    @ll(_twopc_debug, "2PC: reset 2PC state".cstring())
    @ll(_twopc_debug, "2PC: set 2PC state => %d".cstring(), state())

  fun state_is_start(): Bool =>
    state is TwoPCFsmStart

  fun state_is_1precommit(): Bool =>
    state is TwoPCFsm1Precommit

  fun state_is_2abort(): Bool =>
    state is TwoPCFsm2Abort

  fun state_is_2commit(): Bool =>
    state is TwoPCFsm2Commit

  fun state_is_2commit_fast(): Bool =>
    state is TwoPCFsm2CommitFast

  fun ref set_state_1precommit() =>
    state = TwoPCFsm1Precommit
    @ll(_twopc_debug, "2PC: set 2PC state => %d".cstring(), state())

  fun ref set_state_commit() =>
    state = TwoPCFsm2Commit
    @ll(_twopc_debug, "2PC: set 2PC state => %d".cstring(), state())

  fun ref set_state_commit_fast() =>
    state = TwoPCFsm2CommitFast
    @ll(_twopc_debug, "2PC: set 2PC state => %d".cstring(), state())

  fun ref set_state_abort() =>
    state = TwoPCFsm2Abort
    @ll(_twopc_debug, "2PC: set 2PC state => %d".cstring(), state())

  fun ref preemptive_txn_abort(sbt: CheckpointBarrierToken) =>
    txn_id = "preemptive txn abort"
    barrier_token = sbt

  fun ref barrier_complete(sbt: CheckpointBarrierToken,
    is_rollback: Bool = false,
    stream_id: cwm.StreamId = 223344 /* arbitrary integer != 1 or 0 */):
  (None | Array[cwm.Message])
  =>
    if state_is_start() then
      // Calculate short circuit/commit-fast here.
      // Don't short circuit if we're rolling back.
      if (not is_rollback) and
         (current_offset > 0) and
         (current_offset == last_offset)
      then
        set_state_commit_fast()
        return None
      end
      if is_rollback and (current_offset == 0)
      then
        // We've rolled back and also 1. we've never sent anything
        // or 2. we still have amnesia about what we've written.
        // In either case, phase 1 isn't needed.  The phase 2 abort
        // that we send later will be harmless.
        set_state_commit_fast()
        return None
      end

      state = TwoPCFsm1Precommit
      let prefix = if is_rollback then "rollback--" else "" end
      txn_id = prefix + make_txn_id_string(sbt.id)
      barrier_token = sbt
      current_txn_end_offset = current_offset
    elseif state_is_2abort() then
      // We are here because:
      // 0. We were disconnected from the external sink.
      // 1. We saw a single CheckpointBarrierToken but not all the copies
      //    that we were expecting.
      // 2. We were reconnected to the external sink.  Since we'd seen
      //    a CheckpointBarrierToken, we'd set state to 2abort.
      //    NOTE: We also told the barrier coordinator to abort the
      //          checkpoint!
      // 3. We saw the final copy of the CheckpointBarrierToken and
      //    then got to here.
      //
      // Since some app data was sent to the sink, then we must
      // go through a round of 2PC to tell the sink to throw away
      // that data.  If no app data was sent to the sink, we would've
      // hit the commit-fast path above.
      @ll(_twopc_info, "NOTICE, need to send Phase1 and then force abort for Phase2".cstring())
    else
      @ll(_twopc_err, "2PC: ERROR: _twopc.state = %d".cstring(), state())
      Fail()
    end

    let msgs: Array[cwm.Message] = recover trn msgs.create() end
    if not notify1_sent then
      // The barrier arrived before we've sent a Notify message for
      // stream ID 1.  Our attempt to abort a byte range for stream ID 1
      // will be rejected if we don't send a notify first.
      if (not is_rollback) or (stream_id != 1) then
        Fail()
      end
      @ll(_twopc_debug, "barrier_complete: push NotifyMsg onto list for %s".cstring(), txn_id.cstring())
      msgs.push(cwm.NotifyMsg(stream_id, stream_name, 0))
    end

    @ll(_twopc_debug, "barrier_complete: push Phase1 onto list for %s".cstring(), txn_id.cstring())
    let where_list: cwm.WhereList =
      [(1, last_offset.u64(), current_offset.u64())]
    let bs = TwoPCEncode.phase1(txn_id, where_list)
    msgs.push(cwm.MessageMsg(0, 0, 0, None, bs))

    consume msgs

  fun ref checkpoint_complete(sink: ConnectorSink ref, drop_phase2_msg: Bool) =>
    if (not ((state_is_2commit()) or
             (state_is_2commit_fast())))
    then
      if state_is_start() then
        // If the connector sink disconnects immediately after we've
        // decided that the checkpoint will commit, then the disconnect
        // will call reset_state().  When the rest of Wallaroo's events
        // catch up, we'll be in this case, which is ok.
        None
      else
        @ll(_twopc_err, "2PC: DBG: _twopc.state = %s,".cstring(), state().string().cstring())
        Fail()
      end
    end

    if state_is_2commit() then
      if not drop_phase2_msg then
        send_phase2(sink, true)
      end
    end

    last_offset = current_txn_end_offset

  fun ref rollback(current_offset': USize) =>
    current_offset = current_offset'
    last_offset = current_offset'
    current_txn_end_offset = current_offset'

  fun ref hard_close() =>
    txn_id_at_close = txn_id
    barrier_token_at_close = barrier_token
    @ll(_twopc_debug, "2PC: DBG: hard_close: state = %s, txn_id_at_close = %s, barrier_token_at_close = %s".cstring(), state().string().cstring(), txn_id_at_close.cstring(), barrier_token_at_close.string().cstring())
    // Do not reset_state() here.  Wait (typically) until 2PC intro is done.

  fun make_txn_id_string(checkpoint_id: CheckpointId): String =>
    stream_name + ":c_id=" + checkpoint_id.string()

  fun ref twopc_intro_done(sink: ConnectorSink ref) =>
    """
    We use barrier_token_at_close to determine if we were
    disconnected during a round of 2PC.  If so, we assume that we
    lost the phase1 reply from the connector sink, so we make the
    pessimistic assumption that the connector sink voted rollback/abort.
    """
    if barrier_token_at_close != barrier_token_initial then
      @ll(_twopc_info, "2PC: Wallaroo local abort for txn_id %s barrier %s _twopc.state = %d".cstring(), txn_id_at_close.cstring(), barrier_token_at_close.string().cstring(), state())

      // It's possible that barrier_token_at_close completed
      // successfully and phase 2 commit was sent to the sink, but our
      // connection was closed immediately after sending that commit.
      // In that case, our attempt to abort here will be ignored:
      // "_clear_barrier received at BarrierCoordinator for unknown
      // barrier token CheckpointBarrierToken(NNN). Did we rollback?"
      // That error is harmless.
      //
      // However, in other cases, our abort here is the right thing
      // to do, and this barrier token will be recognized and trigger
      // the rollback that we need.
      sink.abort_decision("TCP connection closed during 2PC",
        txn_id_at_close, barrier_token_at_close)

      // NOTE: If we disconnected, then that txn will be aborted
      // by other parts of the system, e.g c_id=5.  However, we
      // should not set_state_abort() here because when it's time for
      // c_id=6, we shouldn't let 5's abort state affect 6's.
      reset_state()
      txn_id = txn_id_at_close
      txn_id_at_close = ""
      barrier_token_at_close = barrier_token_initial
    else
      reset_state()
    end

  fun ref twopc_phase1_reply(sink: ConnectorSink ref,
    txn_id': String, commit: Bool): (Bool | None)
  =>
    if txn_id' != txn_id then
      // It's possible that the reply we got is for an old txn id, see
      // comments in ConnectorSink.twopc_phase1_reply.  The other
      // explanation, believe/hope/trust, is that this response from
      // the connector is buggy/Byzantine and must be fixed.
      @ll(_twopc_info, "2PC: twopc_reply: txn_id %s != %s".cstring(),
        txn_id'.cstring(), txn_id.cstring())
      return None
    end

    if state_is_2abort() then
      @ll(_twopc_info, "2PC: txn_id %s was %s; send abort now".cstring(), txn_id'.cstring(), commit.string().cstring())
      send_phase2(sink, false)
      return false
    end

    if not (state_is_start() or state_is_1precommit() or
      state_is_2commit_fast()) then
      @ll(_twopc_err, "2PC: ERROR: twopc_reply: _twopc.state = %d".cstring(), state())
      Fail()
    end

    if commit then
      // NOTE: TwoPCFsm2Commit means that our connector sink has
      // voted to commit. It does not mean that we know
      // the status of the global Wallaroo checkpoint protocol.
      set_state_commit()
      @ll(_twopc_debug, "2PC: txn_id %s was %s".cstring(), txn_id'.cstring(), commit.string().cstring())
      true
    else
      set_state_abort()
      false
    end

  fun send_phase2(sink: ConnectorSink ref, commit: Bool)
  =>
    let bs: Array[U8] val = TwoPCEncode.phase2(txn_id, commit)
    let msg: cwm.MessageMsg = cwm.MessageMsg(0, 0, 0, None, bs)
    sink.send_msg(sink, msg)
    @ll(_twopc_debug, "2PC: sent phase 2 commit=%s for txn_id %s".cstring(), commit.string().cstring(), txn_id.cstring())

  fun send_workers_left(sink: ConnectorSink ref,
    rtag: U64, leaving_workers: Array[cwm.WorkerName val] val)
  =>
    let bs: Array[U8] val = TwoPCEncode.workers_left(rtag, leaving_workers)
    let msg: cwm.MessageMsg = cwm.MessageMsg(0, 0, 0, None, bs)
    sink.send_msg(sink, msg)
    @ll(_twopc_debug, "2PC: sent leaving_workers %s/%s".cstring(),
      rtag.string().cstring(), ",".join(leaving_workers.values()))
