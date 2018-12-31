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


class iso _TestExpandSlidingWindow is UnitTest
  fun name(): String => "windows/_TestExpandSlidingWindow"

  fun apply(h: TestHelper) =>
    var range: U64 = Seconds(10)
    var slide: U64 = Seconds(2)
    var delay: U64 = Seconds(1)

    var event_ts: U64 = Seconds(0)
    var end_ts: U64 = Seconds(0)

    (let init_pane_count, let pane_size, let panes_per_slide) =
      _initialize_from(range, slide, delay)

    h.assert_eq[USize](init_pane_count, 6)
    h.assert_eq[U64](pane_size, Seconds(2))
    h.assert_eq[USize](panes_per_slide, 1)

    event_ts = Milliseconds(100_000)
    end_ts = Seconds(100)
    var v = _ExpandSlidingWindow.new_pane_count(event_ts, end_ts,
      init_pane_count, pane_size, panes_per_slide)
    h.assert_eq[USize](v - init_pane_count, 1)

    event_ts = Milliseconds(101_999)
    end_ts = Seconds(100)
    v = _ExpandSlidingWindow.new_pane_count(event_ts, end_ts,
      init_pane_count, pane_size, panes_per_slide)
    h.assert_eq[USize](v - init_pane_count, 1)

    event_ts = Milliseconds(102_000)
    end_ts = Seconds(100)
    v = _ExpandSlidingWindow.new_pane_count(event_ts, end_ts,
      init_pane_count, pane_size, panes_per_slide)
    h.assert_eq[USize](v - init_pane_count, 2)

    event_ts = Milliseconds(103_000)
    end_ts = Seconds(100)
    v = _ExpandSlidingWindow.new_pane_count(event_ts, end_ts,
      init_pane_count, pane_size, panes_per_slide)
    h.assert_eq[USize](v - init_pane_count, 2)

    event_ts = Milliseconds(108_999)
    end_ts = Seconds(100)
    v = _ExpandSlidingWindow.new_pane_count(event_ts, end_ts,
      init_pane_count, pane_size, panes_per_slide)
    h.assert_eq[USize](v - init_pane_count, 5)

    event_ts = Milliseconds(115_000)
    end_ts = Seconds(100)
    v = _ExpandSlidingWindow.new_pane_count(event_ts, end_ts,
      init_pane_count, pane_size, panes_per_slide)
    h.assert_eq[USize](v - init_pane_count, 8)

    event_ts = Milliseconds(199_999)
    end_ts = Seconds(100)
    v = _ExpandSlidingWindow.new_pane_count(event_ts, end_ts,
      init_pane_count, pane_size, panes_per_slide)
    h.assert_eq[USize](v - init_pane_count, 50)

    event_ts = Milliseconds(1_010_000)
    end_ts = Seconds(100)
    v = _ExpandSlidingWindow.new_pane_count(event_ts, end_ts,
      init_pane_count, pane_size, panes_per_slide)
    h.assert_eq[USize](v - init_pane_count, 456)

    true

  fun _initialize_from(range: U64, slide: U64, delay: U64):
    (USize, U64, USize)
  =>
    // !@ This code is duplicated from SlidingWindow and needs to be
    // broken out and tested
    // Return (pane_count, pane_size, panes_per_slide, end_ts)
    let pane_size = Math.gcd(range.usize(), slide.usize()).u64()
    let panes_per_slide = (slide / pane_size).usize()
    let panes_per_window = (range / pane_size).usize()
    // Normalize delay to units of slide.
    let delay_slide_units = (delay.f64() / slide.f64()).ceil()
    // Calculate how many panes we need. The delay tells us how long we
    // wait after the close of a window to trigger and clear it. We need
    // enough extra panes to account for this delay.
    let extra_panes = delay_slide_units.usize() * panes_per_slide
    let pane_count = panes_per_window + extra_panes

    (pane_count, pane_size, panes_per_slide)
