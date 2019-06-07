/*

Copyright 2019 The Wallaroo Authors.

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
use "wallaroo"
use "wallaroo/core/aggregations"
use "wallaroo/core/common"
use "wallaroo/core/state"
use "wallaroo/core/topology"
use "wallaroo_labs/time"


actor _EphemeralWindowTests is TestList
  new create(env: Env) => PonyTest(env, this)
  new make() => None
  fun tag tests(test: PonyTest) =>
    test(_FirstMessageForOpenWindowIsPlacedInWindow)
    test(_MessageBeforeTriggerPointForOpenWindowIsPlacedInWindow)
    test(_MessageAfterTriggerPointIsPlacedInWindowAndWindowIsTriggered)
    test(_MessageForOpenButTriggeredWindowIsTreatedAsDropLateData)
    test(_MessageForOpenButTriggeredWindowIsTreatedAsFirePerMessageLateData)
    test(_KeyIsRetainedForFirstMessage)
    test(_KeyIsRetainedForMessageBeforeTriggerPoint)
    test(_KeyIsRetainedForTriggeredWindowBeforeRemovePoint)
    test(_KeyIsNotRetainedForTriggeredWindowAfterRemovePoint)

class iso _FirstMessageForOpenWindowIsPlacedInWindow is UnitTest
  fun name(): String =>
    "windows/ephemeral_windows/" +
      "_FirstMessageForOpenWindowIsPlacedInWindow"

  fun apply(h: TestHelper) ? =>
    // given
    let trigger_range = Seconds(5)
    let post_trigger_range = Seconds(5)
    let ew =
      EphemeralWindowsBuilder(trigger_range, post_trigger_range)
        .over[USize, Array[USize] val, _Collected](_Collect)
        .state_wrapper("key", _Zeros)
        .>apply(1, Seconds(100), Seconds(100))

    // when
    let res = ew(2, Seconds(9999), Seconds(106))

    // then
    let res_array = _ForceArrayArray(res._1)?
    h.assert_eq[USize](res_array.size(), 1)
    h.assert_array_eq[USize](res_array(0)?, [1])

class iso _MessageBeforeTriggerPointForOpenWindowIsPlacedInWindow is UnitTest
  fun name(): String =>
    "windows/ephemeral_windows/" +
      "_MessageBeforeTriggerPointForOpenWindowIsPlacedInWindow"

  fun apply(h: TestHelper) ? =>
    // given
    let trigger_range = Seconds(5)
    let post_trigger_range = Seconds(5)
    let ew =
      EphemeralWindowsBuilder(trigger_range, post_trigger_range)
        .over[USize, Array[USize] val, _Collected](_Collect)
        .state_wrapper("key", _Zeros)
        .>apply(1, Seconds(100), Seconds(100))

    // when
    let res = ew(2, Seconds(104), Seconds(111))

    // then
    let res_array = _ForceArrayArray(res._1)?
    h.assert_eq[USize](res_array.size(), 1)
    h.assert_array_eq[USize](res_array(0)?, [1; 2])

class iso _MessageAfterTriggerPointIsPlacedInWindowAndWindowIsTriggered
  is UnitTest
  fun name(): String =>
    "windows/ephemeral_windows/" +
      "_MessageAfterTriggerPointIsPlacedInWindowAndWindowIsTriggered"

  fun apply(h: TestHelper) ? =>
    // given
    let trigger_range = Seconds(5)
    let post_trigger_range = Seconds(5)
    let ew =
      EphemeralWindowsBuilder(trigger_range, post_trigger_range)
        .over[USize, Array[USize] val, _Collected](_Collect)
        .state_wrapper("key", _Zeros)
        .>apply(1, Seconds(100), Seconds(100))

    // when
    //!@ This raises question about whether the trigger point has to do with
    // the message event_ts at all.  It seems like the only thing that matters
    // is whether the window is triggered yet. So a policy that respects a
    // trigger point for the message might be a separate feature.
    let res = ew(2, Seconds(106), Seconds(106))

    // then
    let res_array = _ForceArrayArray(res._1)?
    h.assert_eq[USize](res_array.size(), 1)
    h.assert_array_eq[USize](res_array(0)?, [1; 2])

class iso _MessageForOpenButTriggeredWindowIsTreatedAsDropLateData is UnitTest
  fun name(): String =>
    "windows/ephemeral_windows/" +
      "_MessageAfterTriggerPointForOpenWindowIsTreatedAsDropLateData"

  fun apply(h: TestHelper) ? =>
    // given
    let trigger_range = Seconds(5)
    let post_trigger_range = Seconds(5)
    let ew =
      EphemeralWindowsBuilder(trigger_range, post_trigger_range)
        .over[USize, Array[USize] val, _Collected](_Collect)
        .state_wrapper("key", _Zeros)
        .>apply(1, Seconds(100), Seconds(100))
        .>apply(2, Seconds(106), Seconds(106))

    // when
    let res = ew(3, Seconds(107), Seconds(107))

    // then
    let res_array = _ForceArrayArray(res._1)?
    h.assert_eq[USize](res_array.size(), 1)
    h.assert_array_eq[USize](res_array(0)?, [])

class iso _MessageForOpenButTriggeredWindowIsTreatedAsFirePerMessageLateData
  is UnitTest
  fun name(): String =>
    "windows/ephemeral_windows/" +
      "_MessageForOpenButTriggeredWindowIsTreatedAsFirePerMessageLateData"

  fun apply(h: TestHelper) ? =>
    // given
    let trigger_range = Seconds(5)
    let post_trigger_range = Seconds(5)
    let ew =
      EphemeralWindowsBuilder(trigger_range, post_trigger_range)
        .with_late_data_policy(LateDataPolicy.fire_per_message())
        .over[USize, Array[USize] val, _Collected](_Collect)
        .state_wrapper("key", _Zeros)
        .>apply(1, Seconds(100), Seconds(100))
        .>apply(2, Seconds(106), Seconds(106))

    // when
    let res = ew(3, Seconds(107), Seconds(107))

    // then
    let res_array = _ForceArrayArray(res._1)?
    h.assert_eq[USize](res_array.size(), 1)
    h.assert_array_eq[USize](res_array(0)?, [3])

class iso _KeyIsRetainedForFirstMessage is UnitTest
  fun name(): String =>
    "windows/ephemeral_windows/" +
      "_KeyIsRetainedForFirstMessage"

  fun apply(h: TestHelper) =>
    // given
    let trigger_range = Seconds(5)
    let post_trigger_range = Seconds(5)
    let ew =
      EphemeralWindowsBuilder(trigger_range, post_trigger_range)
        .over[USize, Array[USize] val, _Collected](_Collect)
        .state_wrapper("key", _Zeros)

    // when
    let res = ew(1, Seconds(100), Seconds(100))

    // then
    // Check that retain_state return value is true
    h.assert_eq[Bool](res._3, true)

class iso _KeyIsRetainedForMessageBeforeTriggerPoint is UnitTest
  fun name(): String =>
    "windows/ephemeral_windows/" +
      "_KeyIsRetainedForMessageBeforeTriggerPoint"

  fun apply(h: TestHelper) =>
    // given
    let trigger_range = Seconds(5)
    let post_trigger_range = Seconds(5)
    let ew =
      EphemeralWindowsBuilder(trigger_range, post_trigger_range)
        .over[USize, Array[USize] val, _Collected](_Collect)
        .state_wrapper("key", _Zeros)
        .>apply(1, Seconds(100), Seconds(100))

    // when
    let res = ew(2, Seconds(103), Seconds(103))

    // then
    // Check that retain_state return value is true
    h.assert_eq[Bool](res._3, true)

class iso _KeyIsRetainedForTriggeredWindowBeforeRemovePoint is UnitTest
  fun name(): String =>
    "windows/ephemeral_windows/" +
      "_KeyIsRetainedForTriggeredWindowBeforeRemovePoint"

  fun apply(h: TestHelper) =>
    // given
    let trigger_range = Seconds(5)
    let post_trigger_range = Seconds(5)
    let ew =
      EphemeralWindowsBuilder(trigger_range, post_trigger_range)
        .over[USize, Array[USize] val, _Collected](_Collect)
        .state_wrapper("key", _Zeros)
        .>apply(1, Seconds(100), Seconds(100))
        .>apply(2, Seconds(106), Seconds(106))

    // when
    let res = ew(2, Seconds(107), Seconds(107))

    // then
    // Check that retain_state return value is true
    h.assert_eq[Bool](res._3, true)

class iso _KeyIsNotRetainedForTriggeredWindowAfterRemovePoint is UnitTest
  fun name(): String =>
    "windows/ephemeral_windows/" +
      "_KeyIsNotRetainedForTriggeredWindowAfterRemovePoint"

  fun apply(h: TestHelper) =>
    // given
    let trigger_range = Seconds(5)
    let post_trigger_range = Seconds(5)
    let ew =
      EphemeralWindowsBuilder(trigger_range, post_trigger_range)
        .over[USize, Array[USize] val, _Collected](_Collect)
        .state_wrapper("key", _Zeros)
        .>apply(1, Seconds(100), Seconds(100))
        .>apply(2, Seconds(106), Seconds(106))

    // when
    let res = ew(2, Seconds(111), Seconds(111))

    // then
    // Check that retain_state return value is false
    h.assert_eq[Bool](res._3, false)
