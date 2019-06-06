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
use "random"
use "time"
use "wallaroo/core/aggregations"
use "wallaroo/core/common"
use "wallaroo/core/state"
use "wallaroo/core/topology"
use "wallaroo_labs/time"


actor _LateDataPolicyTests is TestList
  new create(env: Env) => PonyTest(env, this)
  new make() => None
  fun tag tests(test: PonyTest) =>
    test(_LateDataIgnoredUnderDrop)
    test(_LateDataTriggersOwnWindowUnderFirePerMessage)
    test(_LateDataTriggersNewWindowUnderFirePerMessage)
    test(_FirePerMessageUsesEventTimeAsOutputTsForLateData)
    test(_PlaceInOldestWindowOneWindow)
    test(_PlaceInOldestWindowTwoWindows)
    test(_PlaceInOldestWindowDoesntAutomaticallyTrigger)

class iso _LateDataIgnoredUnderDrop is UnitTest
  fun name(): String => "windows/late_data/_LateDataIgnoredUnderDrop"

  fun apply(h: TestHelper) ? =>
    // First message starts window
    // Second message is late data
    // Third message triggers window including first message (needs watermark
    // past range and delay, and event ts that places it in that same window)

    // Result:
    //  [1; 3]

    // given
    let range: U64 = Seconds(10)
    let tw =
      RangeWindowsBuilder(range)
        .over[USize, Array[USize] val, _Collected](_Collect)
        .state_wrapper("key", _Zeros)
        .>apply(1, Seconds(100), Seconds(100))
        .>apply(2, Seconds(50), Seconds(100))

    // when
    let res = tw(3, Seconds(101), Seconds(111))

    // then
    let res_array = _ForceArrayArray(res._1)?
    h.assert_eq[USize](res_array.size(), 1)
    h.assert_array_eq[USize](res_array(0)?, [1; 3])


class iso _LateDataTriggersOwnWindowUnderFirePerMessage is UnitTest
  fun name(): String =>
    "windows/late_data/_LateDataTriggersOwnWindowUnderFirePerMessage"

  fun apply(h: TestHelper) ? =>
    // First message starts window
    // Second message is late data
    // Third message triggers window including first message (needs watermark
    // past range and delay, and event ts that places it in that same window)

    // Result:
    //   [2]
    //   [1; 3]

    // given
    let range: U64 = Seconds(10)
    //!@
    // let tw = RangeWindows[USize, Array[USize] val, _Collected]("key",
    //   _Collect, range, slide, delay, _Zeros, LateDataPolicy.fire_per_message())
    let tw =
      RangeWindowsBuilder(range)
        .with_late_data_policy(LateDataPolicy.fire_per_message())
        .over[USize, Array[USize] val, _Collected](_Collect)
        .state_wrapper("key", _Zeros)
        .>apply(1, Seconds(100), Seconds(100))

    // when
    let res1 = tw(2, Seconds(50), Seconds(100))
    let res2 = tw(3, Seconds(101), Seconds(111))

    // then
    let res_array1 = _ForceArrayArray(res1._1)?
    h.assert_eq[USize](res_array1.size(), 1)
    h.assert_array_eq[USize](res_array1(0)?, [2])
    let res_array2 = _ForceArrayArray(res2._1)?
    h.assert_eq[USize](res_array2.size(), 1)
    h.assert_array_eq[USize](res_array2(0)?, [1; 3])

class iso _LateDataTriggersNewWindowUnderFirePerMessage is UnitTest
  fun name(): String =>
    "windows/late_data/_LateDataTriggersNewWindowUnderFirePerMessage"

  fun apply(h: TestHelper) ? =>
    // First message starts window
    // Second message joins/triggers window
    // Third message is late data

    // Result:
    //   [1; 2]
    //   [3]

    // given
    let range: U64 = Seconds(10)
    // let tw = RangeWindows[USize, Array[USize] val, _Collected]("key",
    //   _Collect, range, slide, delay, _Zeros, LateDataPolicy.fire_per_message())
    let tw =
      RangeWindowsBuilder(range)
        .with_late_data_policy(LateDataPolicy.fire_per_message())
        .over[USize, Array[USize] val, _Collected](_Collect)
        .state_wrapper("key", _Zeros)
        .>apply(1, Seconds(100), Seconds(100))

    // when
    let res1 = tw(2, Seconds(101), Seconds(111))
    let res2 = tw(3, Seconds(50), Seconds(111))

    // then
    let res_array1 = _ForceArrayArray(res1._1)?
    h.assert_eq[USize](res_array1.size(), 1)
    h.assert_array_eq[USize](res_array1(0)?, [1; 2])
    let res_array2 = _ForceArrayArray(res2._1)?
    h.assert_eq[USize](res_array2.size(), 1)
    h.assert_array_eq[USize](res_array2(0)?, [3])

