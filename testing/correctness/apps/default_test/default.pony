"""
APP:
./default_test -i 127.0.0.1:7000 -o 127.0.0.1:5555 -m 127.0.0.1:5001 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -n node-name --ponythreads=2 --ponynoblock -t

2 WORKER:
./default_test -i 127.0.0.1:7000 -o 127.0.0.1:5555 -m 127.0.0.1:5001 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -n node-name --ponythreads=2 --ponynoblock -t -w 2

./default_test -i 127.0.0.1:7000 -o 127.0.0.1:5555 -m 127.0.0.1:5001 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -n worker2 --ponythreads=2 --ponynoblock -t -w 2


SENDER:
giles/sender/sender -h 127.0.0.1:7000 -m 50000000 -s 300 -i 5_000_000 -f apps/default_test/default.txt -r --ponythreads=1 -w

"""
use "buffered"
use "serialise"
use "sendence/bytes"
use "sendence/hub"
use "wallaroo/"
use "wallaroo/fail"
use "wallaroo/state"
use "wallaroo/source"
use "wallaroo/tcp_sink"
use "wallaroo/tcp_source"
use "wallaroo/topology"

actor Main
  new create(env: Env) =>
    try
      let symbol_data_partition = Partition[String, String](
        StringPartitionFunction, Symbols.symbols)

      let application = recover val
        Application("Complex Numbers App")
          .new_pipeline[String, Result val]("Default Test",
            TCPSourceConfig[String].from_options(DefaultTestFrameHandler,
              TCPSourceConfigCLIParser(env.args)(0)))
            .to_state_partition[String, String, Result val, NormalState](UpdateState, NormalStateBuilder, "normal-state",
              symbol_data_partition where multi_worker = true,
              default_state_name = "default-state")
            .to_sink(TCPSinkConfig[Result val].from_options(ResultEncoder,
               TCPSinkConfigCLIParser(env.args)(0)))
          .partition_default_target[String, Result val, DefaultState](
            "Default Test", "default-state", UpdateDefaultState,
            DefaultStateBuilder)

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
    _count = in_reader.u64_be()
    let last_string_size = in_reader.u32_be().usize()
    _last_string = String.from_array(in_reader.block(last_string_size))

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
        sc_repo.lookup_by_name("NormalStateChange") as NormalStateChange
      else
        NormalStateChange(0, "NormalStateChange")
      end

    let new_count = state.count + 1
    state_change.update(new_count, msg)

   let res = Result(new_count, msg)
   // @printf[I32](("N>R: [" + res.count.string() + " | " + res.defaulted_string + " | " + res.letter_count.string() + " |\n").cstring())

    (res, state_change)

  fun state_change_builders():
    Array[StateChangeBuilder[NormalState] val] val
  =>
    recover val
      let scbs = Array[StateChangeBuilder[NormalState] val]
      scbs.push(recover val NormalStateChangeBuilder end)
    end

class val DefaultStateBuilder
  fun apply(): DefaultState => DefaultState
  fun name(): String => "Default State"

class DefaultState is State
  var count: U64 = 0
  var letter_count: U64 = 0
  var last_string: String = ""

class DefaultStateChange is StateChange[DefaultState]
  let _id: U64
  let _name: String
  var _count: U64 = 0
  var _letter_count: U64 = 0
  var _last_string: String = ""

  fun name(): String => _name
  fun id(): U64 => _id

  new create(id': U64, name': String) =>
    _id = id'
    _name = name'

  fun ref update(count: U64, last_string: String, letter_count: U64) =>
    _count = count
    _letter_count = letter_count
    _last_string = last_string

  fun apply(state: DefaultState ref) =>
    // @printf[I32]("State change!!\n".cstring())
    state.count = _count
    state.letter_count = _letter_count
    state.last_string = _last_string

  fun write_log_entry(out_writer: Writer) =>
    out_writer.u64_be(_count)
    out_writer.u32_be(_last_string.size().u32())
    out_writer.write(_last_string)
    out_writer.u64_be(_letter_count)

  fun ref read_log_entry(in_reader: Reader) ? =>
    _count = in_reader.u64_be()
    let last_string_size = in_reader.u32_be().usize()
    _last_string = String.from_array(in_reader.block(last_string_size))
    _letter_count = in_reader.u64_be()

class DefaultStateChangeBuilder is StateChangeBuilder[DefaultState]
  fun apply(id: U64): StateChange[DefaultState] =>
    DefaultStateChange(id, "DefaultStateChange")

primitive UpdateDefaultState is StateComputation[String, Result val,
  DefaultState]
  fun name(): String => "Update Default State"

  fun apply(msg: String,
    sc_repo: StateChangeRepository[DefaultState],
    state: DefaultState): (Result val, StateChange[DefaultState] ref)
  =>
    // @printf[I32]("!!Update Default State\n".cstring())
    let state_change: DefaultStateChange ref =
      try
        sc_repo.lookup_by_name("DefaultStateChange") as DefaultStateChange
      else
        DefaultStateChange(0, "DefaultStateChange")
      end

    let new_count = state.count + 1
    let last_string = msg
    let new_letter_count = state.letter_count + msg.size().u64()
    state_change.update(new_count, last_string, new_letter_count)

    let res = Result(new_count, last_string, new_letter_count)
    // @printf[I32](("D>R: [" + res.count.string() + " | " + res.defaulted_string + " | " + res.letter_count.string() + " |\n").cstring())

    (res, state_change)

  fun state_change_builders():
    Array[StateChangeBuilder[DefaultState] val] val
  =>
    recover val
      let scbs = Array[StateChangeBuilder[DefaultState] val]
      scbs.push(recover val DefaultStateChangeBuilder end)
    end


primitive DefaultTestFrameHandler is FramedSourceHandler[String]
  fun header_length(): USize =>
    4

  fun payload_length(data: Array[U8] iso): USize ? =>
    Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()

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

class Symbols
  let symbols: Array[String] val

  new create() =>
    symbols = recover ["A","B","C", "the", "statement", "Frederick"] end
