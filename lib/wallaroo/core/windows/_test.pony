/*

Copyright 2018 The Wallaroo Authors.

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

use "ponytest"
use "promises"
use "wallaroo/core/aggregations"
use "wallaroo/core/common"
use "wallaroo/core/state"
use "wallaroo/core/topology"
use "wallaroo_labs/time"

actor Main is TestList
  new create(env: Env) => PonyTest(env, this)

  new make() => None

  fun tag tests(test: PonyTest) =>
    test(_TestTumblingWindows)

class iso _TestTumblingWindows is UnitTest
  fun name(): String => "bytes/_TestTumblingWindows"

  fun apply(h: TestHelper) ? =>
    let range: U64 = Seconds(10)
    let delay: U64 = Seconds(10)
    let tw = TumblingWindows[USize, USize, _Total]("key", _Sum, range, delay
      where current_ts = Seconds(100))

    var res: Array[USize] val = recover Array[USize] end

    // First window's data
    res = tw(2, Seconds(96), Seconds(101))
    h.assert_eq[USize](res.size(), 0)
    res = tw(3, Seconds(97), Seconds(102))
    h.assert_eq[USize](res.size(), 0)
    res = tw(4, Seconds(98), Seconds(103))
    h.assert_eq[USize](res.size(), 0)
    res = tw(5, Seconds(99), Seconds(104))
    h.assert_eq[USize](res.size(), 0)

    // Second window's data
    res = tw(1, Seconds(105), Seconds(106))
    h.assert_eq[USize](res.size(), 0)
    res = tw(2, Seconds(106), Seconds(107))
    h.assert_eq[USize](res.size(), 0)
    res = tw(3, Seconds(107), Seconds(108))
    h.assert_eq[USize](res.size(), 0)
    res = tw(4, Seconds(108), Seconds(109))
    h.assert_eq[USize](res.size(), 0)

    // Third window's data. This first message should trigger
    // first window.
    res = tw(10, Seconds(110), Seconds(111))
    h.assert_eq[USize](res.size(), 1)
    h.assert_eq[USize](res(0)?, 14)
    tw(20, Seconds(111), Seconds(112))
    tw(30, Seconds(112), Seconds(113))
    tw(40, Seconds(113), Seconds(114))

    // Use this message to trigger windows 2 and 3
    res = tw(1, Seconds(200), Seconds(201))
    h.assert_eq[USize](res.size(), 2)
    h.assert_eq[USize](res(0)?, 10)
    h.assert_eq[USize](res(1)?, 100)

    true

class _Total is State
  var v: USize = 0

class _Sum is Aggregation[USize, USize, _Total]
  fun initial_accumulator(): _Total => _Total
  fun update(input: USize, acc: _Total) =>
    acc.v = acc.v + input
  fun combine(acc1: _Total, acc2: _Total): _Total =>
    let new_t = _Total
    new_t.v = acc1.v + acc2.v
    new_t
  fun output(key: Key, acc: _Total): (USize | None) =>
    acc.v
  fun name(): String => "_Sum"
