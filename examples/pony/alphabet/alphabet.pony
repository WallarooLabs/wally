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
use "collections"
use "serialise"
use "wallaroo_labs/bytes"
use "wallaroo"
use "wallaroo/core/common"
use "wallaroo_labs/logging"
use "wallaroo_labs/mort"
use "wallaroo_labs/time"
use "wallaroo/core/sink/tcp_sink"
use "wallaroo/core/source"
use "wallaroo/core/source/gen_source"
use "wallaroo/core/source/tcp_source"
use "wallaroo/core/state"
use "wallaroo/core/topology"

actor Main
  new create(env: Env) =>
    Log.set_defaults()
    try
      let pipeline = recover val
          let votes = Wallaroo.source[Votes]("Alphabet Votes",
                TCPSourceConfig[Votes].from_options(VotesDecoder,
                  TCPSourceConfigCLIParser("Alphabet Votes", env.args)?))

          votes
            .key_by(ExtractFirstLetter)
            .to[LetterTotal](AddVotes)
            .to_sink(TCPSinkConfig[LetterTotal].from_options(
              LetterTotalEncoder, TCPSinkConfigCLIParser(env.args)?(0)?))
        end

      Wallaroo.build_application(env, "Alphabet Contest", pipeline)
    else
      @printf[I32]("Couldn't build topology\n".cstring())
    end

class val LetterStateBuilder
  fun apply(): LetterState => LetterState

class LetterState is State
  var letter: String = " "
  var count: U64 = 0

primitive AddVotes is StateComputation[Votes, LetterTotal val, LetterState]
  fun name(): String => "Add Votes"

  fun apply(votes: Votes, state: LetterState): LetterTotal val =>
    state.count = votes.count + state.count
    LetterTotal(votes.letter, state.count)

  fun initial_state(): LetterState =>
    LetterState

primitive VotesDecoder is FramedSourceHandler[Votes]
  fun header_length(): USize =>
    4

  fun payload_length(data: Array[U8] iso): USize =>
    5

  fun decode(data: Array[U8] val): Votes ? =>
    // Assumption: 1 byte for letter
    let letter = String.from_array(data.trim(0, 1))
    let count = Bytes.to_u32(data(1)?, data(2)?, data(3)?, data(4)?)
    Votes(letter, count.u64())

primitive ExtractFirstLetter
  fun apply(votes: Votes): Key =>
    votes.letter

class val Votes
  let letter: String
  let count: U64

  new val create(l: String, c: U64) =>
    letter = l
    count = c

  fun string(): String =>
    letter + ": " + count.string()

class val LetterTotal
  let letter: String
  let count: U64

  new val create(l: String, c: U64) =>
    letter = l
    count = c

primitive LetterTotalEncoder
  fun apply(t: LetterTotal val, wb: Writer = Writer): Array[ByteSeq] val =>
    wb.u32_be(9)
    wb.write(t.letter) // Assumption: letter is 1 byte
    wb.u64_be(t.count)
    wb.done()
