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

  fun ref with_delay(delay: U64): RangeWindowsBuilder =>
    _delay = delay
    this

  fun ref over[In: Any val, Out: Any val, S: State ref](
    agg: Aggregation[In, Out, S]): StateInitializer[In, Out, S]
  =>
    if _slide == _range then
      TumblingWindowsStateInitializer[In, Out, S](agg, _range, _delay)
    else
      SlidingWindowsStateInitializer[In, Out, S](agg, _range, _slide, _delay)
    end

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
  fun ref apply(input: In, event_ts: U64, wall_time: U64):
    (Out | Array[Out] val | None)
  fun ref on_timeout(wall_time: U64): (Out | Array[Out] val | None)

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

  fun ref apply(input: In, event_ts: U64, wall_time: U64):
    (Out | Array[Out] val | None) =>
    _agg.update(input, _acc)
    // We trigger a result per message
    _agg.output(_key, _acc)

  fun ref on_timeout(wall_time: U64): Array[Out] val =>
    // We trigger per message, so we do nothing on the timer
    recover val Array[Out] end

  fun ref encode(auth: AmbientAuth): ByteSeq =>
    try
      Serialised(SerialiseAuth(auth), this)?.output(OutputSerialisedAuth(
        auth))
    else
      Fail()
      recover Array[U8] end
    end

///////////////////////////
// TUMBLING RANGE WINDOWS
///////////////////////////
class val TumblingWindowsStateInitializer[In: Any val, Out: Any val,
  Acc: State ref] is StateInitializer[In, Out, Acc]
  let _agg: Aggregation[In, Out, Acc]
  let _range: U64
  let _delay: U64

  new val create(agg: Aggregation[In, Out, Acc], range: U64, delay: U64) =>
    _agg = agg
    _range = range
    _delay = delay

  fun state_wrapper(key: Key): StateWrapper[In, Out, Acc] =>
    TumblingWindows[In, Out, Acc](key, _agg, _range, _delay)

  fun val runner_builder(step_group_id: RoutingId, parallelization: USize):
    RunnerBuilder
  =>
    StateRunnerBuilder[In, Out, Acc](this, step_group_id, parallelization)

  fun val decode(in_reader: Reader, auth: AmbientAuth):
    StateWrapper[In, Out, Acc] ?
  =>
    try
      let data: Array[U8] iso = in_reader.block(in_reader.size())?
      match Serialised.input(InputSerialisedAuth(auth), consume data)(
        DeserialiseAuth(auth))?
      | let tw: TumblingWindows[In, Out, Acc] => tw
      else
        error
      end
    else
      error
    end

  fun name(): String =>
    _agg.name()

