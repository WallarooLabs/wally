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

use "collections"
use "ponytest"
use "promises"
use "wallaroo/core/aggregations"
use "wallaroo/core/common"
use "wallaroo/core/state"
use "wallaroo/core/topology"
use "wallaroo_labs/time"

class iso _TestTumblingWindowsTimeoutTrigger is UnitTest
  fun name(): String => "windows/_TestTumblingWindowsTimeoutTrigger"

  fun apply(h: TestHelper) ? =>
    // given
    let watermark: U64 = Seconds(111)
    let range: U64 = Seconds(1)
    let tw = _TumblingWindow(range, _Sum)
            .>apply(111, watermark, watermark)

    // when
    let res = tw.on_timeout(TimeoutWatermark(), watermark)

    // then
    let res_array = _ForceArray(res._1)?
    h.assert_eq[USize](res_array.size(), 1)
    h.assert_eq[USize](res_array(0)?, 111)
    h.assert_true(res._2 != TimeoutWatermark())


class iso _TestOnTimeoutWatermarkTsIsJustBeforeNextWindowStart is UnitTest
  fun name(): String => "windows/_TestOnTimeoutWatermarkTsIsJustBeforeNextWindowStart"

  fun apply(h: TestHelper) ? =>
    // given
    let range: U64 = Milliseconds(50)
    let slide = range
    let delay: U64 = 0
    let tw = _TumblingWindow(Milliseconds(50), _NonZeroSum)
             .>apply(1, Milliseconds(5000), Milliseconds(5000))

    // when
    let no_output_watermark = U64(0)
    let res = tw.on_timeout(TimeoutWatermark(), no_output_watermark)

    // then
    let res_array = _ForceArray(res._1)?
    h.assert_eq[USize](res_array.size(), 1)
    h.assert_eq[USize](res_array(0)?, 1)
    h.assert_eq[U64](res._2, Milliseconds(5050))

class iso _Test0 is UnitTest  // !@
  fun name(): String =>
    "windows/_Test0"

  fun apply(h: TestHelper) ? =>
    // given
    let range: U64 = Milliseconds(50)
    let slide = range
    let delay: U64 = 0
    let tw = RangeWindows[USize, USize, _Total]("key", _NonZeroSum, range, slide,
      delay)
    tw(1, Milliseconds(5000), Milliseconds(5000))
    tw(3, Milliseconds(5300), Milliseconds(5300))

    // when
    let res = tw(11, Milliseconds(6050), Milliseconds(6050))

    // then
    let res_array = _ForceArray(res._1)?
    h.assert_eq[USize](res_array.size(), 1)
    h.assert_eq[USize](res_array(0)?, 3)
    h.assert_eq[U64](res._2, Milliseconds(5350))

class iso _Test1 is UnitTest  // !@
  fun name(): String =>
    "windows/_Test1"

  fun apply(h: TestHelper) ? =>
    // given
    let tw = _TumblingWindow(Milliseconds(50), _NonZeroSum)
             .>apply(1, Milliseconds(5000), Milliseconds(5000))
             .>apply(3, Milliseconds(5300), Milliseconds(5300))
             .>apply(11, Milliseconds(6050), Milliseconds(6050))
             .>apply(13, Milliseconds(6051), Milliseconds(6051))

    // when
    let res = tw.on_timeout(TimeoutWatermark(), Milliseconds(5350))

    // then
    let res_array = _ForceArray(res._1)?
    h.assert_eq[USize](res_array.size(), 1)
    h.assert_eq[USize](res_array(0)?, 24)
    h.assert_eq[U64](res._2, Milliseconds(6100))

class iso _Test2 is UnitTest  // !@
  fun name(): String =>
    "windows/_Test2"

  fun apply(h: TestHelper) ? =>
    // given
    let tw = _TumblingWindow(Seconds(1), _NonZeroSum)
             .>apply(1, Milliseconds(5050), Milliseconds(5050))
             .>apply(3, Milliseconds(5350), Milliseconds(5350))
             .>apply(24, Milliseconds(6250), Milliseconds(6250))

    // when
    let res = tw.on_timeout(TimeoutWatermark(), Milliseconds(5350))

    // then
    let res_array = _ForceArray(res._1)?
    h.assert_eq[USize](res_array.size(), 1)
    h.assert_eq[USize](res_array(0)?, 24)
    h.assert_eq[U64](res._2, Milliseconds(7050))

