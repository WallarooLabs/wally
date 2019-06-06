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
use "wallaroo_labs/math"
use "wallaroo_labs/time"

actor _ExpandSlidingWindowTests is TestList
  new create(env: Env) => PonyTest(env, this)
  new make() => None
  fun tag tests(test: PonyTest) =>
    test(_TestExpandSlidingWindow)
    test(_TestExpandSlidingWindowPrimitive)

class iso _TestExpandSlidingWindow is UnitTest
  fun name(): String => "windows/_TestExpandSlidingWindow"

  fun apply(h: TestHelper) =>
    var range: U64 = Seconds(10)
    var slide: U64 = Seconds(2)
    var delay: U64 = Seconds(1)

    var event_ts: U64 = Seconds(0)
    var end_ts: U64 = Seconds(0)

    (let init_pane_count, let pane_size, let panes_per_slide, _, _) =
      _InitializePaneParameters(range, slide, delay)

    h.assert_eq[USize](init_pane_count, 6)
    h.assert_eq[U64](pane_size, Seconds(2))
    h.assert_eq[USize](panes_per_slide, 1)

    event_ts = Milliseconds(100_000)
    end_ts = Seconds(100)-1
    var v = _ExpandSlidingWindow.new_pane_count(event_ts, end_ts,
      init_pane_count, pane_size, panes_per_slide)
    h.assert_eq[USize](v - init_pane_count, 1)

    event_ts = Milliseconds(101_999)
    end_ts = Seconds(100)-1
    v = _ExpandSlidingWindow.new_pane_count(event_ts, end_ts,
      init_pane_count, pane_size, panes_per_slide)
    h.assert_eq[USize](v - init_pane_count, 1)

    event_ts = Milliseconds(102_000)
    end_ts = Seconds(100)-1
    v = _ExpandSlidingWindow.new_pane_count(event_ts, end_ts,
      init_pane_count, pane_size, panes_per_slide)
    h.assert_eq[USize](v - init_pane_count, 2)

    event_ts = Milliseconds(103_000)
    end_ts = Seconds(100)-1
    v = _ExpandSlidingWindow.new_pane_count(event_ts, end_ts,
      init_pane_count, pane_size, panes_per_slide)
    h.assert_eq[USize](v - init_pane_count, 2)

    event_ts = Milliseconds(108_999)
    end_ts = Seconds(100)-1
    v = _ExpandSlidingWindow.new_pane_count(event_ts, end_ts,
      init_pane_count, pane_size, panes_per_slide)
    h.assert_eq[USize](v - init_pane_count, 5)

    event_ts = Milliseconds(115_000)
    end_ts = Seconds(100)-1
    v = _ExpandSlidingWindow.new_pane_count(event_ts, end_ts,
      init_pane_count, pane_size, panes_per_slide)
    h.assert_eq[USize](v - init_pane_count, 8)

    event_ts = Milliseconds(199_999)
    end_ts = Seconds(100)-1
    v = _ExpandSlidingWindow.new_pane_count(event_ts, end_ts,
      init_pane_count, pane_size, panes_per_slide)
    h.assert_eq[USize](v - init_pane_count, 50)

    event_ts = Milliseconds(1_010_000)
    end_ts = Seconds(100)-1
    v = _ExpandSlidingWindow.new_pane_count(event_ts, end_ts,
      init_pane_count, pane_size, panes_per_slide)
    h.assert_eq[USize](v - init_pane_count, 456)

class iso _TestExpandSlidingWindowPrimitive is UnitTest
  fun name(): String => "windows/_TestExpandSlidingWindowPrimitive"
  fun apply(h: TestHelper) =>
    var v = _ExpandSlidingWindow.new_pane_count(where
      event_ts=2, end_ts=1, cur_pane_count=1, pane_size=1, panes_per_slide=1)
    h.assert_eq[USize](2, v)

    v = _ExpandSlidingWindow.new_pane_count(where
      event_ts=3, end_ts=1, cur_pane_count=2, pane_size=1, panes_per_slide=2)
    h.assert_eq[USize](4, v)