class TumblingWindows[In: Any val, Out: Any val, Acc: State ref] is
  Windows[In, Out, Acc]
  let _key: Key
  let _agg: Aggregation[In, Out, Acc]

  let _windows: Array[(Acc | EmptyWindow)]
  let _windows_start_ts: Array[U64]
  var _earliest_window_idx: USize
  let _range: U64
  let _delay: U64

  new create(key: Key, agg: Aggregation[In, Out, Acc], range: U64, delay: U64,
    current_ts: U64 = Time.nanos())
  =>
    _key = key
    _agg = agg
    _range = range
    // Normalize delay to units of range. Since we are using tumbling windows,
    // this simplifies calculations.
    let delay_range_units = (delay.f64() / range.f64()).ceil()
    // let delay_range_units = delay / range
    _delay = range * delay_range_units.u64()
    // Calculate how many windows we need. The delay tells us how long we
    // wait after the close of a window to trigger and clear it. We need
    // enough extra windows to account for this delay.
    let extra_windows = delay_range_units.usize()
    let window_count = 1 + extra_windows
    _windows = Array[(Acc | EmptyWindow)](window_count)
    _windows_start_ts = Array[U64](window_count)
    _earliest_window_idx = 0
    var window_start: U64 = current_ts - (range * window_count.u64())
    for i in Range(0, window_count) do
      _windows.push(EmptyWindow)
      _windows_start_ts.push(window_start)
      window_start = window_start + range
    end

  fun ref apply(input: In, event_ts: U64, wall_time: U64): Array[Out] val =>
    try
      let earliest_ts = _windows_start_ts(_earliest_window_idx)?
      let end_ts = earliest_ts + (_windows.size().u64() * _range)
      var applied = false
      if (event_ts >= earliest_ts) and (event_ts < end_ts) then
        _apply_input(input, event_ts, earliest_ts)
        applied = true
      end

      // Check if we need to trigger and clear windows
      let outs = _attempt_to_trigger(wall_time)

      // If we haven't already applied the input, do it now.
      if not applied and _is_valid_ts(event_ts, wall_time) then
        let new_earliest_ts = _windows_start_ts(_earliest_window_idx)?
        _apply_input(input, event_ts, new_earliest_ts)
      end

      outs
    else
      Fail()
      recover Array[Out] end
    end

  fun ref on_timeout(wall_time: U64): Array[Out] val =>
    _attempt_to_trigger(wall_time)

  fun ref encode(auth: AmbientAuth): ByteSeq =>
    try
      Serialised(SerialiseAuth(auth), this)?.output(OutputSerialisedAuth(
        auth))
    else
      Fail()
      recover Array[U8] end
    end

  fun ref _apply_input(input: In, event_ts: U64, earliest_ts: U64) =>
    // Should we ensure the event_ts is in the correct range?

    if event_ts >= earliest_ts then
      let window_idx_offset = ((event_ts - earliest_ts) / _range).usize()
      let window_idx =
        (_earliest_window_idx + window_idx_offset) % _windows.size()
      try
        match _windows(window_idx)?
        | let ew: EmptyWindow =>
          let acc = _agg.initial_accumulator()
          _agg.update(input, acc)
          _windows(window_idx)? = acc
        | let acc: Acc =>
          _agg.update(input, acc)
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

  fun ref _attempt_to_trigger(wall_time: U64): Array[Out] val =>
    let outs = recover iso Array[Out] end
    try
      let earliest_ts = _windows_start_ts(_earliest_window_idx)?
      let end_ts = earliest_ts + (_windows.size().u64() * _range)
      // Convert to range units
      let end_ts_diff =
        ((wall_time - end_ts).f64() / _range.f64()).ceil().u64()
      var stopped = false
      while not stopped do
        (let next_out, stopped) = _check_first_window(wall_time, end_ts_diff)
        match next_out
        | let out: Out =>
          outs.push(out)
        end
      end
    else
      Fail()
    end
    consume outs

  fun ref _check_first_window(wall_time: U64, end_ts_diff: U64):
    ((Out | None), Bool)
  =>
    var out: (Out | None) = None
    var stopped: Bool = true
    try
      let earliest_ts = _windows_start_ts(_earliest_window_idx)?
      if _should_trigger(earliest_ts, wall_time) then
        match _windows(_earliest_window_idx)?
        | let acc: Acc =>
          out = _agg.output(_key, acc)
        end
        _windows(_earliest_window_idx)? = EmptyWindow
        let all_window_range = _windows.size().u64() * _range
        if end_ts_diff > all_window_range then
          _windows_start_ts(_earliest_window_idx)? = earliest_ts + end_ts_diff
        else
          _windows_start_ts(_earliest_window_idx)? = earliest_ts +
            all_window_range
        end
        stopped = false
        _earliest_window_idx = (_earliest_window_idx + 1) % _windows.size()
      end
    else
      Fail()
    end
    (out, stopped)

  //!@ This means that even if there's a window open that's prior to
  //current_ts - (delay + range) then we'll drop the message that we could
  //have put in there. It's probably preferable to check that the event_ts
  //is greater than the earliest window start_ts we have available instead.
  fun _is_valid_ts(event_ts: U64, current_ts: U64): Bool =>
    event_ts > (current_ts - (_delay + _range))

  fun _should_trigger(window_start_ts: U64, current_ts: U64): Bool =>
    (window_start_ts + _range) < (current_ts - _delay)

