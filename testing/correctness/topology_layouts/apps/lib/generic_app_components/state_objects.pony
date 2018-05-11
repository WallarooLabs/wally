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
use "serialise"
use "wallaroo_labs/mort"
use "wallaroo/core/common"
use "wallaroo/core/state"
use "wallaroo/core/topology"

class U64Counter is State
  var count: U64 = 0

  fun ref apply(n: U64): U64 =>
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
  fun apply(input: U64): Key =>
    (input.next_pow2()).string()

primitive PowersOfTwoPartitionFunction2
  fun apply(input: U64): Key =>
    (input.next_pow2()).string()

primitive Mod6PartitionFunction
  fun apply(input: U64): Key =>
    (input % 6).string()

primitive Mod3PartitionFunction
  fun apply(input: U64): Key =>
    (input % 3).string()

primitive Mod6CountMaxPartitionFunction
  fun apply(cm: CountMax): Key =>
    (cm.max.u64() % 6).string()

primitive CountMaxMod6PartitionFunction
  fun apply(input: CountMax): Key =>
    (input.max % 6).string()

primitive UpdateU64Counter is StateComputation[U64, U64, U64Counter]
  fun name(): String => "Update U64 Counter"

  fun apply(input: U64, sc_repo: StateChangeRepository[U64Counter],
    state: U64Counter): (U64, StateChange[U64Counter] ref)
  =>
    let state_change: U64CounterStateChange ref =
      try
        sc_repo.lookup_by_name("U64CounterStateChange")?
          as U64CounterStateChange
      else
        U64CounterStateChange(0)
      end

    let new_count = state.count + 1
    state_change.update(new_count)
    (input, state_change)

  fun state_change_builders():
    Array[StateChangeBuilder[U64Counter]] val
  =>
    recover val
      let scbs = Array[StateChangeBuilder[U64Counter]]
      scbs.push(recover val U64CounterStateChangeBuilder end)
      scbs
    end

primitive UpdateU64Counter2 is StateComputation[U64, U64, U64Counter]
  fun name(): String => "Update U64 Counter 2"

  fun apply(input: U64, sc_repo: StateChangeRepository[U64Counter],
    state: U64Counter): (U64, StateChange[U64Counter] ref)
  =>
    let state_change: U64CounterStateChange ref =
      try
        sc_repo.lookup_by_name("U64CounterStateChange")?
          as U64CounterStateChange
      else
        U64CounterStateChange(0)
      end

    let new_count = state.count + 1
    state_change.update(new_count)
    (input, state_change)

  fun state_change_builders():
    Array[StateChangeBuilder[U64Counter]] val
  =>
    recover val
      let scbs = Array[StateChangeBuilder[U64Counter]]
      scbs.push(recover val U64CounterStateChangeBuilder end)
      scbs
    end

class U64Sum is State
  var sum: U64 = 0
  var count: USize val = 0

  fun ref update(n: U64) =>
    sum = sum + n
    count = count + 1

primitive U64SumBuilder
  fun name(): String => "U64Sum"
  fun apply(): U64Sum => U64Sum

primitive UpdateU64Sum is StateComputation[U64, U64, U64Sum]
  fun name(): String => "Update U64Sum"

  fun apply(u: U64,
    sc_repo: StateChangeRepository[U64Sum],
    state: U64Sum): (U64, DirectStateChange)
  =>
    state.update(u)

    (state.sum, DirectStateChange)

  fun state_change_builders():
    Array[StateChangeBuilder[U64Sum]] val
  =>
    recover Array[StateChangeBuilder[U64Sum]] end

class val CountMax
  let count: USize
  let max: U64

  new val create(count': USize, max': U64) =>
    count = count'
    max = max'

class CountAndMax is State
  var count: USize = 0
  var max: U64 = 0

  fun ref apply(u: U64) =>
    count = count + 1
    max = max.max(u)

primitive CountAndMaxBuilder
  fun name(): String => "CountAndMax"
  fun apply(): CountAndMax => CountAndMax

primitive UpdateCountAndMax is StateComputation[U64, CountMax, CountAndMax]
  fun name(): String => "Update Count and Max"

  fun apply(u: U64,
    sc_repo: StateChangeRepository[CountAndMax],
    state: CountAndMax): (CountMax, DirectStateChange)
  =>
    state.apply(u)

    (CountMax(state.count, state.max), DirectStateChange)

  fun state_change_builders():
    Array[StateChangeBuilder[CountAndMax]] val
  =>
    recover Array[StateChangeBuilder[CountAndMax]] end

primitive UpdateCountAndMaxFromCountMax is StateComputation[CountMax, CountMax,
  CountAndMax]
  fun name(): String => "Update Count and Max from CountMax"

  fun apply(cm: CountMax,
    sc_repo: StateChangeRepository[CountAndMax],
    state: CountAndMax): (CountMax, DirectStateChange)
  =>
    state.apply(cm.max)

    (CountMax(state.count, state.max), DirectStateChange)

  fun state_change_builders():
    Array[StateChangeBuilder[CountAndMax]] val
  =>
    recover Array[StateChangeBuilder[CountAndMax]] end
