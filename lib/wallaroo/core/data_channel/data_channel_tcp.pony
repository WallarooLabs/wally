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

use "buffered"
use "collections"
use "time"
use "files"
use "wallaroo_labs/bytes"
use "wallaroo_labs/time"
use "wallaroo/core/boundary"
use "wallaroo/core/common"
use "wallaroo/ent/barrier"
use "wallaroo/ent/data_receiver"
use "wallaroo/ent/network"
use "wallaroo/ent/recovery"
use "wallaroo/ent/router_registry"
use "wallaroo/ent/checkpoint"
use "wallaroo_labs/mort"
use "wallaroo/core/messages"
use "wallaroo/core/metrics"
use "wallaroo/core/topology"
use "wallaroo/core/initialization"

class DataChannelListenNotifier is DataChannelListenNotify
  let _name: String
  let _auth: AmbientAuth
  let _is_initializer: Bool
  let _recovery_file: FilePath
  var _host: String = ""
  var _service: String = ""
  let _connections: Connections
  let _metrics_reporter: MetricsReporter
  let _layout_initializer: LayoutInitializer tag
  let _data_receivers: DataReceivers
  let _recovery_replayer: RecoveryReconnecter
  let _router_registry: RouterRegistry
  let _joining_existing_cluster: Bool

  new iso create(name: String, auth: AmbientAuth,
    connections: Connections, is_initializer: Bool,
    metrics_reporter: MetricsReporter iso,
    recovery_file: FilePath,
    layout_initializer: LayoutInitializer tag,
    data_receivers: DataReceivers, recovery_replayer: RecoveryReconnecter,
    router_registry: RouterRegistry, joining: Bool = false)
  =>
    _name = name
    _auth = auth
    _is_initializer = is_initializer
    _connections = connections
    _metrics_reporter = consume metrics_reporter
    _recovery_file = recovery_file
    _layout_initializer = layout_initializer
    _data_receivers = data_receivers
    _recovery_replayer = recovery_replayer
    _router_registry = router_registry
    _joining_existing_cluster = joining

  fun ref listening(listen: DataChannelListener ref) =>
    try
      (_host, _service) = listen.local_address().name()?
      if _host == "::1" then _host = "127.0.0.1" end

      if not _is_initializer then
        _connections.register_my_data_addr(_host, _service)
      end
      _router_registry.register_data_channel_listener(listen)

      @printf[I32]((_name + " data channel: listening on " + _host + ":" +
        _service + "\n").cstring())
      if _recovery_file.exists() then
        @printf[I32]("Recovery file exists for data channel\n".cstring())
      end
      if _joining_existing_cluster then
        //TODO: Do we actually need to do this? Isn't this sent as
        // part of joining worker initialized message?
        let message = ChannelMsgEncoder.identify_data_port(_name, _service,
          _auth)?
        _connections.send_control_to_cluster(message)
      else
        if not _recovery_file.exists() then
          let message = ChannelMsgEncoder.identify_data_port(_name, _service,
            _auth)?
          _connections.send_control_to_cluster(message)
        end
      end
      let f = File(_recovery_file)
      f.print(_host)
      f.print(_service)
      f.sync()
      f.dispose()
    else
      @printf[I32]((_name + " data: couldn't get local address\n").cstring())
      listen.close()
    end

  fun ref not_listening(listen: DataChannelListener ref) =>
    (let h, let s) = try
      listen.local_address().name(None, false)?
    else
      listen.requested_address()
    end
    @printf[I32]((_name + " data: unable to listen on (%s:%s)\n").cstring(),
      h.cstring(), s.cstring())
    Fail()

  fun ref connected(
    listen: DataChannelListener ref,
    router_registry: RouterRegistry): DataChannelNotify iso^
  =>
    DataChannelConnectNotifier(_connections, _auth,
    _metrics_reporter.clone(), _layout_initializer, _data_receivers,
    _recovery_replayer, router_registry)

