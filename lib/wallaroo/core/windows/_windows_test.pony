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


class iso _TestTumblingWindows is UnitTest
  fun name(): String => "bytes/_TestTumblingWindows"

  fun apply(h: TestHelper) ? =>
    let range: U64 = Seconds(10)
    // Tumbling windows have the same slide as range
    let slide = range
    let delay: U64 = Seconds(10)
    let tw = RangeWindows[USize, USize, _Total]("key", _Sum, range, slide,
      delay)

    var res: ((USize | Array[USize] val | None), U64) =
      (recover Array[USize] end, 0)

    // First window's data
    res = tw(2, Seconds(96), Seconds(101))
    h.assert_eq[USize](_array(res._1)?.size(), 0)
    res = tw(3, Seconds(97), Seconds(102))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 0)
    res = tw(4, Seconds(98), Seconds(103))
    h.assert_eq[USize](_array(res._1)?.size(), 0)
    res = tw(5, Seconds(99), Seconds(104))
    h.assert_eq[USize](_array(res._1)?.size(), 0)

    // Second window's data
    res = tw(1, Seconds(105), Seconds(106))
    h.assert_eq[USize](_array(res._1)?.size(), 0)
    res = tw(2, Seconds(106), Seconds(107))
    h.assert_eq[USize](_array(res._1)?.size(), 0)
    res = tw(3, Seconds(107), Seconds(108))
    h.assert_eq[USize](_array(res._1)?.size(), 0)
    res = tw(4, Seconds(108), Seconds(109))
    h.assert_eq[USize](_array(res._1)?.size(), 0)

    // Third window's data. This first message should trigger
    // first window.
    res = tw(10, Seconds(110), Seconds(111))
    h.assert_eq[USize](_array(res._1)?.size(), 0)
    res = tw(20, Seconds(111), Seconds(112))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 14)
    tw(30, Seconds(112), Seconds(113))
    tw(40, Seconds(113), Seconds(114))

    // Use this message to trigger windows 2 and 3
    res = tw(1, Seconds(200), Seconds(201))
    h.assert_eq[USize](_array(res._1)?.size(), 2)
    h.assert_eq[USize](_array(res._1)?(0)?, 20)
    h.assert_eq[USize](_array(res._1)?(1)?, 90)

    true

  fun _array(res: (USize | Array[USize] val | None)): Array[USize] val ? =>
    match res
    | let a: Array[USize] val => a
    else error end

class iso _TestSlidingWindows is UnitTest
  fun name(): String => "bytes/_TestSlidingWindows"

  fun apply(h: TestHelper) ? =>
    let range: U64 = Seconds(10)
    let slide: U64 = Seconds(2)
    let delay: U64 = Seconds(10)
    let sw = RangeWindows[USize, USize, _Total]("key", _Sum, range, slide,
      delay)

    var res: ((USize | Array[USize] val | None), U64) =
      (recover Array[USize] end, 0)

    // First 2 windows values
    res = sw(2, Seconds(92), Seconds(100))
    h.assert_eq[USize](_array(res._1)?.size(), 0)

    res = sw(3, Seconds(93), Seconds(102))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 0)

    res = sw(4, Seconds(94), Seconds(103))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 0)

    res = sw(5, Seconds(95), Seconds(104))
    h.assert_eq[USize](_array(res._1)?.size(), 0)

    // Second 2 windows with values
    res = sw(1, Seconds(102), Seconds(106))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 5)

    res = sw(2, Seconds(103), Seconds(107))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 14)

    res = sw(3, Seconds(104), Seconds(108))
    h.assert_eq[USize](_array(res._1)?.size(), 0)

    res = sw(4, Seconds(105), Seconds(109))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 14)

    // Third 2 windows with values.
    res = sw(10, Seconds(108), Seconds(112))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 14)

    res = sw(20, Seconds(109), Seconds(113))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 14)

    res = sw(30, Seconds(110), Seconds(114))
    h.assert_eq[USize](_array(res._1)?.size(), 0)

    res = sw(40, Seconds(111), Seconds(115))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 12)

    // Fourth set of windows
    // Use this message to trigger 10 windows.
    res = sw(2, Seconds(192), Seconds(200))
    h.assert_eq[USize](_array(res._1)?.size(), 10)
    h.assert_eq[USize](_array(res._1)?(0)?, 10)
    h.assert_eq[USize](_array(res._1)?(1)?, 10)
    h.assert_eq[USize](_array(res._1)?(2)?, 40)
    h.assert_eq[USize](_array(res._1)?(3)?, 110)
    h.assert_eq[USize](_array(res._1)?(4)?, 107)
    h.assert_eq[USize](_array(res._1)?(5)?, 100)
    h.assert_eq[USize](_array(res._1)?(6)?, 100)
    h.assert_eq[USize](_array(res._1)?(7)?, 70)
    h.assert_eq[USize](_array(res._1)?(8)?, 0)
    h.assert_eq[USize](_array(res._1)?(9)?, 0)

    res = sw(3, Seconds(193), Seconds(202))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 0)

    res = sw(4, Seconds(194), Seconds(203))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 0)

    res = sw(5, Seconds(195), Seconds(204))
    h.assert_eq[USize](_array(res._1)?.size(), 0)

    // Fifth 2 windows with values
    res = sw(1, Seconds(202), Seconds(206))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 5)

    res = sw(2, Seconds(203), Seconds(207))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 14)

    res = sw(3, Seconds(204), Seconds(208))
    h.assert_eq[USize](_array(res._1)?.size(), 0)

    res = sw(4, Seconds(205), Seconds(209))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 14)

    // Sixth 2 windows with values.
    res = sw(10, Seconds(211), Seconds(212))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 14)

    res = sw(20, Seconds(212), Seconds(213))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 14)

    res = sw(30, Seconds(213), Seconds(214))
    h.assert_eq[USize](_array(res._1)?.size(), 0)

    res = sw(40, Seconds(214), Seconds(215))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 12)

    true

  fun _array(res: (USize | Array[USize] val | None)): Array[USize] val ? =>
    match res
    | let a: Array[USize] val => a
    else error end

