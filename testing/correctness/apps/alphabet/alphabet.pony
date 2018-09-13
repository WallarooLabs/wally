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
use "options"
use "serialise"
use "wallaroo_labs/bytes"
use "wallaroo"
use "wallaroo/core/common"
use "wallaroo_labs/mort"
use "wallaroo/core/sink/tcp_sink"
use "wallaroo/core/source"
use "wallaroo/core/source/tcp_source"
use "wallaroo/core/state"
use "wallaroo/core/topology"

actor Main
  new create(env: Env) =>
    try
      // Add "--to-parallel" option
      var to_parallel: Bool = false
      let options = Options(env.args, false)

      options.add("to-parallel", "", None)

      for option in options do
        match option
        | ("to-parallel", None) =>
          to_parallel = true
        end
      end


      let parts: Array[String] val = recover
        let s = "abcdefghijklmnopqrstuvwxyz"
        let a = Array[String]
        for b in s.values() do
          for c in s.values() do
            a.push(String.from_array([b ; c]))
          end
        end
        a.push("!!")
        consume a
      end

      let letter_partition = Partitions[Votes val](
        LetterPartitionFunction, parts)

      let application = recover val
        let a = Application("Alphabet Popularity Contest")
        let p = a.new_pipeline[Votes val, LetterTotal val]("Alphabet Votes",
          TCPSourceConfig[Votes val].from_options(VotesDecoder,
            TCPSourceConfigCLIParser(env.args)?(0)?))
        // add `to_parallel` steps based on cmd line arg
        if to_parallel then
          p.to[Votes val](DoubleVoteBuilder)
          p.to_parallel[Votes val](HalfVoteBuilder)
        end
        p.to_state_partition[LetterTotal val,
          LetterState](AddVotes, LetterStateBuilder, "letter-state",
            letter_partition where multi_worker = true)
        p.to_sink(TCPSinkConfig[LetterTotal val].from_options(
          LetterTotalEncoder,
          TCPSinkConfigCLIParser(env.args)?(0)?))
        consume a
      end
      Startup(env, application, "alphabet-contest")
    else
      @printf[I32]("Couldn't build topology\n".cstring())
    end

primitive DoubleVote
  fun name(): String => "Double Vote"

  fun apply(v: Votes val): Votes val =>
    Votes(v.letter, v.count * 2)

primitive DoubleVoteBuilder
  fun apply(): Computation[Votes val, Votes val] val =>
    DoubleVote

primitive HalfVote
  fun name(): String => "Half Vote"

  fun apply(v: Votes val): Votes val =>
    Votes(v.letter, v.count / 2)

primitive HalfVoteBuilder
  fun apply(): Computation[Votes val, Votes val] val =>
    HalfVote

class val LetterStateBuilder
  fun apply(): LetterState => LetterState
  fun name(): String => "Letter State"

class LetterState is State
  var letter: String = " "
  var count: U64 = 0

primitive AddVotes is StateComputation[Votes val, LetterTotal val, LetterState]
  fun name(): String => "Add Votes"

  fun apply(votes: Votes val,
    sc_repo: StateChangeRepository[LetterState],
    state: LetterState): (LetterTotal val, DirectStateChange)
  =>
    if state.letter == " " then state.letter = votes.letter end
    state.count = state.count + votes.count

    (LetterTotal(state.letter, state.count), DirectStateChange)

  fun state_change_builders():
    Array[StateChangeBuilder[LetterState]] val
  =>
    recover Array[StateChangeBuilder[LetterState]] end

primitive VotesDecoder is FramedSourceHandler[Votes val]
  fun header_length(): USize =>
    4

  fun payload_length(data: Array[U8] iso): USize =>
    6

  fun decode(data: Array[U8] val): Votes val ? =>
    // Assumption: 1 byte for letter
    let letter = String.from_array(data.trim(0, 2))
    let count = Bytes.to_u32(data(2)?, data(3)?, data(4)?, data(5)?)
    Votes(letter, count.u64())

primitive LetterPartitionFunction
  fun apply(votes: Votes val): String =>
    votes.letter

class Votes
  let letter: String
  let count: U64

  new val create(l: String, c: U64) =>
    letter = l
    count = c

class LetterTotal
  let letter: String
  let count: U64

  new val create(l: String, c: U64) =>
    letter = l
    count = c

primitive LetterTotalEncoder
  fun apply(t: LetterTotal val, wb: Writer = Writer): Array[ByteSeq] val =>
    wb.u32_be(10)
    wb.write(t.letter) // Assumption: letter is 2 bytes
    wb.u64_be(t.count)
    wb.done()