class iso _FirePerMessageUsesEventTimeAsOutputTsForLateData is UnitTest
  fun name(): String =>
    "windows/_FirePerMessageUsesEventTimeAsOutputTsForLateData"

  fun apply(h: TestHelper) ? =>
    // given
    let range: U64 = Seconds(10)
    //!@
    // let tw = RangeWindows[USize, USize, _Total]("key",
    //   _Sum, range, slide, delay, _Zeros, LateDataPolicy.fire_per_message())
    let tw =
      RangeWindowsBuilder(range)
        .with_late_data_policy(LateDataPolicy.fire_per_message())
        .over[USize, USize, _Total](_Sum)
        .state_wrapper("key", _Zeros)
        .>apply(1, Seconds(100), Seconds(100))

    // when
    let res1 = tw(2, Seconds(101), Seconds(111))
    let res2 = tw(3, Seconds(50), Seconds(112))

    // then
    let res_array1 = _ForceArray(res1._1)?
    h.assert_eq[USize](res_array1.size(), 1)
    h.assert_eq[USize](res_array1(0)?, 3)
    h.assert_eq[U64](res1._2, Seconds(110) - 1)
    let res_array2 = _ForceArrayWithEventTimes(res2._1)?
    h.assert_eq[USize](res_array2.size(), 1)
    h.assert_eq[U64](res_array2(0)?._2, Seconds(50))
    h.assert_eq[U64](res2._2, Seconds(50))

class iso _PlaceInOldestWindowOneWindow is UnitTest
  fun name(): String => "windows/late_data/_PlaceInOldestWindowOneWindow"

  fun apply(h: TestHelper) ? =>
    // First message starts window (ensure there is only one window?)
    // Second message is late data
    // Third message triggers all windows(needs watermark
    // past range and delay for first window, and event ts that places it in
    // that same window)

    // Result:
    //   [1; 2; 3]

    // given
    let range: U64 = Seconds(10)
    //!@
    // let tw = RangeWindows[USize, Array[USize] val, _Collected]("key",
    //   _Collect, range, slide, delay, _Zeros,
    //   LateDataPolicy.place_in_oldest_window())
    let tw =
      RangeWindowsBuilder(range)
        .with_late_data_policy(LateDataPolicy.place_in_oldest_window())
        .over[USize, Array[USize] val, _Collected](_Collect)
        .state_wrapper("key", _Zeros)
        .>apply(1, Seconds(100), Seconds(100))
        .>apply(2, Seconds(50), Seconds(100))

    // when
    let res = tw(3, Seconds(101), Seconds(111))

    // then
    let res_array = _ForceArrayArray(res._1)?
    h.assert_eq[USize](res_array.size(), 1)
    h.assert_array_eq[USize](res_array(0)?, [1; 2; 3])

class iso _PlaceInOldestWindowTwoWindows is UnitTest
  fun name(): String => "windows/late_data/_PlaceInOldestWindowTwoWindows"

  fun apply(h: TestHelper) ? =>
    // First message starts window
    // Second message starts second window
    // Third message is late data
    // Fourth message triggers all windows(needs watermark
    // past range and delay for second window, and event ts that places it in
    // that same window)

    // Result:
    //   [1; 3]
    //   [2; 4]

    // given
    let range: U64 = Seconds(10)
    //!@
    // let tw = RangeWindows[USize, Array[USize] val, _Collected]("key",
    //   _Collect, range, slide, delay, _Zeros,
    //   LateDataPolicy.place_in_oldest_window())
    let tw =
      RangeWindowsBuilder(range)
        .with_late_data_policy(LateDataPolicy.place_in_oldest_window())
        .over[USize, Array[USize] val, _Collected](_Collect)
        .state_wrapper("key", _Zeros)
        .>apply(1, Seconds(100), Seconds(100))
        .>apply(2, Seconds(111), Seconds(100))
        .>apply(3, Seconds(50), Seconds(100))

    // when
    let res = tw(4, Seconds(112), Seconds(121))

    // then
    let res_array = _ForceArrayArray(res._1)?
    h.assert_eq[USize](res_array.size(), 2)
    h.assert_array_eq[USize](res_array(0)?, [1; 3])
    h.assert_array_eq[USize](res_array(1)?, [2; 4])

class iso _PlaceInOldestWindowDoesntAutomaticallyTrigger is UnitTest
  fun name(): String =>
    "windows/late_data/_PlaceInOldestWindowDoesntAutomaticallyTrigger"

  fun apply(h: TestHelper) ? =>
    // First message starts window
    // Second message joins/triggers window
    // Third message is late data

    // Result:
    //  [1; 2]

    // given
    let range: U64 = Seconds(10)
    //!@
    // let tw = RangeWindows[USize, Array[USize] val, _Collected]("key",
    //   _Collect, range, slide, delay, _Zeros,
    //   LateDataPolicy.place_in_oldest_window())
    let tw =
      RangeWindowsBuilder(range)
        .with_late_data_policy(LateDataPolicy.place_in_oldest_window())
        .over[USize, Array[USize] val, _Collected](_Collect)
        .state_wrapper("key", _Zeros)
        .>apply(1, Seconds(100), Seconds(100))

    // when
    let res1 = tw(2, Seconds(101), Seconds(111))
    let res2 = tw(3, Seconds(50), Seconds(111))

    // then
    let res_array1 = _ForceArrayArray(res1._1)?
    h.assert_eq[USize](res_array1.size(), 1)
    h.assert_array_eq[USize](res_array1(0)?, [1; 2])
    let res_array2 = _ForceArrayArray(res2._1)?
    h.assert_eq[USize](res_array2.size(), 0)

