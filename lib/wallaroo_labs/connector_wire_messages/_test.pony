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
    test(_TestBitFlags)
    test(_TestHelloMsg)
    test(_TestOkMsg)
    test(_TestErrorMsg)
    test(_TestNotifyMsg)
    test(_TestNotifyAckMsg)
    test(_TestMessageMsg)
    test(_TestAckMsg)
    test(_TestRestartMsg)

class iso _TestBitFlags is UnitTest
  fun name(): String => "connector_wire_messages/_TestBitFlags"

  fun apply(h: TestHelper) =>
    // Test Ephemeral: value 1
    h.assert_eq[U8](Ephemeral(), 1)
    h.assert_eq[U8](Ephemeral(2), 3)
    h.assert_eq[U8](Ephemeral.clear(3), 2)
    h.assert_true(Ephemeral.eq(1))
    h.assert_false(Ephemeral.eq(2))
    h.assert_true(Ephemeral == 1)
    h.assert_false(Ephemeral == 2)
    h.assert_true(Ephemeral.is_set(3))
    h.assert_false(Ephemeral.is_set(2))

    // test Boundary: Value 2
    h.assert_eq[U8](Boundary(), 2)
    h.assert_eq[U8](Boundary(2), 2)
    h.assert_eq[U8](Boundary.clear(3), 1)
    h.assert_true(Boundary.eq(2))
    h.assert_false(Boundary.eq(3))
    h.assert_true(Boundary == 2)
    h.assert_false(Boundary == 1)
    h.assert_true(Boundary.is_set(3))
    h.assert_false(Boundary.is_set(4))

    // test Eos: Value 4
    h.assert_eq[U8](Eos(), 4)
    h.assert_eq[U8](Eos(4), 4)
    h.assert_eq[U8](Eos.clear(5), 1)
    h.assert_true(Eos.eq(4))
    h.assert_false(Eos.eq(5))
    h.assert_true(Eos == 4)
    h.assert_false(Eos == 1)
    h.assert_true(Eos.is_set(5))
    h.assert_false(Eos.is_set(3))

   // test UnstableReference: Value 8
    h.assert_eq[U8](UnstableReference(), 8)
    h.assert_eq[U8](UnstableReference(8), 8)
    h.assert_eq[U8](UnstableReference.clear(9), 1)
    h.assert_true(UnstableReference.eq(8))
    h.assert_false(UnstableReference.eq(9))
    h.assert_true(UnstableReference == 8)
    h.assert_false(UnstableReference == 9)
    h.assert_true(UnstableReference.is_set(9))
    h.assert_false(UnstableReference.is_set(3))

   // test EventTime: Value 16
    h.assert_eq[U8](EventTime(), 16)
    h.assert_eq[U8](EventTime(16), 16)
    h.assert_eq[U8](EventTime.clear(17), 1)
    h.assert_true(EventTime.eq(16))
    h.assert_false(EventTime.eq(17))
    h.assert_true(EventTime == 16)
    h.assert_false(EventTime == 17)
    h.assert_true(EventTime.is_set(17))
    h.assert_false(EventTime.is_set(15))

   // test Key: Value 32
    h.assert_eq[U8](Key(), 32)
    h.assert_eq[U8](Key(32), 32)
    h.assert_eq[U8](Key.clear(33), 1)
    h.assert_true(Key.eq(32))
    h.assert_false(Key.eq(33))
    h.assert_true(Key == 32)
    h.assert_false(Key == 33)
    h.assert_true(Key.is_set(33))
    h.assert_false(Key.is_set(31))

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
    let cl: Array[Credit] val = [(1, "1", 0); (2, "2", 1); (3, "3", 2)]
    let sl: SourceList val = [
      ("s1", "1.1.1.1:1234")
      ("source2", "127.0.0.1:5000")
      ("s3", "8.8.8.8:80")]
    let a = OkMsg(ic, cl, sl)
    let encoded = Frame.encode(a)
    let m = Frame.decode(encoded)?
    let b = m as OkMsg
    h.assert_eq[U32](a.initial_credits, ic)
    h.assert_eq[U32](b.initial_credits, ic)
    for (i, cr) in a.credit_list.pairs() do
      h.assert_eq[StreamId](cr._1, cl(i)?._1)
      h.assert_eq[StreamName](cr._2, cl(i)?._2)
      h.assert_eq[PointOfRef](cr._3, cl(i)?._3)
    end
    for (i, cr) in b.credit_list.pairs() do
      h.assert_eq[StreamId](cr._1, cl(i)?._1)
      h.assert_eq[StreamName](cr._2, cl(i)?._2)
      h.assert_eq[PointOfRef](cr._3, cl(i)?._3)
    end
    for (i, p) in a.source_list.pairs() do
      h.assert_eq[SourceName](p._1, sl(i)?._1)
      h.assert_eq[SourceAddress](p._2, sl(i)?._2)
    end
    for (i, p) in b.source_list.pairs() do
      h.assert_eq[SourceName](p._1, sl(i)?._1)
      h.assert_eq[SourceAddress](p._2, sl(i)?._2)
    end

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
    """
    Allowed flag combinations
        1 2 4   8   16  32
        E B Eo  Un  Et  K
    E   x   x       x   x
    B     x x       x
    Eo      x   x   x   x
    Un          x   x   x
    Et              x   x
    K                   x
    """
    let sid: StreamId = 1
    let mid: MessageId = 10
    let kb = "key"
    let et: EventTimeType val = 123456789
    let mb = "this is a message"
    let all_flags: Array[U8] val =
      recover
        [
          // Ephemeral
          1
          1 or 4
          1 or 16
          1 or 32
          1 or 4 or 16
          1 or 4 or 32
          1 or 4 or 16 or 32
          // Boundary
          2
          2 or 4
          2 or 16
          2 or 4 or 16
          // EOS
          4
          4 or 8
          4 or 16
          4 or 32
          4 or 8 or 16
          4 or 8 or 32
          4 or 8 or 16 or 32
          // UnstableReference
          8
          8 or 16
          8 or 32
          8 or 16 or 32
          // EventTime
          16
          16 or 32
          // Key
          32
        ]
      end

    for fl in all_flags.values() do
      let a = MessageMsg(
        sid,
        fl,
        if Ephemeral.is_set(fl) then None else mid end,
        if EventTime.is_set(fl) then et else None end,
        if Key.is_set(fl) then kb else None end,
        if Boundary.is_set(fl) then None else mb end)?


      let encoded = Frame.encode(a)
      let m = Frame.decode(encoded)?
      let b = m as MessageMsg
      if not Ephemeral.is_set(fl) then
        match a.message_id
        | let mid': U64 => h.assert_eq[MessageId](mid', mid)
        end
        match b.message_id
        | let mid': U64 => h.assert_eq[MessageId](mid', mid)
        end
      else
        h.assert_true(a.message_id is None)
        h.assert_true(b.message_id is None)
      end
      if EventTime.is_set(fl) then
        match a.event_time
        | let et': I64 =>
          h.assert_eq[EventTimeType](et', et)
        end
        match b.event_time
        | let et': I64 =>
          h.assert_eq[EventTimeType](et', et)
        end
      else
        h.assert_true(a.event_time is None)
        h.assert_true(b.event_time is None)
      end
      if Key.is_set(fl) then
        match a.key
        | let kb': String =>
          h.assert_eq[String](kb', kb)
        end
        match b.key
        | let kb': String =>
          h.assert_eq[String](kb', kb)
        end
      else
        h.assert_true(a.key is None)
        h.assert_true(b.key is None)
      end
      if not Boundary.is_set(fl) then
        match a.message
        | let mb': String =>
          h.assert_eq[String](mb', mb)
        end
        match b.message
        | let mb': String =>
          h.assert_eq[String](mb', mb)
        end
      else
        h.assert_true(a.message is None)
        h.assert_true(b.message is None)
      end
    end

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
