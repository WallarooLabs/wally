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


use "buffered"
use "collections"
use "random"
use "time"
use "serialise"
use "wallaroo/core/aggregations"
use "wallaroo/core/common"
use "wallaroo/core/invariant"
use "wallaroo/core/state"
use "wallaroo/core/topology"
use "wallaroo_labs/math"
use "wallaroo_labs/mort"


class _SlidingWindowsWrapperBuilder[In: Any val, Out: Any val, Acc: State ref]
  is WindowsWrapperBuilder[In, Out, Acc]
  let _key: Key
  let _agg: Aggregation[In, Out, Acc]
  let _range: U64
  let _slide: U64
  let _delay: U64
  let _rand: Random
  let _late_data_policy: U16

  new create(key: Key, agg: Aggregation[In, Out, Acc], range: U64, slide: U64,
    delay: U64, rand: Random, late_data_policy: U16)
  =>
    _key = key
    _agg = agg
    _range = range
    _slide = slide
    _delay = delay
    _rand = rand
    _late_data_policy = late_data_policy

  fun ref apply(first_event_ts: U64, watermark_ts: U64):
    _PanesSlidingWindows[In, Out, Acc]
  =>
    _PanesSlidingWindows[In, Out, Acc](_key, _agg, _range, _slide, _delay,
      _late_data_policy, watermark_ts, _rand)

