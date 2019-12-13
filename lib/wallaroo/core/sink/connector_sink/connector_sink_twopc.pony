/*

Copyright (C) 2016-2020, Wallaroo Labs
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
  let txn_id_initial: String = ""
  var txn_id: String = txn_id_initial
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
    if txn_id != txn_id_initial then
      @ll(_twopc_err, "update_offset: txn_id %s != txn_id_initial %s".cstring(), txn_id.cstring(), txn_id_initial.cstring())
      Fail()
    end
    current_offset = current_offset + encoded1_len

  fun ref rollback(current_offset': USize) =>
    current_offset = current_offset'
    last_offset = current_offset'
    current_txn_end_offset = current_offset'

  fun ref hard_close() =>
    None

  fun make_txn_id_string(checkpoint_id: CheckpointId): String =>
    stream_name + ":c_id=" + checkpoint_id.string()

  fun ref send_phase1(sink: ConnectorSink ref, checkpoint_id: CheckpointId) =>
    let tid = make_txn_id_string(checkpoint_id)
    let where_list: cwm.WhereList =
      [(1, last_offset.u64(), current_offset.u64())]
    let bs = TwoPCEncode.phase1(tid, where_list)
    let msg: cwm.MessageMsg = cwm.MessageMsg(0, 0, 0, None, bs)
    sink.send_msg(msg)
    @ll(_twopc_debug, "2PC: sent phase 1 where_list 1,%s,%s tid/txn_id %s".cstring(), last_offset.string().cstring(), current_offset.string().cstring(), tid.cstring())
    txn_id = tid
    current_txn_end_offset = current_offset

  fun ref send_phase2(sink: ConnectorSink ref, tid: String, commit: Bool)
  =>
    let bs: Array[U8] val = TwoPCEncode.phase2(tid, commit)
    let msg: cwm.MessageMsg = cwm.MessageMsg(0, 0, 0, None, bs)
    sink.send_msg(msg)
    @ll(_twopc_debug, "2PC: sent phase 2 commit=%s for tid/txn_id %s".cstring(), commit.string().cstring(), tid.cstring())
    clear_txn_id()
    if commit then
      last_offset = current_txn_end_offset
      if last_offset != current_offset then
        @ll(_twopc_err, "Offset error during txn: last_offset %lu current_offset %lu".cstring(), last_offset, current_offset)
        Fail()
      end
    end

  fun ref clear_txn_id() =>
    txn_id = txn_id_initial

  fun send_workers_left(sink: ConnectorSink ref,
    rtag: U64, leaving_workers: Array[cwm.WorkerName val] val)
  =>
    let bs: Array[U8] val = TwoPCEncode.workers_left(rtag, leaving_workers)
    let msg: cwm.MessageMsg = cwm.MessageMsg(0, 0, 0, None, bs)
    sink.send_msg(msg)
    @ll(_twopc_debug, "2PC: sent leaving_workers %s/%s".cstring(),
      rtag.string().cstring(), ",".join(leaving_workers.values()))
