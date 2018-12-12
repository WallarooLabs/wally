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


class iso _TestStageWatermarks is UnitTest
  fun name(): String => "bytes/_TestStageWatermarks"

  fun apply(h: TestHelper) =>
    // Upstream Ids
    let u1: RoutingId = 1
    let u2: RoutingId = 2
    let u3: RoutingId = 3
    // Upstream Watermarks
    var u1w = Seconds(10)
    var u2w = Seconds(15)
    var u3w = Seconds(5)
    // Test timestamps
    var wts = Seconds(0)
    var chts = Seconds(0)
    var ots = Seconds(0)

    var expected_input_watermark = Seconds(0)
    var expected_output_watermark = Seconds(0)

    let last_heard_threshold = Seconds(100)
    var current_ts = Seconds(200)
    let w = StageWatermarks(last_heard_threshold)

    // No upstream data yet, so effective watermark is max
    chts = w.check_effective_input_watermark(current_ts)
    h.assert_eq[U64](chts, U64.max_value())

    current_ts = Seconds(210)
    wts = w.receive_watermark(u1, u1w, current_ts)
    expected_input_watermark = u1w
    h.assert_eq[U64](wts, expected_input_watermark)
    chts = w.check_effective_input_watermark(current_ts)
    h.assert_eq[U64](wts, chts)

    // u3 is behind, but the watermark can't move backwards. The effective
    // minimum remains the same in this case.
    current_ts = Seconds(220)
    wts = w.receive_watermark(u3, u3w, current_ts)
    h.assert_eq[U64](wts, expected_input_watermark)
    chts = w.check_effective_input_watermark(current_ts)
    h.assert_eq[U64](wts, chts)

    // u2 is ahead, but we can't advance past the current effective minimum
    current_ts = Seconds(230)
    wts = w.receive_watermark(u2, u2w, current_ts)
    h.assert_eq[U64](wts, expected_input_watermark)
    chts = w.check_effective_input_watermark(current_ts)
    h.assert_eq[U64](wts, chts)


    // Some work is done and we advance output watermark
    (ots, _) = w.update_output_watermark(expected_input_watermark)
    expected_output_watermark = expected_input_watermark
    h.assert_eq[U64](ots, expected_output_watermark)


    // u3 advances, but u1 is still holding us back.
    current_ts = Seconds(235)
    u3w = Seconds(16)
    wts = w.receive_watermark(u3, u3w, current_ts)
    h.assert_eq[U64](wts, expected_input_watermark)
    chts = w.check_effective_input_watermark(current_ts)
    h.assert_eq[U64](wts, chts)

    // u1 advances beyond u2, but so u2 becomes effective minimum.
    current_ts = Seconds(240)
    u1w = Seconds(20)
    wts = w.receive_watermark(u1, u1w, current_ts)
    expected_input_watermark = u2w
    h.assert_eq[U64](wts, expected_input_watermark)
    chts = w.check_effective_input_watermark(current_ts)
    h.assert_eq[U64](wts, chts)


    // Some work is done and we advance output watermark
    (ots, _) = w.update_output_watermark(expected_input_watermark)
    expected_output_watermark = expected_input_watermark
    h.assert_eq[U64](ots, expected_output_watermark)


    // Haven't heard from u2 past the threshold, so we advance to u3.
    current_ts = Seconds(331)
    chts = w.check_effective_input_watermark(current_ts)
    expected_input_watermark = u3w
    h.assert_eq[U64](chts, expected_input_watermark)

    // Haven't heard from u3 past the threshold. u1w is now effective min.
    current_ts = Seconds(336)
    u2w = Seconds(25)
    wts = w.receive_watermark(u2, u2w, current_ts)
    expected_input_watermark = u1w
    h.assert_eq[U64](wts, expected_input_watermark)
    chts = w.check_effective_input_watermark(current_ts)
    h.assert_eq[U64](wts, chts)


    // The output watermark can never go backwards.
    (ots, _) = w.update_output_watermark(Seconds(1))
    h.assert_eq[U64](ots, expected_output_watermark)


    // u3 advances, and is the new effective minimum.
    current_ts = Seconds(340)
    u3w = Seconds(21)
    wts = w.receive_watermark(u3, u3w, current_ts)
    expected_input_watermark = u3w
    h.assert_eq[U64](wts, expected_input_watermark)
    chts = w.check_effective_input_watermark(current_ts)
    h.assert_eq[U64](wts, chts)

    // Some work is done and we advance output watermark
    (ots, _) = w.update_output_watermark(expected_input_watermark)
    expected_output_watermark = expected_input_watermark
    h.assert_eq[U64](ots, expected_output_watermark)


    // As long as no last_heard_threshold is passed, repeatedly checking
    // shouldn't change input watermark.
    current_ts = Seconds(341)
    w.check_effective_input_watermark(current_ts)
    current_ts = Seconds(342)
    w.check_effective_input_watermark(current_ts)
    w.check_effective_input_watermark(current_ts)
    current_ts = Seconds(343)
    chts = w.check_effective_input_watermark(current_ts)
    h.assert_eq[U64](chts, expected_input_watermark)


    true
