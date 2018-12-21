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
use col = "collections"

// Message bit flags

type Flags is U8

trait val BitFlags
  fun apply(value: Flags): Flags      // set the mask's bit
  fun clear(other: Flags): Flags      // unset the mask's bit
  fun eq(y: Flags): Bool              // is this mask the only one set?
  fun is_set(other: Flags): Bool      // is the mask's bit set?


primitive Ephemeral is BitFlags
  fun apply(value: Flags = 0): Flags => value.op_or(1)
  fun clear(other: Flags): Flags => other.op_and(Flags(1).op_not())
  fun eq(other: Flags): Bool => other == 1
  fun is_set(other: Flags): Bool => other.op_and(1) == 1

primitive Boundary is BitFlags
  fun apply(value: Flags = 0): Flags => value.op_or(2)
  fun clear(other: Flags): Flags => other.op_and(Flags(2).op_not())
  fun eq(other: Flags): Bool => other == 2
  fun is_set(other: Flags): Bool => other.op_and(2) == 2

primitive Eos is BitFlags
  fun apply(value: Flags = 0): Flags => value.op_or(4)
  fun clear(other: Flags): Flags => other.op_and(Flags(4).op_not())
  fun eq(other: Flags): Bool => other == 4
  fun is_set(other: Flags): Bool => other.op_and(4) == 4

primitive UnstableReference is BitFlags
  fun apply(value: Flags = 0): Flags => value.op_or(8)
  fun clear(other: Flags): Flags => other.op_and(Flags(8).op_not())
  fun eq(other: Flags): Bool => other == 8
  fun is_set(other: Flags): Bool => other.op_and(8) == 8

primitive EventTime is BitFlags
  fun apply(value: Flags = 0): Flags => value.op_or(16)
  fun clear(other: Flags): Flags => other.op_and(Flags(16).op_not())
  fun eq(other: Flags): Bool => other == 16
  fun is_set(other: Flags): Bool => other.op_and(16) == 16

primitive Key is BitFlags
  fun apply(value: Flags = 0): Flags => value.op_or(32)
  fun clear(other: Flags): Flags => other.op_and(Flags(32).op_not())
  fun eq(other: Flags): Bool => other == 32
  fun is_set(other: Flags): Bool => other.op_and(32) == 32

primitive FlagsAllowed
  fun apply(f: Flags): Bool =>
  """
  Allowed flag combinations
      E B Eo  Un  Et  K
  E   x   x       x   x
  B     x x       x
  Eo      x   x   x   x
  Un          x   x   x
  Et              x   x
  K                   x
  """
  if Ephemeral.is_set(f) then
    if Boundary.is_set(f) or UnstableReference.is_set(f) then
      false
    else
      true
    end
  elseif Boundary.is_set(f) then
    if UnstableReference.is_set(f) or Key.is_set(f) then
      false
    else
      true
    end
  else
    true
  end

// Frame types

primitive FrameTag
  fun decode(rb: Reader): Message ? =>
    let frame_tag = rb.u8()?
    match frame_tag
    | 0 => HelloMsg.decode(rb)?
    | 1 => OkMsg.decode(consume rb)?
    | 2 => ErrorMsg.decode(consume rb)?
    | 3 => NotifyMsg.decode(consume rb)?
    | 4 => NotifyAckMsg.decode(consume rb)?
    | 5 => MessageMsg.decode(consume rb)?
    | 6 => AckMsg.decode(consume rb)?
    | 7 => RestartMsg.decode(consume rb)
    else
      error
    end

  fun apply(msg: Message): U8 =>
    match msg
    | let m: HelloMsg => 0
    | let m: OkMsg => 1
    | let m: ErrorMsg => 2
    | let m: NotifyMsg => 3
    | let m: NotifyAckMsg => 4
    | let m: MessageMsg => 5
    | let m: AckMsg => 6
    | let m: RestartMsg => 7
    end

// Framing
type StreamId is U64
type StreamName is String
type PointOfRef is U64
type Credit is (StreamId, StreamName, PointOfRef)
type EventTimeType is I64
type MessageId is U64
type MessageBytes is ByteSeq
type KeyBytes is ByteSeq


