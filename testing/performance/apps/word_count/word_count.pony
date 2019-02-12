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
Word Count App
"""
use "assert"
use "buffered"
use "collections"
use "net"
use "serialise"
use "wallaroo_labs/bytes"
use "wallaroo"
use "wallaroo_labs/mort"
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
      let pipeline = recover val
        let lines = Wallaroo.source[String]("Word Count",
          TCPSourceConfig[String].from_options(StringFrameHandler,
                TCPSourceConfigCLIParser("Word Count", env.args)?, 1))

        lines
          .to[String](Split)
          .key_by(ExtractWord)
          .to[RunningTotal](AddCount)
          .to_sink(TCPSinkConfig[RunningTotal].from_options(
            RunningTotalEncoder, TCPSinkConfigCLIParser(env.args)?(0)?))
      end
      Wallaroo.build_application(env, "Word Count", pipeline)
    else
      @printf[I32]("Couldn't build topology\n".cstring())
    end

primitive Split is StatelessComputation[String, String]
  fun name(): String => "Split"

  fun apply(s: String): Array[String] val =>
    let punctuation = """ !"#$%&'()*+,-./:;<=>?@[\]^_`{|}~ """
    let words = recover trn Array[String] end
    for line in s.split("\n").values() do
      let cleaned =
        recover val s.clone().>lower().>lstrip(punctuation)
          .>rstrip(punctuation) end
      for word in cleaned.split(punctuation).values() do
        words.push(word)
      end
    end
    consume words

class val RunningTotal
  let word: String
  let count: U64

  new val create(w: String, c: U64) =>
    word = w
    count = c

class WordTotal is State
  var count: U64

  new create(c: U64) =>
    count = c

primitive AddCount is StateComputation[String, RunningTotal, WordTotal]
  fun name(): String => "Add Count"

  fun apply(word: String, state: WordTotal): RunningTotal =>
    state.count = state.count + 1
    RunningTotal(word, state.count)

  fun initial_state(): WordTotal =>
    WordTotal(0)

primitive StringFrameHandler is FramedSourceHandler[String]
  fun header_length(): USize =>
    4

  fun payload_length(data: Array[U8] iso): USize ? =>
    Bytes.to_u32(data(0)?, data(1)?, data(2)?, data(3)?).usize()

  fun decode(data: Array[U8] val): String =>
    String.from_array(data)

primitive ExtractWord
  fun apply(input: String): Key =>
    input

primitive RunningTotalEncoder
  fun apply(t: RunningTotal, wb: Writer = Writer): Array[ByteSeq] val =>
    ////////////////////////////////////////
    // Option A: Write out output as String
    let result =
      recover val
        String().>append(t.word).>append(", ").>append(t.count.string())
          .>append("\n")
      end
    @printf[I32]("!!%s".cstring(), result.cstring())
    wb.write(result)

    ///////////////////////////////////////////////
    // Option B: Write out output as encoded bytes
    // wb.u32_be(t.word.size().u32())
    // wb.write(t.word)
    // wb.u64_be(t.count)

    wb.done()
