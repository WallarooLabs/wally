/*

Copyright 2018 The Wallaroo Authors.

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

use "ponytest"
use "wallaroo/core/boundary"
use "wallaroo/core/common"
use "wallaroo/core/network"
use "wallaroo/core/routing"

actor Main is TestList
  new make() =>
    None

  fun tag tests(test: PonyTest) =>
    test(_TestDropsConnectionWhenConnectingWhenSpiked)
    test(_TestDoesntDropConnectionWhenConnectingWhenNotSpiked)
    test(_TestDropsConnectionWhenConnectedWhenSpiked)
    test(_TestDoesntDropConnectionWhenConnectedWhenNotSpiked)
    test(_TestDoesntDropConnectionWhenConnectFailedWhenSpiked)
    test(_TestDoesntDropConnectionWhenConnectFailedWhenNotSpiked)
    test(_TestDoesntDropConnectionWhenClosedWhenSpiked)
    test(_TestDoesntDropConnectionWhenClosedWhenNotSpiked)
    test(_TestDropsConnectionWhenSentvWhenSpiked)
    test(_TestDoesntDropConnectionWhenSentvWhenNotSpiked)
    test(_TestDropsConnectionWhenReceivedWhenSpiked)
    test(_TestDoesntDropConnectionWhenReceivedWhenNotSpiked)
    test(_TestDoesntDropConnectionWhenExpectWhenSpiked)
    test(_TestDoesntDropConnectionWhenExpectWhenNotSpiked)
    test(_TestDoesntDropConnectionWhenThrottledWhenSpiked)
    test(_TestDoesntDropConnectionWhenThrottledWhenNotSpiked)
    test(_TestDoesntDropConnectionWhenUnthrottledWhenSpiked)
    test(_TestDoesntDropConnectionWhenUnthrottledWhenNotSpiked)
    test(_TestDropsConnectionWhenSpikedWithMargin)

class iso _TestDropsConnectionWhenConnectingWhenSpiked is UnitTest
  fun name(): String =>
    "spike/DropsConnectionWhenConnectingWhenSpiked"

  fun ref apply(h: TestHelper) ? =>
    let spike_probability = F64(1)
    let expected_actions = recover val ["connecting"; "closed"] end
    let connection_count = U32(1)
    _TestConnection(spike_probability, expected_actions, connection_count, h)?
      .simulate_connecting(connection_count)

    h.long_test(10_000_000_000)

class iso _TestDoesntDropConnectionWhenConnectingWhenNotSpiked is UnitTest
  fun name(): String =>
    "spike/DoesntDropConnectionWhenConnectingWhenNotSpiked"

  fun ref apply(h: TestHelper) ? =>
    let spike_probability = F64(0)
    let expected_actions = recover val ["connecting"] end
    let connection_count = U32(1)
    _TestConnection(spike_probability, expected_actions, connection_count, h)?
      .simulate_connecting(connection_count)

    h.long_test(10_000_000_000)

class iso _TestDropsConnectionWhenConnectedWhenSpiked is UnitTest
  fun name(): String =>
    "spike/DropsConnectionWhenConnectedWhenSpiked"

  fun ref apply(h: TestHelper) ? =>
    let spike_probability = F64(1)
    let expected_actions = recover val ["connected"; "closed"] end
    let connection_count = U32(1)
    _TestConnection(spike_probability, expected_actions, connection_count, h)?
      .simulate_connected()

    h.long_test(10_000_000_000)

class iso _TestDoesntDropConnectionWhenConnectedWhenNotSpiked is UnitTest
  fun name(): String =>
    "spike/DoesntDropConnectionWhenConnectedWhenNotSpiked"

  fun ref apply(h: TestHelper) ? =>
    let spike_probability = F64(0)
    let expected_actions = recover val ["connected"] end
    let connection_count = U32(1)
    _TestConnection(spike_probability, expected_actions, connection_count, h)?
      .simulate_connected()

    h.long_test(10_000_000_000)

class iso _TestDoesntDropConnectionWhenConnectFailedWhenSpiked is UnitTest
  fun name(): String =>
    "spike/DoesntDropConnectionWhenConnectFailed"

  fun ref apply(h: TestHelper) ? =>
    let spike_probability = F64(1)
    let expected_actions = recover val ["connect_failed"] end
    let connection_count = U32(1)
    _TestConnection(spike_probability, expected_actions, connection_count, h)?
      .simulate_connect_failed()

    h.long_test(10_000_000_000)

class iso _TestDoesntDropConnectionWhenConnectFailedWhenNotSpiked is UnitTest
  fun name(): String =>
    "spike/DoesntDropConnectionWhenConnectFailedWhenNotSpiked"

  fun ref apply(h: TestHelper) ? =>
    let spike_probability = F64(0)
    let expected_actions = recover val ["connect_failed"] end
    let connection_count = U32(1)
    _TestConnection(spike_probability, expected_actions, connection_count, h)?
      .simulate_connect_failed()

    h.long_test(10_000_000_000)

class iso _TestDoesntDropConnectionWhenClosedWhenSpiked is UnitTest
  fun name(): String =>
    "spike/DoesntDropConnectionWhenConnectFailed"

  fun ref apply(h: TestHelper) ? =>
    let spike_probability = F64(1)
    let expected_actions = recover val ["closed"] end
    let connection_count = U32(1)
    _TestConnection(spike_probability, expected_actions, connection_count, h)?
      .simulate_closed()

    h.long_test(10_000_000_000)

class iso _TestDoesntDropConnectionWhenClosedWhenNotSpiked is UnitTest
  fun name(): String =>
    "spike/DoesntDropConnectionWhenClosedWhenNotSpiked"

  fun ref apply(h: TestHelper) ? =>
    let spike_probability = F64(0)
    let expected_actions = recover val ["closed"] end
    let connection_count = U32(1)
    _TestConnection(spike_probability, expected_actions, connection_count, h)?
      .simulate_closed()

    h.long_test(10_000_000_000)

class iso _TestDropsConnectionWhenSentvWhenSpiked is UnitTest
  fun name(): String =>
    "spike/DropsConnectionWhenSentvWhenSpiked"

  fun ref apply(h: TestHelper) ? =>
    let spike_probability = F64(1)
    let expected_actions = recover val ["sentv"; "closed"] end
    let connection_count = U32(1)
    let data = recover val ["Hello"; "Willow"] end
    _TestConnection(spike_probability, expected_actions, connection_count, h)?
      .simulate_sentv(data)

    h.long_test(10_000_000_000)

class iso _TestDoesntDropConnectionWhenSentvWhenNotSpiked is UnitTest
  fun name(): String =>
    "spike/DoesntDropConnectionWhenSentvWhenNotSpiked"

  fun ref apply(h: TestHelper) ? =>
    let spike_probability = F64(0)
    let expected_actions = recover val ["sentv"] end
    let connection_count = U32(1)
    let data = recover val ["Goodbye"; "Angel"] end
    _TestConnection(spike_probability, expected_actions, connection_count, h)?
      .simulate_sentv(data)

    h.long_test(10_000_000_000)

class iso _TestDropsConnectionWhenReceivedWhenSpiked is UnitTest
  fun name(): String =>
    "spike/DropsConnectionWhenReceivedWhenSpiked"

  fun ref apply(h: TestHelper) ? =>
    let spike_probability = F64(1)
    let expected_actions = recover val ["received"; "closed"] end
    let connection_count = U32(1)
    let times = USize(3)
    let expected_data = recover val [as U8: 1; 2; 3; 4; 5; 10] end
    let send_data = recover iso [as U8: 1; 2; 3; 4; 5; 10] end
    _TestConnection(spike_probability, expected_actions, connection_count, h
      where expected_data = expected_data)?
        .simulate_received(consume send_data, times)

    h.long_test(10_000_000_000)

class iso _TestDoesntDropConnectionWhenReceivedWhenNotSpiked is UnitTest
  fun name(): String =>
    "spike/DoesntDropConnectionWhenReceivedWhenNotSpiked"

  fun ref apply(h: TestHelper) ? =>
    let spike_probability = F64(0)
    let expected_actions = recover val ["received"] end
    let connection_count = U32(1)
    let times = USize(3)
    let expected_data = recover val [as U8: 1; 2; 3; 4; 5; 10] end
    let send_data = recover iso [as U8: 1; 2; 3; 4; 5; 10] end
    _TestConnection(spike_probability, expected_actions, connection_count, h
      where expected_data = expected_data)?
        .simulate_received(consume send_data, times)

    h.long_test(10_000_000_000)

class iso _TestDoesntDropConnectionWhenExpectWhenSpiked is UnitTest
  fun name(): String =>
    "spike/DoesntDropConnectionWhenExpectWhenSpiked"

  fun ref apply(h: TestHelper) ? =>
    //!@ What is this test testing? Why doesn't Spike close it when expect?

    let spike_probability = F64(1)
    let expected_actions = recover val ["expect"] end
    let connection_count = U32(1)
    let qty = USize(13)
    _TestConnection(spike_probability, expected_actions, connection_count, h)?
        .simulate_expect(qty)

    h.long_test(10_000_000_000)


class iso _TestDoesntDropConnectionWhenExpectWhenNotSpiked is UnitTest
  fun name(): String =>
    "spike/DoesntDropConnectionWhenExpectWhenNotSpiked"

  fun ref apply(h: TestHelper) ? =>
    let spike_probability = F64(0)
    let expected_actions = recover val ["expect"] end
    let connection_count = U32(1)
    let qty = USize(18)
    _TestConnection(spike_probability, expected_actions, connection_count, h)?
        .simulate_expect(qty)

    h.long_test(10_000_000_000)

class iso _TestDoesntDropConnectionWhenThrottledWhenSpiked is UnitTest
  fun name(): String =>
    "spike/DoesntDropConnectionWhenThrottledWhenSpiked"

  fun ref apply(h: TestHelper) ? =>
    //!@ What is this test testing? Why doesn't Spike close it when throttled?

    let spike_probability = F64(1)
    let expected_actions = recover val ["throttled"] end
    let connection_count = U32(1)
    _TestConnection(spike_probability, expected_actions, connection_count, h)?
        .simulate_throttled()

    h.long_test(10_000_000_000)

class iso _TestDoesntDropConnectionWhenThrottledWhenNotSpiked is UnitTest
  fun name(): String =>
    "spike/DoesntDropConnectionWhenThrottledWhenNotSpiked"

  fun ref apply(h: TestHelper) ? =>
    let spike_probability = F64(0)
    let expected_actions = recover val ["throttled"] end
    let connection_count = U32(1)
    _TestConnection(spike_probability, expected_actions, connection_count, h)?
        .simulate_throttled()

    h.long_test(10_000_000_000)

class iso _TestDoesntDropConnectionWhenUnthrottledWhenSpiked is UnitTest
  fun name(): String =>
    "spike/DoesntDropConnectionWhenUnthrottledWhenSpiked"

  fun ref apply(h: TestHelper) ? =>
    let spike_probability = F64(1)
    let expected_actions = recover val ["unthrottled"] end
    let connection_count = U32(1)
    _TestConnection(spike_probability, expected_actions, connection_count, h)?
        .simulate_unthrottled()

    h.long_test(10_000_000_000)

class iso _TestDoesntDropConnectionWhenUnthrottledWhenNotSpiked is UnitTest
  fun name(): String =>
    "spike/DoesntDropConnectionWhenUnthrottledWhenNotSpiked"

  fun ref apply(h: TestHelper) ? =>
    let spike_probability = F64(0)
    let expected_actions = recover val ["unthrottled"] end
    let connection_count = U32(1)
    _TestConnection(spike_probability, expected_actions, connection_count, h)?
        .simulate_unthrottled()

    h.long_test(10_000_000_000)

class iso _TestDropsConnectionWhenSpikedWithMargin is UnitTest
  fun name(): String =>
    "spike/DropsConnectionWhenSpikedWithMargin"

  fun ref apply(h: TestHelper) ? =>
    let spike_probability = F64(1)
    let margin = USize(3)
    // if margin == 3, the 4th action should drop
    let expected_actions =
      recover val ["connected"; "connected"; "connected"; "closed"] end
    let connection_count = U32(1)
    let connection = _TestConnection(spike_probability, expected_actions,
      connection_count, h where margin = margin)?

    connection.simulate_connected()
    connection.simulate_connected()
    connection.simulate_connected()
    connection.simulate_connected()

    h.long_test(10_000_000_000)

////////////////
// STUBS/MOCKS
////////////////
primitive _TestConnection
  fun apply(spike_probability: F64, expected_actions: Array[String] val,
    connection_count: U32, h: TestHelper,
    expected_data: Array[U8] val = recover val [] end,
    margin: USize = 0): NullTCPActor ?
  =>
    for ea in expected_actions.values() do
      h.expect_action(ea)
    end

    let spike_config = SpikeConfig(where seed'=1, prob'=spike_probability,
      margin'=margin)?
    let notify = _TestGeneralTCPNotify[NullTCPActor ref](h, connection_count,
      expected_actions, expected_data)
    let should_close = expected_actions.contains("closed")
    NullTCPActor(h, consume notify, spike_config, should_close)

class _TestGeneralTCPNotify[T: TCPActor ref] is GeneralTCPNotify[T]
  let _h: TestHelper
  let _count: U32
  let _expected_actions: Array[String] val
  let _expected_data: Array[U8] val

  new iso create(h: TestHelper, connection_count: U32,
    expected_actions: Array[String] val, expected_data: Array[U8] val)
   =>
    _h = h
    _count = connection_count
    _expected_actions = expected_actions
    _expected_data = expected_data

  fun ref connecting(conn: T, count: U32) =>
    if not _expected_actions.contains(__loc.method_name()) then
      _h.fail()
    end
    _h.complete_action(__loc.method_name())
    _h.assert_eq[U32](count, _count)

  fun ref connected(conn: T) =>
    if not _expected_actions.contains(__loc.method_name()) then
      _h.fail()
    end
    _h.complete_action(__loc.method_name())

  fun ref connect_failed(conn: T) =>
    if not _expected_actions.contains(__loc.method_name()) then
      _h.fail()
    end
    _h.complete_action(__loc.method_name())

  fun ref closed(conn: T, locally_initiated_close: Bool) =>
    if not _expected_actions.contains(__loc.method_name()) then
      _h.fail()
    end
    _h.complete_action(__loc.method_name())

  fun ref sentv(conn: T,
    data: ByteSeqIter): ByteSeqIter
  =>
    if not _expected_actions.contains(__loc.method_name()) then
      _h.fail()
    end
    _h.complete_action(__loc.method_name())
    data

  fun ref received(conn: T, data: Array[U8] iso,
    times: USize): Bool
  =>
    if not _expected_actions.contains(__loc.method_name()) then
      _h.fail()
    end
    _h.complete_action(__loc.method_name())
    _h.assert_array_eq[U8](consume data, _expected_data)
    true

  fun ref expect(conn: T, qty: USize): USize =>
    if not _expected_actions.contains(__loc.method_name()) then
      _h.fail()
    end
    _h.complete_action(__loc.method_name())
    qty

  fun ref throttled(conn: T) =>
    if not _expected_actions.contains(__loc.method_name()) then
      _h.fail()
    end
    _h.complete_action(__loc.method_name())

  fun ref unthrottled(conn: T) =>
    if not _expected_actions.contains(__loc.method_name()) then
      _h.fail()
    end
    _h.complete_action(__loc.method_name())

actor NullTCPActor is TCPActor
  let _h: TestHelper
  let _notify: GeneralTCPNotify[NullTCPActor ref]
  let _should_close: Bool

  new create(h: TestHelper, notify: GeneralTCPNotify[NullTCPActor ref] iso,
    spike_config: SpikeConfig, should_close: Bool)
  =>
    _h = h
    _should_close = should_close
    _notify =
      // if spike_config.drop then
        DropConnection[NullTCPActor ref](spike_config, consume notify)
      // end


  //////////////////////
  // TESTING INTERFACE
  //
  // These behaviors are used to simulate ASIO and other events that
  // trigger notify calls internally.
  //////////////////////
  be simulate_connecting(connection_count: U32) =>
    _notify.connecting(this, connection_count)

  be simulate_connected() =>
    _notify.connected(this)

  be simulate_connect_failed() =>
    _notify.connect_failed(this)

  be simulate_closed(locally_initiated_close: Bool = false) =>
    _notify.closed(this, locally_initiated_close)

  be simulate_sentv(data: ByteSeqIter) =>
    _notify.sentv(this, data)

  be simulate_received(data: Array[U8] iso, times: USize) =>
    _notify.received(this, consume data, times)

  be simulate_expect(qty: USize) =>
    _notify.expect(this, qty)

  be simulate_throttled() =>
    _notify.throttled(this)

  be simulate_unthrottled() =>
    _notify.unthrottled(this)

  //////////////////////
  // TCPActor interface
  //////////////////////
  fun ref set_nodelay(state: Bool) =>
    None

  fun ref expect(qty: USize = 0) =>
    None

  be _event_notify(event: AsioEventID, flags: U32, arg: U32) =>
    None

  be write_again() =>
    None

  be read_again() =>
    None

  fun ref receive_ack(seq_id: SeqId) =>
    None

  fun ref receive_connect_ack(seq_id: SeqId) =>
    None

  fun ref resend_producer_registrations() =>
    None

  fun ref start_normal_sending() =>
    None

  fun ref receive_immediate_ack() =>
    None

  fun ref close() =>
    if _should_close then
      let locally_initiated_close = false
      _notify.closed(this, locally_initiated_close)
    else
      _h.fail("close() was called unexpectedly!")
    end
