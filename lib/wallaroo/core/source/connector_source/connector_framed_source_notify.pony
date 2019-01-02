/*

Copyright 2017 The Wallaroo Authors.

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
use "collections"
use "time"
use "wallaroo_labs/time"
use "wallaroo_labs/bytes"
use cwm = "wallaroo_labs/connector_wire_messages"
use "wallaroo/core/boundary"
use "wallaroo/core/common"
use "wallaroo/core/partitioning"
use "wallaroo/ent/checkpoint"
use "wallaroo/ent/data_receiver"
use "wallaroo/ent/recovery"
use "wallaroo_labs/mort"
use "wallaroo/core/messages"
use "wallaroo/core/metrics"
use "wallaroo/core/routing"
use "wallaroo/core/source"
use "wallaroo/core/topology"

type _ProtoFsmState is (_ProtoFsmConnected | _ProtoFsmHandshake |
                        _ProtoFsmStreaming | _ProtoFsmError |
                        _ProtoFsmDisconnected)
primitive _ProtoFsmConnected
  fun apply(): U8 => 1
primitive _ProtoFsmHandshake
  fun apply(): U8 => 2
primitive _ProtoFsmStreaming
  fun apply(): U8 => 3
primitive _ProtoFsmError
  fun apply(): U8 => 4
primitive _ProtoFsmDisconnected
  fun apply(): U8 => 5

class _StreamState
  var pending_query: Bool
  var base_point_of_reference: U64
  var last_message_id: U64
  var filter_message_id: U64
  var barrier_last_message_id: U64
  var barrier_checkpoint_id: CheckpointId

  new ref create(pending_query': Bool, base_point_of_reference': U64,
    last_message_id': U64, filter_message_id': U64,
    barrier_last_message_id': U64, barrier_checkpoint_id': CheckpointId)
=>
  pending_query = pending_query'
  base_point_of_reference = base_point_of_reference'
  last_message_id = last_message_id'
  filter_message_id = filter_message_id'
  barrier_last_message_id = barrier_last_message_id'
  barrier_checkpoint_id = barrier_checkpoint_id'

class ConnectorSourceNotify[In: Any val]
  let _source_id: RoutingId
  let _env: Env
  let _auth: AmbientAuth
  let _msg_id_gen: MsgIdGenerator = MsgIdGenerator
  var _header: Bool = true
  let _pipeline_name: String
  let _source_name: String
  let _handler: FramedSourceHandler[In] val
  let _runner: Runner
  var _router: Router
  let _metrics_reporter: MetricsReporter
  let _header_size: USize
  var _active_stream_registry: (None|ConnectorSourceListener[In]) = None
  var _connector_source: (None|ConnectorSource[In] ref) = None

  let _stream_map: Map[U64, _StreamState] = _stream_map.create()
  var _session_active: Bool = false
  var _session_tag: USize = 0
  var _fsm_state: _ProtoFsmState = _ProtoFsmDisconnected
  // let _cookie: String = "dragons love tacos" // SLF TODO: configurable!
  let _cookie: String = "1234" // SLF TODO: configurable!
  var _program_name: String = ""
  var _instance_name: String = ""

  // Watermark !@ How do we handle this respecting per-connector-type policies
  var _watermark_ts: U64 = 0

  new iso create(source_id: RoutingId, pipeline_name: String, env: Env,
    auth: AmbientAuth, handler: FramedSourceHandler[In] val,
    runner_builder: RunnerBuilder, partitioner_builder: PartitionerBuilder,
    router': Router, metrics_reporter: MetricsReporter iso,
    event_log: EventLog, target_router: Router)
  =>
    _source_id = source_id
    _pipeline_name = pipeline_name
    _source_name = pipeline_name + " source"
    _env = env
    _auth = auth
    _handler = handler
    _runner = runner_builder(event_log, auth, None,
      target_router, partitioner_builder)
    _router = router'
    _metrics_reporter = consume metrics_reporter
    _header_size = _handler.header_length()

  fun routes(): Map[RoutingId, Consumer] val =>
    _router.routes()

  fun ref received(source: ConnectorSource[In] ref, data: Array[U8] iso): Bool =>
    if _header then
      try
        let payload_size: USize = _handler.payload_length(consume data)?

        source.expect(payload_size)
        _header = false
      else
        Fail()
      end
      true
    else
      ifdef "trace" then
        @printf[I32](("Rcvd msg at " + _pipeline_name + " source\n").cstring())
      end
      _metrics_reporter.pipeline_ingest(_pipeline_name, _source_name)
      let ingest_ts = Time.nanos()
      let pipeline_time_spent: U64 = 0
      let latest_metrics_id: U16 = 1

      received_connector_msg(source, consume data, latest_metrics_id,
        ingest_ts, pipeline_time_spent)
    end

  fun ref received_connector_msg(source: ConnectorSource[In] ref,
    data: Array[U8] iso,
    latest_metrics_id: U16,
    ingest_ts: U64,
    pipeline_time_spent: U64): Bool
  =>
    try
      let connector_msg = cwm.Frame.decode(consume data)?
      match connector_msg
      | let m: cwm.HelloMsg =>
        ifdef "trace" then
          @printf[I32]("^*^* got HelloMsg\n".cstring())
        end
        if _fsm_state isnt _ProtoFsmConnected then
          @printf[I32]("ERROR: %s.received_connector_msg: state is %d\n".cstring(),
            __loc.type_name().cstring(), _fsm_state())
          Fail()
        end

        if m.version != "0.0.1" then
          @printf[I32]("ERROR: %s.received_connector_msg: unknown protocol version %s\n".cstring(),
            __loc.type_name().cstring(), m.version.cstring())
          return _to_error_state(source, "Unknown protocol version")
        end
        if m.cookie != _cookie then
          @printf[I32]("ERROR: %s.received_connector_msg: bad cookie %s\n".cstring(),
            __loc.type_name().cstring(), m.cookie.cstring())
          return _to_error_state(source, "Bad cookie")
        end

        // SLF TODO: add routing logic to handle
        // m.program_name and m.instance_name routing requirements
        // Right now, we assume that all messages are to be processed
        // by this connector's one & only pipeline as defined by the
        // app's pipeline definition.

        _fsm_state = _ProtoFsmHandshake
        (_active_stream_registry as ConnectorSourceListener[In]).
          get_all_streams(_session_tag,
            _connector_source as ConnectorSource[In])
        return _continue_perhaps(source)

      | let m: cwm.OkMsg =>
        ifdef "trace" then
          @printf[I32]("^*^* got OkMsg\n".cstring())
        end
        return _to_error_state(source, "Invalid message: ok")

      | let m: cwm.ErrorMsg =>
        @printf[I32]("Client sent us ERROR msg: %s\n".cstring(),
          m.message.cstring())
        source.close()
        return _continue_perhaps(source)

      | let m: cwm.NotifyMsg =>
        ifdef "trace" then
          @printf[I32]("^*^* got NotifyMsg: %lu %s %lu\n".cstring(),
            m.stream_id, m.stream_name.cstring(), m.point_of_ref)
        end
        if _fsm_state isnt _ProtoFsmStreaming then
          return _to_error_state(source, "Bad protocol FSM state")
        end

        // SLF TODO:
        // 1. Send query to active stream registry if no key and if query
        //    isn't already in flight.
        // 2. Update _stream_map for pending query
        // 3. Edit stream_notify_result(): Create reply msg & send to socket.

        try
          if not _stream_map.contains(m.stream_id) then
            (_active_stream_registry as ConnectorSourceListener[In])
              .stream_notify(_session_tag, m.stream_id, m.stream_name,
                m.point_of_ref, _connector_source as ConnectorSource[In])
            _stream_map(m.stream_id) = _StreamState(true, 0, 0, 0, 0, 0)
          else
            // SLF TODO: create NOTIFY_ACK with success=false & send to socket.
            None
          end
        else
          Fail()
        end

      | let m: cwm.NotifyAckMsg =>
        ifdef "trace" then
          @printf[I32]("^*^* got NotifyAckMsg\n".cstring())
        end
        return _to_error_state(source, "Invalid message: notify_ack")

      | let m: cwm.MessageMsg =>
        ifdef "trace" then
          @printf[I32]("^*^* got MessageMsg\n".cstring())
        end
        if _fsm_state isnt _ProtoFsmStreaming then
          return _to_error_state(source, "Bad protocol FSM state")
        end

        // SLF TODO:
        // 1. Check m.flags for sanity, send ErrorMsg if bad.
        // 2. Check m.stream_id for active & not-pending status in
        //    _stream_map, send ErrorMsg if bad.
        // 3. If message_id is lower than last-received-id, then
        //    drop message (i.e. we dedupe).
        //    - If ephemeral flag, then don't check & don't dedupe?
        // 3. If UnstableReference flag, then ... don't dedupe?
        // 4. If Boundary flag, then ... anything extra?
        // 5. If Eos flag, then close this session:
        //    - remove from _stream_map
        //    - send stream_update() to active stream registry
        //      see this.closed() for example usage
        // 6. What did I forget?  See received_old_school() for hints:
        //    it isn't perfect but it "works" at demo quality.
        // 7. Finish with: return _run_and_subsequent_activity(...)
        //    - Do not fall through to end of match statement.
        @printf[I32]("^*^* got MessageMsg message of the message family of messages, SLF TODO do stuff below\n".cstring())

      | let m: cwm.AckMsg =>
        ifdef "trace" then
          @printf[I32]("^*^* got AckMsg\n".cstring())
        end
        return _to_error_state(source, "Invalid message: ack")

      | let m: cwm.RestartMsg =>
        ifdef "trace" then
          @printf[I32]("^*^* got RestartMsg\n".cstring())
        end
        return _to_error_state(source, "Invalid message: restart")

      end
    else
      @printf[I32](("Unable to decode message at " + _pipeline_name +
        " source\n").cstring())
      ifdef debug then
        Fail()
      end
      return _to_error_state(source, "Unable to decode message")
    end
    _continue_perhaps(source)

  fun ref _run_and_subsequent_activity(latest_metrics_id: U16,
    ingest_ts: U64,
    pipeline_time_spent: U64,
    key_string: String val,
    source: ConnectorSource[In] ref,
    decoded: (In val| None val)): Bool
   =>
    let decode_end_ts = Time.nanos()
    _metrics_reporter.step_metric(_pipeline_name,
      "Decode Time in Connector Source", latest_metrics_id, ingest_ts,
      decode_end_ts)
    let latest_metrics_id' = latest_metrics_id + 1

    let msg_uid = _msg_id_gen()

    // TODO: We need a way to determine the key based on the policy
    // for any particular connector. For example, the Kafka connector
    // needs a way to provide the Kafka key here.

    let initial_key =
      if key_string isnt None then
        key_string
      else
        msg_uid.string()
      end

    (let is_finished, let last_ts) =
      try
        _runner.run[In](_pipeline_name, pipeline_time_spent, decoded as In,
          consume initial_key, _source_id, source, _router,
          msg_uid, None, decode_end_ts,
          latest_metrics_id', ingest_ts, _metrics_reporter)
      else
        (true, ingest_ts)
      end

    if is_finished then
      let end_ts = Time.nanos()
      let time_spent = end_ts - ingest_ts

      ifdef "detailed-metrics" then
        _metrics_reporter.step_metric(_pipeline_name,
          "Before end at Connector Source", 9999,
          last_ts, end_ts)
      end

      _metrics_reporter.pipeline_metric(_pipeline_name, time_spent +
        pipeline_time_spent)
      _metrics_reporter.worker_metric(_pipeline_name, time_spent)
    end

    _continue_perhaps(source)

  fun ref _continue_perhaps(source: ConnectorSource[In] ref): Bool =>
    source.expect(_header_size)
    _header = true
    _continue_perhaps2()

  fun ref _continue_perhaps2(): Bool =>    
    ifdef linux then
      true
    else
      false
    end

  fun ref update_router(router': Router) =>
    _router = router'

  fun ref update_boundaries(obs: box->Map[String, OutgoingBoundary]) =>
    match _router
    | let p_router: StatePartitionRouter =>
      _router = p_router.update_boundaries(_auth, obs)
    else
      ifdef "trace" then
        @printf[I32](("FramedSourceNotify doesn't have StatePartitionRouter." +
          " Updating boundaries is a noop for this kind of Source.\n")
          .cstring())
      end
    end

  fun ref accepted(source: ConnectorSource[In] ref) =>
    @printf[I32]((_source_name + ": accepted a connection\n").cstring())
    if _fsm_state isnt _ProtoFsmDisconnected then
      @printf[I32]("ERROR: %s.connected: state is %d\n".cstring(),
        __loc.type_name().cstring(), _fsm_state())
      Fail()
    end
    _fsm_state = _ProtoFsmConnected
    _header = true
    _session_active = true
    _session_tag = _session_tag + 1
    _stream_map.clear()
    source.expect(_header_size)

  fun ref closed(source: ConnectorSource[In] ref) =>
    @printf[I32]("ConnectorSource connection closed\n".cstring())
    _session_active = false
    _fsm_state = _ProtoFsmDisconnected
    _clear_stream_map()

  fun ref throttled(source: ConnectorSource[In] ref) =>
    @printf[I32]("%s.throttled: %s Experiencing backpressure!\n".cstring(),
      __loc.type_name().cstring(), _pipeline_name.cstring())
    Backpressure.apply(_auth) // SLF TODO: appropriate?

  fun ref unthrottled(source: ConnectorSource[In] ref) =>
    @printf[I32]("%s.unthrottled: %s Releasing backpressure!\n".cstring(),
      __loc.type_name().cstring(), _pipeline_name.cstring())
    Backpressure.release(_auth) // SLF TODO: appropriate?

  fun ref connecting(conn: ConnectorSource[In] ref, count: U32) =>
    """
    Called if name resolution succeeded for a ConnectorSource and we are now
    waiting for a connection to the server to succeed. The count is the number
    of connections we're trying. The notifier will be informed each time the
    count changes, until a connection is made or connect_failed() is called.
    """
    Fail()

  fun ref connected(conn: ConnectorSource[In] ref) =>
    """
    Called when we have successfully connected to the server.
    """
    Fail()

  fun ref connect_failed(conn: ConnectorSource[In] ref) =>
    """
    Called when we have failed to connect to all possible addresses for the
    server. At this point, the connection will never be established.
    """
    Fail()

  fun ref expect(conn: ConnectorSource[In] ref, qty: USize): USize =>
    """
    Called when the connection has been told to expect a certain quantity of
    bytes. This allows nested notifiers to change the expected quantity, which
    allows a lower level protocol to handle any framing (e.g. SSL).
    """
    qty

  fun ref _clear_stream_map() =>
    for (stream_id, s) in _stream_map.pairs() do
      try
        (_active_stream_registry as ConnectorSourceListener[In]).stream_update(
          stream_id, s.barrier_checkpoint_id, s.barrier_last_message_id,
          s.last_message_id, None)
      else
        Fail()
      end
    end
    _stream_map.clear()

  fun ref set_active_stream_registry(
    active_stream_registry: ConnectorSourceListener[In],
    connector_source: ConnectorSource[In] ref) =>
    @printf[I32]("^*^* %s.%s\n".cstring(),
      __loc.type_name().cstring(), __loc.method_name().cstring())
    _active_stream_registry = active_stream_registry
    _connector_source = connector_source

  fun create_checkpoint_state(): Array[ByteSeq val] val =>
    // recover val ["<{stand-in for state for ConnectorSource with routing id="; _source_id.string(); "}>"] end
    let w: Writer = w.create()
    for (stream_id, s) in _stream_map.pairs() do
      w.u64_be(stream_id)
      w.u64_be(s.barrier_checkpoint_id)
      w.u64_be(s.barrier_last_message_id)
      w.u64_be(s.last_message_id)
    end
    w.done()

  fun ref prepare_for_rollback() =>
    // SLF TODO
    if _session_active then
      _clear_stream_map()
      @printf[I32]("^*^* %s.%s\n".cstring(),
        __loc.type_name().cstring(), __loc.method_name().cstring())
    end

  fun ref rollback(checkpoint_id: CheckpointId, payload: ByteSeq val) =>
    @printf[I32]("^*^* %s.%s(%lu)\n".cstring(),
      __loc.type_name().cstring(), __loc.method_name().cstring(),
      checkpoint_id)

    // SLF TODO: invalidate/clear/destroy items in active stream registry
    // that we inserted into the registry.
    let r = Reader
    r.append(payload)
    try
      while true do
        let stream_id = r.u64_be()?
        let barrier_checkpoint_id = r.u64_be()?
        let barrier_last_message_id = r.u64_be()?
        let last_message_id = r.u64_be()?
        @printf[I32]("^*^* read = s-id %lu b-ckp-id %lu b-l-msg-id %lu l-msg-id %lu\n".cstring(),
          stream_id, barrier_checkpoint_id, barrier_last_message_id, last_message_id)
        (_active_stream_registry as ConnectorSourceListener[In]).stream_update(stream_id, barrier_checkpoint_id,
            barrier_last_message_id, last_message_id, None)
      end
    end

  fun ref initiate_barrier(checkpoint_id: CheckpointId) =>
    // SLF TODO
    if _session_active then
      for s in _stream_map.values() do
        s.barrier_checkpoint_id = checkpoint_id
        s.barrier_last_message_id = s.last_message_id
        @printf[I32]("^*^* %s.%s(%lu) _barrier_last_message_id = %lu\n".cstring(),
          __loc.type_name().cstring(), __loc.method_name().cstring(),
          checkpoint_id, s.barrier_last_message_id)
      end
    end

  fun ref barrier_complete(checkpoint_id: CheckpointId) =>
    // SLF TODO
    if _session_active then
      for (stream_id, s) in _stream_map.pairs() do
        @printf[I32]("^*^* %s.%s(%lu) _barrier_last_message_id = %lu, _last_message_id = %lu\n".cstring(),
          __loc.type_name().cstring(), __loc.method_name().cstring(),
          checkpoint_id, s.barrier_last_message_id, s.last_message_id)
        try
          (_active_stream_registry as ConnectorSourceListener[In]).stream_update(
              stream_id, checkpoint_id, s.barrier_last_message_id,
              s.last_message_id,
              (_connector_source as ConnectorSource[In]))
        else
          Fail()
        end
      end
    end

  fun ref stream_notify_result(session_tag: USize, success: Bool,
    stream_id: U64, point_of_reference: U64, last_message_id: U64) =>
    if (session_tag != _session_tag) or (not _session_active) then
      // This is a reply from a query that we'd sent in a prior TCP
      // connection, or else the TCP connection is closed now,
      // so ignore it.
      return
    end

    @printf[I32]("^*^* %s.%s(%s, %lu, p-o-r %lu, l-msgid %lu)\n".cstring(),
      __loc.type_name().cstring(), __loc.method_name().cstring(),
      success.string().cstring(),
      stream_id, point_of_reference, last_message_id)
    try
      let success_reply =
        if success and (not _stream_map.contains(stream_id)) then
          true
        else
          let s = _stream_map(stream_id)?
          if success and s.pending_query then
            s.pending_query = false
            s.base_point_of_reference = point_of_reference
            s.base_point_of_reference = last_message_id // SLF TODO simulation HACK, deleteme!
            s.filter_message_id = last_message_id
            true
          else
            false
          end
        end
      let m = cwm.NotifyAckMsg(success_reply, stream_id, point_of_reference)
      try
        _send_reply(_connector_source as ConnectorSource[In] ref, m)
      else
        Fail()
      end
    else
      Fail()
    end

  fun ref get_all_streams_result(session_tag: USize,
    data: Array[(U64,String,U64)] val)
  =>
    if (session_tag != _session_tag) or (not _session_active) then
      return
    end
    @printf[I32]("^*^* %s.%s(%lu, ...%d...)\n".cstring(),
      __loc.type_name().cstring(), __loc.method_name().cstring(),
      session_tag, data.size())

    let initial_credits: U32 = 20 // SLF TODO: configurable?
    let w: Writer = w.create()
    try
      _send_reply(_connector_source as ConnectorSource[In] ref,
        cwm.OkMsg(initial_credits, data))
    else
      Fail()
    end

    _fsm_state = _ProtoFsmStreaming

  fun ref _to_error_state(source: ConnectorSource[In] ref, msg: String): Bool
  =>
    _send_reply(source, cwm.ErrorMsg(msg))

    _fsm_state = _ProtoFsmError
    source.close()
    _continue_perhaps2()

  fun _send_reply(source: ConnectorSource[In] ref, msg: cwm.Message) =>
    let w1: Writer = w1.create()
    let w2: Writer = w2.create()

    let b1 = cwm.Frame.encode(msg, w1)
    w2.u32_be(b1.size().u32())
    //@printf[I32]("b1: %s\n".cstring(), _print_array[U8](b1).cstring())
    w2.writev([b1])

    let b2 = recover trn w2.done() end
    //for s in b2.values() do
    //  @printf[I32]("b2: partial %s\n".cstring(), _print_array[U8](s).cstring())
    //end
    source.writev_final(consume b2)

  fun _print_array[A: Stringable #read](array: ReadSeq[A]): String =>
    """
    Generate a printable string of the contents of the given readseq to use in
    error messages.
    """
    "[len=" + array.size().string() + ": " + ", ".join(array.values()) + "]"
