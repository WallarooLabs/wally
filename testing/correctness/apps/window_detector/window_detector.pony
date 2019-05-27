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


//stdlib
use "assert"
use "buffered"
use "collections"
use "json"
use "options"
use "serialise"
use "time"

// wallaroo/lib
use "wallaroo"
use "wallaroo/core/aggregations"
use "wallaroo/core/common"
use "wallaroo/core/sink/tcp_sink"
use "wallaroo/core/source"
use "wallaroo/core/source/connector_source"
use "wallaroo/core/source/gen_source"
use "wallaroo/core/source/tcp_source"
use "wallaroo/core/state"
use "wallaroo/core/topology"
use "wallaroo/core/windows"

// wallaroo/lib/wallaroo_labs
use "wallaroo_labs/bytes"
use "wallaroo_labs/mort"
use "wallaroo_labs/time"


primitive Tumbling
primitive Counting
primitive Sliding
type WindowType is (Tumbling | Counting | Sliding)

primitive Drop
  fun apply(): U16 => LateDataPolicy.drop()
primitive FirePerMessage
  fun apply(): U16 => LateDataPolicy.fire_per_message()
primitive PlaceInOldestWindow
  fun apply(): U16 => LateDataPolicy.place_in_oldest_window()
type WindowPolicy is (Drop | FirePerMessage | PlaceInOldestWindow)


actor Main
  new create(env: Env) =>

    try
      // Add options:
      let options = Options(env.args, false)

      let window_policy_options: Array[String] val = ["drop"
        "fire-per-message"
        "place-in-oldest-window"]
      options.add("window-policy", "", StringArgument)
      var window_policy: WindowPolicy = Drop
      options.add("window-type", "", StringArgument)
      var window_type: WindowType = Tumbling
      options.add("window-delay", "", I64Argument)
      var window_delay: USize = 0
      options.add("window-size", "", I64Argument)
      var window_size: USize = 50
      options.add("window-slide", "", I64Argument)
      var window_slide: USize = 0
      options.add("decoder", "", StringArgument)
      var decoder_type: String = "binary"
      let decoder_options: Array[String] val = ["binary"; "json"]

      for option in options do
        match option
        | ("window-policy", let arg: String) =>
          if arg == "fire-per-message" then
            window_policy = FirePerMessage
          elseif arg == "place-in-oldest-window" then
            window_policy = PlaceInOldestWindow
          elseif arg == "drop" then
            window_policy = Drop
          else
            env.err.print("Invalid window policy. Please use one of [" +
              ", ".join(window_policy_options.values()) + "]")
            Fail()
          end
        | ("window-type", let arg: String) =>
          match arg
          | "tumbling" => window_type = Tumbling
          | "counting" => window_type = Counting
          | "sliding" => window_type = Sliding
          else
            @printf[I32](("argument for window-type must be one of " +
              "[tumbling, counting, sliding]\n").cstring())
            error
          end
        | ("window-delay", let arg: I64) =>
          window_delay = arg.usize()
        | ("window-size", let arg: I64) =>
          window_size = arg.usize()
        | ("window_slide", let arg: I64) =>
          window_slide = arg.usize()
        | ("decoder", let arg: String) =>
          if arg == "binary" then decoder_type = "binary"
          elseif arg == "json" then decoder_type = "json"
          else env.err.print("Invalid decoder option. Please use one of [" +
            ", ".join(decoder_options.values()) + "]")
          end
        end
      end

      // Pre-construct the window step based on config option
      let window_step = match window_type
      | Counting =>
         Wallaroo.count_windows(window_size)
          .over[Message, WindowMessage, WindowState](Collect)
      | (let arg: (Sliding | Tumbling)) =>
        Wallaroo.range_windows(Milliseconds(window_size))
          .with_slide(if window_slide != 0 then Milliseconds(window_slide)
            else Milliseconds(window_size) end)
          .with_delay(Milliseconds(window_delay))
          .with_late_data_policy(window_policy())
          .over[Message, WindowMessage, WindowState](Collect)
      end

      let decoder = if decoder_type == "json" then
        JsonDecoder
      else
        Decoder
      end

      let pipeline = recover val
        Wallaroo.source[Message]("Detector",
          TCPSourceConfig[Message]
            .from_options(decoder,
              TCPSourceConfigCLIParser("Detector", env.args)?))
          .key_by(ExtractKey)
          .to[WindowMessage](window_step)
          .to[Message](SplitAccumulated)
          .to_sink(TCPSinkConfig[Message].from_options(Encoder,
              TCPSinkConfigCLIParser(env.args)?(0)?))
      end
      Wallaroo.build_application(env, "window_detector", pipeline)
    else
      env.out.print("Couldn't build topology!")
    end


