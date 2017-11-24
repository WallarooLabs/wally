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
APP:
./weightest_test -i 127.0.0.1:7000 -o 127.0.0.1:5555 -m 127.0.0.1:5001 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -n node-name --ponythreads=2 --ponynoblock -t

2 WORKER:
./weightest_test -i 127.0.0.1:7000 -o 127.0.0.1:5555 -m 127.0.0.1:5001 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -n node-name --ponythreads=2 --ponynoblock -t -w 2

./weightest_test -i 127.0.0.1:7000 -o 127.0.0.1:5555 -m 127.0.0.1:5001 -c 127.0.0.1:6000 -n worker2 --ponythreads=2 --ponynoblock


SENDER:
giles/sender/sender -h 127.0.0.1:7000 -m 50000000 -s 300 -i 5_000_000 -f apps/weightest_test/weighted.txt -r --ponythreads=1 -w

"""
use "buffered"
use "serialise"
use "wallaroo_labs/bytes"
use "wallaroo_labs/hub"
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
      let symbol_data_partition = Partition[String, String](
        StringPartitionFunction, PartitionFileReader("partition.txt",        env.root as AmbientAuth))

      let application = recover val
        Application("Weighted Test App")
          .new_pipeline[String, Result val]("Weighted Test",
            TCPSourceConfig[String].from_options(WeightedTestFrameHandler,
              TCPSourceConfigCLIParser(env.args)?(0)?))
            .to_state_partition[String, String, Result val, NormalState](UpdateState, NormalStateBuilder, "normal-state",
              symbol_data_partition where multi_worker = true)
            .to_sink(TCPSinkConfig[Result val].from_options(ResultEncoder,
              TCPSinkConfigCLIParser(env.args)?(0)?))
      end
      Startup(env, application, None)//, 1)
    else
      @printf[I32]("Couldn't build topology\n".cstring())
    end

class val NormalStateBuilder
  fun apply(): NormalState => NormalState
  fun name(): String => "Normal State"

class NormalState is State
  var count: U64 = 0
  var last_string: String = ""

class NormalStateChange is StateChange[NormalState]
  let _id: U64
  let _name: String
  var _count: U64 = 0
  var _last_string: String = ""

  fun name(): String => _name
  fun id(): U64 => _id

  new create(id': U64, name': String) =>
    _id = id'
    _name = name'

  fun ref update(count: U64, last_string: String) =>
    _count = count
    _last_string = last_string

  fun apply(state: NormalState ref) =>
    // @printf[I32]("State change!!\n".cstring())
    state.count = _count
    state.last_string = _last_string

  fun write_log_entry(out_writer: Writer) =>
    out_writer.u64_be(_count)
    out_writer.u32_be(_last_string.size().u32())
    out_writer.write(_last_string)

  fun ref read_log_entry(in_reader: Reader) ? =>
    _count = in_reader.u64_be()?
    let last_string_size = in_reader.u32_be()?.usize()
    _last_string = String.from_array(in_reader.block(last_string_size)?)

class NormalStateChangeBuilder is StateChangeBuilder[NormalState]
  fun apply(id: U64): StateChange[NormalState] =>
    NormalStateChange(id, "NormalStateChange")

primitive UpdateState is StateComputation[String, Result val, NormalState]
  fun name(): String => "Update Normal State"

  fun apply(msg: String,
    sc_repo: StateChangeRepository[NormalState],
    state: NormalState): (Result val, StateChange[NormalState] ref)
  =>
    // @printf[I32]("!!Update Normal State\n".cstring())
    let state_change: NormalStateChange ref =
      try
        sc_repo.lookup_by_name("NormalStateChange")? as NormalStateChange
      else
        NormalStateChange(0, "NormalStateChange")
      end

    let new_count = state.count + 1
    state_change.update(new_count, msg)

    (Result(new_count, msg), state_change)

  fun state_change_builders():
    Array[StateChangeBuilder[NormalState]] val
  =>
    recover val
      let scbs = Array[StateChangeBuilder[NormalState]]
      scbs.push(recover val NormalStateChangeBuilder end)
      scbs
    end



primitive WeightedTestFrameHandler is FramedSourceHandler[String]
  fun header_length(): USize =>
    4

  fun payload_length(data: Array[U8] iso): USize ? =>
    Bytes.to_u32(data(0)?, data(1)?, data(2)?, data(3)?).usize()

  fun decode(data: Array[U8] val): String ? =>
    let str = String.from_array(data)
    if str != "" then
      str
    else
      error
    end


primitive StringPartitionFunction
  fun apply(input: String): String => input

class Result
  let count: U64
  let defaulted_string: String
  let letter_count: U64

  new val create(c: U64, d: String = "", l: U64 = 0) =>
    count = c
    defaulted_string = d
    letter_count = l

  fun serial_size(): U32 => (16 + defaulted_string.size()).u32()

primitive ResultEncoder
  fun apply(r: Result val, wb: Writer = Writer): Array[ByteSeq] val =>
    @printf[I32](("R: [" + r.count.string() + " | " + r.defaulted_string + " | " + r.letter_count.string() + " |\n").cstring())
    wb.u32_be(r.serial_size())

    wb.u64_be(r.count)
    wb.write(r.defaulted_string.array())
    wb.u64_be(r.letter_count)
    let payload = wb.done()
    HubProtocol.payload("default-test", "reports:default-test",
      consume payload, wb)
    wb.done()

// class Symbols
//   let symbols: Array[WeightedKey[String]] val

//   new create() =>
//     symbols = recover [
// ("a", 110),
// ("b", 40),
// ("c", 5),
// ("d", 735),
// ("e", 45),
// ("f", 260),
// ("g", 410),
// ("h", 915),
// ("i", 480)
// ] end
