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

use "buffered"
use "ponytest"

actor Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)

  new make() => None

  fun tag tests(test: PonyTest) =>
    test(_TestHelloMsg)
    test(_TestOkMsg)
    test(_TestErrorMsg)
    test(_TestNotifyMsg)
    test(_TestNotifyAckMsg)
    test(_TestMessageMsg)
    test(_TestMessageMsg2)
    test(_TestEosMessageMsg)
    test(_TestAckMsg)
    test(_TestRestartMsg)

class iso _TestHelloMsg is UnitTest
  fun name(): String => "connector_wire_messages/_TestHelloMsg"

  fun apply(h: TestHelper) ? =>
    let a = HelloMsg("version", "cookie", "program", "instance")
    let encoded = Frame.encode(a)
    let m = Frame.decode(encoded)?
    let b = m as HelloMsg
    h.assert_eq[String](a.version, b.version)
    h.assert_eq[String](a.cookie, b.cookie)
    h.assert_eq[String](a.program_name, b.program_name)
    h.assert_eq[String](a.instance_name, b.instance_name)

class iso _TestOkMsg is UnitTest
  fun name(): String => "connector_wire_messages/_TestOkMsg"

  fun apply(h: TestHelper) ? =>
    let ic: U32 = 100
    let a = OkMsg(ic)
    let encoded = Frame.encode(a)
    let m = Frame.decode(encoded)?
    let b = m as OkMsg
    h.assert_eq[U32](a.initial_credits, ic)
    h.assert_eq[U32](b.initial_credits, ic)

class iso _TestErrorMsg is UnitTest
  fun name(): String => "connector_wire_messages/_TestErrorMsg"

  fun apply(h: TestHelper) ? =>
    let msg: String = "some error"
    let a = ErrorMsg(msg)
    let encoded = Frame.encode(a)
    let m = Frame.decode(encoded)?
    let b = m as ErrorMsg
    h.assert_eq[String](a.message, msg)
    h.assert_eq[String](b.message, msg)

class iso _TestNotifyMsg is UnitTest
  fun name(): String => "connector_wire_messages/_TestNotifyMsg"

  fun apply(h: TestHelper) ? =>
    let cr: Credit = (1, "2", 3)
    let a = NotifyMsg(cr._1, cr._2, cr._3)
    let encoded = Frame.encode(a)
    let m = Frame.decode(encoded)?
    let b = m as NotifyMsg
    h.assert_eq[StreamId](a.stream_id, cr._1)
    h.assert_eq[StreamName](a.stream_name, cr._2)
    h.assert_eq[PointOfRef](a.point_of_ref, cr._3)
    h.assert_eq[StreamId](b.stream_id, cr._1)
    h.assert_eq[StreamName](b.stream_name, cr._2)
    h.assert_eq[PointOfRef](b.point_of_ref, cr._3)

class iso _TestNotifyAckMsg is UnitTest
  fun name(): String => "connector_wire_messages/_TestNotifyAckMsg"

  fun apply(h: TestHelper) ? =>
    let success = true
    let sid: StreamId = 1
    let por: PointOfRef = 12
    let a = NotifyAckMsg(success, sid, por)
    let encoded = Frame.encode(a)
    let m = Frame.decode(encoded)?
    let b = m as NotifyAckMsg
    h.assert_eq[Bool](a.success, success)
    h.assert_eq[StreamId](a.stream_id, sid)
    h.assert_eq[PointOfRef](a.point_of_ref, por)
    h.assert_eq[Bool](b.success, success)
    h.assert_eq[StreamId](b.stream_id, sid)
    h.assert_eq[PointOfRef](b.point_of_ref, por)

