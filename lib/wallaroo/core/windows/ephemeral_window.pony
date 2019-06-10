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


class _EphemeralWindowWrapperBuilder[In: Any val, Out: Any val, Acc: State ref]
  is WindowsWrapperBuilder[In, Out, Acc]
  let _key: Key
  let _agg: Aggregation[In, Out, Acc]
  let _trigger_range: U64
  let _post_trigger_range: U64
  let _delay: U64
  let _rand: Random
  let _late_data_policy: U16

  new create(key: Key, agg: Aggregation[In, Out, Acc], trigger_range: U64,
    post_trigger_range: U64, delay: U64, rand: Random, late_data_policy: U16)
  =>
    _key = key
    _agg = agg
    _trigger_range = trigger_range
    _post_trigger_range = post_trigger_range
    _delay = delay
    _rand = rand
    _late_data_policy = late_data_policy
    if _late_data_policy == LateDataPolicy.place_in_oldest_window() then
      FatalUserError("'Place in oldest window' is not a valid late data policy for ephemeral windows.")
    end

  fun ref apply(first_event_ts: U64, watermark_ts: U64):
    WindowsWrapper[In, Out, Acc]
  =>
    _EphemeralWindow[In, Out, Acc](_key, _agg, _trigger_range,
      _post_trigger_range, _delay, _late_data_policy, first_event_ts,
      watermark_ts, _rand)

class _EphemeralWindow[In: Any val, Out: Any val, Acc: State ref] is
  WindowsWrapper[In, Out, Acc]
  """
  A window created for an ephemeral key. There are four possibilities for a
  message received for an ephemeral key:
    - It's the first for the key -> open a new ephemeral window
    - It arrives at an existing, non-triggered window -> call update()
    - It arrives at an existing, triggered window -> apply late data policy
    - It arrives after the ephemeral window was removed -> treat as first
      message for ephemeral key (i.e. open a new ephemeral window).
  """
  let _key: Key
  let _agg: Aggregation[In, Out, Acc]
  let _acc: Acc
  let _identity_acc: Acc
  let _delay: U64
  var _highest_seen_event_ts: U64
  var _starting_event_ts: U64
  var _starting_watermark_ts: U64
  var _trigger_point: U64
  var _remove_point: U64
  let _late_data_policy: U16
  var _already_triggered: Bool = false

  new create(key: Key, agg: Aggregation[In, Out, Acc], trigger_range: U64, post_trigger_range: U64, delay: U64, late_data_policy: U16,
    first_event_ts: U64, watermark_ts: U64, rand: Random)
  =>
    _key = key
    _agg = agg
    _delay = delay
    _identity_acc = _agg.initial_accumulator()
    _acc = _identity_acc
    _highest_seen_event_ts = watermark_ts
    _starting_event_ts = first_event_ts
    _starting_watermark_ts = watermark_ts
    _trigger_point = _starting_watermark_ts + trigger_range
    _remove_point = _trigger_point + post_trigger_range
    _late_data_policy = late_data_policy

  fun ref apply(input: In, event_ts: U64, watermark_ts: U64):
    WindowOutputs[Out]
  =>
    var outs: Array[(Out, U64)] iso = recover outs.create() end
    var output_watermark_ts = watermark_ts
    let retain_state = watermark_ts < _remove_point
    if not _already_triggered then
      _agg.update(input, _acc)
      match _try_trigger_window(watermark_ts)
      | let o: Out => outs.push((o, watermark_ts))
      end
    else
      match _apply_late_data_policy(input, event_ts)
      | let o: Out => outs.push((o, watermark_ts))
      end
      output_watermark_ts = output_watermark_ts.max(event_ts)
    end
    (consume outs, watermark_ts, retain_state)

  fun ref attempt_to_trigger(watermark_ts: U64): WindowOutputs[Out] =>
    var outs: Array[(Out, U64)] iso = recover outs.create() end
    let retain_state = watermark_ts < _remove_point
    if not _already_triggered then
      match _try_trigger_window(watermark_ts)
      | let o: Out => outs.push((o, watermark_ts))
      end
    end
    (consume outs, watermark_ts, retain_state)

  fun ref _try_trigger_window(watermark_ts: U64): (Out | None) =>
    if watermark_ts > _trigger_point then
      _already_triggered = true
      _agg.output(_key, watermark_ts, _acc)
    else
      None
    end

  fun ref _apply_late_data_policy(input: In, event_ts: U64): (Out | None)
  =>
    match _late_data_policy
    | LateDataPolicy.drop() =>
      ifdef debug then
        @printf[I32]("Ephemeral window has already been triggered. Ignoring.\n".cstring())
      end
      None
    | LateDataPolicy.fire_per_message() =>
      let acc = _agg.initial_accumulator()
      _agg.update(input, acc)
      // We are currently using the event timestamp of the late message
      // as the window end timestamp.
      match _agg.output(_key, event_ts, acc)
      | let o: Out =>
        o
      else
        None
      end
    | LateDataPolicy.place_in_oldest_window() =>
      Fail()
      None
    end

  fun check_panes_increasing(): Bool =>
    false


