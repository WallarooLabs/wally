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
use "time"
use "wallaroo"
use "wallaroo/core/aggregations"
use "wallaroo/core/common"
use "wallaroo/core/sink/tcp_sink"
use "wallaroo/core/source"
use "wallaroo/core/source/gen_source"
use "wallaroo/core/source/tcp_source"
use "wallaroo/core/state"
use "wallaroo/core/topology"
use "wallaroo/core/windows"
use "wallaroo_labs/mort"
use "wallaroo_labs/time"

type NanosecondsSinceEpoch is U64


actor Main
  new create(env: Env) =>
    try
      let pipeline = recover val
        let events = Wallaroo.source[Event]("Multi_Aggregations",
          TCPSourceConfig[Event]
              .from_options(EventDecoder,
                            TCPSourceConfigCLIParser(env.args)?(0)?))
        events
          .key_by(GetEventKey)
          .to[Event](Wallaroo.range_windows(Milliseconds(50))
                      .aligned()
                      .over[Event, Event, EventTotal](
                        SumEvents))
          .to[Event](Wallaroo.range_windows(Seconds(1))
                       .aligned()
                       .over[Event, Event, EventTotal](
                         SumEvents2))
          .to_sink(TCPSinkConfig[Event].from_options(
            EventEncoder, TCPSinkConfigCLIParser(env.args)?(0)?))
      end
      Wallaroo.build_application(env, "EventAggregations", pipeline)
    else
      @printf[I32]("Couldn't build topology\n".cstring())
    end

class val Event
  // A generic event, bearing an original event time, a key,
  // and a piece of data.
  let event_time: NanosecondsSinceEpoch
  let event_data: U32
  let event_key: Key

  new val create(at: NanosecondsSinceEpoch, data: U32, key: Key) =>
    event_time = at
    event_data = data
    event_key = key

class EventTotal is State
  var sum_of_event_data: U32

  new create(sum: U32) =>
    sum_of_event_data = sum

primitive SumEvents is Aggregation[Event, Event, EventTotal]
  fun initial_accumulator(): EventTotal =>
    EventTotal(0)

  fun update(e: Event, et: EventTotal) =>
    et.sum_of_event_data = et.sum_of_event_data + e.event_data

  fun combine(et1: EventTotal box, et2: EventTotal box): EventTotal =>
    EventTotal(et1.sum_of_event_data + et2.sum_of_event_data)

  fun output(k: Key, window_end_ts: U64, et: EventTotal): (None| Event) =>
    if et.sum_of_event_data > 0 then
      @printf[I32]("********* outputting %s %s %s\n".cstring(),
        window_end_ts.string().cstring(),
        et.sum_of_event_data.string().cstring(),
        k.cstring())
      Event(window_end_ts,et.sum_of_event_data, k)
    end

  fun name(): String => "SumEvents"


primitive SumEvents2 is Aggregation[Event, Event, EventTotal]
  fun initial_accumulator(): EventTotal =>
    EventTotal(0)

  fun update(e: Event, et: EventTotal) =>
    @printf[I32]("updated2 %s %s\n".cstring(), e.event_time.string().cstring(), e.event_data.string().cstring())
    et.sum_of_event_data = et.sum_of_event_data + e.event_data

  fun combine(et1: EventTotal box, et2: EventTotal box): EventTotal =>
    EventTotal(et1.sum_of_event_data + et2.sum_of_event_data)

  fun output(k: Key, window_end_ts: U64, et: EventTotal): (None| Event) =>
    if et.sum_of_event_data > 0 then
      @printf[I32]("********* outputting2 %s %s %s\n".cstring(),
        window_end_ts.string().cstring(),
        et.sum_of_event_data.string().cstring(),
        k.cstring())
      Event(window_end_ts,et.sum_of_event_data, k)
    end

  fun name(): String => "SumEvents2"


primitive GetEventKey
  fun apply(e: Event): Key =>
    e.event_key

primitive EventEncoder
  fun apply(e: Event, wb: Writer): Array[ByteSeq] val =>
    let scaled_ts = (e.event_time/1_000_000).u64()
    let output = ("t=" + scaled_ts.string() +
                  ",data=" + e.event_data.string() +
                  ",key=" + e.event_key + "\n")
    wb.u32_be(output.size().u32())
    wb.write(output)
    wb.done()

primitive EventDecoder is FramedSourceHandler[Event]
  fun header_length(): USize => 4

  fun payload_length(data: Array[U8] iso): USize ? =>
    USize.from[U32](data.read_u32(0)?.bswap())

  fun decode(data: Array[U8] val): Event ? =>
    (let t,_) = String.from_array(data.trim(0,4)).read_int[U64]()?
    (let d,_) = String.from_array(data.trim(4,8)).read_int[U32]()?
    let k = String.from_array(data.trim(8,12))
    @printf[I32]("********* decoded %s %s %s\n".cstring(),
       t.string().cstring(), d.string().cstring(), k.string().cstring())
    // Scale milisecond-encoded time to nanoseconds
    Event(t * 1_000_000, d, k)

  fun event_time_ns(e: Event): U64 =>
    e.event_time