class iso _TestOutputWatermarkTsIsJustBeforeNextWindowStart is UnitTest
  fun name(): String =>
    "windows/_TestOutputWatermarkTsIsJustBeforeNextWindowStart"

  fun apply(h: TestHelper) ? =>
    // given
    let range: U64 = Milliseconds(50)
    let slide = range
    let delay: U64 = 0
    let upstream_id: U128 = 1000
    let now: U64 = 1000
    let tw = RangeWindows[USize, USize, _Total]("key", _NonZeroSum, range, slide,
      delay)
    tw(1, Milliseconds(5000), Milliseconds(5000))

    // when
    let res = tw(3, Milliseconds(5100), Milliseconds(5100))

    // then
    let res_array = _ForceArray(res._1)?
    h.assert_eq[USize](res_array.size(), 1)
    h.assert_eq[USize](res_array(0)?, 1)
    h.assert_eq[U64](res._2, Milliseconds(5050))


class iso _TestMessageAssignmentToTumblingWindows is UnitTest
  fun name(): String => "windows/_TestMessageAssignmentToTumblingWindows"

  fun apply(h: TestHelper) ? =>
    // given
    let range: U64 = Milliseconds(50)
    let slide = range
    let delay: U64 = 0
    let upstream_id: U128 = 1000
    let now: U64 = 1000
    let tw = RangeWindows[USize, USize, _Total]("key", _NonZeroSum, range, slide,
      delay)

    // when
    let r1 = tw(1, Milliseconds(5000), Milliseconds(5000))
    let r2 = tw(3, Milliseconds(5100), Milliseconds(5100))
    let r3 = tw(5, Milliseconds(5200), Milliseconds(5200))
    let r4 = tw(1, Milliseconds(5300), Milliseconds(5300))
    let r5 = tw.on_timeout(TimeoutWatermark(), r4._2)

    // then
    let r1_array = _ForceArray(r1._1)?
    h.assert_eq[USize](r1_array.size(), 0)
    h.assert_eq[U64](r1._2, 0) // we expect 5050 (should be `5050)` )

    let r2_array = _ForceArray(r2._1)?
    h.assert_eq[USize](r2_array.size(), 1)
    h.assert_eq[USize](r2_array(0)?, 1)
    h.assert_eq[U64](r2._2, Milliseconds(5050))

    let r3_array = _ForceArray(r3._1)?
    h.assert_eq[USize](r3_array.size(), 1)
    h.assert_eq[USize](r3_array(0)?, 3)
    h.assert_eq[U64](r3._2, Milliseconds(5150))

    let r4_array = _ForceArray(r4._1)?
    h.assert_eq[USize](r4_array.size(), 1)
    h.assert_eq[USize](r4_array(0)?, 5)
    h.assert_eq[U64](r4._2, Milliseconds(5250))

    let r5_array = _ForceArray(r5._1)?
    h.assert_eq[USize](r5_array.size(), 1)
    h.assert_eq[USize](r5_array(0)?, 1)
    h.assert_eq[U64](r5._2, Milliseconds(5350))

primitive _ForceArray
  fun apply(res: (USize | Array[USize] val | None)): Array[USize] val ? =>
    match res
    | let a: Array[USize] val => a
    else error end

primitive _TumblingWindow
  fun apply(range: U64, calculation: Aggregation[USize, USize, _Total]):
    RangeWindows[USize, USize, _Total]
  =>
    let slide = range
    let delay: U64 = 0
    RangeWindows[USize, USize, _Total]("key", _NonZeroSum, range, slide, delay)


class iso _TestTumblingWindows is UnitTest
  fun name(): String => "windows/_TestTumblingWindows"

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
  fun name(): String => "windows/_TestSlidingWindows"

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

    h.assert_eq[Bool](sw.check_panes_increasing(), true)

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

    h.assert_eq[Bool](sw.check_panes_increasing(), true)

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

    h.assert_eq[Bool](sw.check_panes_increasing(), true)

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

    h.assert_eq[Bool](sw.check_panes_increasing(), true)

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

    h.assert_eq[Bool](sw.check_panes_increasing(), true)

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

    h.assert_eq[Bool](sw.check_panes_increasing(), true)

    true

  fun _array(res: (USize | Array[USize] val | None)): Array[USize] val ? =>
    match res
    | let a: Array[USize] val => a
    else error end

