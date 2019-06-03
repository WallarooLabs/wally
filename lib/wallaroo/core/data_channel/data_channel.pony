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

use "buffered"
use "collections"
use "net"
use "time"
use "wallaroo/core/boundary"
use "wallaroo/core/common"
use "wallaroo/core/data_receiver"
use "wallaroo/core/initialization"
use "wallaroo/core/messages"
use "wallaroo/core/metrics"
use "wallaroo/core/network"
use "wallaroo/core/recovery"
use "wallaroo/core/router_registry"
use "wallaroo/core/tcp_actor"
use "wallaroo_labs/bytes"
use "wallaroo_labs/mort"
use "wallaroo_labs/time"

type DataChannelAuth is (AmbientAuth | NetAuth | TCPAuth | TCPConnectAuth)

actor DataChannel is TCPActor
  var _listener: (DataChannelListener | None) = None
  let _muted_downstream: SetIs[Any tag] = _muted_downstream.create()
  var _tcp_handler: TestableTCPHandler = EmptyTCPHandler

  let _connections: Connections
  let _auth: AmbientAuth
  var _header: Bool = true
  let _metrics_reporter: MetricsReporter
  let _layout_initializer: LayoutInitializer tag
  let _data_receivers: DataReceivers
  let _recovery_replayer: RecoveryReconnecter
  let _router_registry: RouterRegistry

  let _queue: Array[Array[U8] val] = _queue.create()

  // Initial state is an empty DataReceiver wrapper that should never
  // be used (we fail if it is).
  var _receiver: _DataReceiverWrapper = _InitDataReceiver

  new _accept(listener: DataChannelListener,
    tcp_handler_builder: TestableTCPHandlerBuilder,
    connections: Connections, auth: AmbientAuth,
    metrics_reporter: MetricsReporter iso,
    layout_initializer: LayoutInitializer tag,
    data_receivers: DataReceivers, recovery_replayer: RecoveryReconnecter,
    router_registry: RouterRegistry)
  =>
    """
    A new connection accepted on a server.
    """
    _listener = listener
    _connections = connections
    _auth = auth
    _metrics_reporter = consume metrics_reporter
    _layout_initializer = layout_initializer
    _data_receivers = data_receivers
    _recovery_replayer = recovery_replayer
    _router_registry = router_registry
    _receiver = _WaitingDataReceiver(_auth, this, _data_receivers)
    _tcp_handler = tcp_handler_builder(this)
    _tcp_handler.accept()

  fun ref tcp_handler(): TestableTCPHandler =>
    _tcp_handler

  be writev(data: ByteSeqIter) =>
    _tcp_handler.writev(data)

  be mute(d: Any tag) =>
    """
    Temporarily suspend reading off this DataChannel until such time as
    `unmute` is called.
    """
    _mute(d)

  fun ref _mute(d: Any tag) =>
    _muted_downstream.set(d)
    _tcp_handler.mute()

  be unmute(d: Any tag) =>
    """
    Start reading off this DataChannel again after having been muted.
    """
    _unmute(d)

  fun ref _unmute(d: Any tag) =>
    _muted_downstream.unset(d)

    if _muted_downstream.size() == 0 then
      _tcp_handler.unmute()
    end

  fun ref closed(locally_initiated_close: Bool) =>
    @printf[I32]("DataChannel: server closed\n".cstring())
    try (_listener as DataChannelListener)._conn_closed() end

  be dispose() =>
    """
    Close the connection gracefully once all writes are sent.
    """
    @printf[I32]("Shutting down DataChannel\n".cstring())
    close()

  ////////////////////////////////////////
  // !@ OLD DATA_CHANNEL_TCP METHODS
  fun ref queue_msg(msg: Array[U8] val) =>
    _queue.push(msg)

  be identify_data_receiver(dr: DataReceiver, sender_boundary_id: U128,
    highest_seq_id: SeqId)
  =>
    """
    Each abstract data channel (a connection from an OutgoingBoundary)
    corresponds to a single DataReceiver. On reconnect, we want a new
    DataChannel for that boundary to use the same DataReceiver. This is
    called once we have found (or initially created) the DataReceiver for
    the DataChannel corresponding to this notify.
    """
    // State change to our real DataReceiver.
    _receiver = _DataReceiver(_auth, _connections, _metrics_reporter.clone(),
      _layout_initializer, _data_receivers, _recovery_replayer,
      _router_registry, this, dr)
    dr.data_connect(sender_boundary_id, highest_seq_id, this)
    for msg in _queue.values() do
      _receiver.decode_and_process(msg)
    end
    _queue.clear()

    _unmute(this)

  fun ref received(data: Array[U8] iso, times: USize): Bool
  =>
    if _header then
      ifdef "trace" then
        @printf[I32]("Rcvd msg header on data channel\n".cstring())
      end
      try
        let expect_bytes =
          Bytes.to_u32(data(0)?, data(1)?, data(2)?, data(3)?).usize()

        expect(expect_bytes)
        _header = false
      end
      true
    else
      ifdef "trace" then
        @printf[I32]("Rcvd msg on data channel\n".cstring())
      end
      _receiver.decode_and_process(consume data)

      expect(4)
      _header = true

      ifdef linux then
        true
      else
        false
      end
    end

  fun ref accepted() =>
    @printf[I32]("accepted data channel connection\n".cstring())
    set_nodelay(true)
    expect(4)

  fun ref connected() =>
    @printf[I32]("incoming connected on data channel\n".cstring())


