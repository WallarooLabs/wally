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

use "buffered"
use "options"
use "wallaroo"
use "wallaroo/core/common"
use "wallaroo/core/sink/tcp_sink"
use "wallaroo/core/source"
use "wallaroo/core/source/gen_source"
use "wallaroo/core/state"
use "wallaroo/core/topology"
use "wallaroo_labs/bytes"
use "wallaroo_labs/logging"
use "wallaroo_labs/mort"


actor Main
  new create(env: Env) =>
    Log.set_defaults()
    try
      var seq_offset: USize = 0

      let options = Options(env.args, false)
      options.add("cluster-initializer", "", None)
      for option in options do
        match option
        | ("cluster-initializer", None) =>
          seq_offset = 1
        end
      end

      let pipeline = recover val
        let seq_values = Wallaroo.source[SeqValue]("Local Sequence Detector",
          GenSourceConfig[SeqValue](SeqValueGeneratorBuilder(
            seq_offset)))

        seq_values
          .local_key_by(ExtractKey)
          .to[SeqValue](CheckSequence)
          .to_sink(TCPSinkConfig[SeqValue].from_options(
            SeqValueEncoder, TCPSinkConfigCLIParser(env.args)?(0)?))
      end
      Wallaroo.build_application(env, "Local Sequence Detector", pipeline)
    else
      @printf[I32]("Couldn't build topology\n".cstring())
    end

class val SeqValue
  let key: Key
  let value: USize

  new val create(k: Key, v: USize) =>
    key = k
    value = v

  fun string(): String =>
    "[k: " + key + ", v: " + value.string() + "]"

primitive ExtractKey
  fun apply(sv: SeqValue): Key =>
    sv.key

class SeqState is State
  var mod: USize = -1
  var last: USize = 0

class val CheckSequence is StateComputation[SeqValue, SeqValue, SeqState]
  fun name(): String => __loc.type_name()

  fun apply(sv: SeqValue, state: SeqState): SeqValue =>
    ifdef debug then
      @printf[I32](("Got %s\n").cstring(), sv.string().cstring())
    end
    if state.mod == -1 then
      state.mod = sv.value % 2
    end
    state.last = sv.value
    if (sv.value % 2) != state.mod then
      Fail()
    end
    sv

  fun initial_state(): SeqState =>
    SeqState

primitive SeqValueEncoder
  fun apply(sv: SeqValue, wb: Writer = Writer): Array[ByteSeq] val =>
    ifdef debug then
      @printf[I32]("output: %s\n".cstring(), sv.string().cstring())
    end
    wb.writev(Bytes.length_encode(sv.string()))
    wb.done()

class val SeqValueGeneratorBuilder
  let _offset: USize

  new val create(offset: USize) =>
    _offset = offset

  fun apply(): SeqValueGenerator =>
    SeqValueGenerator(_offset)

class SeqValueGenerator
  let _keys: Array[String] = ["a"; "b"; "c"; "d"]
  let _last_values: Array[USize]
  var _key_index: USize = 0

  new create(offset: USize) =>
    _last_values = [offset; offset; offset; offset]

  fun ref initial_value(): SeqValue =>
    _next()

  fun ref apply(sv: SeqValue): SeqValue =>
    _next()

  fun ref _next(): SeqValue =>
    try
      let sv = SeqValue(_keys(_key_index)?, _last_values(_key_index)?)
      _advance_index()
      sv
    else
      Fail()
      SeqValue("fake", 0)
    end

  fun ref _advance_index() =>
    try
      _last_values(_key_index)? = _last_values(_key_index)? + 2
      _key_index = (_key_index + 1) % _keys.size()
    else
      Fail()
    end