class iso _TestSlidingWindowsNoDelay is UnitTest
  fun name(): String => "windows/_TestSlidingWindowsNoDelay"

  fun apply(h: TestHelper) ? =>
    let range: U64 = Seconds(10)
    let slide: U64 = Seconds(2)
    let delay: U64 = Seconds(0)
    let sw = RangeWindows[USize, USize, _Total]("key", _Sum, range, slide,
      delay)

    var res: ((USize | Array[USize] val | None), U64) =
      (recover Array[USize] end, 0)

    // First 2 windows values
    res = sw(2, Seconds(92), Seconds(100))
    h.assert_eq[USize](_array(res._1)?.size(), 0)

    res = sw(3, Seconds(93), Seconds(102))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 5)

    res = sw(4, Seconds(94), Seconds(103))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 9)

    res = sw(5, Seconds(95), Seconds(104))
    h.assert_eq[USize](_array(res._1)?.size(), 0)

    h.assert_eq[Bool](sw.check_panes_increasing(), true)

    // Second 2 windows with values
    res = sw(1, Seconds(102), Seconds(106))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 10)

    res = sw(2, Seconds(103), Seconds(107))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 3)

    res = sw(3, Seconds(104), Seconds(108))
    h.assert_eq[USize](_array(res._1)?.size(), 0)

    res = sw(4, Seconds(105), Seconds(109))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 10)

    h.assert_eq[Bool](sw.check_panes_increasing(), true)

    // Third 2 windows with values.
    res = sw(10, Seconds(108), Seconds(112))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 20)

    res = sw(20, Seconds(109), Seconds(113))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 40)

    res = sw(30, Seconds(110), Seconds(114))
    h.assert_eq[USize](_array(res._1)?.size(), 0)

    res = sw(40, Seconds(111), Seconds(115))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 107)

    h.assert_eq[Bool](sw.check_panes_increasing(), true)

    // Fourth set of windows
    // Use this message to trigger 10 windows.
    res = sw(2, Seconds(192), Seconds(200))
    h.assert_eq[USize](_array(res._1)?.size(), 5)
    h.assert_eq[USize](_array(res._1)?(0)?, 100)
    h.assert_eq[USize](_array(res._1)?(1)?, 100)
    h.assert_eq[USize](_array(res._1)?(2)?, 70)
    h.assert_eq[USize](_array(res._1)?(3)?, 0)
    h.assert_eq[USize](_array(res._1)?(4)?, 0)

    res = sw(3, Seconds(193), Seconds(202))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 5)

    res = sw(4, Seconds(194), Seconds(203))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 9)

    res = sw(5, Seconds(195), Seconds(204))
    h.assert_eq[USize](_array(res._1)?.size(), 0)

    h.assert_eq[Bool](sw.check_panes_increasing(), true)

    true

  fun _array(res: (USize | Array[USize] val | None)): Array[USize] val ? =>
    match res
    | let a: Array[USize] val => a
    else error end

class iso _TestSlidingWindowsOutOfOrder is UnitTest
  fun name(): String => "windows/_TestSlidingWindowsOutOfOrder"

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

    h.assert_eq[Bool](sw.check_panes_increasing(), true)

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

    h.assert_eq[Bool](sw.check_panes_increasing(), true)

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

    h.assert_eq[Bool](sw.check_panes_increasing(), true)

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

    h.assert_eq[Bool](sw.check_panes_increasing(), true)

    true

  fun _array(res: (USize | Array[USize] val | None)): Array[USize] val ? =>
    match res
    | let a: Array[USize] val => a
    else error end

class iso _TestSlidingWindowsGCD is UnitTest
  fun name(): String => "windows/_TestSlidingWindowsGCD"

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
  fun name(): String => "windows/_TestSlidingWindowsLateData"

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