///////////////////////////
// SLIDING RANGE WINDOWS
///////////////////////////
class val SlidingWindowsStateInitializer[In: Any val, Out: Any val,
  Acc: State ref] is StateInitializer[In, Out, Acc]
  let _agg: Aggregation[In, Out, Acc]
  let _range: U64
  let _slide: U64
  let _delay: U64

  new val create(agg: Aggregation[In, Out, Acc], range: U64, slide: U64,
    delay: U64)
  =>
    _agg = agg
    _range = range
    _slide = slide
    _delay = delay

  fun state_wrapper(key: Key): StateWrapper[In, Out, Acc] =>
    SlidingWindows[In, Out, Acc](key, _agg, _range, _slide, _delay)

  fun val runner_builder(step_group_id: RoutingId, parallelization: USize):
    RunnerBuilder
  =>
    StateRunnerBuilder[In, Out, Acc](this, step_group_id, parallelization)

  fun val decode(in_reader: Reader, auth: AmbientAuth):
    StateWrapper[In, Out, Acc] ?
  =>
    try
      let data: Array[U8] iso = in_reader.block(in_reader.size())?
      match Serialised.input(InputSerialisedAuth(auth), consume data)(
        DeserialiseAuth(auth))?
      | let sw: SlidingWindows[In, Out, Acc] => sw
      else
        error
      end
    else
      error
    end

  fun name(): String =>
    _agg.name()

class SlidingWindows[In: Any val, Out: Any val, Acc: State ref] is
  Windows[In, Out, Acc]
  let _windows: _SlidingWindows[In, Out, Acc]

  new create(key: Key, agg: Aggregation[In, Out, Acc], range: U64, slide: U64,
    delay: U64, current_ts: U64 = Time.nanos())
  =>
    // Check if range divides evenly by slide.  Otherwise complain and Fail().
    _windows = _SlidingWindows[In, Out, Acc](key, agg, range, slide, delay,
      current_ts)

  fun ref apply(input: In, event_ts: U64, wall_time: U64): Array[Out] val =>
    _windows(input, event_ts, wall_time)

  fun ref on_timeout(wall_time: U64): Array[Out] val =>
    _attempt_to_trigger(wall_time)

  fun ref encode(auth: AmbientAuth): ByteSeq =>
    try
      Serialised(SerialiseAuth(auth), this)?.output(OutputSerialisedAuth(
        auth))
    else
      Fail()
      recover Array[U8] end
    end

  fun ref _attempt_to_trigger(wall_time: U64): Array[Out] val =>
    _windows.attempt_to_trigger(wall_time)

