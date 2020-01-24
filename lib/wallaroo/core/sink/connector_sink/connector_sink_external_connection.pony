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
use cwm = "wallaroo_labs/connector_wire_messages"
use "wallaroo_labs/logging"
use "wallaroo_labs/mort"

trait _ExtConnOps
  """
  aka, "external connection operations"

  This trait describes the FSM used to manage mid-level details of this
  sink's TCP connection, e.g., disconnected, connected but not yet ready
  to send application data to the external sink, connection is fully
  operational.See the FSM state diagram on the righthand side of
  connector-sink-2pc-management.png.
  """

  fun name(): String

  fun ref enter(sink: ConnectorSink ref, previous_state: _ExtConnOps) => None

  fun ref set_advertise_status(sink: ConnectorSink ref, status: Bool) =>
    _invalid_call(__loc.method_name()); Fail()

  fun ref handle_message(sink: ConnectorSink ref, msg: cwm.Message) =>
    _invalid_call(__loc.method_name()); Fail()

  fun ref reconn_timer(sink: ConnectorSink ref) =>
    _invalid_call(__loc.method_name()); Fail()

  fun ref rollback_info(sink: ConnectorSink ref,
    barrier_token: CheckpointBarrierToken)
  =>
    _invalid_call(__loc.method_name()); Fail()

  fun ref tcp_closed(sink: ConnectorSink ref) =>
    _invalid_call(__loc.method_name()); Fail()

  fun ref tcp_connected(sink: ConnectorSink ref) =>
    _invalid_call(__loc.method_name()); Fail()

  fun ref twopc_intro(sink: ConnectorSink ref) =>
    _invalid_call(__loc.method_name()); Fail()

  fun _invalid_call(method_name: String) =>
    @l(Log.crit(), Log.conn_sink(),
      "Invalid call to %s on _ExtConnOps state %s".cstring(),
      method_name.cstring(), name().cstring())