class iso _TestSlidingWindowsEarlyData is UnitTest
  fun name(): String => "windows/_TestSlidingWindowsEarlyData"

  fun apply(h: TestHelper) ? =>
    let range: U64 = Seconds(10)
    let slide: U64 = Seconds(2)
    let delay: U64 = Seconds(10)
    let sw = RangeWindows[USize, USize, _Total]("key", _Sum, range, slide,
      delay)

    var res: ((USize | Array[USize] val | None), U64) =
      (recover Array[USize] end, 0)

    // First values
    res = sw(2, Seconds(92), Seconds(100))
    h.assert_eq[USize](_array(res._1)?.size(), 0)

    // Send in a bunch of early values
    res = sw(1, Seconds(102), Seconds(100))
    h.assert_eq[USize](_array(res._1)?.size(), 0)
    h.assert_eq[Bool](sw.check_panes_increasing(), true)
    res = sw(2, Seconds(103), Seconds(100))
    h.assert_eq[USize](_array(res._1)?.size(), 0)
    h.assert_eq[Bool](sw.check_panes_increasing(), true)
    res = sw(3, Seconds(104), Seconds(100))
    h.assert_eq[USize](_array(res._1)?.size(), 0)
    h.assert_eq[Bool](sw.check_panes_increasing(), true)
    res = sw(4, Seconds(105), Seconds(100))
    h.assert_eq[USize](_array(res._1)?.size(), 0)
    h.assert_eq[Bool](sw.check_panes_increasing(), true)
    res = sw(10, Seconds(108), Seconds(100))
    h.assert_eq[USize](_array(res._1)?.size(), 0)
    h.assert_eq[Bool](sw.check_panes_increasing(), true)
    res = sw(20, Seconds(109), Seconds(100))
    h.assert_eq[USize](_array(res._1)?.size(), 0)
    h.assert_eq[Bool](sw.check_panes_increasing(), true)
    res = sw(30, Seconds(110), Seconds(100))
    h.assert_eq[USize](_array(res._1)?.size(), 0)
    h.assert_eq[Bool](sw.check_panes_increasing(), true)
    res = sw(40, Seconds(111), Seconds(100))
    h.assert_eq[USize](_array(res._1)?.size(), 0)
    h.assert_eq[Bool](sw.check_panes_increasing(), true)

    // Send in more normal values
    res = sw(3, Seconds(93), Seconds(102))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 0)
    h.assert_eq[Bool](sw.check_panes_increasing(), true)

    res = sw(4, Seconds(94), Seconds(103))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 0)

    res = sw(5, Seconds(95), Seconds(104))
    h.assert_eq[USize](_array(res._1)?.size(), 0)

    // Send in late values just to trigger stuff
    res = sw(0, Seconds(1), Seconds(106))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 5)

    res = sw(0, Seconds(1), Seconds(107))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 14)

    res = sw(0, Seconds(1), Seconds(108))
    h.assert_eq[USize](_array(res._1)?.size(), 0)

    res = sw(0, Seconds(1), Seconds(109))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 14)

    res = sw(0, Seconds(1), Seconds(112))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 14)

    res = sw(0, Seconds(1), Seconds(113))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 14)

    res = sw(0, Seconds(1), Seconds(114))
    h.assert_eq[USize](_array(res._1)?.size(), 0)

    res = sw(0, Seconds(1), Seconds(115))
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 12)

    // Fourth set of windows
    // Use this message to trigger 10 windows.
    res = sw(2, Seconds(192), Seconds(200))
    h.assert_eq[USize](_array(res._1)?.size(), 16)
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
    // Extra windows added because of expansion to cover early data
    for i in Range(10, 16) do
      h.assert_eq[USize](_array(res._1)?(i)?, 0)
    end

    true

  fun _array(res: (USize | Array[USize] val | None)): Array[USize] val ? =>
    match res
    | let a: Array[USize] val => a
    else error end

