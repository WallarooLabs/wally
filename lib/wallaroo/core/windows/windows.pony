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
use "time"
use "serialise"
use "wallaroo/core/aggregations"
use "wallaroo/core/common"
use "wallaroo/core/state"
use "wallaroo/core/topology"
use "wallaroo_labs/math"
use "wallaroo_labs/mort"

primitive EmptyWindow
primitive EmptyPane

class RangeWindowsBuilder
  var _range: U64
  var _slide: U64
  var _delay: U64

  new create(range: U64) =>
    _range = range
    _slide = range
    _delay = 0

  fun ref with_slide(slide: U64): RangeWindowsBuilder =>
    //!@ Check that slide divides evenly into range
    _slide = slide
    this

  fun ref with_delay(delay: U64): RangeWindowsBuilder =>
    _delay = delay
    this

  fun ref over[In: Any val, Out: Any val, S: State ref](
    agg: Aggregation[In, Out, S]): StateInitializer[In, Out, S]
  =>
    if _slide > _range then
      FatalUserError("A window's slide cannot be greater than its range. " +
        "But found slide " + _slide.string() + " for range " + _range.string())
    end

    RangeWindowsStateInitializer[In, Out, S](agg, _range, _slide, _delay)

class CountWindowsBuilder
  var _count: USize

  new create(count: USize) =>
    _count = count

  fun ref over[In: Any val, Out: Any val, S: State ref](
    agg: Aggregation[In, Out, S]): StateInitializer[In, Out, S]
  =>
    TumblingCountWindowsStateInitializer[In, Out, S](agg, _count)

trait Windows[In: Any val, Out: Any val, Acc: State ref] is
  StateWrapper[In, Out, Acc]
  fun ref apply(input: In, event_ts: U64, watermark_ts: U64):
    ((Out | Array[Out] val | None), U64)

  fun ref on_timeout(wall_time: U64): ((Out | Array[Out] val | None), U64)

  /////////
  // _initial_* methods for windows that behave differently the first time
  // they encounter a watermark
  /////////
  fun ref _initial_apply(input: In, event_ts: U64, watermark_ts: U64,
    windows_wrapper: WindowsWrapper[In, Out, Acc]):
    ((Out | Array[Out] val | None), U64)
  =>
    (None, 0)

  fun ref _initial_attempt_to_trigger(watermark_ts: U64,
    windows_wrapper: WindowsWrapper[In, Out, Acc]):
    ((Out | Array[Out] val | None), U64)
  =>
    (None, 0)

trait WindowsWrapperBuilder[In: Any val, Out: Any val, Acc: State ref]
  fun apply(watermark_ts: U64): WindowsWrapper[In, Out, Acc]

trait WindowsWrapper[In: Any val, Out: Any val, Acc: State ref]
  fun ref apply(input: In, event_ts: U64, watermark_ts: U64):
    (Array[Out] val, U64)

  fun ref attempt_to_trigger(watermark_ts: U64): (Array[Out] val, U64)

///////////////////////////
// GLOBAL WINDOWS
///////////////////////////
class val GlobalWindowStateInitializer[In: Any val, Out: Any val,
  Acc: State ref] is StateInitializer[In, Out, Acc]
  let _agg: Aggregation[In, Out, Acc]

  new val create(agg: Aggregation[In, Out, Acc]) =>
    _agg = agg

  fun state_wrapper(key: Key): StateWrapper[In, Out, Acc] =>
    GlobalWindow[In, Out, Acc](key, _agg)

  fun val runner_builder(step_group_id: RoutingId, parallelization: USize):
    RunnerBuilder
  =>
    StateRunnerBuilder[In, Out, Acc](this, step_group_id, parallelization)

  fun timeout_interval(): U64 =>
    // Triggers on every message, so we don't need timeouts.
    0

  fun val decode(in_reader: Reader, auth: AmbientAuth):
    StateWrapper[In, Out, Acc] ?
  =>
    try
      let data: Array[U8] iso = in_reader.block(in_reader.size())?
      match Serialised.input(InputSerialisedAuth(auth), consume data)(
        DeserialiseAuth(auth))?
      | let gw: GlobalWindow[In, Out, Acc] => gw
      else
        error
      end
    else
      error
    end

  fun name(): String =>
    _agg.name()

