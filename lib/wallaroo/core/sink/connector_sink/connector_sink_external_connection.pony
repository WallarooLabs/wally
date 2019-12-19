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

use cwm = "wallaroo_labs/connector_wire_messages"
use "wallaroo_labs/logging"
use "wallaroo_labs/mort"

/****
Boilerplate: sed -n '/BEGIN RIGHT/,/END RIGHT/p' connector-sink-2pc-management.dot | grep label | grep -e '->' | sed -e 's:.*label="::' -e 's:".*::' -e 's:\\n.*::g' | sed 's/://' | sort -u | awk 'BEGIN {print "trait _ExtConnOps\n  fun name(): String\n";} {printf("  fun ref %s(sink: ConnectorSink ref):\n    _ExtConnOps ref\n  =>\n    _invalid_call(__loc.method_name()); Fail(); this\n\n", $1); }'
Missing: handle_message()
****/

trait _ExtConnOps
  fun name(): String

  fun ref set_advertise_status(sink: ConnectorSink ref, status: Bool):
    _ExtConnOps ref
  =>
    _invalid_call(__loc.method_name()); Fail(); this

  fun ref handle_message(sink: ConnectorSink ref, msg: cwm.Message):
    _ExtConnOps ref
  =>
    _invalid_call(__loc.method_name()); Fail(); this

  fun ref reconn_timer(sink: ConnectorSink ref):
    _ExtConnOps ref
  =>
    _invalid_call(__loc.method_name()); Fail(); this

  fun ref rollback_info(sink: ConnectorSink ref):
    _ExtConnOps ref
  =>
    _invalid_call(__loc.method_name()); Fail(); this

  fun ref tcp_closed(sink: ConnectorSink ref):
    _ExtConnOps ref
  =>
    _invalid_call(__loc.method_name()); Fail(); this

  fun ref tcp_connected(sink: ConnectorSink ref):
    _ExtConnOps ref
  =>
    _invalid_call(__loc.method_name()); Fail(); this

  fun ref twopc_intro(sink: ConnectorSink ref):
    _ExtConnOps ref
  =>
    _invalid_call(__loc.method_name()); Fail(); this

  fun _invalid_call(method_name: String) =>
    @l(Log.crit(), Log.conn_sink(),
      "Invalid call to %s on _ExtConnOps state %s".cstring(),
      method_name.cstring(), name().cstring())

primitive _CRTransition
  fun apply(curr: _ExtConnOps, next: _ExtConnOps): _ExtConnOps =>
    @l(Log.debug(), Log.conn_sink(),
      "CRTransition:: %s -> %s".cstring(),
      curr.name().cstring(), next.name().cstring())
    next

primitive _CRTransitionConnected
  fun apply(curr: _ExtConnOps, advertise_status: Bool,
    sink: ConnectorSink ref): _ExtConnOps
  =>
    let next = _ExtConnConnected(advertise_status)
    @l(Log.debug(), Log.conn_sink(),
      "CRTransition:: %s -> %s".cstring(),
      curr.name().cstring(), next.name().cstring())
    next.enter(sink)
    next

primitive _CRTransitionDisconnected
  fun apply(curr: _ExtConnOps, advertise_status: Bool): _ExtConnOps =>
    let next = _ExtConnDisconnected(advertise_status)
    @l(Log.debug(), Log.conn_sink(),
      "CRTransition:: %s -> %s".cstring(),
      curr.name().cstring(), next.name().cstring())
    next.enter()
    next

/****
Boilerplate: sed -n '/BEGIN RIGHT/,/END RIGHT/p' connector-sink-2pc-management.dot | grep -e '->' | awk '{print $1}' | sort -u | grep -v START | awk '{ printf("class _ExtConn%s is _ExtConnOps\n  fun name(): String => __loc.type_name()\n\n", $1); }'
****/

class _ExtConnConnected is _ExtConnOps
  var _advertise_status: Bool
  var _msgs_received: U8 = 0

  fun name(): String => __loc.type_name()

  new create(advertise_status: Bool) =>
    _advertise_status = advertise_status

  fun ref set_advertise_status(sink: ConnectorSink ref, status: Bool):
    _ExtConnOps ref
  =>
    _advertise_status = status
    this

  fun ref handle_message(sink: ConnectorSink ref, msg: cwm.Message):
    _ExtConnOps ref
  =>
    match msg
    | let m: cwm.OkMsg =>
      @l(Log.debug(), Log.conn_sink(), "Got OkMsg".cstring())
      _msgs_received = _msgs_received + 1
      this
    | let m: cwm.NotifyAckMsg =>
      @l(Log.debug(), Log.conn_sink(), "NotifyAck: success %s stream_id %d p-o-r %lu".cstring(), m.success.string().cstring(), m.stream_id, m.point_of_ref)
      _msgs_received = _msgs_received + 1
      if m.success then
        // We ignore the point of reference sent to us by
        // the connector sink.
        this
      else
        sink._error_and_close("Got NotifyAck success=false")
        _CRTransitionDisconnected(this, _advertise_status)
      end
    | let m: cwm.MessageMsg =>
      try
        let inner = cwm.TwoPCFrame.decode(m.message as Array[U8] val)?
        match inner
        | let mi: cwm.ReplyUncommittedMsg =>
          @l(Log.debug(), Log.conn_sink(), "2PC: GOT ReplyUncommittedMsg, # of items = %d".cstring(), mi.txn_ids.size())
          sink.report_ready_to_work()
          //TODO// sink._notify.unthrottled(this)

          if mi.txn_ids.size() == 0 then
            @l(Log.debug(), Log.conn_sink(),
              "Uncommitted txns list is empty".cstring())
            _CRTransition(this, _ExtConnTwoPCReady(_advertise_status))
          else
            @l(Log.debug(), Log.conn_sink(),
              "Uncommitted txns list is NOT empty, TODOTODO".cstring())
            _CRTransition(this, _ExtConnWaitingForRollbackPayload(
              _advertise_status, mi.txn_ids))
          end