class iso _TestSlidingWindowsOutOfOrder is UnitTest
  fun name(): String => "bytes/_TestSlidingWindowsOutOfOrder"

  fun apply(h: TestHelper) ? =>
    let range: U64 = Seconds(10)
    let slide: U64 = Seconds(2)
    let delay: U64 = Seconds(10)
    let sw = RangeWindows[USize, USize, _Total]("key", _Sum, range, slide,
      delay)

    var res: ((USize | Array[USize] val | None), U64) =
      (recover Array[USize] end, 0)

    // First 2 windows values
    res = sw(5, Seconds(95), Seconds(100))
    h.assert_eq[USize](_array(res._1)?.size(), 0)

    res = sw(4, Seconds(94), Seconds(102))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 0)

    res = sw(3, Seconds(93), Seconds(103))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 0)

    res = sw(2, Seconds(92), Seconds(104))
    h.assert_eq[USize](_array(res._1)?.size(), 0)

    // Second 2 windows with values
    res = sw(4, Seconds(105), Seconds(106))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 5)

    res = sw(3, Seconds(104), Seconds(107))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 14)

    res = sw(2, Seconds(103), Seconds(108))
    h.assert_eq[USize](_array(res._1)?.size(), 0)

    res = sw(1, Seconds(102), Seconds(109))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 14)

    // Third 2 windows with values.
    res = sw(40, Seconds(111), Seconds(112))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 14)

    res = sw(30, Seconds(110), Seconds(113))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 14)

    res = sw(20, Seconds(109), Seconds(114))
    h.assert_eq[USize](_array(res._1)?.size(), 0)

    res = sw(10, Seconds(108), Seconds(115))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 12)

    // Fourth set of windows
    // Use this message to trigger 10 windows.
    res = sw(2, Seconds(192), Seconds(200))
    h.assert_eq[USize](_array(res._1)?.size(), 10)
    h.assert_eq[USize](_array(res._1)?(0)?, 10)
    h.assert_eq[USize](_array(res._1)?(1)?, 10)
    h.assert_eq[USize](_array(res._1)?(2)?, 40)
    h.assert_eq[USize](_array(res._1)?(3)?, 110)
    h.assert_eq[USize](_array(res._1)?(4)?, 107)
    h.assert_eq[USize](_array(res._1)?(5)?, 100)
    h.assert_eq[USize](_array(res._1)?(6)?, 100)
    h.assert_eq[USize](_array(res._1)?(7)?, 70)
    h.assert_eq[USize](_array(res._1)?(8)?, 0)
    h.assert_eq[USize](_array(res._1)?(9)?, 0)

    true

  fun _array(res: (USize | Array[USize] val | None)): Array[USize] val ? =>
    match res
    | let a: Array[USize] val => a
    else error end