class _PanesSlidingWindows[In: Any val, Out: Any val, Acc: State ref] is
  WindowsWrapper[In, Out, Acc]
  """
  A panes-based sliding windows implementation that always recalculates
  the combination of all lowest level partial aggregations stored in panes.
  """
  var _panes: Array[(Acc | EmptyPane)]
  var _panes_start_ts: Array[U64]
  // How many panes make up a complete window
  let _panes_per_window: USize
  // How large is a single pane in nanoseconds
  let _pane_size: U64
  // How many panes make up the slide between windows
  let _panes_per_slide: USize
  var _earliest_window_idx: USize

  let _key: Key
  let _agg: Aggregation[In, Out, Acc]
  let _identity_acc: Acc
  let _range: U64
  let _slide: U64
  let _delay: U64
  var _highest_seen_event_ts: U64
  let _late_data_policy: U16

  new create(key: Key, agg: Aggregation[In, Out, Acc], range: U64, slide: U64,
    delay: U64, late_data_policy: U16, watermark_ts: U64, rand: Random)
  =>
    _key = key
    _agg = agg
    _range = range
    _slide = slide
    _identity_acc = _agg.initial_accumulator()
    _highest_seen_event_ts = watermark_ts
    _late_data_policy = late_data_policy

    // To avoid the thundering herd problems that can come with perfectly
    // aligned windows, we randomly offset every window with an offset up to
    // 80% of the range.
    let window_alignment_offset = ((rand.real() * 0.8) * _range.f64()).u64()

    (let pane_count, _pane_size, _panes_per_slide, _panes_per_window,
      _delay) = _InitializePaneParameters(range, slide, delay)
    _panes = Array[(Acc | EmptyPane)](pane_count)
    _panes_start_ts = Array[U64](pane_count)
    _earliest_window_idx = 0

    var pane_start: U64 = (watermark_ts - _delay) - window_alignment_offset
    // Make sure we don't underflow, creating a pane start way off in the future
    if pane_start > watermark_ts then pane_start = 0 end
    for i in Range(0, pane_count) do
      _panes.push(EmptyPane)
      _panes_start_ts.push(pane_start)
      pane_start = pane_start + _pane_size
    end

  fun ref apply(input: In, event_ts: U64, watermark_ts: U64):
    WindowOutputs[Out]
  =>
    _highest_seen_event_ts = _highest_seen_event_ts.max(event_ts)
    try
      var is_late_data = false
      (let earliest_ts, let end_ts) = _earliest_and_end_ts()?
      var applied = false
      if not _is_past_end_ts(event_ts, end_ts) then
        is_late_data = _apply_input(input, event_ts, earliest_ts)
        applied = true
      end

      // Check if we need to trigger and clear windows
      (var outs, var output_watermark_ts, var retain_state) =
        attempt_to_trigger(watermark_ts)

      // If we haven't already applied the input, do it now.
      if not applied then
        (var new_earliest_ts, let new_end_ts) = _earliest_and_end_ts()?
        if _is_past_end_ts(event_ts, new_end_ts) then
          // !TODO!: Think about constraining the extent to which we expand
          // windows to prevent memory exhaustion.
          _expand_windows(event_ts, new_end_ts)?
          new_earliest_ts = _earliest_ts()?
        end
        is_late_data = _apply_input(input, event_ts, new_earliest_ts)
      end

      if is_late_data then
        match _late_data_policy
        | LateDataPolicy.drop() =>
          ifdef debug then
            @printf[I32]("Event ts %s is earlier than earliest window %s. Ignoring\n".cstring(), event_ts.string().cstring(), earliest_ts.string().cstring())
          end
        | LateDataPolicy.fire_per_message() =>
          let acc = _agg.initial_accumulator()
          _agg.update(input, acc)
          // We are currently using the event timestamp of the late message
          // as the window end timestamp.
          match _agg.output(_key, event_ts, acc)
          | let o: Out =>
            // We are currently using the event timestamp of the late message
            // as the window end timestamp.
            outs.push((o, event_ts))
          end
          output_watermark_ts = output_watermark_ts.max(event_ts)
        | LateDataPolicy.place_in_oldest_window() =>
          let new_earliest_ts = _earliest_ts()?
          _apply_input(input, new_earliest_ts, new_earliest_ts)
        end
      end
      (consume outs, output_watermark_ts, retain_state)
    else
      Fail()
      (recover Array[(Out, U64)] end, 0, true)
    end

  // TODO: Update signature -> `true` is not very clear as the return value.
  // Return true if the input is late, which means we need to handle it
  // according to the late data policy.
  fun ref _apply_input(input: In, event_ts: U64, earliest_ts: U64): Bool =>
    ifdef debug then
      try
        Invariant(not _is_past_end_ts(event_ts, _earliest_and_end_ts()?._2))
      end
    end
    if event_ts >= earliest_ts then
      let pane_idx = _pane_idx_for_event_ts(event_ts, earliest_ts)
      try
        ifdef debug then
          Invariant(event_ts >= _panes_start_ts(pane_idx)?)
        end
        match _panes(pane_idx)?
        | let acc: Acc =>
          _agg.update(input, acc)
        else
          let new_acc = _agg.initial_accumulator()
          _agg.update(input, new_acc)
          _panes(pane_idx)? = new_acc
        end
      else
        Fail()
      end
      false
    else
      true
    end

  fun ref attempt_to_trigger(input_watermark_ts: U64):
    (Array[(Out, U64)] iso^, U64, Bool)
  =>
    let outs = recover iso Array[(Out, U64)] end
    var output_watermark_ts: U64 = 0
    let trigger_offset = _range + _delay

    let effective_watermark_ts =
      if input_watermark_ts == TimeoutWatermark() then
        // Set it at a point at which we know it will trigger
        // all windows that could contain messages.
        _highest_seen_event_ts + trigger_offset
      else
        input_watermark_ts
      end
    try
      (let earliest_ts, let end_ts) = _earliest_and_end_ts()?
      let last_pane_idx =
        (_earliest_window_idx + (_panes_start_ts.size() - 1)) %
          _panes_start_ts.size()
      let last_pane_start_ts = _panes_start_ts(last_pane_idx)?

      var lowest_possible_new_start_ts = effective_watermark_ts - trigger_offset
      if lowest_possible_new_start_ts > effective_watermark_ts then
        lowest_possible_new_start_ts = 0
      end

      let trigger_diff =
        if lowest_possible_new_start_ts > last_pane_start_ts then
          lowest_possible_new_start_ts - last_pane_start_ts
        else
          0
        end

      var stopped = false
      while not stopped do
        (let next_out, let out_event_ts, stopped) =
          _check_first_window(effective_watermark_ts, trigger_diff)
        output_watermark_ts = output_watermark_ts.max(out_event_ts)
        match next_out
        | let out: Out =>
          outs.push((out, out_event_ts))
        end
      end
      ifdef debug then
        Invariant(_panes_are_contiguous())
      end
    else
      Fail()
    end
    (consume outs, output_watermark_ts, true)

  fun ref _check_first_window(watermark_ts: U64, trigger_diff: U64):
    ((Out | None), U64, Bool)
  =>
    try
      let earliest_ts = _earliest_ts()?
      let window_end_ts = earliest_ts + (_range - 1)
      if _should_trigger(earliest_ts, watermark_ts) then
        (let out, let output_watermark_ts) = _trigger_next(earliest_ts,
          window_end_ts, trigger_diff)?
        (out, output_watermark_ts, false)
      else
        (None, 0, true)
      end
    else
      Fail()
      (None, 0, true)
    end

  fun ref _trigger_next(earliest_ts: U64, window_end_ts: U64,
    trigger_diff: U64): ((Out | None), U64) ?
  =>
    var running_acc = _identity_acc
    var pane_idx = _earliest_window_idx
    for i in Range(0, _panes_per_window) do
      // If we find an EmptyPane, then we ignore it.
      match _panes(pane_idx)?
      | let next_acc: Acc =>
        running_acc = _agg.combine(running_acc, next_acc)
      end
      pane_idx = (pane_idx + 1) % _panes.size()
    end
    let out = _agg.output(_key, window_end_ts, running_acc)
    var next_start_ts = earliest_ts + (_all_pane_range() + trigger_diff)
    var next_pane_idx = _earliest_window_idx
    for _ in Range(0, _panes_per_slide) do
      _panes(next_pane_idx)? = EmptyPane
      _panes_start_ts(next_pane_idx)? = next_start_ts
      next_pane_idx = (next_pane_idx + 1) % _panes.size()
      next_start_ts = next_start_ts + _pane_size
    end
    _earliest_window_idx = next_pane_idx
    (out, window_end_ts)

  fun ref _expand_windows(event_ts: U64, end_ts: U64) ? =>
    let new_pane_count = _ExpandSlidingWindow.new_pane_count(event_ts,
      end_ts, _panes.size(), _pane_size, _panes_per_slide)
    let expanded_panes: Array[(Acc | EmptyPane)] =
      Array[(Acc | EmptyPane)](new_pane_count)
    let old_panes = (_panes = expanded_panes)
    let expanded_panes_start_ts: Array[U64] = Array[U64](new_pane_count)
    let old_panes_start_ts = (_panes_start_ts = expanded_panes_start_ts)

    // Use working_idx so we add panes to expanded_panes from earliest to
    // latest.
    var working_idx = _earliest_window_idx
    var pane_start: U64 = old_panes_start_ts(_earliest_window_idx)?
    let old_panes_size = old_panes.size()
    for i in Range(0, old_panes_size) do
      _panes.push(old_panes(working_idx)?)
      pane_start = old_panes_start_ts(working_idx)?
      _panes_start_ts.push(pane_start)
      working_idx = (working_idx + 1) % old_panes_size
    end

    // Add the new panes
    pane_start = pane_start + _pane_size
    for i in Range(old_panes_size, new_pane_count) do
      _panes.push(EmptyPane)
      _panes_start_ts.push(pane_start)
      pane_start = pane_start + _pane_size
    end
    _earliest_window_idx = 0

  fun _earliest_ts(): U64 ? =>
    _panes_start_ts(_earliest_window_idx)?

  fun _earliest_and_end_ts(): (U64, U64) ? =>
    let earliest_ts = _earliest_ts()?
    let end_ts = (earliest_ts + _all_pane_range()) - 1
    (earliest_ts, end_ts)

  fun _all_pane_range(): U64 =>
    _panes.size().u64() * _pane_size

  fun _is_past_end_ts(event_ts: U64, end_ts: U64) : Bool =>
    event_ts > end_ts

  fun _pane_idx_for_event_ts(event_ts: U64, earliest_ts: U64): USize =>
    let pane_idx_offset = ((event_ts - earliest_ts) / _pane_size).usize()
    (_earliest_window_idx + pane_idx_offset) % _panes.size()

  fun _should_trigger(window_start_ts: U64, watermark_ts: U64): Bool =>
    let end_bound = (watermark_ts - _delay)
    if end_bound > watermark_ts then
      false // Underflow! It's too early to trigger.
    else
      (window_start_ts + (_range - 1)) < end_bound
    end

  fun _panes_are_contiguous(): Bool =>
    try
      var panes_are_contiguous = true
      var idx = _earliest_window_idx
      var last_start_ts = _panes_start_ts(idx)?
      for _ in Range(1, _panes_start_ts.size()) do
        idx = (idx + 1) % _panes_start_ts.size()
        let next_start_ts = _panes_start_ts(idx)?
        if (next_start_ts - last_start_ts) != _pane_size then
          panes_are_contiguous = false
        end
        last_start_ts = next_start_ts
      end
      panes_are_contiguous
    else
      Fail()
      false
    end

  fun check_panes_increasing(): Bool =>
    try
      var last_ts = _earliest_ts()?
      for offset in Range(1, _panes.size()) do
        let next_idx = (_earliest_window_idx + offset) % _panes.size()
        let next_ts = _panes_start_ts(next_idx)?
        if next_ts < last_ts then
          return false
        end
        last_ts = next_ts
      end
    else
      return false
    end
    true