class DataChannelConnectNotifier is DataChannelNotify
  let _connections: Connections
  let _auth: AmbientAuth
  var _header: Bool = true
  let _metrics_reporter: MetricsReporter
  let _layout_initializer: LayoutInitializer tag
  let _data_receivers: DataReceivers
  let _recovery_replayer: RecoveryReconnecter
  let _router_registry: RouterRegistry

  // Initial state is an empty DataReceiver wrapper that should never
  // be used (we fail if it is).
  var _receiver: _DataReceiverWrapper = _InitDataReceiver

  // Keep track of register_producer calls that we weren't ready to forward
  let _queued_register_producers: Array[(RoutingId, RoutingId)] =
    _queued_register_producers.create()
  let _queued_unregister_producers: Array[(RoutingId, RoutingId)] =
    _queued_register_producers.create()

  new iso create(connections: Connections, auth: AmbientAuth,
    metrics_reporter: MetricsReporter iso,
    layout_initializer: LayoutInitializer tag,
    data_receivers: DataReceivers, recovery_replayer: RecoveryReconnecter,
    router_registry: RouterRegistry)
  =>
    _connections = connections
    _auth = auth
    _metrics_reporter = consume metrics_reporter
    _layout_initializer = layout_initializer
    _data_receivers = data_receivers
    _recovery_replayer = recovery_replayer
    _router_registry = router_registry
    _receiver = _WaitingDataReceiver(this)

  fun ref identify_data_receiver(dr: DataReceiver, sender_boundary_id: U128,
    highest_seq_id: SeqId, conn: DataChannel ref)
  =>
    """
    Each abstract data channel (a connection from an OutgoingBoundary)
    corresponds to a single DataReceiver. On reconnect, we want a new
    DataChannel for that boundary to use the same DataReceiver. This is
    called once we have found (or initially created) the DataReceiver for
    the DataChannel corresponding to this notify.
    """
    // State change to our real DataReceiver.
    _receiver = _DataReceiver(dr)
    _receiver.data_connect(sender_boundary_id, highest_seq_id, conn)

    // If we have pending register_producer calls, then try to process them now
    var retries = Array[(RoutingId, RoutingId)]
    for r in _queued_register_producers.values() do
      retries.push(r)
    end
    _queued_register_producers.clear()
    for (input, output) in retries.values() do
      _receiver.register_producer(input, output)
    end
    // If we have pending unregister_producer calls, then try to process them
    // now
    retries = Array[(RoutingId, RoutingId)]
    for r in _queued_unregister_producers.values() do
      retries.push(r)
    end
    _queued_unregister_producers.clear()
    for (input, output) in retries.values() do
      _receiver.unregister_producer(input, output)
    end

    conn._unmute(this)

  fun ref queue_register_producer(input_id: RoutingId, output_id: RoutingId) =>
    _queued_register_producers.push((input_id, output_id))

  fun ref queue_unregister_producer(input_id: RoutingId, output_id: RoutingId) =>
    _queued_unregister_producers.push((input_id, output_id))

  fun ref received(conn: DataChannel ref, data: Array[U8] iso): Bool
  =>
    if _header then
      ifdef "trace" then
        @printf[I32]("Rcvd msg header on data channel\n".cstring())
      end
      try
        let expect =
          Bytes.to_u32(data(0)?, data(1)?, data(2)?, data(3)?).usize()

        conn.expect(expect)
        _header = false
      end
      true
    else
      // because we received this from another worker
      let ingest_ts = WallClock.nanoseconds()
      let my_latest_ts = Time.nanos()

      ifdef "trace" then
        @printf[I32]("Rcvd msg on data channel\n".cstring())
      end
      match ChannelMsgDecoder(consume data, _auth)
      | let data_msg: DataMsg =>
        ifdef "trace" then
          @printf[I32]("Received DataMsg on Data Channel\n".cstring())
        end
        _metrics_reporter.step_metric(data_msg.metric_name,
          "Before receive on data channel (network time)", data_msg.metrics_id,
          data_msg.latest_ts, ingest_ts)
        _receiver.received(data_msg.delivery_msg,
            data_msg.pipeline_time_spent + (ingest_ts - data_msg.latest_ts),
            data_msg.seq_id, my_latest_ts, data_msg.metrics_id + 1,
            my_latest_ts)
      | let dc: DataConnectMsg =>
        ifdef "trace" then
          @printf[I32]("Received DataConnectMsg on Data Channel\n".cstring())
        end
        // Before we can begin processing messages on this data channel, we
        // need to determine which DataReceiver we'll be forwarding data
        // messages to.
        conn._mute(this)
        _data_receivers.request_data_receiver(dc.sender_name,
          dc.sender_boundary_id, dc.highest_seq_id, conn)
      | let sm: StepMigrationMsg =>
        ifdef "trace" then
          @printf[I32]("Received StepMigrationMsg on Data Channel\n".cstring())
        end
        _layout_initializer.receive_immigrant_step(sm)
      | let m: MigrationBatchCompleteMsg =>
        ifdef "trace" then
          @printf[I32]("Received MigrationBatchCompleteMsg on Data Channel\n".cstring())
        end
        // Go through layout_initializer and router_registry to make sure
        // pending messages on registry are processed first. That's because
        // the current message path for receiving immigrant steps is
        // layout_initializer then router_registry.
        _layout_initializer.ack_migration_batch_complete(m.sender_name)
      | let aw: AckDataReceivedMsg =>
        ifdef "trace" then
          @printf[I32]("Received AckDataReceivedMsg on Data Channel\n"
            .cstring())
        end
        Fail()
      | let r: ReplayMsg =>
        ifdef "trace" then
          @printf[I32]("Received ReplayMsg on Data Channel\n".cstring())
        end
        try
          match r.msg(_auth)?
          | let data_msg: DataMsg =>
            _metrics_reporter.step_metric(data_msg.metric_name,
              "Before replay receive on data channel (network time)",
              data_msg.metrics_id, data_msg.latest_ts, ingest_ts)
            _receiver.replay_received(data_msg.delivery_msg,
              data_msg.pipeline_time_spent + (ingest_ts - data_msg.latest_ts),
              data_msg.seq_id, my_latest_ts, data_msg.metrics_id + 1,
              my_latest_ts)
          | let fbm: ForwardBarrierMsg =>
            _receiver.forward_barrier(fbm.target_id, fbm.origin_id, fbm.token,
              fbm.seq_id)
          end
        else
          Fail()
        end
      | let c: ReplayCompleteMsg =>
        ifdef "trace" then
          @printf[I32]("Received ReplayCompleteMsg on Data Channel\n"
            .cstring())
        end
        //!@ We should probably be removing this whole message
        // _recovery_replayer.add_boundary_replay_complete(c.sender_name,
        //   c.boundary_id)
      | let m: SpinUpLocalTopologyMsg =>
        @printf[I32]("Received spin up local topology message!\n".cstring())
      | let m: ReportStatusMsg =>
        _receiver.report_status(m.code)
      | let m: RegisterProducerMsg =>
        _receiver.register_producer(m.source_id, m.target_id)
      | let m: UnregisterProducerMsg =>
        _receiver.unregister_producer(m.source_id, m.target_id)
      | let m: ForwardBarrierMsg =>
        _receiver.forward_barrier(m.target_id, m.origin_id, m.token, m.seq_id)
      | let m: UnknownChannelMsg =>
        @printf[I32]("Unknown Wallaroo data message type: UnknownChannelMsg.\n"
          .cstring())
      else
        @printf[I32]("Unknown Wallaroo data message type.\n".cstring())
      end

      conn.expect(4)
      _header = true

      ifdef linux then
        true
      else
        false
      end
    end

  fun ref accepted(conn: DataChannel ref) =>
    @printf[I32]("accepted data channel connection\n".cstring())
    conn.set_nodelay(true)
    conn.expect(4)

  fun ref connected(sock: DataChannel ref) =>
    @printf[I32]("incoming connected on data channel\n".cstring())

  fun ref closed(conn: DataChannel ref) =>
    @printf[I32]("DataChannelConnectNotifier: server closed\n".cstring())
    //TODO: Initiate reconnect to downstream node here. We need to
    //      create a new connection in OutgoingBoundary

