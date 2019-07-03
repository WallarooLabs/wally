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
use cwm = "wallaroo_labs/connector_wire_messages"
use "wallaroo_labs/logging"
use "wallaroo_labs/mort"

class ConnectorSink2PC
  var state: cwm.TwoPCFsmState = cwm.TwoPCFsmStart
  var txn_id: String = ""
  var txn_id_at_close: String = ""
  var barrier_token_initial: CheckpointBarrierToken = CheckpointBarrierToken(0)
  var barrier_token: CheckpointBarrierToken = barrier_token_initial
  var barrier_token_at_close: CheckpointBarrierToken = barrier_token_initial
  var last_offset: USize = 0
  var current_offset: USize = 0
  var current_txn_end_offset: USize = 0
  let stream_name: String
  let _twopc_debug: U16 = Log.make_sev_cat(Log.debug(), Log.twopc())
  let _twopc_info: U16 = Log.make_sev_cat(Log.info(), Log.twopc())
  let _twopc_err: U16 = Log.make_sev_cat(Log.err(), Log.twopc())

  new create(stream_name': String) =>
    stream_name = stream_name'

  fun ref update_offset(encoded1_len: USize) =>
    current_offset = current_offset + encoded1_len

  fun ref reset_state() =>
    state = cwm.TwoPCFsmStart
    txn_id = ""
    barrier_token = CheckpointBarrierToken(0)
    @ll(_twopc_debug, "2PC: reset 2PC state\n".cstring())
    @ll(_twopc_debug, "2PC: set 2PC state => %d\n".cstring(), state())

  fun state_is_start(): Bool =>
    state is cwm.TwoPCFsmStart

  fun state_is_1precommit(): Bool =>
    state is cwm.TwoPCFsm1Precommit

  fun state_is_2commit(): Bool =>
    state is cwm.TwoPCFsm2Commit

  fun state_is_2commit_fast(): Bool =>
    state is cwm.TwoPCFsm2CommitFast

  fun ref set_state_commit() =>
    state = cwm.TwoPCFsm2Commit
    @ll(_twopc_debug, "2PC: set 2PC state => %d\n".cstring(), state())

  fun ref set_state_commit_fast() =>
    state = cwm.TwoPCFsm2CommitFast
    @ll(_twopc_debug, "2PC: set 2PC state => %d\n".cstring(), state())

  fun ref set_state_abort() =>
    state = cwm.TwoPCFsm2Abort
    @ll(_twopc_debug, "2PC: set 2PC state => %d\n".cstring(), state())

  fun ref preemptive_txn_abort(sbt: CheckpointBarrierToken) =>
    txn_id = "preemptive txn abort"
    barrier_token = sbt

  fun ref barrier_complete(sbt: CheckpointBarrierToken):
    (None | cwm.MessageMsg)
  =>
    if state_is_start() then
      if (current_offset > 0) and
         (current_offset == last_offset)
      then
        set_state_commit_fast()
        return None
      end

      state = cwm.TwoPCFsm1Precommit
      txn_id = make_txn_id_string(sbt.id)
      barrier_token = sbt
      current_txn_end_offset = current_offset
    else
      @ll(_twopc_err, "2PC: ERROR: _twopc.state = %d\n".cstring(), state())
      Fail()
    end

    let where_list: cwm.WhereList =
      [(1, last_offset.u64(), current_offset.u64())]
    let bs = cwm.TwoPCEncode.phase1(txn_id, where_list)
    try
      cwm.MessageMsg(0, cwm.Ephemeral(), 0, 0, None, [bs])?
     else
      Fail()
    end

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
        @ll(_twopc_err, "2PC: DBG: _twopc.state = %s,\n".cstring(), state().string().cstring())
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
    @ll(_twopc_debug, "2PC: DBG: hard_close: state = %s, txn_id_at_close = %s, barrier_token_at_close = %s\n".cstring(), state().string().cstring(), txn_id_at_close.cstring(), barrier_token_at_close.string().cstring())
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

      sink.abort_decision("TCP connection closed during 2PC",
        txn_id_at_close, barrier_token_at_close)
      @ll(_twopc_debug, "2PC: Wallaroo local abort for txn_id %s barrier %s\n".cstring(), txn_id_at_close.cstring(), barrier_token_at_close.string().cstring())

      // SLF TODO: if we disconnected, then that txn will be aborted
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

  fun ref twopc_phase1_reply(txn_id': String, commit: Bool): Bool =>
    if not state_is_1precommit() then
      @ll(_twopc_err, "2PC: ERROR: twopc_reply: _twopc.state = %d\n".cstring(), state())
      Fail()
    end
    if txn_id' != txn_id then
      @ll(_twopc_err, "2PC: ERROR: twopc_reply: txn_id %s != %s\n".cstring(),
        txn_id'.cstring(), txn_id.cstring())
      Fail()
    end

    if commit then
      // NOTE: TwoPCFsm2Commit means that our connector sink has
      // voted to commit. It does not mean that we know
      // the status of the global Wallaroo checkpoint protocol.
      set_state_commit()
      @ll(_twopc_debug, "2PC: txn_id %s was %s\n".cstring(), txn_id'.cstring(), commit.string().cstring())
      true
    else
      set_state_abort()
      false
    end

  fun send_phase2(sink: ConnectorSink ref, commit: Bool)
  =>
    let b: Array[U8] val = cwm.TwoPCEncode.phase2(txn_id, commit)
    try
      let msg: cwm.MessageMsg = cwm.MessageMsg(0, cwm.Ephemeral(), 0, 0, None, [b])?
       sink.send_msg(sink, msg)
     else
       Fail()
    end
    @ll(_twopc_debug, "2PC: sent phase 2 commit=%s for txn_id %s\n".cstring(), commit.string().cstring(), txn_id.cstring())