class iso _TestSlidingWindowsStragglers is UnitTest
  fun name(): String => "windows/_TestSlidingWindowsStragglers"

  fun apply(h: TestHelper) ? =>
    let range: U64 = Seconds(10)
    let slide: U64 = Seconds(2)
    let delay: U64 = Seconds(1_000)
    let sw = RangeWindows[USize, USize, _Total]("key", _Sum, range, slide,
      delay)

    // Last heard threshold of 100 seconds
    let watermarks = StageWatermarks(Seconds(100_000))

    var res: ((USize | Array[USize] val | None), U64) =
      (recover Array[USize] end, 0)

    var wm = Seconds(10_000)
    var cur_ts = Seconds(50_000)
    wm = watermarks.receive_watermark(1, wm, cur_ts)
    res = sw(1, wm, wm)
    watermarks.update_output_watermark(res._2)
    h.assert_eq[USize](_array(res._1)?.size(), 0)

    wm = Seconds(10_001)
    cur_ts = Seconds(50_001)
    wm = watermarks.receive_watermark(1, wm, cur_ts)
    res = sw(3, wm, wm)
    watermarks.update_output_watermark(res._2)
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_array(res._1)?(0)?, 0)

    wm = Seconds(10_002)
    cur_ts = Seconds(50_002)
    wm = watermarks.receive_watermark(1, wm, cur_ts)
    res = sw(5, wm, wm)
    watermarks.update_output_watermark(res._2)
    h.assert_eq[USize](_array(res._1)?.size(), 0)

    // It's been a while since we've heard from anyone
    cur_ts = Seconds(10_000_000)
    let input_w = watermarks.check_effective_input_watermark(cur_ts)
    let output_w = watermarks.output_watermark()
    res = sw.on_timeout(input_w, output_w)
    watermarks.update_output_watermark(res._2)
    h.assert_eq[USize](_array(res._1)?.size(), 506)
    for i in Range(0, 500) do
      h.assert_eq[USize](_array(res._1)?(i)?, 0)
    end
    h.assert_eq[USize](_array(res._1)?(500)?, 1 + 3)
    h.assert_eq[USize](_array(res._1)?(501)?, 1 + 3 + 5)
    h.assert_eq[USize](_array(res._1)?(502)?, 1 + 3 + 5)
    h.assert_eq[USize](_array(res._1)?(503)?, 1 + 3 + 5)
    h.assert_eq[USize](_array(res._1)?(504)?, 1 + 3 + 5)
    h.assert_eq[USize](_array(res._1)?(505)?, 5)
    h.assert_eq[Bool](sw.check_panes_increasing(), true)

    true

  fun _array(res: (USize | Array[USize] val | None)): Array[USize] val ? =>
    match res
    | let a: Array[USize] val => a
    else error end

class iso _TestSlidingWindowsStragglersSequence is UnitTest
  fun name(): String => "windows/_TestSlidingWindowsStragglersSequence"

  fun apply(h: TestHelper) ? =>
    let range: U64 = Seconds(10)
    let slide: U64 = Seconds(2)
    let delay: U64 = Seconds(1_000)
    let sw = RangeWindows[USize, Array[USize] val, Collected]("key",
      _Collect, range, slide, delay)

    // Last heard threshold of 100 seconds
    let watermarks = StageWatermarks(Seconds(100_000))

    var res: ((Array[USize] val | Array[Array[USize] val] val | None), U64) =
      (recover Array[Array[USize] val] end, 0)

    var wm = Seconds(10_000)
    var cur_ts = Seconds(50_000)
    wm = watermarks.receive_watermark(1, wm, cur_ts)
    res = sw(1, wm, wm)
    h.assert_eq[USize](_array(res._1)?.size(), 0)

    wm = Seconds(10_001)
    cur_ts = Seconds(50_001)
    wm = watermarks.receive_watermark(1, wm, cur_ts)
    res = sw(2, wm, wm)
    watermarks.update_output_watermark(res._2)
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_sum(_array(res._1)?(0)?), 0)

    wm = Seconds(10_002)
    cur_ts = Seconds(50_002)
    wm = watermarks.receive_watermark(1, wm, cur_ts)
    res = sw(3, wm, wm)
    watermarks.update_output_watermark(res._2)
    h.assert_eq[USize](_array(res._1)?.size(), 0)

    wm = Seconds(10_003)
    cur_ts = Seconds(50_003)
    wm = watermarks.receive_watermark(1, wm, cur_ts)
    res = sw(4, wm, wm)
    watermarks.update_output_watermark(res._2)
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_sum(_array(res._1)?(0)?), 0)

    wm = Seconds(10_004)
    cur_ts = Seconds(50_004)
    wm = watermarks.receive_watermark(1, wm, cur_ts)
    res = sw(5, wm, wm)
    watermarks.update_output_watermark(res._2)
    h.assert_eq[USize](_array(res._1)?.size(), 0)

    wm = Seconds(10_005)
    cur_ts = Seconds(50_005)
    wm = watermarks.receive_watermark(1, wm, cur_ts)
    res = sw(6, wm, wm)
    watermarks.update_output_watermark(res._2)
    h.assert_eq[USize](_array(res._1)?.size(), 1)
    h.assert_eq[USize](_sum(_array(res._1)?(0)?), 0)

    // It's been awhile since we've heard from anyone
    cur_ts = Seconds(100_000_000)
    let input_w = watermarks.check_effective_input_watermark(cur_ts)
    let output_w = watermarks.output_watermark()
    res = sw.on_timeout(input_w, output_w)
    watermarks.update_output_watermark(res._2)
    h.assert_eq[USize](_array(res._1)?.size(), 505)
    // Check empty windows before our stragglers
    for i in Range(0, 498) do
      h.assert_eq[USize](_sum(_array(res._1)?(i)?), 0)
    end
    h.assert_eq[USize](_sum(_array(res._1)?(498)?), 1 + 2)
    h.assert_eq[USize](_sum(_array(res._1)?(499)?), 1 + 2 + 3 + 4)
    h.assert_eq[USize](_sum(_array(res._1)?(500)?), 1 + 2 + 3 + 4 + 5 + 6)
    h.assert_eq[USize](_sum(_array(res._1)?(501)?), 1 + 2 + 3 + 4 + 5 + 6)
    h.assert_eq[USize](_sum(_array(res._1)?(502)?), 1 + 2 + 3 + 4 + 5 + 6)
    h.assert_eq[USize](_sum(_array(res._1)?(503)?), 3 + 4 + 5 + 6)
    h.assert_eq[USize](_sum(_array(res._1)?(504)?), 5 + 6)
    for c in _array(res._1)?.values() do
      h.assert_eq[Bool](CollectCheck(c), true)
    end
    h.assert_eq[Bool](sw.check_panes_increasing(), true)

  fun _array(res: (Array[USize] val | Array[Array[USize] val] val | None)):
    Array[Array[USize] val] val ?
  =>
    match res
    | let a: Array[Array[USize] val] val => a
    else error end

  fun _sum(arr: Array[USize] val): USize =>
    var sum: USize = 0
    for u in arr.values() do
      sum = sum + u
    end
    sum