primitive _InitializePaneParameters
  fun apply(range: U64, slide: U64, delay: U64):
    (USize, U64, USize, USize, U64)
  =>
    let pane_size = Math.gcd(range.usize(), slide.usize()).u64()
    let panes_per_slide = (slide / pane_size).usize()
    let panes_per_window = (range / pane_size).usize()
    // Normalize delay to units of slide.
    let delay_slide_units = (delay.f64() / slide.f64()).ceil()
    let normalized_delay = slide * delay_slide_units.u64()
    // Calculate how many panes we need. The delay tells us how long we
    // wait after the close of a window to trigger and clear it. We need
    // enough extra panes to account for this delay.
    let extra_panes = delay_slide_units.usize() * panes_per_slide
    let pane_count = panes_per_window + extra_panes

    (pane_count, pane_size, panes_per_slide, panes_per_window,
      normalized_delay)

primitive _ExpandSlidingWindow
  fun new_pane_count(event_ts: U64, end_ts: U64, cur_pane_count: USize,
    pane_size: U64, panes_per_slide: USize): USize
  =>
    let min_new_panes =
      ((event_ts - (end_ts+1)).f64() / pane_size.f64()).usize() + 1
    let new_count = Math.lcm(min_new_panes, panes_per_slide)
    let result = new_count + cur_pane_count
    ifdef debug then
      Invariant(event_ts > end_ts)
      Invariant((cur_pane_count % panes_per_slide) == 0)
      Invariant((result % panes_per_slide) == 0)
    end
    result