class GlobalWindow[In: Any val, Out: Any val, Acc: State ref] is
  Windows[In, Out, Acc]
  let _key: Key
  let _agg: Aggregation[In, Out, Acc]
  let _acc: Acc

  new create(key: Key, agg: Aggregation[In, Out, Acc]) =>
    _key = key
    _agg = agg
    _acc = agg.initial_accumulator()

  fun ref apply(input: In, event_ts: U64, watermark_ts: U64):
    ((Out | Array[Out] val | None), U64)
  =>
    _agg.update(input, _acc)
    // We trigger a result per message
    let res = _agg.output(_key, _acc)
    (res, watermark_ts)

  fun ref on_timeout(watermark_ts: U64): (Array[Out] val, U64) =>
    // We trigger per message, so we do nothing on the timer
    (recover val Array[Out] end, watermark_ts)

  fun ref encode(auth: AmbientAuth): ByteSeq =>
    try
      Serialised(SerialiseAuth(auth), this)?.output(OutputSerialisedAuth(
        auth))
    else
      Fail()
      recover Array[U8] end
    end

///////////////////////////
// RANGE WINDOWS
///////////////////////////
class val RangeWindowsStateInitializer[In: Any val, Out: Any val,
  Acc: State ref] is StateInitializer[In, Out, Acc]
  let _agg: Aggregation[In, Out, Acc]
  let _range: U64
  let _slide: U64
  let _delay: U64

  new val create(agg: Aggregation[In, Out, Acc], range: U64, slide: U64,
    delay: U64)
  =>
    if range == 0 then
      FatalUserError("Range windows must have a range greater than 0!\n")
    end
    if slide == 0 then
      FatalUserError("Range windows must have a slide greater than 0!\n")
    end
    _agg = agg
    _range = range
    _slide = slide
    _delay = delay

  fun state_wrapper(key: Key): StateWrapper[In, Out, Acc] =>
    RangeWindows[In, Out, Acc](key, _agg, _range, _slide, _delay)

  fun val runner_builder(step_group_id: RoutingId, parallelization: USize):
    RunnerBuilder
  =>
    StateRunnerBuilder[In, Out, Acc](this, step_group_id, parallelization)

  fun timeout_interval(): U64 =>
    (_range + _delay) * 2

  fun val decode(in_reader: Reader, auth: AmbientAuth):
    StateWrapper[In, Out, Acc] ?
  =>
    try
      let data: Array[U8] iso = in_reader.block(in_reader.size())?
      match Serialised.input(InputSerialisedAuth(auth), consume data)(
        DeserialiseAuth(auth))?
      | let sw: RangeWindows[In, Out, Acc] => sw
      else
        error
      end
    else
      error
    end

  fun name(): String =>
    _agg.name()