// Message
class val Message
  let _key: String
  let _value: U64
  let _ts: U64

  new val create(k: String, v: U64, ts': (U64 | None) = None) =>
    _key = k
    _value = v
    _ts = match ts'
    | let t: U64 =>
      t
    else
      Time.nanos()
    end

  fun ts(): U64 =>
    _ts

  fun key(): String =>
    _key

  fun value(): U64 =>
    _value

  fun string(): String =>
    "{\"key\": \"" + _key
     + "\", \"value\": " + _value.string()
     + ", \"ts\": " + _ts.string()
     + "}"

// ExtractKey
primitive ExtractKey
  fun apply(m: Message): String => m.key()

// WindowState
class WindowState is State
  var key: String = ""
  let values: Array[U64]

  new create(key': String = "", values': (Array[U64] ref^ | None) = None) =>
    key = key'
    values = match values'
    | None =>
      Array[U64]
    | let v: Array[U64] ref^ =>
      consume v
    end

  fun ref update(msg: Message) =>
    if key == "" then
      key = msg.key()
    end
    ifdef debug then
      if key != msg.key() then
        @printf[I32](("Illegal state update: Wrong key.\nState key is %s but" +
          " message key is %s\n").cstring(), key.cstring(), msg.key().cstring())
        Fail()
      end
    end
    values.push(msg.value())

  fun combine(other: WindowState box): WindowState =>
    ifdef debug then
      if key != other.key then
        if ((values.size() > 0) and (key == "")) or
           ((other.values.size() > 0) and (other.key == "")) then
          @printf[I32](("Illegal state combine: Wrong key.\nThis.key is" +
            "%s but" +
            " other.key is %s\n").cstring(), key.cstring(), other.key.cstring())
          Fail()
        end
      end
    end
    let key' = if key == "" then
      other.key
    else
      key
    end
    let local = values.clone()
    local.append(other.values)
    WindowState(key', local.clone())

  fun val clone(): Array[U64] ref^ =>
    values.clone()

// WindowMessage
class val WindowMessage
  let _key: String
  let _values: Array[U64] val
  let _ts: U64

  new val create(k: String, v: Array[U64] val, ts': (U64 | None) = None) =>
    _key = k
    _values = v
    _ts = match ts'
    | let t: U64 =>
      t
    else
      Time.nanos()
    end

  fun ts(): U64 =>
    _ts

  fun key(): String =>
    _key

  fun values(): Array[U64] val =>
    _values

// Decoder
primitive Decoder is FramedSourceHandler[Message]
  fun header_length(): USize => 4

  fun payload_length(data: Array[U8] iso): USize ? =>
    Bytes.to_u32(data(0)?, data(1)?, data(2)?, data(3)?).usize()

  fun decode(data: Array[U8] val): Message ? =>
    let u: U64 = Bytes.to_u64(data(0)?, data(1)?, data(2)?, data(3)?,
      data(4)?, data(5)?, data(6)?, data(7)?)
    let k: String = String.from_array(recover data.slice(8) end)
    let m = Message(k, u)
    ifdef debug then
        (let sec', let ns') = Time.now()
        let us' = ns' / 1000
      try
        let ts' = PosixDate(sec', ns').format("%Y-%m-%d %H:%M:%S." + us'.string())?
        @printf[I32]("%s Source decoded: %s\n".cstring(), ts'.cstring(),
          m.string().cstring())
      end
    end
    consume m

// JsonDecoder
primitive JsonDecoder is FramedSourceHandler[Message]
  fun header_length(): USize => 4

  fun payload_length(data: Array[U8] iso): USize ? =>
    Bytes.to_u32(data(0)?, data(1)?, data(2)?, data(3)?).usize()

  fun decode(data: Array[U8] val): Message ? =>
    let s = String.from_array(data)
    let doc = JsonDoc
    doc.parse(s)?
    let json: JsonObject = doc.data as JsonObject
    let key: String = json.data("key")? as String
    let value: U64 = (json.data("value")? as I64).u64()
    let ts: U64 = (json.data("ts")? as I64).u64()
    let m = Message(key, value, ts)
    ifdef debug then
        (let sec', let ns') = Time.now()
        let us' = ns' / 1000
      try
        let ts' = PosixDate(sec', ns').format("%Y-%m-%d %H:%M:%S." + us'.string())?
        @printf[I32]("%s Source decoded: %s\n".cstring(), ts'.cstring(),
          m.string().cstring())
      end
    end
    consume m

  fun event_time_ns(m: Message): U64 => 
    ifdef debug then @printf[I32]("event_time_ts()\n".cstring()) end
    m.ts()

// Collect
primitive Collect is Aggregation[Message, (WindowMessage | None), WindowState]

  fun name(): String => "Collect"

  fun initial_accumulator(): WindowState =>
    WindowState

  fun update(msg: Message, state: WindowState) =>
    ifdef debug then
      @printf[I32]("Update on %s\n".cstring(), msg.string().cstring())
    end
    state.update(msg)

  fun combine(s1: WindowState box, s2: WindowState box): WindowState =>
    ifdef debug then
      @printf[I32]("combine\n".cstring())
    end
    s1.combine(s2)

  fun output(key: Key, window_end_ts: U64, s: WindowState):
    (WindowMessage | None)
  =>
    ifdef debug then @printf[I32]("Output\n".cstring()) end
    if s.values.size() > 0 then
      let vals: Array[U64] iso = recover Array[U64] end
      for v in s.values.values() do
        vals.push(v)
      end
      WindowMessage(key.string(), consume vals)
    else
      None
    end

// SplitAccumulated
primitive SplitAccumulated is StatelessComputation[WindowMessage, Message]
  fun name(): String => "SplitAccumulated"

  fun apply(wm: WindowMessage): Array[Message] val =>
    let messages = recover trn Array[Message] end
    let ts = wm.ts()
    let k = wm.key()
    for v in wm.values().values() do
      messages.push(Message(k, v, ts))
    end
    consume messages

// Encoder
primitive Encoder
  fun apply(m: Message, wb: Writer = Writer): Array[ByteSeq] val =>
    ifdef debug then
      @printf[I32]("output: %s\n".cstring(), m.string().cstring())
    end
    wb.writev(Bytes.length_encode(m.string()))
    wb.done()