class iso _TestMessageMsg is UnitTest
  fun name(): String => "connector_wire_messages/_TestMessageMsg"

  fun apply(h: TestHelper) ? =>
    let sid: StreamId = 1
    let mid: MessageId = 10
    let kb = "key"
    let et: EventTimeType val = 123456789
    let mb = "this is a message"

    let a = MessageMsg(sid, mid, et, kb, mb)
    let encoded = Frame.encode(a)
    let m = Frame.decode(encoded)?
    let b = m as MessageMsg
    h.assert_eq[StreamId](a.stream_id, sid)
    h.assert_eq[StreamId](b.stream_id, sid)
    h.assert_eq[MessageId](a.message_id, mid)
    h.assert_eq[MessageId](b.message_id, mid)
    h.assert_eq[EventTimeType](a.event_time, et)
    h.assert_eq[EventTimeType](b.event_time, et)
    // TODO: Figure out how to test equality on these
    // h.assert_eq[KeyBytes](a.key, kb)
    // h.assert_eq[KeyBytes](b.key, kb)
    // h.assert_eq[MessageBytes](a.message as MessageBytes, mb)
    // h.assert_eq[MessageBytes](b.message as MessageBytes, mb)

class iso _TestMessageMsg2 is UnitTest
  fun name(): String => "connector_wire_messages/_TestMessageMsg2"

  fun apply(h: TestHelper) ? =>
    let sid_list: Array[StreamId] = [0; 1; 42; 9111222333444]
    let mid_list: Array[MessageId] = [0; 2; 52; 8111222333444]
    let evt_list: Array[EventTimeType] = [0; 3; 62; 7111222333]

    for sid in sid_list.values() do
      for mid in mid_list.values() do
        for et in evt_list.values() do
          for kb in [None; "some key"].values() do
            for mb in [None; "medium == message"].values() do
              let a = MessageMsg(sid, mid, et, kb, mb)
              let encoded = Frame.encode(a)
              let m = Frame.decode(encoded)?
              let b = m as MessageMsg
              h.assert_eq[StreamId](a.stream_id, sid)
              h.assert_eq[StreamId](b.stream_id, sid)
              h.assert_eq[MessageId](a.message_id, mid)
              h.assert_eq[MessageId](b.message_id, mid)
              h.assert_eq[EventTimeType](a.event_time, et)
              h.assert_eq[EventTimeType](b.event_time, et)
            end
          end
        end
      end
    end

class iso _TestEosMessageMsg is UnitTest
  fun name(): String => "connector_wire_messages/_TestEosMessageMsg"

  fun apply(h: TestHelper) ? =>
    let sid: StreamId = 0x0000000077007700
    let a = EosMessageMsg(sid)
    let encoded = Frame.encode(a)
    let m = Frame.decode(encoded)?
    let b = m as EosMessageMsg
    h.assert_eq[U64](a.stream_id, sid)
    h.assert_eq[U64](b.stream_id, sid)

class iso _TestAckMsg is UnitTest
  fun name(): String => "connector_wire_messages/_TestAckMsg"

  fun apply(h: TestHelper) ? =>
    let credits: U32 = 100
    let cl: Array[(StreamId, PointOfRef)] val = [(1, 1) ; (2, 2) ; (3, 3)]
    let a = AckMsg(credits, cl)
    let encoded = Frame.encode(a)
    let m = Frame.decode(encoded)?
    let b = m as AckMsg
    h.assert_eq[U32](a.credits, credits)
    for (i, p) in a.credit_list.pairs() do
      h.assert_eq[StreamId](p._1, cl(i)?._1)
      h.assert_eq[PointOfRef](p._2, cl(i)?._2)
    end
    h.assert_eq[U32](b.credits, credits)
    for (i, p) in b.credit_list.pairs() do
      h.assert_eq[StreamId](p._1, cl(i)?._1)
      h.assert_eq[PointOfRef](p._2, cl(i)?._2)
    end

class iso _TestRestartMsg is UnitTest
  fun name(): String => "connector_wire_messages/_TestRestartMsg"

  fun apply(h: TestHelper) ? =>
    let addr: String = "127.0.0.1:5555"
    let a = RestartMsg(addr)
    let encoded = Frame.encode(a)
    let m = Frame.decode(encoded)?
    let b = m as RestartMsg
    h.assert_eq[String](a.address, addr)
    h.assert_eq[String](b.address, addr)