class _ExtConnState
  let _debug: LogSevCat = Log.make_sev_cat(Log.debug(), Log.conn_sink())
  var advertise_status: Bool
  var rollback_info: (None | CheckpointBarrierToken)
  var uncommitted_txn_ids: (None | Array[String val] val)

  new create(advertise_status': Bool,
    rollback_info': (None | CheckpointBarrierToken),
    uncommitted_txn_ids': (None | Array[String val] val))
  =>
    advertise_status = advertise_status'
    rollback_info = rollback_info'
    uncommitted_txn_ids = uncommitted_txn_ids'

primitive _ECTransition
  fun apply(curr: _ExtConnOps, next: _ExtConnOps, sink: ConnectorSink ref) =>
    @l(Log.debug(), Log.conn_sink(),
      "ECTransition:: %s -> %s".cstring(),
      curr.name().cstring(), next.name().cstring())
    // We must update sink's _ec pointer before calling .enter()!
    // Otherwise, if .enter() also updates the _cprb pointer, then
    // a pointer update will get clobbered & lost.
    sink._update_ec_member(next)
    next.enter(sink, curr)

class _ExtConnConnected is _ExtConnOps
  let _debug: LogSevCat = Log.make_sev_cat(Log.debug(), Log.conn_sink())
  let _debug_2pc: LogSevCat = Log.make_sev_cat(Log.debug(), Log.twopc())
  var _state: _ExtConnState

  fun name(): String => __loc.type_name()

  new create(state: _ExtConnState) =>
    _state = state

  fun ref enter(sink: ConnectorSink ref, previous_state: _ExtConnOps) =>
    // Send 2PC intro messages now, all in a row, assuming they'll all
    // be successful.  If one of them isn't successful, we'll deal with
    // that reply when it arrives.

    // 2PC intro: Send the Hello message to start things off
    sink.send_msg(sink._make_hello_msg())

    // 2PC intro: Send a Notify for stream ID 1.
    sink.send_msg(sink._make_notify1_msg())

    // 2PC intro: We don't know how many transactions the sink has that
    // have been waiting for a phase 2 message.  We need to discover
    // their txn_id strings and abort/commit them.
    let list_u = sink._make_list_uncommitted_msg_encoded()
    let list_u_msg = cwm.MessageMsg(0, 0, 0, None, list_u)
    sink.send_msg(list_u_msg)

  fun ref set_advertise_status(sink: ConnectorSink ref, status: Bool) =>
    @ll(_debug, "set_advertise_status: %s: %s -> %s".cstring(), name().cstring(), _state.advertise_status.string().cstring(), status.string().cstring())
    _state.advertise_status = status

  fun ref handle_message(sink: ConnectorSink ref, msg: cwm.Message) =>
    match msg
    | let m: cwm.OkMsg =>
      @ll(_debug, "Got OkMsg".cstring())
    | let m: cwm.NotifyAckMsg =>
      @ll(_debug, "NotifyAck: success %s stream_id %d p-o-r %lu".cstring(), m.success.string().cstring(), m.stream_id, m.point_of_ref)
      if m.success then
        // We ignore the point of reference sent to us by the connector sink.
        None
      else
        sink._error_and_close("Got NotifyAck success=false")
        _ECTransition(this, _ExtConnDisconnected(_state), sink)
      end
    | let m: cwm.MessageMsg =>
      try
        let inner = cwm.TwoPCFrame.decode(m.message as Array[U8] val)?
        match inner
        | let mi: cwm.ReplyUncommittedMsg =>
          @ll(_debug_2pc, "GOT ReplyUncommittedMsg, # of items = %d".cstring(), mi.txn_ids.size())
          if mi.txn_ids.size() == 0 then
            @ll(_debug,
              "Uncommitted txns list is empty".cstring())
            _ECTransition(this, _ExtConnTwoPCReady(_state), sink)
          else
            _state.uncommitted_txn_ids = mi.txn_ids
            _ECTransition(this, _ExtConnWaitingForRollbackPayload(
              _state), sink)
          end
        else
          Fail()
        end
      else
        sink._error_and_close("Bad msg @ line " + __loc.line().string())
        _ECTransition(this, _ExtConnDisconnected(_state), sink)
      end
    else
      Fail()
    end

  fun ref rollback_info(sink: ConnectorSink ref,
    barrier_token: CheckpointBarrierToken)
  =>
    _state.rollback_info = barrier_token
    @ll(_debug, "rollback_info line %lu: use".cstring(), __loc.line())

  fun ref tcp_closed(sink: ConnectorSink ref) =>
    _ECTransition(this, _ExtConnDisconnected(_state), sink)

class _ExtConnDisconnected is _ExtConnOps
  let _debug: LogSevCat = Log.make_sev_cat(Log.debug(), Log.conn_sink())
  var _state: _ExtConnState

  fun name(): String => __loc.type_name()

  new create(state: _ExtConnState) =>
    _state = state

  fun ref enter(sink: ConnectorSink ref, previous_state: _ExtConnOps) =>
    let old_state = _state

    // This is a bit unusual, to change advertise_status like this.  But
    // it's a state change that the Checkpoint/Rollback component knows
    // about. Reset state now, because cprb_send_abort_next_checkpoint()
    // may alter our state.
    _state = _ExtConnState(where advertise_status' = false,
      rollback_info' = None, uncommitted_txn_ids' = None)
    @ll(_debug, "set_advertise_status: %s: %s -> %s".cstring(), name().cstring(), _state.advertise_status.string().cstring(), "false".cstring())

    if old_state.advertise_status then
      // The CpRb component wants to know about our status change.
      // However, if we did *not* come from _ExtConnTwoPCReady, then
      // we weren't really connected in a useful way, so we should not
      // send abort_next_checkpoint.
      match previous_state
      | let x: _ExtConnTwoPCReady =>
        @ll(_debug, "Call cprb_send_abort_next_checkpoint".cstring())
        sink.cprb_send_abort_next_checkpoint()
      else
        @ll(_debug, "Do not call cprb_send_abort_next_checkpoint".cstring())
      end
    end

  fun ref rollback_info(sink: ConnectorSink ref,
    barrier_token: CheckpointBarrierToken)
  =>
    _state.rollback_info = barrier_token
    @ll(_debug, "rollback_info line %lu: use".cstring(), __loc.line())

  fun ref set_advertise_status(sink: ConnectorSink ref, status: Bool) =>
    @ll(_debug, "set_advertise_status: %s: %s -> %s".cstring(), name().cstring(), _state.advertise_status.string().cstring(), status.string().cstring())
    _state.advertise_status = status

  fun ref tcp_connected(sink: ConnectorSink ref) =>
    _ECTransition(this, _ExtConnConnected(_state), sink)

class _ExtConnInit is _ExtConnOps
  let _debug: LogSevCat = Log.make_sev_cat(Log.debug(), Log.conn_sink())
  var _state: _ExtConnState = _ExtConnState(
    where advertise_status' = true, uncommitted_txn_ids' = None,
    rollback_info' = None)

  fun name(): String => __loc.type_name()

  fun ref rollback_info(sink: ConnectorSink ref,
    barrier_token: CheckpointBarrierToken)
  =>
    // We have crashed and recovered and rollback has started before
    // the sink is connected the first time.
    _state.rollback_info = barrier_token
    @ll(_debug, "rollback_info line %lu: use".cstring(), __loc.line())

  fun ref set_advertise_status(sink: ConnectorSink ref, status: Bool) =>
    @ll(_debug, "set_advertise_status: %s: %s -> %s".cstring(), name().cstring(), _state.advertise_status.string().cstring(), status.string().cstring())
    _state.advertise_status = status

  fun ref tcp_closed(sink: ConnectorSink ref) =>
    _ECTransition(this, _ExtConnDisconnected(_state), sink)

  fun ref tcp_connected(sink: ConnectorSink ref) =>
    _ECTransition(this, _ExtConnConnected(_state), sink)

class _ExtConnTwoPCReady is _ExtConnOps
  let _debug: LogSevCat = Log.make_sev_cat(Log.debug(), Log.conn_sink())
  let _debug_2pc: LogSevCat = Log.make_sev_cat(Log.debug(), Log.twopc())
  var _state: _ExtConnState

  fun name(): String => __loc.type_name()

  new create(state: _ExtConnState) =>
    _state = state

  fun ref enter(sink: ConnectorSink ref, previous_state: _ExtConnOps) =>
    @ll(_debug_2pc, "_ExtConnTwoPCReady _advertise_status %s".cstring(),
      _state.advertise_status.string().cstring())
    if _state.advertise_status then
      sink.cprb_send_conn_ready()
    end

  fun ref handle_message(sink: ConnectorSink ref, msg: cwm.Message) =>
    match msg
    | let m: cwm.MessageMsg =>
      try
        let inner = cwm.TwoPCFrame.decode(m.message as Array[U8] val)?
        match inner
        | let mi: cwm.ReplyUncommittedMsg =>
          Fail()
        | let mi: cwm.TwoPCReplyMsg =>
          @ll(_debug_2pc, "reply for txn_id %s was %s".cstring(),
            mi.txn_id.cstring(), mi.commit.string().cstring())
          sink.cprb_send_phase1_result(mi.txn_id, mi.commit)
        else
          Fail()
        end
      else
        sink._error_and_close("Bad msg @ line " + __loc.line().string())
        _ECTransition(this, _ExtConnDisconnected(_state), sink)
      end
    else
      sink._error_and_close("Bad msg @ line " + __loc.line().string())
      _ECTransition(this, _ExtConnDisconnected(_state), sink)
    end

  fun ref rollback_info(sink: ConnectorSink ref,
    barrier_token: CheckpointBarrierToken)
  =>
    // This message can arrive at this state if we went directly
    // from Connected -> TwoPCReady, because the uncommited txn list
    // was empty.  We don't need this info; ignore it.
    @ll(_debug, "rollback_info line %lu: ignore".cstring(), __loc.line())

  fun ref set_advertise_status(sink: ConnectorSink ref, status: Bool) =>
    let old_status = _state.advertise_status

    @ll(_debug, "set_advertise_status: %s: %s -> %s".cstring(), name().cstring(), old_status.string().cstring(), status.string().cstring())
    // Set status now, because the sink callback may depend on this update!
    _state.advertise_status = status

    if (not old_status) and status then
      @ll(_debug, "set_advertise_status: send conn_ready".cstring())
      sink.cprb_send_conn_ready()
    end

  fun ref tcp_closed(sink: ConnectorSink ref) =>
    _ECTransition(this, _ExtConnDisconnected(_state), sink)

class _ExtConnWaitingForRollbackPayload is _ExtConnOps
  let _debug: LogSevCat = Log.make_sev_cat(Log.debug(), Log.conn_sink())
  let _debug_2pc: LogSevCat = Log.make_sev_cat(Log.debug(), Log.twopc())
  var _state: _ExtConnState

  fun name(): String => __loc.type_name()

  new create(state: _ExtConnState) =>
    _state = state
    @ll(_debug, "_ExtConnWaitingForRollbackPayload: rollback_info = %s".cstring(),
      match _state.rollback_info
      | None => "<None>".cstring()
      | let x: CheckpointBarrierToken => x.string().cstring()
      end)

  fun ref enter(sink: ConnectorSink ref, previous_state: _ExtConnOps) =>
    match _state.rollback_info
    | let barrier_token: CheckpointBarrierToken =>
      @ll(_debug, "rollback_info line %lu: bingo".cstring(), __loc.line())
      rollback_info(sink, barrier_token)
    end

  fun ref handle_message(sink: ConnectorSink ref, msg: cwm.Message) =>
    match msg
    | let m: cwm.MessageMsg =>
      try
        let inner = cwm.TwoPCFrame.decode(m.message as Array[U8] val)?
        match inner
        | let mi: cwm.ReplyUncommittedMsg =>
          Fail()
        | let mi: cwm.TwoPCReplyMsg =>
          @ll(_debug_2pc, "2PC: reply for txn_id %s was %s".cstring(),
            mi.txn_id.cstring(), mi.commit.string().cstring())
          Fail()
        else
          Fail()
        end
      else
        sink._error_and_close("Bad msg @ line " + __loc.line().string())
        _ECTransition(this, _ExtConnDisconnected(_state), sink)
      end
    else
      sink._error_and_close("Bad msg @ line " + __loc.line().string())
      _ECTransition(this, _ExtConnDisconnected(_state), sink)
    end

  fun ref rollback_info(sink: ConnectorSink ref,
    barrier_token: CheckpointBarrierToken)
  =>
    @ll(_debug, "rollback_info line %lu: bingo".cstring(), __loc.line())
    _state.rollback_info = barrier_token
    match _state.uncommitted_txn_ids
    | None =>
      Fail()
    | let uncommitted: Array[String val] val =>
      @ll(_debug, "uncommitted.size() = %lu".cstring(), uncommitted.size())
      if uncommitted.size() != 1 then
        Fail()
      end
      let commited_txn_id = sink.cprb_make_txn_id_string(barrier_token.id)
      try
        let precommitted_txn_id = uncommitted(0)?
        let decision = precommitted_txn_id == commited_txn_id
        @l(Log.info(), Log.conn_sink(), "Uncommitted decision = %s for uncommitted %s committed %s".cstring(),
          decision.string().cstring(), precommitted_txn_id.cstring(),
          commited_txn_id.cstring())
        sink.cprb_send_2pc_phase2(precommitted_txn_id, decision, true)
      end
    end
    if sink._get_ec_member() is this then
      _ECTransition(this, _ExtConnTwoPCReady(_state), sink)
    else
      @l(Log.info(), Log.conn_sink(),
        "Control inversion: the Phase 2 send command failed, and we have already made an EC state transition.".cstring())
      // No explicit transition here -- use the transition already specified
    end

  fun ref set_advertise_status(sink: ConnectorSink ref, status: Bool) =>
    @ll(_debug, "set_advertise_status: %s: %s -> %s".cstring(), name().cstring(), _state.advertise_status.string().cstring(), status.string().cstring())
    _state.advertise_status = status

  fun ref tcp_closed(sink: ConnectorSink ref)  =>
    _ECTransition(this, _ExtConnDisconnected(_state), sink)
