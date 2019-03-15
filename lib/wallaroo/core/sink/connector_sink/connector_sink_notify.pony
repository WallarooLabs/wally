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

use "backpressure"
use "buffered"
use "net"
use "wallaroo/core/common"
use "wallaroo/core/network"
use "wallaroo_labs/bytes"
use cp = "wallaroo_labs/connector_protocol"
use "wallaroo_labs/mort"

class ConnectorSinkNotify
  var _fsm_state: cp.ConnectorProtoFsmState = cp.ConnectorProtoFsmDisconnected
  var _header: Bool = true
  var _connected: Bool = false
  var _throttled: Bool = false
  let _stream_id: cp.StreamId = 1
  let _sink_id: RoutingId
  let _worker_name: WorkerName
  let _protocol_version: String
  let _cookie: String
  let _auth: ApplyReleaseBackpressureAuth
  let stream_name: String
  var credits: U32 = 0
  var acked_point_of_ref: cp.MessageId = 0
  var message_id: cp.MessageId = acked_point_of_ref
  var _connection_count: USize = 0
  // 2PC
  var _rtag: U64 = 77777
  var twopc_intro_done: Bool = false
  var twopc_txn_id_last_committed: (None|String) = None
  var twopc_uncommitted_list: (None|Array[String] val) = None

  new create(sink_id: RoutingId, worker_name: WorkerName,
    protocol_version: String, cookie: String,
    auth: ApplyReleaseBackpressureAuth)
  =>
    _sink_id = sink_id
    _worker_name = worker_name
    _protocol_version = protocol_version
    _cookie = cookie
    _auth = auth

    stream_name = "worker-" + worker_name + "-id-" + _sink_id.string()

  fun ref accepted(conn: WallarooOutgoingNetworkActor ref) =>
    Unreachable()

  fun ref auth_failed(conn: WallarooOutgoingNetworkActor ref) =>
    Unreachable()

  fun ref connecting(conn: WallarooOutgoingNetworkActor ref, count: U32) =>
    None

  fun ref connected(conn: WallarooOutgoingNetworkActor ref) =>
    @printf[I32]("ConnectorSink connected\n".cstring())
    _header = true
    _connected = true
    _throttled = false
    twopc_intro_done = false
    twopc_uncommitted_list = None
    twopc_txn_id_last_committed = None // SLF: TODO is this right??
    _connection_count = _connection_count + 1
    // Apply runtime throttle until we're done with initial 2PC ballet.
    throttled(conn)
    conn.expect(4)

    // TODO: configure connector v2 program string
    // TODO: configure connector v2 instance_name string
    let hello = cp.HelloMsg(_protocol_version, _cookie,
      "a program", "an instance")
    send_msg(conn, hello)

    // 2PC: We don't know how many transactions the sink has that
    // have been waiting for a phase 2 message.  We need to discover
    // their txn_id strings and abort them.
    _rtag = _rtag + 1
    let list_u = cp.TwoPCEncode.list_uncommitted(_rtag)
    try
      let list_u_msg =
        cp.MessageMsg(0, cp.Ephemeral(), 0, 0, None, [list_u])?
      send_msg(conn, list_u_msg)
    else
      Fail()
    end

    // 2PC: We also don't know how much fine-grained control the sink
    // has for selectively aborting & committing the stuff that we
    // send to it.  Thus, we should not send any Wallaroo app messages
    // to the sink until we get a ReplyUncommittedMsg response.

    _fsm_state = cp.ConnectorProtoFsmHandshake

  fun ref closed(conn: WallarooOutgoingNetworkActor ref) =>
    """
    We have no idea how much stuff that we've sent recently
    has actually been received by the now-disconnected sink.
    It *is* possible, however, that we sent nothing since the
    last checkpoint; in this case, our TCP connection breaking
    and re-connecting means no sink stream data has been lost,
    so no rollback is required.

    We are going to rely on the connector sink to figure out
    if a rollback is necessary.  If the connector sink
    discovers missing stream data after the reconnect (e.g.,
    the TCP connection broke at output byte offset 100, then
    after re-connecting, the first message_id Wallaroo sends
    is greater than 100), then the connector sink must tell
    us to abort in phase 1 in the next round of 2PC.
    """
    @printf[I32]("ConnectorSink connection closed, muting upstreams\n".cstring())
    _connected = false
    _throttled = false
    twopc_intro_done = false
    twopc_uncommitted_list = None
    throttled(conn)

  fun ref dispose() =>
    @printf[I32]("ConnectorSink connection dispose\n".cstring())

  fun ref connect_failed(conn: WallarooOutgoingNetworkActor ref) =>
    @printf[I32]("ConnectorSink connection failed\n".cstring())

  fun ref expect(conn: WallarooOutgoingNetworkActor ref, qty: USize): USize =>
    qty

  fun ref received(conn: WallarooOutgoingNetworkActor ref, data: Array[U8] iso,
    times: USize): Bool
  =>
    if _header then
      try
        let payload_size: USize = _payload_length(consume data)?

        conn.expect(payload_size)
        _header = false
      else
        Fail()
      end
      true
    else
      conn.expect(4)
      _header = true
      let data' = recover val consume data end
      try
        _process_connector_sink_v2_data(conn, data')?
      else
        Fail()
      end
      true
    end

  fun ref sent(conn: WallarooOutgoingNetworkActor ref, data: (String val | Array[U8 val] val))
    : (String val | Array[U8 val] val)
  =>
    Unreachable()
    data

  fun ref sentv(conn: WallarooOutgoingNetworkActor ref,
    data: ByteSeqIter): ByteSeqIter
  =>
    @printf[I32]("Sink sentv\n".cstring())
    for x in data.values() do
      @printf[I32]("Sink sentv: %s\n".cstring(), _print_array[U8](x).cstring())
    end
    data

  fun ref throttled(conn: WallarooOutgoingNetworkActor ref) =>
    if (not _throttled) or (not twopc_intro_done) then
      _throttled = true
      Backpressure.apply(_auth)
      @printf[I32](("ConnectorSink is experiencing back pressure, " +
        "connected = %s\n").cstring(), _connected.string().cstring())
    end

  fun ref unthrottled(conn: WallarooOutgoingNetworkActor ref) =>
    if _throttled and twopc_intro_done then
      _throttled = false
      Backpressure.release(_auth)
      @printf[I32](("ConnectorSink is no longer experiencing" +
        " back pressure, connected = %s\n").cstring(),
      _connected.string().cstring())
    end

  fun send_msg(conn: WallarooOutgoingNetworkActor ref, msg: cp.Message) =>
    let w1: Writer = w1.create()
    let w2: Writer = w2.create()

    let b = cp.Frame.encode(msg, w1)
    w2.u32_be(b.size().u32())
    @printf[I32]("Sink b1: size %d\n".cstring(), b.size())
    w2.write(b)

    let b2 = recover trn w2.done() end
    try (conn as ConnectorSink ref)._writev(consume b2, None) else Fail() end

  fun ref _process_connector_sink_v2_data(
    conn: WallarooOutgoingNetworkActor ref, data: Array[U8] val): None ?
  =>
    match cp.Frame.decode(data)?
    | let m: cp.HelloMsg =>
      Fail()
    | let m: cp.OkMsg =>
      if _fsm_state is cp.ConnectorProtoFsmHandshake then
        _fsm_state = cp.ConnectorProtoFsmStreaming

        credits = m.initial_credits
        if credits < 2 then
          _error_and_close(conn, "HEY, too few credits: " + credits.string())
        else
          let notify = cp.NotifyMsg(_stream_id, stream_name, message_id)
          send_msg(conn, notify)
          credits = credits - 1
        end
      else
        _error_and_close(conn, "Bad FSM State: A" + _fsm_state().string())
      end
    | let m: cp.ErrorMsg =>
      _error_and_close(conn, "Bad FSM State: B" + _fsm_state().string())
    | let m: cp.NotifyMsg =>
      _error_and_close(conn, "Bad FSM State: C" + _fsm_state().string())
    | let m: cp.NotifyAckMsg =>
      if _fsm_state is cp.ConnectorProtoFsmStreaming then
        @printf[I32]("NotifyAck: success %s stream_id %d p-o-r %lu\n".cstring(), m.success.string().cstring(), m.stream_id, m.point_of_ref)
        // We are going to ignore the point of reference sent to us by
        // the connector sink.  We assume that we know best, and if our
        // point of reference is earlier, then we'll send some duplicates
        // and the connector sink can ignore them.
      else
        _error_and_close(conn, "Bad FSM State: D" + _fsm_state().string())
      end
    | let m: cp.MessageMsg =>
      // 2PC messages are sent via MessageMsg on stream_id 0.
      if (m.stream_id != 0) or (m.message is None) then
        _error_and_close(conn, "Bad FSM State: Ea" + _fsm_state().string())
        return
      end
      @printf[I32]("2PC: GOT MessageMsg\n".cstring())
      try
        let inner = cp.TwoPCFrame.decode(m.message as Array[U8] val)?
        match inner
        | let mi: cp.ReplyUncommittedMsg =>
          // This is a reply to a ListUncommitted message that we sent
          // perhaps some time ago.  Meanwhile, it's possible that we
          // have already started a new round of 2PC ... so our new
          // round's txn_id may be in the txn_id's list.
          if mi.rtag != _rtag then
            @printf[I32]("2PC: bad rtag match: %lu != %lu\n".cstring(), mi.rtag, _rtag)
            Fail()
          end
          ifdef "trace" then
            @printf[I32]("TRACE: uncommitted txns = %d\n".cstring(),
              mi.txn_ids.size())
            twopc_uncommitted_list = mi.txn_ids
            process_uncommitted_list(conn as ConnectorSink ref)
          end

          // The 2PC intro dance has finished.  We can permit the rest
          // of the sink's operation to resume.  The txns in the
          // twopc_uncommitted_list will be committed/aborted as soon
          // as we have all the relevant information is available (and
          // may already have been done by the process_uncommitted_list()
          // call above).
          twopc_intro_done = true
          unthrottled(conn)
          if _connection_count == 1 then
            try
              (conn as ConnectorSink ref).report_ready_to_work()
            else
              Fail()
            end
            None
          end
          try (conn as ConnectorSink ref).twopc_intro_done() else Fail() end
        | let mi: cp.TwoPCReplyMsg =>
          @printf[I32]("2PC: reply for txn_id %s was %s\n".cstring(), mi.txn_id.cstring(), mi.commit.string().cstring())
          try (conn as ConnectorSink ref).twopc_phase1_reply(
            mi.txn_id, mi.commit)
          else Fail() end
        else
          Fail()
        end
      else
        _error_and_close(conn, "Bad FSM State: Eb" + _fsm_state().string())
        return
      end
    | let m: cp.AckMsg =>
      if _fsm_state is cp.ConnectorProtoFsmStreaming then
        // TODO: note that we aren't actually using credits
        credits = credits + m.credits
        for (s_id, p_o_r) in m.credit_list.values() do
          if s_id == _stream_id then
            if p_o_r > message_id then
              // This is possible with 2PC, but it's harmless if
              // we recognize it and ignore it.
              // 0. The connector sink's p_o_r is 4000.
              // 1. The connector sink sends phase1=abort.
              // 2. We send phase2=abort.
              // 3. The connector sink decides to send an ACK with p_o_r=4000.
              //    This message is delayed just a little bit to make a race.
              // 4. We process prepare_to_rollback & rollback.  Our
              //    message_id is reset to message_id=0.  Wallaroo
              //    has fully rolled back state and is ready to resume
              //    all of its work from offset=0.
              // 5. The ACK from step #3 arrives.
              //    4000 > 0, which looks like a terrible state:
              //    we haven't sent anything, but the sink is ACKing
              //    4000 bytes.
              //
              // I am going to disable unsolicited ACK'ing by the
              // connector sink.  Disabling unsolicited ACKs would
              // definitely prevent late-arriving ACKs.  (Will still
              // send ACK in response to Eos.)
              // TODO: Otherwise I believe we'd have to
              // add a checkpoint #/rollback #/state-something to
              // the ACK message to be able to identify late-arriving
              // ACKs.
              None
            elseif p_o_r < acked_point_of_ref then
              @printf[I32]("Error: Ack: stream-id %lu p_o_r %lu acked_point_of_ref %lu\n".cstring(), _stream_id, p_o_r, acked_point_of_ref)
              Fail()
            else
              acked_point_of_ref = p_o_r
            end
          else
            @printf[I32]("Ack: unknown stream_id %d\n".cstring(), s_id)
            Fail()
          end
        end
      else
        _error_and_close(conn, "Bad FSM State: F" + _fsm_state().string())
      end
    | let m: cp.RestartMsg =>
      ifdef "trace" then
        @printf[I32]("TRACE: got restart message, closing connection\n".cstring())
      end
      conn.close()
    end

  fun ref process_uncommitted_list(conn: ConnectorSink ref) =>
    """
    In case of a Wallaroo failure, we need to do two things that can
    happen in either order: 1. get list of uncommitted transactions,
    2. get the initial rollback() message + payload blob of state.
    After both have happened, then we need to commit/abort any
    uncommitted txns outstanding at the connector sink.
    """

    match (twopc_txn_id_last_committed, twopc_uncommitted_list)
    | (let last_committed: String, let uncommitted: Array[String] val) =>
      @printf[I32]("2PC: process_uncommitted_list processing %d items, last_committed = %s\n".cstring(), uncommitted.size(), last_committed.cstring())
      for txn_id in uncommitted.values() do
        let do_commit = if txn_id == last_committed then true else false end
        @printf[I32]("2PC: uncommitted txn_id %s commit=%s\n".cstring(), txn_id.cstring(), do_commit.string().cstring())
        let abort = cp.TwoPCEncode.phase2(txn_id, do_commit)
        try
          let abort_msg =
            cp.MessageMsg(0, cp.Ephemeral(), 0, 0, None, [abort])?
          send_msg(conn, abort_msg)
        else
          Fail()
        end
      end
      twopc_uncommitted_list = []
    else
      @printf[I32]("2PC: process_uncommitted_list waiting\n".cstring())
      None
    end


  fun ref _error_and_close(conn: WallarooOutgoingNetworkActor ref,
    msg: String)
  =>
    send_msg(conn, cp.ErrorMsg(msg))
    conn.close()

  fun ref make_message(encoded1: Array[(String val | Array[U8 val] val)] val):
    cp.MessageMsg ?
  =>
    let stream_id: cp.StreamId = 1
    let flags: cp.Flags = 0
    let event_time = None
    let key = None

    let base_message_id = message_id
    for e in encoded1.values() do
      message_id = message_id + e.size().u64()
    end
    cp.MessageMsg(stream_id, flags, base_message_id, event_time, key, encoded1)?

  fun _payload_length(data: Array[U8] iso): USize ? =>
    Bytes.to_u32(data(0)?, data(1)?, data(2)?, data(3)?).usize()


  fun _print_array[A: Stringable #read](array: ReadSeq[A]): String =>
    """
    Generate a printable string of the contents of the given readseq to use in
    error messages.
    """
    "[len=" + array.size().string() + ": " + ", ".join(array.values()) + "]"
