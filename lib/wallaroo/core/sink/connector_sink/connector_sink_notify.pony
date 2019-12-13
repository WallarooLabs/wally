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
use "wallaroo_labs/connector_protocol"
use cwm = "wallaroo_labs/connector_wire_messages"
use "wallaroo_labs/logging"
use "wallaroo_labs/mort"

class ConnectorSinkNotify
  var _header: Bool = true
  var _connected: Bool = false
  var _throttled: Bool = false
  let _auth: ApplyReleaseBackpressureAuth
  let _conn_debug: U16 = Log.make_sev_cat(Log.debug(), Log.conn_sink())
  let _conn_info: U16 = Log.make_sev_cat(Log.info(), Log.conn_sink())
  let _conn_err: U16 = Log.make_sev_cat(Log.err(), Log.conn_sink())

  new create(auth: ApplyReleaseBackpressureAuth) =>
    _auth = auth

  fun ref accepted(conn: ConnectorSink ref) =>
    Unreachable()

  fun ref auth_failed(conn: ConnectorSink ref) =>
    Unreachable()

  fun ref connecting(conn: ConnectorSink ref, count: U32) =>
    @ll(_conn_debug, "ConnectorSink connecting".cstring())
    None

  fun ref connected(conn: ConnectorSink ref,
    twopc: ConnectorSink2PC)
  =>
    @ll(_conn_info, "ConnectorSink connected".cstring())
    _header = true
    _connected = true
    _throttled = false
    // Apply runtime throttle until we're done with initial 2PC ballet.
    throttled(conn)
    conn.set_nodelay(true)
    conn.expect(4)

    conn.cb_connected()

  fun ref closed(conn: ConnectorSink ref,
    twopc: ConnectorSink2PC)
  =>
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
    @ll(_conn_info, "ConnectorSink connection closed, throttling".cstring())
    _connected = false
    _throttled = false
    throttled(conn)
    conn.cb_closed()

  fun ref dispose() =>
    @ll(_conn_info, "ConnectorSink connection dispose".cstring())

  fun ref connect_failed(conn: ConnectorSink ref) =>
    @ll(_conn_info, "ConnectorSink connection failed".cstring())

  fun ref expect(conn: ConnectorSink ref, qty: USize): USize =>
    qty

  fun ref received(conn: ConnectorSink ref, data: Array[U8] iso, times: USize): Bool
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
      try
        conn.expect(4)
        _header = true
        let data' = recover val consume data end
        conn.cb_received(data')?
      else
        Fail()
      end
      true
    end

  fun _payload_length(data: Array[U8] iso): USize ? =>
    Bytes.to_u32(data(0)?, data(1)?, data(2)?, data(3)?).usize()

  fun ref sent(conn: ConnectorSink ref, data: (String val | Array[U8 val] val))
    : (String val | Array[U8 val] val)
  =>
    """
    All 2PC messages are sent via send_msg(), which uses
    conn._write_final(), which does *not* filter its data through the
    sent() callback.

    As a result, this function should be unreachable.
    """
    Unreachable()
    data

  fun ref sentv(conn: ConnectorSink ref,
    data: ByteSeqIter): ByteSeqIter
  =>
    """
    All non-2PC data is written to the ConnectorSink via writev(),
    thus all non-2PC data (i.e., all Wallaroo app data that is sent
    to the sink) is filtered by this callback.
    """
    if _connected then
      data
    else
      @ll(_conn_debug, "Sink sentv: not connected".cstring())
      []
    end

  fun ref throttled(conn: ConnectorSink ref) =>
    if (not _throttled) then
      _throttled = true
      if true then
        Backpressure.apply(_auth)
        @ll(_conn_info, ("ConnectorSink is experiencing back pressure, " +
          "connected = %s").cstring(), _connected.string().cstring())
      else
        @ll(_conn_info, ("ConnectorSink is experiencing back pressure SKIPPED, " +
          "connected = %s").cstring(), _connected.string().cstring())
      end
    end

  fun ref unthrottled(conn: ConnectorSink ref) =>
    if _throttled then
      _throttled = false
      if true then
        Backpressure.release(_auth)
        @ll(_conn_info, ("ConnectorSink is no longer experiencing" +
          " back pressure, connected = %s").cstring(),
          _connected.string().cstring())
      else
        @ll(_conn_info, ("ConnectorSink is no longer experiencing" +
          " back pressure SKIPPED, connected = %s").cstring(),
          _connected.string().cstring())
      end
    end
