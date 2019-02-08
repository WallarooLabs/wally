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

type WindowOutputs[Out: Any val] is
  (Array[(Out, U64)] val, U64)

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
    (ComputationResult[Out], U64)

  fun ref on_timeout(input_watermark_ts: U64, output_watermark_ts: U64):
    (ComputationResult[Out], U64)

  fun window_count(): USize

  /////////
  // _initial_* methods for windows that behave differently the first time
  // they encounter a watermark
  /////////
  fun ref _initial_apply(input: In, event_ts: U64, watermark_ts: U64,
    windows_wrapper: WindowsWrapper[In, Out, Acc]):
    (ComputationResult[Out], U64)
  =>
    (None, 0)

  fun ref _initial_attempt_to_trigger(input_watermark_ts: U64,
    windows_wrapper: WindowsWrapper[In, Out, Acc]):
    (ComputationResult[Out], U64)
  =>
    (None, 0)

trait WindowsWrapperBuilder[In: Any val, Out: Any val, Acc: State ref]
  fun ref apply(watermark_ts: U64): WindowsWrapper[In, Out, Acc]

trait WindowsWrapper[In: Any val, Out: Any val, Acc: State ref]
  fun ref apply(input: In, event_ts: U64, watermark_ts: U64): WindowOutputs[Out]

  fun ref attempt_to_trigger(watermark_ts: U64): WindowOutputs[Out]

  fun window_count(): USize

  fun earliest_start_ts(): U64

  fun check_panes_increasing(): Bool =>
    false


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
    (ComputationResult[Out], U64)
  =>
    _agg.update(input, _acc)
    // We trigger a result per message
    let res = _agg.output(_key, event_ts, _acc)
    (res, watermark_ts)

  fun ref on_timeout(input_watermark_ts: U64, output_watermark_ts: U64):
    (ComputationResult[Out], U64)
  =>
    // We trigger per message, so we do nothing on the timer
    (recover val Array[Out] end, input_watermark_ts)

  fun window_count(): USize => 1

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
    // !@ !TODO!: Decide if we should set a minimum to this interval to
    // avoid extremely frequent timer messages.
    let range_delay_based = (_range + _delay) * 2
    // if range_delay_based > Seconds(1) then
    //   range_delay_based
    // else
    //   Seconds(1)
    // end
    range_delay_based

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
    (ComputationResult[Out], U64)
  =>
    _phase(input, event_ts, watermark_ts)

  fun ref _initial_apply(input: In, event_ts: U64, watermark_ts: U64,
    windows_wrapper: WindowsWrapper[In, Out, Acc]):
    (ComputationResult[Out], U64)
  =>
    _phase = ProcessingWindowsPhase[In, Out, Acc](windows_wrapper)
    _phase(input, event_ts, watermark_ts)

  fun ref on_timeout(input_watermark_ts: U64, output_watermark_ts: U64):
    (ComputationResult[Out], U64)
  =>
    _attempt_to_trigger(input_watermark_ts, output_watermark_ts)

  fun window_count(): USize =>
    _phase.window_count()

  fun earliest_start_ts(): U64 =>
    _phase.earliest_start_ts()

  fun ref encode(auth: AmbientAuth): ByteSeq =>
    try
      Serialised(SerialiseAuth(auth), this)?.output(OutputSerialisedAuth(
        auth))
    else
      Fail()
      recover Array[U8] end
    end

  fun ref _attempt_to_trigger(input_watermark_ts: U64,
    output_watermark_ts: U64):
    (ComputationResult[Out], U64)
  =>
    _phase.attempt_to_trigger(input_watermark_ts)

  fun ref _initial_attempt_to_trigger(input_watermark_ts: U64,
    windows_wrapper: WindowsWrapper[In, Out, Acc]):
    (ComputationResult[Out], U64)
  =>
    _phase = ProcessingWindowsPhase[In, Out, Acc](windows_wrapper)
    _phase.attempt_to_trigger(input_watermark_ts)

  fun check_panes_increasing(): Bool =>
    _phase.check_panes_increasing()

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

  fun ref apply(watermark_ts: U64): _PanesSlidingWindows[In, Out, Acc] =>
    _PanesSlidingWindows[In, Out, Acc](_key, _agg, _range, _slide, _delay,
      watermark_ts)


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
    (ComputationResult[Out], U64)
  =>
    var out: (Out | None) = None
    _agg.update(input, _acc)
    _current_count = _current_count + 1

    if _current_count >= _count_trigger then
      out = _trigger(event_ts)
    end

    (out, watermark_ts)

  fun ref on_timeout(input_watermark_ts: U64, output_watermark_ts: U64):
    (ComputationResult[Out], U64)
  =>
    var out: (Out | None) = None
    var new_output_watermark_ts = output_watermark_ts
    if _current_count > 0 then
      out = _trigger(new_output_watermark_ts)
      new_output_watermark_ts = input_watermark_ts
    end
    (out, new_output_watermark_ts)

  fun window_count(): USize => 1

  fun ref _trigger(output_watermark_ts: U64): (Out | None) =>
    var out: (Out | None) = None
    out = _agg.output(_key, output_watermark_ts, _acc)
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