class RangeWindows[In: Any val, Out: Any val, Acc: State ref] is
  Windows[In, Out, Acc]
  var _phase: WindowsPhase[In, Out, Acc] = EmptyWindowsPhase[In, Out, Acc]

  new create(key: Key, agg: Aggregation[In, Out, Acc], range: U64, slide: U64,
    delay: U64)
  =>
    let wrapper_builder = _SlidingWindowsWrapperBuilder[In, Out, Acc](key, agg,
      range, slide, delay)
    _phase = InitialWindowsPhase[In, Out, Acc](this, wrapper_builder)

  fun ref apply(input: In, event_ts: U64, watermark_ts: U64):
    ((Out | Array[Out] val | None), U64)
  =>
    _phase(input, event_ts, watermark_ts)

  fun ref _initial_apply(input: In, event_ts: U64, watermark_ts: U64,
    windows_wrapper: WindowsWrapper[In, Out, Acc]):
    ((Out | Array[Out] val | None), U64)
  =>
    _phase = ProcessingWindowsPhase[In, Out, Acc](windows_wrapper)
    _phase(input, event_ts, watermark_ts)

  fun ref on_timeout(watermark_ts: U64):
    ((Out | Array[Out] val| None), U64)
  =>
    _attempt_to_trigger(watermark_ts)

  fun ref encode(auth: AmbientAuth): ByteSeq =>
    try
      Serialised(SerialiseAuth(auth), this)?.output(OutputSerialisedAuth(
        auth))
    else
      Fail()
      recover Array[U8] end
    end

  fun ref _attempt_to_trigger(watermark_ts: U64):
    ((Out | Array[Out] val | None), U64)
  =>
    _phase.attempt_to_trigger(watermark_ts)

  fun ref _initial_attempt_to_trigger(watermark_ts: U64,
    windows_wrapper: WindowsWrapper[In, Out, Acc]):
    ((Out | Array[Out] val | None), U64)
  =>
    _phase = ProcessingWindowsPhase[In, Out, Acc](windows_wrapper)
    _phase.attempt_to_trigger(watermark_ts)

class _SlidingWindowsWrapperBuilder[In: Any val, Out: Any val, Acc: State ref]
  is WindowsWrapperBuilder[In, Out, Acc]
  let _key: Key
  let _agg: Aggregation[In, Out, Acc]
  let _range: U64
  let _slide: U64
  let _delay: U64

  new create(key: Key, agg: Aggregation[In, Out, Acc], range: U64, slide: U64,
    delay: U64)
  =>
    _key = key
    _agg = agg
    _range = range
    _slide = slide
    _delay = delay

  fun apply(watermark_ts: U64): _SlidingWindows[In, Out, Acc] =>
    _SlidingWindows[In, Out, Acc](_key, _agg, _range, _slide, _delay,
      watermark_ts)