trait _DataReceiverWrapper
  fun ref decode_and_process(data: Array[U8] val) =>
    Fail()

class _InitDataReceiver is _DataReceiverWrapper

class _WaitingDataReceiver is _DataReceiverWrapper
  let _auth: AmbientAuth
  let _data_channel: DataChannel ref
  let _data_receivers: DataReceivers

  new create(auth: AmbientAuth, data_channel: DataChannel ref,
    data_receivers: DataReceivers)
  =>
    _auth = auth
    _data_channel = data_channel
    _data_receivers = data_receivers

  fun ref decode_and_process(data: Array[U8] val) =>
    match ChannelMsgDecoder(data, _auth)
    | let dc: DataConnectMsg =>
      ifdef "trace" then
        @printf[I32]("Received DataConnectMsg on Data Channel\n".cstring())
      end
      // Before we can begin processing messages on this data channel, we
      // need to determine which DataReceiver we'll be forwarding data
      // messages to.
      _data_channel._mute(_data_channel)
      _data_receivers.request_data_receiver(dc.sender_name,
        dc.sender_boundary_id, dc.highest_seq_id, _data_channel)
    else
      _data_channel.queue_msg(data)
    end

class _DataReceiver is _DataReceiverWrapper
  let _auth: AmbientAuth
  let _connections: Connections
  let _metrics_reporter: MetricsReporter
  let _layout_initializer: LayoutInitializer tag
  let _data_receivers: DataReceivers
  let _recovery_replayer: RecoveryReconnecter
  let _router_registry: RouterRegistry
  let _data_channel: DataChannel ref
  let _data_receiver: DataReceiver

  new create(auth: AmbientAuth, connections: Connections,
    metrics_reporter: MetricsReporter iso,
    layout_initializer: LayoutInitializer tag,
    data_receivers: DataReceivers, recovery_replayer: RecoveryReconnecter,
    router_registry: RouterRegistry,
    data_channel: DataChannel ref, dr: DataReceiver)
  =>
    _auth = auth
    _connections = connections
    _metrics_reporter = consume metrics_reporter
    _layout_initializer = layout_initializer
    _data_receivers = data_receivers
    _recovery_replayer = recovery_replayer
    _router_registry = router_registry
    _data_channel = data_channel
    _data_receiver = dr

  fun ref decode_and_process(data: Array[U8] val) =>
    // because we received this from another worker
    let ingest_ts = WallClock.nanoseconds()
    let my_latest_ts = ingest_ts

    match ChannelMsgDecoder(data, _auth)
    | let data_msg: DataMsg =>
      ifdef "trace" then
        @printf[I32]("Received DataMsg on Data Channel\n".cstring())
      end
      _metrics_reporter.step_metric(data_msg.metric_name,
        "Before receive on data channel (network time)", data_msg.metrics_id,
        data_msg.latest_ts, ingest_ts)
      _data_receiver.received(data_msg.delivery_msg, data_msg.producer_id,
          data_msg.pipeline_time_spent + (ingest_ts - data_msg.latest_ts),
          data_msg.seq_id, my_latest_ts, data_msg.metrics_id + 1,
          my_latest_ts)
    | let dc: DataConnectMsg =>
      @printf[I32](("Received DataConnectMsg on DataChannel, but we already " +
        "have a DataReceiver for this connection.\n").cstring())
    | let ia: DataReceiverAckImmediatelyMsg =>
      _data_receiver.data_receiver_ack_immediately()
    | let km: KeyMigrationMsg =>
      ifdef "trace" then
        @printf[I32]("Received KeyMigrationMsg on Data Channel\n".cstring())
      end
      _layout_initializer.receive_immigrant_key(km)
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
    | let m: SpinUpLocalTopologyMsg =>
      @printf[I32]("Received spin up local topology message!\n".cstring())
    | let m: ReportStatusMsg =>
      _data_receiver.report_status(m.code)
    | let m: RegisterProducerMsg =>
      _data_receiver.register_producer(m.source_id, m.target_id)
    | let m: UnregisterProducerMsg =>
      _data_receiver.unregister_producer(m.source_id, m.target_id)
    | let m: ForwardBarrierMsg =>
      _data_receiver.forward_barrier(m.target_id, m.origin_id, m.token, m.seq_id)
    | let m: UnknownChannelMsg =>
      @printf[I32]("Unknown Wallaroo data message type: UnknownChannelMsg.\n"
        .cstring())
    else
      @printf[I32]("Unknown Wallaroo data message type.\n".cstring())
    end


