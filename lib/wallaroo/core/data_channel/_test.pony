/*

Copyright (C) 2016-2017, Wallaroo Labs
Copyright (C) 2016-2017, The Pony Developers
Copyright (c) 2014-2015, Causality Ltd.
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

use "ponytest"
use "wallaroo/core/boundary"
use "wallaroo/ent/data_receiver"
use "wallaroo/ent/network"
use "wallaroo/ent/recovery"
use "wallaroo/ent/router_registry"
use "wallaroo/core/metrics"
use "wallaroo/core/topology"

actor Main is TestList
  new create(env: Env) => PonyTest(env, this)
  new make() => None

  fun tag tests(test: PonyTest) =>
    test(_TestDataChannelWritev)
    test(_TestDataChannelExpect)

class _TestDataChannel is DataChannelListenNotify
  """
  Run a typical TCP test consisting of a single DataChannelListener that
  accepts a single DataChannel as a client, using a dynamic available listen
  port.
  """
  let _h: TestHelper
  var _client_conn_notify: (DataChannelNotify iso | None) = None
  var _server_conn_notify: (DataChannelNotify iso | None) = None

  new iso create(h: TestHelper) =>
    _h = h

  fun iso apply(c: DataChannelNotify iso, s: DataChannelNotify iso) =>
    _client_conn_notify = consume c
    _server_conn_notify = consume s

    let h = _h
    h.expect_action("server create")
    h.expect_action("server listen")
    h.expect_action("client create")
    h.expect_action("server accept")

    try
      let auth = h.env.root as AmbientAuth
      let event_log = EventLog()
      let conns = Connections("app_name", "worker_name", auth,
        "127.0.0.1", "0",
        "127.0.0.1", "0",
        _NullMetricsSink, "127.0.0.1", "0",
        true, "/tmp/foo_connections.txt", false
        where event_log = event_log)
      let dr = DataReceivers(auth, conns, "worker_name")
      let rr = RouterRegistry(auth, "worker_name", dr, conns, 1)
      h.dispose_when_done(DataChannelListener(auth, consume this, rr))
      h.dispose_when_done(conns)
      h.complete_action("server create")
    else
      h.fail_action("server create")
    end

    h.long_test(2_000_000_000)

  fun ref not_listening(listen: DataChannelListener ref) =>
    _h.fail_action("server listen")

  fun ref listening(listen: DataChannelListener ref) =>
    _h.complete_action("server listen")

    try
      let auth = _h.env.root as AmbientAuth
      let notify = (_client_conn_notify = None) as DataChannelNotify iso^
      (let host, let port) = listen.local_address().name()?
      _h.dispose_when_done(DataChannel(auth, consume notify, host, port))
      _h.complete_action("client create")
    else
      _h.fail_action("client create")
    end

  fun ref connected(listen: DataChannelListener ref,
    router_registry: RouterRegistry): DataChannelNotify iso^ ?
  =>
    try
      let notify = (_server_conn_notify = None) as DataChannelNotify iso^
      _h.complete_action("server accept")
      consume notify
    else
      _h.fail_action("server accept")
      error
    end

class iso _TestDataChannelExpect is UnitTest
  """
  Test expecting framed data with TCP.
  """
  fun name(): String => "data_channel/expect"
  fun exclusion_group(): String => "data_channel"

  fun ref apply(h: TestHelper) =>
    h.expect_action("client receive")
    h.expect_action("server receive")
    h.expect_action("expect received")

    _TestDataChannel(h)(_TestDataChannelExpectNotify(h, false), _TestDataChannelExpectNotify(h, true))

class _TestDataChannelExpectNotify is DataChannelNotify
  let _h: TestHelper
  let _server: Bool
  var _expect: USize = 4
  var _frame: Bool = true

  new iso create(h: TestHelper, server: Bool) =>
    _server = server
    _h = h

  fun ref accepted(conn: DataChannel ref) =>
    conn.set_nodelay(true)
    conn.expect(_expect)
    _send(conn, "hi there")

  fun ref connect_failed(conn: DataChannel ref) =>
    _h.fail_action("client connect")

  fun ref connected(conn: DataChannel ref) =>
    _h.complete_action("client connect")
    conn.set_nodelay(true)
    conn.expect(_expect)

  fun ref expect(conn: DataChannel ref, qty: USize): USize =>
    _h.complete_action("expect received")
    qty

  fun ref received(conn: DataChannel ref, data: Array[U8] val,
    n: USize): Bool
  =>
    if _frame then
      _frame = false
      _expect = 0

      for i in data.values() do
        _expect = (_expect << 8) + i.usize()
      end
    else
      _h.assert_eq[USize](_expect, data.size())

      if _server then
        _h.complete_action("server receive")
        _h.assert_eq[String](String.from_array(data), "goodbye")
      else
        _h.complete_action("client receive")
        _h.assert_eq[String](String.from_array(data), "hi there")
        _send(conn, "goodbye")
      end

      _frame = true
      _expect = 4
    end

    conn.expect(_expect)
    true

  fun ref identify_data_receiver(dr: DataReceiver, sender_boundary_id: U128,
    conn: DataChannel ref)
  =>
    None

  fun ref _send(conn: DataChannel ref, data: String) =>
    let len = data.size()

    var buf = recover Array[U8] end
    buf.push((len >> 24).u8())
    buf.push((len >> 16).u8())
    conn.write(consume buf)

    buf = recover Array[U8] end
    buf.push((len >> 8).u8())
    buf.push((len >> 0).u8())
    buf.append(data)
    conn.write(consume buf)

class iso _TestDataChannelWritev is UnitTest
  """
  Test writev (and sent/sentv notification).
  """
  fun name(): String => "data_channel/writev"
  fun exclusion_group(): String => "data_channel"

  fun ref apply(h: TestHelper) =>
    h.expect_action("client connect")
    h.expect_action("server receive")

    _TestDataChannel(h)(_TestDataChannelWritevNotifyClient(h), _TestDataChannelWritevNotifyServer(h))

class _TestDataChannelWritevNotifyClient is DataChannelNotify
  let _h: TestHelper

  new iso create(h: TestHelper) =>
    _h = h

  fun ref sentv(conn: DataChannel ref, data: ByteSeqIter): ByteSeqIter =>
    recover Array[ByteSeq].>concat(data.values()).>push(" (from client)") end

  fun ref connected(conn: DataChannel ref) =>
    _h.complete_action("client connect")
    conn.writev(recover ["hello"; ", hello"] end)

  fun ref connect_failed(conn: DataChannel ref) =>
    _h.fail_action("client connect")

  fun ref identify_data_receiver(dr: DataReceiver, sender_boundary_id: U128,
    conn: DataChannel ref)
  =>
    None

class _TestDataChannelWritevNotifyServer is DataChannelNotify
  let _h: TestHelper
  var _buffer: String iso = recover iso String end

  new iso create(h: TestHelper) =>
    _h = h

  fun ref received(conn: DataChannel ref, data: Array[U8] iso,
    n: USize): Bool
  =>
    _buffer.append(consume data)

    let expected = "hello, hello (from client)"

    if _buffer.size() >= expected.size() then
      let buffer: String = _buffer = recover iso String end
      _h.assert_eq[String](expected, consume buffer)
      _h.complete_action("server receive")
    end
    true

  fun ref identify_data_receiver(dr: DataReceiver, sender_boundary_id: U128,
    conn: DataChannel ref)
  =>
    None

actor _NullMetricsSink
  be send_metrics(metrics: MetricDataList val) =>
    None

  fun ref set_nodelay(state: Bool) =>
    None

  be writev(data: ByteSeqIter) =>
    None

  be dispose() =>
    None