class _SlidingWindows[In: Any val, Out: Any val, Acc: State ref] is
  WindowsWrapper[In, Out, Acc]
  """
  An inefficient sliding windows implementation that always recalculates
  the combination of all lowest level partial aggregations stored in panes.
  """
  let _panes: Array[(Acc | EmptyPane)]
  let _panes_start_ts: Array[U64]
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

  new create(key: Key, agg: Aggregation[In, Out, Acc], range: U64, slide: U64,
    delay: U64, watermark_ts: U64)
  =>
    // Invariant that range divides evenly by slide

    _key = key
    _agg = agg
    _range = range
    _slide = slide
    _pane_size = Math.gcd(_range.usize(), _slide.usize()).u64()
    _panes_per_slide = (_slide / _pane_size).usize()
    _panes_per_window = (_range / _pane_size).usize()
    _identity_acc = _agg.initial_accumulator()
    // Normalize delay to units of slide.
    let delay_slide_units = (delay.f64() / _slide.f64()).ceil()
    _delay = _slide * delay_slide_units.u64()
    // @printf[I32]("!@ DELAY:%s\n".cstring(), _delay.string().cstring())

    // Calculate how many panes we need. The delay tells us how long we
    // wait after the close of a window to trigger and clear it. We need
    // enough extra panes to account for this delay.
    let extra_panes = delay_slide_units.usize() * _panes_per_slide
    let pane_count = _panes_per_window + extra_panes

    let total_length = pane_count.u64() * _pane_size
    let last_window_start = total_length - range
    let window_count = (last_window_start / _slide).usize() + 1

    _panes = Array[(Acc | EmptyPane)](pane_count)
    _panes_start_ts = Array[U64](pane_count)
    _earliest_window_idx = 0
    var pane_start: U64 = (watermark_ts - (_delay + _range))
    for i in Range(0, pane_count) do
      _panes.push(EmptyPane)
      _panes_start_ts.push(pane_start)
      pane_start = pane_start + _pane_size
    end

  fun ref apply(input: In, event_ts: U64, watermark_ts: U64):
    (Array[Out] val, U64)
  =>
    try
      let earliest_ts = _panes_start_ts(_earliest_window_idx)?
      let end_ts = earliest_ts + (_panes.size().u64() * _pane_size)
      var applied = false
      if (event_ts >= earliest_ts) and (event_ts < end_ts) then
        _apply_input(input, event_ts, earliest_ts)
        applied = true
      end

      // Check if we need to trigger and clear windows
      (let outs, let output_watermark_ts) = attempt_to_trigger(watermark_ts)

      // If we haven't already applied the input, do it now.
      if not applied and _is_valid_ts(event_ts, watermark_ts) then
        let new_earliest_ts = _panes_start_ts(_earliest_window_idx)?
        _apply_input(input, event_ts, new_earliest_ts)
      end

      (outs, output_watermark_ts)
    else
      Fail()
      (recover Array[Out] end, 0)
    end

  fun ref _apply_input(input: In, event_ts: U64, earliest_ts: U64) =>
    // Should we ensure the event_ts is in the correct range?

    if event_ts >= earliest_ts then
      let pane_idx_offset = ((event_ts - earliest_ts) / _pane_size).usize()
      let pane_idx =
        (_earliest_window_idx + pane_idx_offset) % _panes.size()
      try
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
    else
      // !TODO!: Should we keep this debug message? Too-early messages can be
      // expected.
      ifdef debug then
        @printf[I32]("Event ts %s is earlier than earliest window %s. Ignoring\n".cstring(), event_ts.string().cstring(), earliest_ts.string().cstring())
      end
    end

  fun ref attempt_to_trigger(watermark_ts: U64): (Array[Out] val, U64) =>
    let outs = recover iso Array[Out] end
    var output_watermark_ts: U64 = 0
    try
      let earliest_ts = _panes_start_ts(_earliest_window_idx)?
      let end_ts = earliest_ts + (_panes.size().u64() * _pane_size)

      let end_ts_diff =
        if watermark_ts > end_ts then
          watermark_ts - end_ts
        else
          0
        end

      var stopped = false
      // @printf[I32]("\n#######\n!@ attempt_to_trigger\n".cstring())
      while not stopped do
        (let next_out, let next_output_watermark_ts, stopped) =
          _check_first_window(watermark_ts, end_ts_diff)
        if next_output_watermark_ts > output_watermark_ts then
          output_watermark_ts = next_output_watermark_ts
        end
        match next_out
        | let out: Out =>
          outs.push(out)
        end
      end
    else
      Fail()
    end
    (consume outs, output_watermark_ts)

  fun ref _check_first_window(watermark_ts: U64, end_ts_diff: U64):
    ((Out | None), U64, Bool)
  =>
    var out: (Out | None) = None
    var output_watermark_ts: U64 = 0
    var stopped: Bool = true
    try
      let earliest_ts = _panes_start_ts(_earliest_window_idx)?
      let window_end_ts = earliest_ts + _range
      // @printf[I32]("!@ -- Should we trigger earliest:%s, watermark:%s, _earliest_window_idx:%s?\n".cstring(), (earliest_ts / 1_000_000_000).string().cstring(), (watermark_ts / 1_000_000_000).string().cstring(), _earliest_window_idx.string().cstring())
      if _should_trigger(earliest_ts, watermark_ts) then
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
        out = _agg.output(_key, running_acc)

        let all_pane_range = _panes.size().u64() * _pane_size
        var next_start_ts =
          if end_ts_diff > all_pane_range then
            earliest_ts + end_ts_diff
          else
            earliest_ts + all_pane_range
          end

        var next_pane_idx = _earliest_window_idx
        for _ in Range(0, _panes_per_slide) do
          _panes(next_pane_idx)? = EmptyPane
          _panes_start_ts(next_pane_idx)? = next_start_ts
          next_pane_idx = (next_pane_idx + 1) % _panes.size()
          next_start_ts = next_start_ts + _pane_size
        end
        _earliest_window_idx =
          (_earliest_window_idx + _panes_per_slide) % _panes.size()

        output_watermark_ts = window_end_ts
        stopped = false
        // @printf[I32]("!@ -- -- TRIGGERED!! window_end:%s, New _earliest_window_idx:%s\n".cstring(), (output_watermark_ts / 1_000_000_000).string().cstring(), _earliest_window_idx.string().cstring())
      // else
        // @printf[I32]("!@ -- -- NOT TRIGGERED\n".cstring())
      end
    else
      Fail()
    end
    (out, output_watermark_ts, stopped)

  fun _is_valid_ts(event_ts: U64, watermark_ts: U64): Bool =>
    event_ts > (watermark_ts - (_delay + _range))

  fun _should_trigger(window_start_ts: U64, watermark_ts: U64): Bool =>
    (window_start_ts + _range) < (watermark_ts - _delay)