type Message is ( HelloMsg |
                  OkMsg |
                  ErrorMsg |
                  NotifyMsg |
                  NotifyAckMsg |
                  MessageMsg |
                  AckMsg |
                  RestartMsg )

trait MessageTrait
  fun encode(wb: Writer = Writer): Writer ?
  new decode(rb: Reader) ?

primitive Frame
  fun encode(msg: Message, wb: Writer = Writer): Array[U8] val =>
    let encoded = msg.encode()
    wb.u8(FrameTag(msg))
    wb.writev(encoded.done())
    let bs: Array[ByteSeq val] val = wb.done()
    recover
      let a = Array[U8]
      for b in bs.values() do
        a.append(b)
      end
      a
    end

  fun decode(data: Array[U8] val): Message ? =>
    // read length
    let rb = Reader
    rb.append(data)
    FrameTag.decode(consume rb)?


class HelloMsg is MessageTrait
  let version: String
  let cookie: String
  let program_name: String
  let instance_name: String

  new create(version': String, cookie': String, program_name': String,
    instance_name': String)
  =>
    version = version'
    cookie = cookie'
    program_name = program_name'
    instance_name = instance_name'

  new decode(rb: Reader) ? =>
    var length = rb.u16_be()?.usize()
    version = String.from_array(rb.block(length)?)
    length = rb.u16_be()?.usize()
    cookie = String.from_array(rb.block(length)?)
    length = rb.u16_be()?.usize()
    program_name = String.from_array(rb.block(length)?)
    length = rb.u16_be()?.usize()
    instance_name = String.from_array(rb.block(length)?)

  fun encode(wb: Writer = Writer): Writer =>
    wb.u16_be(version.size().u16())
    wb.write(version)
    wb.u16_be(cookie.size().u16())
    wb.write(cookie)
    wb.u16_be(program_name.size().u16())
    wb.write(program_name)
    wb.u16_be(instance_name.size().u16())
    wb.write(instance_name)
    wb

class OkMsg is MessageTrait
  let initial_credits: U32
  let credit_list: Array[Credit] val

  new create(initial_credits': U32, credit_list': Array[Credit] val) =>
    initial_credits = initial_credits'
    credit_list = credit_list'

  new decode(rb: Reader) ? =>
    initial_credits = rb.u32_be()?
    let cl = recover iso Array[Credit] end
    let cl_size = rb.u32_be()?.usize()
    for x in col.Range(0, cl_size) do
      let sid = rb.u64_be()?
      let snl = rb.u16_be()?.usize()
      let sn = String.from_array(rb.block(snl)?)
      let por = rb.u64_be()?
      cl.push((sid, sn, por))
    end
    credit_list = consume cl

  fun encode(wb: Writer = Writer): Writer =>
    wb.u32_be(initial_credits)
    wb.u32_be(credit_list.size().u32())
    for v in credit_list.values() do
      wb.u64_be(v._1)
      wb.u16_be(v._2.size().u16())
      wb.write(v._2)
      wb.u64_be(v._3)
    end
    wb

class ErrorMsg is MessageTrait
  let message: String

  new create(message': String) =>
    message = message'

  new decode(rb: Reader)? =>
    let length = rb.u16_be()?.usize()
    message = String.from_array(rb.block(length)?)

  fun encode(wb: Writer = Writer): Writer =>
    wb.u16_be(message.size().u16())
    wb.write(message)
    wb

class NotifyMsg is MessageTrait
  let stream_id: StreamId
  let stream_name: StreamName
  let point_of_ref: PointOfRef

  new create(stream_id': StreamId, stream_name': StreamName,
    point_of_ref': PointOfRef)
  =>
    stream_id = stream_id'
    stream_name = stream_name'
    point_of_ref = point_of_ref'

  new decode(rb: Reader) ? =>
    stream_id = rb.u64_be()?
    let length = rb.u16_be()?.usize()
    stream_name = String.from_array(rb.block(length)?)
    point_of_ref = rb.u64_be()?

  fun encode(wb: Writer = Writer): Writer =>
    wb.u64_be(stream_id)
    wb.u16_be(stream_name.size().u16())
    wb.write(stream_name)
    wb.u64_be(point_of_ref)
    wb

class NotifyAckMsg is MessageTrait
  let success: Bool
  let stream_id: StreamId
  let point_of_ref: PointOfRef

  new create(success': Bool, stream_id': StreamId, point_of_ref': PointOfRef) =>
    success = success'
    stream_id = stream_id'
    point_of_ref = point_of_ref'

  new decode(rb: Reader) ? =>
    success = if rb.u8()? == 1 then true else false end
    stream_id = rb.u64_be()?
    point_of_ref = rb.u64_be()?

  fun encode(wb: Writer = Writer): Writer =>
    if success then wb.u8(1) else wb.u8(0) end
    wb.u64_be(stream_id)
    wb.u64_be(point_of_ref)
    wb

class MessageMsg is MessageTrait
  let stream_id: StreamId
  let flags: Flags
  let message_id: (MessageId | None)
  let event_time: (EventTimeType | None)
  let key: (KeyBytes | None)
  let message: (MessageBytes | None)

  new create(
    stream_id': StreamId,
    flags': Flags,
    message_id': (MessageId | None) = None,
    event_time': (EventTimeType | None) = None,
    key': (KeyBytes | None) = None,
    message': (MessageBytes | None) = None) ?
  =>
    stream_id = stream_id'
    flags = flags'
    message_id = message_id'
    event_time = event_time'
    key = key'
    message = message'

    if not FlagsAllowed(flags) then
      @printf[I32]("Illegal flags combination: %s\n".cstring(),
        flags'.string().cstring())
      error
    end

  new decode(rb: Reader) ? =>
    stream_id = rb.u64_be()?
    flags = rb.u8()?
    if not FlagsAllowed(flags) then
      @printf[I32]("Illegal flags combination: %s\n".cstring(),
        flags.string().cstring())
      error
    end

    message_id =
      if not Ephemeral.is_set(flags) then
        rb.u64_be()?
      else
        None
      end

    event_time =
      if EventTime.is_set(flags) then
        rb.i64_be()?
      else
        None
      end

    key =
      if (Key.is_set(flags)) and (not Boundary.is_set(flags))  then
        let length = rb.u16_be()?.usize()
        rb.block(length)?
      else
        None
      end

    message =
      if not Boundary.is_set(flags) then
        rb.block(rb.size())?
      else
        None
      end

  fun encode(wb: Writer = Writer): Writer =>
    wb.u64_be(stream_id)
    wb.u8(flags)

    if not Ephemeral.is_set(flags) then
      match message_id
      | let mid: MessageId => wb.u64_be(mid)
      end
    end

    if EventTime.is_set(flags) then
      match event_time
      | let et: EventTimeType => wb.i64_be(et)
      end
    end

    if Key.is_set(flags) then
      match key
      | let kb: KeyBytes =>
        wb.u16_be(kb.size().u16())
        wb.write(kb)
      end
    end

    if not Boundary.is_set(flags) then
      match message
      | let mb: MessageBytes => wb.write(mb)
      end
    end
    wb

class AckMsg is MessageTrait
  let credits: U32
  let credit_list: Array[(StreamId, PointOfRef)] val

  new create(credits': U32, credit_list': Array[(StreamId, PointOfRef)] val) =>
    credits = credits'
    credit_list = credit_list'

  new decode(rb: Reader) ? =>
    credits = rb.u32_be()?
    let cl_size = rb.u32_be()?.usize()
    let cl = recover iso Array[(StreamId, PointOfRef)] end
    for x in col.Range(0, cl_size) do
      cl.push((rb.u64_be()?, rb.u64_be()?))
    end
    credit_list = consume cl


  fun encode(wb: Writer = Writer): Writer =>
    wb.u32_be(credits)
    wb.u32_be(credit_list.size().u32())
    for cr in credit_list.values() do
      wb.u64_be(cr._1)
      wb.u64_be(cr._2)
    end
    wb

class RestartMsg is MessageTrait
  new create() =>
    """
    """

  fun encode(wb: Writer = Writer): Writer =>
    wb

  new  decode(rb: Reader) =>
    """
    """