/****
        | let mi: cwm.TwoPCReplyMsg =>
          @ll(_twopc_debug, "2PC: reply for txn_id %s was %s".cstring(), mi.txn_id.cstring(), mi.commit.string().cstring())
          twopc_phase1_reply(mi.txn_id, mi.commit)
****/
        else
          Fail(); this
        end
      else
        sink._error_and_close("Bad msg @ line " + __loc.line().string())
        _CRTransitionDisconnected(this, _advertise_status)
      end
    else
      Fail(); this
    end

  fun ref tcp_closed(sink: ConnectorSink ref): _ExtConnOps =>
    _CRTransitionDisconnected(this, _advertise_status)

  fun ref enter(sink: ConnectorSink ref) =>
    // 2PC: Send the Hello message to start things off
    sink.send_msg(sink._make_hello_msg())

    // 2PC: Send a Notify for stream ID 1.
    sink.send_msg(sink._make_notify1_msg())

    // 2PC: We don't know how many transactions the sink has that
    // have been waiting for a phase 2 message.  We need to discover
    // their txn_id strings and abort/commit them.
    let list_u = sink._make_list_uncommitted_msg_encoded()
    let list_u_msg = cwm.MessageMsg(0, 0, 0, None, list_u)
    sink.send_msg(list_u_msg)

class _ExtConnDisconnected is _ExtConnOps
  var _advertise_status: Bool

  fun name(): String => __loc.type_name()

  new create(advertise_status: Bool) =>
    _advertise_status = advertise_status

  fun ref set_advertise_status(sink: ConnectorSink ref, status: Bool):
    _ExtConnOps ref
  =>
    _advertise_status = status
    this

  fun ref tcp_connected(sink: ConnectorSink ref): _ExtConnOps =>
    _CRTransitionConnected(this, _advertise_status, sink)

  fun ref enter() =>
    if _advertise_status then
      @l(Log.debug(), Log.conn_sink(),
        "TODO: send abort_next_checkpoint to CpRb".cstring())
      None//TODO
    end
    _advertise_status = false

class _ExtConnInit is _ExtConnOps
  var _advertise_status: Bool = true

  fun name(): String => __loc.type_name()

  new create() =>
    None

  fun ref set_advertise_status(sink: ConnectorSink ref, status: Bool):
    _ExtConnOps ref
  =>
    _advertise_status = status
    this

  fun ref tcp_closed(sink: ConnectorSink ref): _ExtConnOps =>
    _CRTransitionDisconnected(this, _advertise_status)

  fun ref tcp_connected(sink: ConnectorSink ref):
    _ExtConnOps ref
  =>
    _CRTransitionConnected(this, _advertise_status, sink)

class _ExtConnTwoPCReady is _ExtConnOps
  var _advertise_status: Bool

  fun name(): String => __loc.type_name()

  new create(advertise_status: Bool) =>
    _advertise_status = advertise_status

  fun ref set_advertise_status(sink: ConnectorSink ref, status: Bool):
    _ExtConnOps ref
  =>
    _advertise_status = status
    this

  fun ref tcp_closed(sink: ConnectorSink ref): _ExtConnOps =>
    _CRTransitionDisconnected(this, _advertise_status)

class _ExtConnWaitingForRollbackPayload is _ExtConnOps
  var _advertise_status: Bool
  let _uncommitted_txn_ids: Array[String val] val

  fun name(): String => __loc.type_name()

  new create(advertise_status: Bool, uncommitted_txn_ids: Array[String val] val) =>
    _advertise_status = advertise_status
    _uncommitted_txn_ids = uncommitted_txn_ids

  fun ref set_advertise_status(sink: ConnectorSink ref, status: Bool):
    _ExtConnOps ref
  =>
    _advertise_status = status
    this

  fun ref tcp_closed(sink: ConnectorSink ref): _ExtConnOps =>
    _CRTransitionDisconnected(this, _advertise_status)