class iso _TestSlidingWindowsSequence is UnitTest
  fun name(): String => "windows/_TestSlidingWindowsSequence"

  fun apply(h: TestHelper) ? =>
    let range: U64 = Seconds(50)
    let slide: U64 = Seconds(25)
    let delay: U64 = Seconds(3000)
    let sw = RangeWindows[USize, Array[USize] val, Collected]("key",
      _Collect, range, slide, delay)

    var res: ((Array[USize] val | Array[Array[USize] val] val | None), U64) =
      (recover Array[Array[USize] val] end, 0)

    // var wm: USize = 4_888
    // res = sw(0, Seconds(4_889), Seconds(wm))
    var wm: USize = 4_863
    res = sw(0, Seconds(4_864), Seconds(wm))
    for i in Range(0, 28) do
      wm = wm + 25
      sw(i, Seconds(wm), Seconds(wm))
    end
    wm = wm + 10
    sw(28, Seconds(wm), Seconds(wm))
    wm = wm + 10
    sw(29, Seconds(wm), Seconds(wm))
    wm = wm + 10
    sw(30, Seconds(wm), Seconds(wm))


    // First values
    res = sw(20, Seconds(10_901), Seconds(10_901))
    for c in _array(res._1)?.values() do
      h.assert_eq[Bool](CollectCheck(c), true)
    end
    h.assert_eq[Bool](sw.check_panes_increasing(), true)
    res = sw(21, Seconds(10_907), Seconds(10_907))
    for c in _array(res._1)?.values() do
      h.assert_eq[Bool](CollectCheck(c), true)
    end
    h.assert_eq[Bool](sw.check_panes_increasing(), true)
    res = sw(22, Seconds(10_912), Seconds(10_912))
    for c in _array(res._1)?.values() do
      h.assert_eq[Bool](CollectCheck(c), true)
    end
    h.assert_eq[Bool](sw.check_panes_increasing(), true)
    res = sw(23, Seconds(10_918), Seconds(10_918))
    for c in _array(res._1)?.values() do
      h.assert_eq[Bool](CollectCheck(c), true)
    end
    h.assert_eq[Bool](sw.check_panes_increasing(), true)
    res = sw(24, Seconds(10_924), Seconds(10_924))
    for c in _array(res._1)?.values() do
      h.assert_eq[Bool](CollectCheck(c), true)
    end
    h.assert_eq[Bool](sw.check_panes_increasing(), true)
    res = sw(25, Seconds(10_929), Seconds(10_929))
    for c in _array(res._1)?.values() do
      h.assert_eq[Bool](CollectCheck(c), true)
    end
    h.assert_eq[Bool](sw.check_panes_increasing(), true)
    res = sw(26, Seconds(10_935), Seconds(10_935))
    for c in _array(res._1)?.values() do
      h.assert_eq[Bool](CollectCheck(c), true)
    end
    h.assert_eq[Bool](sw.check_panes_increasing(), true)
    res = sw(27, Seconds(10_940), Seconds(10_940))
    for c in _array(res._1)?.values() do
      h.assert_eq[Bool](CollectCheck(c), true)
    end
    h.assert_eq[Bool](sw.check_panes_increasing(), true)
    res = sw(28, Seconds(10_945), Seconds(10_945))
    for c in _array(res._1)?.values() do
      h.assert_eq[Bool](CollectCheck(c), true)
    end
    h.assert_eq[Bool](sw.check_panes_increasing(), true)
    res = sw(29, Seconds(10_951), Seconds(10_951))
    for c in _array(res._1)?.values() do
      h.assert_eq[Bool](CollectCheck(c), true)
    end
    h.assert_eq[Bool](sw.check_panes_increasing(), true)
    res = sw(30, Seconds(10_957), Seconds(10_957))
    for c in _array(res._1)?.values() do
      h.assert_eq[Bool](CollectCheck(c), true)
    end
    h.assert_eq[Bool](sw.check_panes_increasing(), true)
    res = sw(31, Seconds(10_964), Seconds(10_964))
    for c in _array(res._1)?.values() do
      h.assert_eq[Bool](CollectCheck(c), true)
    end
    h.assert_eq[Bool](sw.check_panes_increasing(), true)
    res = sw(32, Seconds(10_968), Seconds(10_968))
    for c in _array(res._1)?.values() do
      h.assert_eq[Bool](CollectCheck(c), true)
    end
    h.assert_eq[Bool](sw.check_panes_increasing(), true)
    res = sw(33, Seconds(10_973), Seconds(10_973))
    for c in _array(res._1)?.values() do
      h.assert_eq[Bool](CollectCheck(c), true)
    end
    h.assert_eq[Bool](sw.check_panes_increasing(), true)
    res = sw(34, Seconds(10_979), Seconds(10_979))
    for c in _array(res._1)?.values() do
      h.assert_eq[Bool](CollectCheck(c), true)
    end

    true

  fun _array(res: (Array[USize] val | Array[Array[USize] val] val | None)):
    Array[Array[USize] val] val ?
  =>
    match res
    | let a: Array[Array[USize] val] val => a
    else error end

