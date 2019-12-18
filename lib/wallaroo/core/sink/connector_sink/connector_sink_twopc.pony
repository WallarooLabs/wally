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
  let txn_id_initial: String = ""
  var txn_id: String = txn_id_initial
  var txn_id_at_close: String = txn_id_initial
  let ph1_barrier_token_initial: CheckpointBarrierToken = CheckpointBarrierToken(0)
  var ph1_barrier_token: CheckpointBarrierToken = ph1_barrier_token_initial
  var ph1_barrier_token_at_close: CheckpointBarrierToken = ph1_barrier_token_initial
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

  fun ref reset_fsm_state() =>
    state = TwoPCFsmStart
    txn_id = txn_id_initial
    clear_ph1_barrier_token()
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
    ph1_barrier_token = sbt

  fun ref barrier_complete(sbt: CheckpointBarrierToken,
    conn: ConnectorSink ref,
    is_rollback: Bool = false,
    stream_id: cwm.StreamId = 223344 /* arbitrary integer != 1 or 0 */):
  (None | Array[cwm.Message])
  =>
    None//TODO

  fun ref checkpoint_complete(sink: ConnectorSink ref, drop_phase2_msg: Bool) =>
    None//TODO

  fun ref rollback(current_offset': USize) =>
    current_offset = current_offset'
    last_offset = current_offset'
    current_txn_end_offset = current_offset'

  fun ref hard_close() =>
    txn_id_at_close = txn_id
    ph1_barrier_token_at_close = ph1_barrier_token
    @ll(_twopc_debug, "2PC: DBG: hard_close: state = %s, txn_id_at_close = %s, ph1_barrier_token_at_close = %s".cstring(), state().string().cstring(), txn_id_at_close.cstring(), ph1_barrier_token_at_close.string().cstring())
    // Do not reset_fsm_state() here.  Wait (typically) until 2PC intro is done.

  fun make_txn_id_string(checkpoint_id: CheckpointId): String =>
    stream_name + ":c_id=" + checkpoint_id.string()

  fun ref twopc_phase1_reply(sink: ConnectorSink ref,
    txn_id': String, commit: Bool): (Bool | None)
  =>
    None//TODO

  fun ref clear_ph1_barrier_token() =>
    ph1_barrier_token = ph1_barrier_token_initial

  fun send_phase2(sink: ConnectorSink ref, commit: Bool,
    override_txn_id: String = "")
  =>
    let tid = if override_txn_id != "" then override_txn_id else txn_id end
    let bs: Array[U8] val = TwoPCEncode.phase2(tid, commit)
    let msg: cwm.MessageMsg = cwm.MessageMsg(0, 0, 0, None, bs)
    sink.send_msg(msg)
    @ll(_twopc_debug, "2PC: sent phase 2 commit=%s for tid/txn_id %s".cstring(), commit.string().cstring(), tid.cstring())

  fun send_workers_left(sink: ConnectorSink ref,
    rtag: U64, leaving_workers: Array[cwm.WorkerName val] val)
  =>
    let bs: Array[U8] val = TwoPCEncode.workers_left(rtag, leaving_workers)
    let msg: cwm.MessageMsg = cwm.MessageMsg(0, 0, 0, None, bs)
    sink.send_msg(msg)
    @ll(_twopc_debug, "2PC: sent leaving_workers %s/%s".cstring(),
      rtag.string().cstring(), ",".join(leaving_workers.values()))
