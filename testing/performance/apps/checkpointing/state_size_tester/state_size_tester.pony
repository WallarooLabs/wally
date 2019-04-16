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

"""
State Size Tester App

Setting up a run (in order):
1) reports sink (if not using Monitoring Hub):
nc -l 127.0.0.1 5555 >> /dev/null

2) metrics sink (if not using Monitoring Hub):
nc -l 127.0.0.1 5001 >> /dev/null

TODO: Add run instructions
"""

use "buffered"
use "options"
use "time"
use "wallaroo_labs/bytes"
use "wallaroo"
use "wallaroo_labs/mort"
use "wallaroo_labs/time"
use "wallaroo/core/common"
use "wallaroo/core/metrics"
use "wallaroo/core/sink/tcp_sink"
use "wallaroo/core/source"
use "wallaroo/core/source/tcp_source"
use "wallaroo/core/state"
use "wallaroo/core/topology"

actor Main
  new create(env: Env) =>
    try

      // Add options:
      // "--state-size": Int
      var state_size: USize = 10
      var output: Bool = false

      let options = Options(env.args, false)

      options.add("state-size", "", I64Argument)
      options.add("output", "", None)

      for option in options do
        match option
        | ("state-size", let arg: I64) =>
          state_size = arg.usize()
        | ("output", None) =>
          output = true
        end

      end

      let pipeline = recover val
        Wallaroo.source[KeyedMessage val](
            "keyval",
            TCPSourceConfig[KeyedMessage val].from_options(
              PartitionedU32FramedHandler,
              TCPSourceConfigCLIParser("keyval", env.args)?))
          .key_by(KeyExtractor)
          .to[KeyedMessage val](KeyedPassThrough(state_size, output))
          .to_sink(TCPSinkConfig[KeyedMessage val].from_options(
            KeyedMessageEncoder, TCPSinkConfigCLIParser(env.args)?(0)?))
      end
      Wallaroo.build_application(env, "State Size Tester", pipeline)
    else
      @printf[I32]("Couldn't build topology\n".cstring())
    end

class FixedState is State
  let state: Array[U8] val

  new create(size: USize) =>
    state = recover val Array[U8].init(0, size) end

class val KeyedPassThrough is StateComputation[KeyedMessage val,
  KeyedMessage val, FixedState]

  let _state_size: USize
  let _output: Bool

  new val create(size: USize, output: Bool) =>
    _state_size = size
    _output = output

  fun name(): String => "Keyed Pass Through"

  fun apply(msg: KeyedMessage val, state: FixedState):
    (KeyedMessage val | None)
  =>
    if _output then msg else None end

  fun initial_state(): FixedState =>
    FixedState(_state_size)

primitive PartitionedU32FramedHandler is FramedSourceHandler[KeyedMessage val]
  fun header_length(): USize => 4

  fun payload_length(data: Array[U8] iso): USize ? =>
    Bytes.to_u32(data(0)?, data(1)?, data(2)?, data(3)?).usize()

  fun decode(data: Array[U8] val): KeyedMessage val ? =>
    try
      let key: U32 = Bytes.to_u32(data(0)?, data(1)?, data(2)?, data(3)?)
      let value: U32 = Bytes.to_u32(data(4)?, data(5)?, data(6)?, data(7)?)
      let decode_nanos: U64 = Time.nanos()
      let msg = KeyedMessage(key, value, decode_nanos)
      consume msg
    else
      error
    end

primitive KeyExtractor
  fun apply(input: KeyedMessage val): Key =>
    input.key.string()

primitive KeyedMessageEncoder
  fun apply(msg: KeyedMessage val, wb: Writer = Writer): Array[ByteSeq] val =>
    let encode_nanos: U64 = Time.nanos()
    let w = Writer
    w.write(msg.key.string())
    w.write(",")
    w.write(msg.value.string())
    w.write(",")
    w.write(msg.decode_nanos.string())
    w.write(",")
    w.write(encode_nanos.string())
    wb.u32_be(w.size().u32())
    wb.writev(w.done())
    wb.done()

class KeyedMessage
  let key: U32
  let value: U32
  let decode_nanos: U64

  new val create(key': U32, value': U32, decode_nanos': U64) =>
    key = key'
    value = value'
    decode_nanos = decode_nanos'