////////////////////////////
// TUMBLING COUNT WINDOWS
////////////////////////////
class val TumblingCountWindowsStateInitializer[In: Any val, Out: Any val,
  Acc: State ref] is StateInitializer[In, Out, Acc]
  let _agg: Aggregation[In, Out, Acc]
  let _count: USize

  new val create(agg: Aggregation[In, Out, Acc], count: USize) =>
    _agg = agg
    _count = count

  fun state_wrapper(key: Key): StateWrapper[In, Out, Acc] =>
    TumblingCountWindows[In, Out, Acc](key, _agg, _count)

  fun val runner_builder(step_group_id: RoutingId, parallelization: USize):
    RunnerBuilder
  =>
    StateRunnerBuilder[In, Out, Acc](this, step_group_id, parallelization)

  fun timeout_interval(): U64 =>
    5_000_000_000

  fun val decode(in_reader: Reader, auth: AmbientAuth):
    StateWrapper[In, Out, Acc] ?
  =>
    try
      let data: Array[U8] iso = in_reader.block(in_reader.size())?
      match Serialised.input(InputSerialisedAuth(auth), consume data)(
        DeserialiseAuth(auth))?
      | let tw: TumblingCountWindows[In, Out, Acc] => tw
      else
        error
      end
    else
      error
    end

  fun name(): String =>
    _agg.name()

class TumblingCountWindows[In: Any val, Out: Any val, Acc: State ref] is
  Windows[In, Out, Acc]
  let _key: Key
  let _agg: Aggregation[In, Out, Acc]
  let _count_trigger: USize
  var _acc: Acc

  var _current_count: USize = 0

  new create(key: Key, agg: Aggregation[In, Out, Acc], count: USize) =>
    _key = key
    _agg = agg
    _count_trigger = count
    _acc = agg.initial_accumulator()

  fun ref apply(input: In, event_ts: U64, watermark_ts: U64):
    ((Out | None), U64)
  =>
    var out: (Out | None) = None
    _agg.update(input, _acc)
    _current_count = _current_count + 1

    if _current_count >= _count_trigger then
      out = _trigger()
    end

    (out, watermark_ts)

  fun ref on_timeout(watermark_ts: U64): ((Out | None), U64) =>
    var out: (Out | None) = None
    if _current_count > 0 then
      out = _trigger()
    end
    (out, watermark_ts)

  fun ref _trigger(): (Out | None) =>
    var out: (Out | None) = None
    out = _agg.output(_key, _acc)
    _acc = _agg.initial_accumulator()
    _current_count = 0
    out

  fun ref encode(auth: AmbientAuth): ByteSeq =>
    try
      Serialised(SerialiseAuth(auth), this)?.output(OutputSerialisedAuth(
        auth))
    else
      Fail()
      recover Array[U8] end
    end