class iso _TestCountWindows is UnitTest
  fun name(): String => "windows/_TestCountWindows"

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
  fun output(key: Key, window_end_ts: U64, acc: _Total): (USize | None) =>
    acc.v
  fun name(): String => "_Sum"

class _NonZeroSum is Aggregation[USize, USize, _Total]
  fun initial_accumulator(): _Total => _Total
  fun update(input: USize, acc: _Total) =>
    acc.v = acc.v + input
  fun combine(acc1: _Total, acc2: _Total): _Total =>
    let new_t = _Total
    new_t.v = acc1.v + acc2.v
    new_t
  fun output(key: Key, window_end_ts: U64, acc: _Total): (USize | None) =>
    if acc.v > 0 then acc.v end
  fun name(): String => "_NonZeroSum"

primitive _Collect is Aggregation[USize, Array[USize] val, Collected]
  fun initial_accumulator(): Collected => Collected
  fun update(input: USize, acc: Collected) =>
    acc.push(input)
  fun combine(acc1: Collected, acc2: Collected): Collected =>
    let new_arr = Collected
    for m1 in acc1.values() do
      new_arr.push(m1)
    end
    for m2 in acc2.values() do
      new_arr.push(m2)
    end
    new_arr
  fun output(key: Key, window_end_ts: U64, acc: Collected): Array[USize] val =>
    let arr: Array[USize] iso = recover Array[USize] end
    for m in acc.values() do
      arr.push(m)
    end
    consume arr
  fun name(): String => "_Collect"

class Collected is State
  let arr: Array[USize] = arr.create()

  fun ref push(u: USize) =>
    arr.push(u)

  fun values(): ArrayValues[USize, this->Array[USize]]^ =>
    arr.values()

primitive CollectCheck
  fun apply(arr: Array[USize] val): Bool =>
    try
      var last = arr(0)?
      for i in Range(1, arr.size()) do
        let v = arr(i)?
        if not ((v == (last + 1)) or (v <= last)) then
          return false
        end
        last = v
      end
    else
      false
    end
    true