trait _DataReceiverWrapper
  fun data_connect(sender_step_id: RoutingId, highest_seq_id: SeqId,
    conn: DataChannel)
  =>
    Fail()
  fun received(d: DeliveryMsg, pipeline_time_spent: U64, seq_id: U64,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    Fail()
  fun replay_received(r: ReplayableDeliveryMsg, pipeline_time_spent: U64,
    seq_id: U64, latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    Fail()
  fun report_status(code: ReportStatusCode) =>
    Fail()

  fun ref register_producer(input_id: RoutingId, output_id: RoutingId) =>
    Fail()
  fun ref unregister_producer(input_id: RoutingId, output_id: RoutingId) =>
    Fail()

  fun forward_barrier(target_id: RoutingId, origin_id: RoutingId,
    token: BarrierToken, seq_id: SeqId)
  =>
    Fail()

class _InitDataReceiver is _DataReceiverWrapper

class _WaitingDataReceiver is _DataReceiverWrapper
  let _dccn: DataChannelConnectNotifier ref

  new create(dccn: DataChannelConnectNotifier ref) =>
    _dccn = dccn

  fun ref register_producer(input_id: RoutingId, output_id: RoutingId) =>
    _dccn.queue_register_producer(input_id, output_id)

  fun ref unregister_producer(input_id: RoutingId, output_id: RoutingId) =>
    _dccn.queue_unregister_producer(input_id, output_id)

class _DataReceiver is _DataReceiverWrapper
  let data_receiver: DataReceiver

  new create(dr: DataReceiver) =>
    data_receiver = dr

  fun data_connect(sender_step_id: RoutingId, highest_seq_id: SeqId,
    conn: DataChannel)
  =>
    data_receiver.data_connect(sender_step_id, highest_seq_id, conn)

  fun received(d: DeliveryMsg, pipeline_time_spent: U64, seq_id: U64,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    data_receiver.received(d, pipeline_time_spent, seq_id, latest_ts,
      metrics_id, worker_ingress_ts)

  fun replay_received(r: ReplayableDeliveryMsg, pipeline_time_spent: U64,
    seq_id: U64, latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    data_receiver.replay_received(r, pipeline_time_spent, seq_id, latest_ts,
      metrics_id, worker_ingress_ts)

  fun report_status(code: ReportStatusCode) =>
    data_receiver.report_status(code)

  fun ref register_producer(input_id: RoutingId, output_id: RoutingId) =>
    data_receiver.register_producer(input_id, output_id)

  fun ref unregister_producer(input_id: RoutingId, output_id: RoutingId) =>
    data_receiver.unregister_producer(input_id, output_id)

  fun forward_barrier(target_id: RoutingId, origin_id: RoutingId,
    token: BarrierToken, seq_id: SeqId)
  =>
    data_receiver.forward_barrier(target_id, origin_id, token, seq_id)