class _SlidingWindows[In: Any val, Out: Any val, Acc: State ref]
  """
  An inefficient sliding windows implementation that always recalculates
  the combination of all lowest level partial aggregations stored in panes.
  """
  let _panes: Array[(Acc | EmptyPane)]
  let _panes_start_ts: Array[U64]
  let _panes_per_window: USize
  var _earliest_window_idx: USize

  let _key: Key
  let _agg: Aggregation[In, Out, Acc]
  let _identity_acc: Acc
  let _range: U64
  let _slide: U64
  let _delay: U64

  new create(key: Key, agg: Aggregation[In, Out, Acc], range: U64, slide: U64,
    delay: U64, current_ts: U64 = Time.nanos())
  =>
    // Invariant that range divides evenly by slide

    _key = key
    _agg = agg
    _range = range
    _slide = slide
    _identity_acc = _agg.initial_accumulator()
    // Normalize delay to units of slide.
    let delay_range_units = (delay.f64() / slide.f64()).ceil()
    _delay = slide * delay_range_units.u64()

    _panes_per_window = (range / slide).usize()

    // Calculate how many windows we need. The delay tells us how long we
    // wait after the close of a window to trigger and clear it. We need
    // enough extra panes to account for this delay.
    let extra_panes = delay_range_units.usize()
    let pane_count = _panes_per_window + extra_panes

    let total_length = pane_count.u64() * slide
    let last_window_start = total_length - range
    let window_count = (last_window_start / slide).usize() + 1

    _panes = Array[(Acc | EmptyPane)](pane_count)
    _panes_start_ts = Array[U64](pane_count)
    _earliest_window_idx = 0
    var pane_start: U64 = current_ts - (slide * pane_count.u64())
    for i in Range(0, pane_count) do
      _panes.push(EmptyPane)
      _panes_start_ts.push(pane_start)
      pane_start = pane_start + slide
    end

  fun ref apply(input: In, event_ts: U64, wall_time: U64): Array[Out] val =>
    try
      let earliest_ts = _panes_start_ts(_earliest_window_idx)?
      let end_ts = earliest_ts + (_panes.size().u64() * _slide)
      var applied = false
      if (event_ts >= earliest_ts) and (event_ts < end_ts) then
        _apply_input(input, event_ts, earliest_ts)
        applied = true
      end

      // Check if we need to trigger and clear windows
      let outs = attempt_to_trigger(wall_time)

      // If we haven't already applied the input, do it now.
      if not applied and _is_valid_ts(event_ts, wall_time) then
        let new_earliest_ts = _panes_start_ts(_earliest_window_idx)?
        _apply_input(input, event_ts, new_earliest_ts)
      end

      outs
    else
      Fail()
      recover Array[Out] end
    end

  fun ref _apply_input(input: In, event_ts: U64, earliest_ts: U64) =>
    // Should we ensure the event_ts is in the correct range?

    if event_ts >= earliest_ts then
      let pane_idx_offset = ((event_ts - earliest_ts) / _slide).usize()
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

  fun ref attempt_to_trigger(wall_time: U64): Array[Out] val =>
    let outs = recover iso Array[Out] end
    try
      let earliest_ts = _panes_start_ts(_earliest_window_idx)?
      let end_ts = earliest_ts + (_panes.size().u64() * _slide)
      // Convert to range units
      let end_ts_diff = wall_time - end_ts
        // ((wall_time - end_ts).f64() / _slide.f64()).ceil().u64()
      var stopped = false
      while not stopped do
        (let next_out, stopped) = _check_first_window(wall_time, end_ts_diff)
        match next_out
        | let out: Out =>
          outs.push(out)
        end
      end
    else
      Fail()
    end
    consume outs

  fun ref _check_first_window(wall_time: U64, end_ts_diff: U64):
    ((Out | None), Bool)
  =>
    var out: (Out | None) = None
    var stopped: Bool = true
    try
      let earliest_ts = _panes_start_ts(_earliest_window_idx)?
      if _should_trigger(earliest_ts, wall_time) then
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
        let all_pane_range = _panes.size().u64() * _slide
        if end_ts_diff > all_pane_range then
          _panes_start_ts(_earliest_window_idx)? = earliest_ts + end_ts_diff
        else
          _panes_start_ts(_earliest_window_idx)? = earliest_ts +
            all_pane_range
        end
        stopped = false
        _panes(_earliest_window_idx)? = EmptyPane
        _earliest_window_idx = (_earliest_window_idx + 1) % _panes.size()
      end
    else
      Fail()
    end
    (out, stopped)

  //!@ This means that even if there's a window open that's prior to
  //current_ts - (delay + range) then we'll drop the message that we could
  //have put in there. It's probably preferable to check that the event_ts
  //is greater than the earliest pane start_ts we have available instead.
  fun _is_valid_ts(event_ts: U64, current_ts: U64): Bool =>
    event_ts > (current_ts - (_delay + _range))

  fun _should_trigger(window_start_ts: U64, current_ts: U64): Bool =>
    (window_start_ts + _range) < (current_ts - _delay)

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

  fun val decode(in_reader: Reader, auth: AmbientAuth):
    StateWrapper[In, Out, Acc] ?
  =>
    try
      let data: Array[U8] iso = in_reader.block(in_reader.size())?
      match Serialised.input(InputSerialisedAuth(auth), consume data)(
        DeserialiseAuth(auth))?
      | let tw: TumblingWindows[In, Out, Acc] => tw
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

  fun ref apply(input: In, event_ts: U64, wall_time: U64): (Out | None) =>
    var out: (Out | None) = None
    _agg.update(input, _acc)
    _current_count = _current_count + 1

    if _current_count >= _count_trigger then
      out = _trigger()
    end

    out

  fun ref on_timeout(wall_time: U64): (Out | None) =>
    var out: (Out | None) = None
    if _current_count > 0 then
      out = _trigger()
    end
    out

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
