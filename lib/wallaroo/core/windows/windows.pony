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
use "time"
use "serialise"
use "wallaroo/aggregations"

primitive EmptyWindow

trait Windows[In: Any val, Out: Any val, Acc: State] is
  StateWrapper[In, Out, Acc]
  fun ref apply(input: In, event_ts: U64, wall_time: U64): Array[Out] val
  fun ref on_timeout(wall_time: U64): Array[Out] val

class GlobalWindow[In: Any val, Out: Any val, Acc: State] is Windows[In, Out]
  let _key: Key
  let _agg: Aggregation[In, Out, Acc]
  let _acc: Acc

  new create(key: Key, agg: Aggregation[In, Out, Acc]) =>
    _key = key
    _agg = agg
    _acc = agg.initial_accumulator()

  fun ref apply(input: In, event_ts: U64, wall_time: U64): Array[Out] val =>
    _agg.update(input, _acc)
    // We trigger a result per message
    recover val [_agg.output(_key, _acc)] end

  fun ref on_timeout(wall_time: U64): Array[Out] val =>
    // We trigger per message, so we do nothing on the timer
    recover val Array[Out] end

class val TumblingWindowsStateInitializer[In: Any val, Out: Any val,
  Acc: State] is StateInitializer[In]
  let _agg: Aggregation[In, Out, Acc]
  let _range: U64
  let _delay: U64

  new val create(agg: Aggregation[In, Out, Acc], range: U64, delay: U64) =>
    _agg = agg
    _range = range
    _delay = delay

  fun state_wrapper(key: Key): StateWrapper[In, Out, Acc] =>
    TumblingWindows[In, Out, Acc](key, _agg, _range, _delay)

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

class TumblingWindows[In: Any val, Out: Any val, Acc: State] is
  Windows[In, Out]
  let _key: Key
  let _agg: Aggregation[In, Out, Acc]

  let _windows: Array[(Acc | EmptyWindow)]
  let _windows_start_ts: Array[U64]
  var _earliest_window_idx: USize
  let _range: U64
  let _delay: U64

  new create(key: Key, agg: Aggregation[In, Out, Acc], range: U64, delay: U64)
  =>
    _key = key
    _agg = agg
    _range = range
    // Normalize delay to units of range. Since we are using tumbling windows,
    // this simplifies calculations.
    let delay_range_units = (delay.f64() / range.f64()).ceil()
    _delay = range * range_units.u64()
    // Calculate how many windows we need. The delay tells us how long we
    // wait after the close of a window to trigger and clear it. We need
    // enough extra windows to account for this delay.
    let extra_windows = delay_range_units.usize()
    let window_count = 1 + extra_windows
    _windows = Array[(Acc | EmptyWindow)](window_count)
    _windows_start_ts = Array[U64](window_count)
    _earliest_window_idx = 0
    let current_ts = Time.nanos()
    var window_start: U64 = current_ts - (range * window_count.u64())
    for i in Range(0, window_count) do
      _windows.push(EmptyWindow)
      _windows_start_ts.push(window_start)
      window_start = window_start + range
    end

  fun ref apply(input: In, event_ts: U64, wall_time: U64): Array[Out] val =>
    let earliest_ts = _windows_start_ts(_earliest_window_idx)?
    let end_ts = earliest_ts + (_windows.size().u64 * _range)
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

    let window_idx = ((event_ts - earliest_ts) / _range).usize()
    match _windows(window_idx)?
    | let ew: EmptyWindow =>
      let acc = agg.initial_accumulator()
      agg.update(first_input, acc)
      _windows(window_idx) = acc
    | let acc: Acc =>
      agg.update(first_input, acc)
    end

  fun ref _attempt_to_trigger(wall_time: U64): Array[Out] val =>
    let outs = recover iso Array[Out] end
    let earliest_ts = _windows_start_ts(_earliest_window_idx)?
    let end_ts = earliest_ts + (_windows.size().u64 * _range)
    // Convert to range units
    let end_ts_diff = ((wall_time - end_ts).f64() / _range.f64()).ceil().u64()
    var stopped = false
    while not stopped do
      (let next_out, stopped) = _check_first_window(wall_time, end_ts_diff)
      match next_out
      | let out: Out =>
        outs.push(out)
      end
    end
    consume outs

  fun ref _check_first_window(wall_time: U64, end_ts_diff: U64):
    ((Out | None), Bool)
  =>
    var out: (Out | None) = None
    var stopped: Bool = true
    let earliest_ts = _windows_start_ts(_earliest_window_idx)?
    if _should_trigger(earliest_ts) then
      match _windows(_earliest_window_idx)?
      | let acc: Acc =>
        out = _agg.output(_key, acc)
      end
      _windows(_earliest_window_idx) = EmptyWindow
      let all_window_range = _windows.size().u64() * _range
      if end_ts_diff > all_window_range then
        _windows_start_ts(_earliest_window_idx) = earliest_ts + end_ts_diff
      else
        _windows_start_ts(_earliest_window_idx) = earliest_ts +
          all_window_range
      end
      stopped = false
      _earliest_window_idx = (_earliest_window_idx + 1) % _windows.size()
    end
    (out, stopped)

  fun _is_valid_ts(event_ts: U64, current_ts: U64): Bool =>
    event_ts > (current_ts - (_delay + _range))

  fun _should_trigger(window_start_ts: U64, current_ts: U64): Bool =>
    (window_start_ts + _range) < (current_ts - _delay)