class iso _TestSlidingWindowsGCD is UnitTest
  fun name(): String => "bytes/_TestSlidingWindowsGCD"

  fun apply(h: TestHelper) ? =>
    let range: U64 = Seconds(10)
    let slide: U64 = Seconds(3)
    let delay: U64 = Seconds(10)
    let sw = RangeWindows[USize, USize, _Total]("key", _Sum, range, slide,
      delay)

    var res: ((USize | Array[USize] val | None), U64) =
      (recover Array[USize] end, 0)

    // First set of windows values
    res = sw(2, Seconds(92), Seconds(100))
    h.assert_eq[USize](_array(res._1)?.size(), 0)

    res = sw(3, Seconds(93), Seconds(102))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 0)

    res = sw(4, Seconds(94), Seconds(103))
    h.assert_eq[USize](_array(res._1)?.size(), 0)

    res = sw(5, Seconds(95), Seconds(104))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 0)

    // Second set of windows with values
    res = sw(1, Seconds(102), Seconds(106))
    h.assert_eq[USize](_array(res._1)?.size(), 0)

    res = sw(2, Seconds(103), Seconds(107))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 5)

    res = sw(3, Seconds(104), Seconds(108))
    h.assert_eq[USize](_array(res._1)?.size(), 0)

    res = sw(4, Seconds(105), Seconds(109))
    h.assert_eq[USize](_array(res._1)?.size(), 0)

    // Third set of windows with values.
    res = sw(10, Seconds(111), Seconds(112))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 14)

    res = sw(20, Seconds(112), Seconds(113))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 14)

    res = sw(30, Seconds(113), Seconds(114))
    h.assert_eq[USize](_array(res._1)?.size(), 0)

    res = sw(40, Seconds(114), Seconds(115))
    h.assert_eq[USize](_array(res._1)?.size(), 0)

    // Fourth set of windows
    // Use this message to trigger 8 windows.
    res = sw(2, Seconds(192), Seconds(200))
    h.assert_eq[USize](_array(res._1)?.size(), 8)
    h.assert_eq[USize](_array(res._1)?(0)?, 13)
    h.assert_eq[USize](_array(res._1)?(1)?, 10)
    h.assert_eq[USize](_array(res._1)?(2)?, 10)
    h.assert_eq[USize](_array(res._1)?(3)?, 20)
    h.assert_eq[USize](_array(res._1)?(4)?, 104)
    h.assert_eq[USize](_array(res._1)?(5)?, 100)
    h.assert_eq[USize](_array(res._1)?(6)?, 100)
    h.assert_eq[USize](_array(res._1)?(7)?, 40)

    res = sw(3, Seconds(193), Seconds(202))
    h.assert_eq[USize](_array(res._1)?.size(), 0)

    res = sw(4, Seconds(194), Seconds(203))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 0)

    res = sw(5, Seconds(195), Seconds(204))
    h.assert_eq[USize](_array(res._1)?.size(), 0)

    // Fifth set of windows with values
    res = sw(1, Seconds(202), Seconds(206))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 2)

    res = sw(2, Seconds(203), Seconds(207))
    h.assert_eq[USize](_array(res._1)?.size(), 0)

    res = sw(3, Seconds(204), Seconds(208))
    h.assert_eq[USize](_array(res._1)?.size(), 0)

    res = sw(4, Seconds(205), Seconds(209))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 14)

    // Sixth set of windows with values.
    res = sw(10, Seconds(211), Seconds(212))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 14)

    res = sw(20, Seconds(212), Seconds(213))
    h.assert_eq[USize](_array(res._1)?.size(), 0)

    res = sw(30, Seconds(213), Seconds(214))
    h.assert_eq[USize](_array(res._1)?.size(), 0)

    res = sw(40, Seconds(214), Seconds(215))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 14)

    true

  fun _array(res: (USize | Array[USize] val | None)): Array[USize] val ? =>
    match res
    | let a: Array[USize] val => a
    else error end

