use "buffered"
use "serialise"
use "wallaroo/fail"
use "wallaroo/state"
use "wallaroo/topology"

class U64Counter is State
  var count: U64 = 0

  fun ref apply(n: U64 val): U64 val =>
    count = count + 1
    n

primitive U64CounterBuilder
  fun name(): String => "U64Counter"
  fun apply(): U64Counter => U64Counter

class U64CounterStateChange is StateChange[U64Counter]
  let _id: U64
  var _count: U64 = 0

  fun name(): String => "U64CounterStateChange"
  fun id(): U64 => _id

  new create(id': U64) =>
    _id = id'

  fun ref update(count': U64) =>
    _count = count'

  fun apply(state: U64Counter) =>
    state.count = _count

  fun write_log_entry(out_writer: Writer) => None

  fun ref read_log_entry(in_reader: Reader) => None

class U64CounterStateChangeBuilder is StateChangeBuilder[U64Counter]
  fun apply(id: U64): StateChange[U64Counter] =>
    U64CounterStateChange(id)

primitive PowersOfTwoPartitionFunction
  fun apply(input: U64): U64 =>
    input.next_pow2()

primitive PowersOfTwoPartitionFunction2
  fun apply(input: U64): U64 =>
    input.next_pow2()

primitive UpdateU64Counter is StateComputation[U64, U64, U64Counter]
  fun name(): String => "Update U64 Counter"

  fun apply(input: U64, sc_repo: StateChangeRepository[U64Counter],
    state: U64Counter): (U64 val, StateChange[U64Counter] ref)
  =>
    let state_change: U64CounterStateChange ref =
      try
        sc_repo.lookup_by_name("U64CounterStateChange")
          as U64CounterStateChange
      else
        U64CounterStateChange(0)
      end

    let new_count = state.count + 1
    state_change.update(new_count)
    (input, state_change)

  fun state_change_builders():
    Array[StateChangeBuilder[U64Counter] val] val
  =>
    recover val
      let scbs = Array[StateChangeBuilder[U64Counter] val]
      scbs.push(recover val U64CounterStateChangeBuilder end)
    end

primitive UpdateU64Counter2 is StateComputation[U64, U64, U64Counter]
  fun name(): String => "Update U64 Counter 2"

  fun apply(input: U64, sc_repo: StateChangeRepository[U64Counter],
    state: U64Counter): (U64 val, StateChange[U64Counter] ref)
  =>
    let state_change: U64CounterStateChange ref =
      try
        sc_repo.lookup_by_name("U64CounterStateChange")
          as U64CounterStateChange
      else
        U64CounterStateChange(0)
      end

    let new_count = state.count + 1
    state_change.update(new_count)
    (input, state_change)

  fun state_change_builders():
    Array[StateChangeBuilder[U64Counter] val] val
  =>
    recover val
      let scbs = Array[StateChangeBuilder[U64Counter] val]
      scbs.push(recover val U64CounterStateChangeBuilder end)
    end