class iso _TestSlidingWindowsLateData is UnitTest
  fun name(): String => "bytes/_TestSlidingWindowsLateData"

  fun apply(h: TestHelper) ? =>
    let range: U64 = Seconds(10)
    let slide: U64 = Seconds(2)
    let delay: U64 = Seconds(10)
    let sw = RangeWindows[USize, USize, _Total]("key", _Sum, range, slide,
      delay)

    var res: ((USize | Array[USize] val | None), U64) =
      (recover Array[USize] end, 0)

    // Some initial values
    res = sw(1, Seconds(92), Seconds(100))
    h.assert_eq[USize](_array(res._1)?.size(), 0)

    res = sw(2, Seconds(93), Seconds(102))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 0)

    // Trigger existing values
    res = sw(10, Seconds(199), Seconds(200))
    h.assert_eq[USize](_array(res._1)?.size(), 10)
    h.assert_eq[USize](_array(res._1)?(0)?, 0)
    h.assert_eq[USize](_array(res._1)?(1)?, 3)
    h.assert_eq[USize](_array(res._1)?(2)?, 3)
    h.assert_eq[USize](_array(res._1)?(3)?, 3)
    h.assert_eq[USize](_array(res._1)?(4)?, 3)
    h.assert_eq[USize](_array(res._1)?(5)?, 3)
    h.assert_eq[USize](_array(res._1)?(6)?, 0)
    h.assert_eq[USize](_array(res._1)?(7)?, 0)
    h.assert_eq[USize](_array(res._1)?(8)?, 0)
    h.assert_eq[USize](_array(res._1)?(9)?, 0)

    // Send in late data, which should be dropped.
    res = sw(100, Seconds(100), Seconds(201))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 0)

    // Send in more late data, which should be dropped.
    res = sw(1, Seconds(101), Seconds(220))
    h.assert_eq[USize](_array(res._1)?.size(), 9)
    h.assert_eq[USize](_array(res._1)?(0)?, 0)
    h.assert_eq[USize](_array(res._1)?(1)?, 0)
    h.assert_eq[USize](_array(res._1)?(2)?, 0)
    h.assert_eq[USize](_array(res._1)?(3)?, 0)
    h.assert_eq[USize](_array(res._1)?(4)?, 10)
    h.assert_eq[USize](_array(res._1)?(5)?, 10)
    h.assert_eq[USize](_array(res._1)?(6)?, 10)
    h.assert_eq[USize](_array(res._1)?(7)?, 10)
    h.assert_eq[USize](_array(res._1)?(8)?, 10)

    true

  fun _array(res: (USize | Array[USize] val | None)): Array[USize] val ? =>
    match res
    | let a: Array[USize] val => a
    else error end

class iso _TestCountWindows is UnitTest
  fun name(): String => "bytes/_TestCountWindows"

  fun apply(h: TestHelper) =>
    let count_trigger: USize = 4
    let cw = TumblingCountWindows[USize, USize, _Total]("key", _Sum,
      count_trigger)

    var res: ((USize | None), U64) = (None, 0)

    // First window's data
    res = cw(2, Seconds(96), Seconds(101))
    h.assert_eq[Bool](true, _result_is(res._1, None))
    res = cw(3, Seconds(97), Seconds(102))
    h.assert_eq[Bool](true, _result_is(res._1, None))
    res = cw(4, Seconds(98), Seconds(103))
    h.assert_eq[Bool](true, _result_is(res._1, None))
    res = cw(5, Seconds(99), Seconds(104))
    h.assert_eq[Bool](true, _result_is(res._1, 14))

    // Second window's data
    res = cw(1, Seconds(105), Seconds(106))
    h.assert_eq[Bool](true, _result_is(res._1, None))
    res = cw(2, Seconds(106), Seconds(107))
    h.assert_eq[Bool](true, _result_is(res._1, None))
    res = cw(3, Seconds(107), Seconds(108))
    h.assert_eq[Bool](true, _result_is(res._1, None))
    res = cw(4, Seconds(108), Seconds(109))
    h.assert_eq[Bool](true, _result_is(res._1, 10))

    // Third window's data.
    res = cw(10, Seconds(110), Seconds(111))
    h.assert_eq[Bool](true, _result_is(res._1, None))
    res = cw(20, Seconds(111), Seconds(112))
    h.assert_eq[Bool](true, _result_is(res._1, None))
    res = cw(30, Seconds(112), Seconds(113))
    h.assert_eq[Bool](true, _result_is(res._1, None))
    res = cw(40, Seconds(113), Seconds(114))
    h.assert_eq[Bool](true, _result_is(res._1, 100))

    true

  fun _result_is(res: (USize | None), check: (USize | None)): Bool =>
    match res
    | let u: USize =>
      match check
      | let u2: USize => u == u2
      else
        false
      end
    | let n: None =>
      match check
      | let n2: None => true
      else
        false
      end
    end

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
