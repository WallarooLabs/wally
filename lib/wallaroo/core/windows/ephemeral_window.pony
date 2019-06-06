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

  fun ref apply(watermark_ts: U64): _EphemeralWindow[In, Out, Acc] =>
    _EphemeralWindow[In, Out, Acc](_key, _agg, _trigger_range,
      _post_trigger_range, _delay, _late_data_policy, watermark_ts, _rand)

class _EphemeralWindow[In: Any val, Out: Any val, Acc: State ref] is
  WindowsWrapper[In, Out, Acc]
  """
  A window created for an ephemeral key. There are four possibilities for a
  message received for an ephemeral key:
    - It's the first for the key -> open a new ephemeral window
    - It arrives at an open, non-triggered window -> call update()
    - It arrives at an open, triggered window -> apply late data policy
    - It arrives after the ephemeral window was removed -> treat as first
      message for ephemeral key (i.e. open a new ephemeral window).
  """
  let _key: Key
  let _agg: Aggregation[In, Out, Acc]
  let _identity_acc: Acc
  let _delay: U64
  var _highest_seen_event_ts: U64
  var _starting_event_ts: U64
  var _trigger_point: U64
  var _remove_point: U64
  let _late_data_policy: U16

  new create(key: Key, agg: Aggregation[In, Out, Acc], trigger_range: U64, post_trigger_range: U64, delay: U64, late_data_policy: U16,
    watermark_ts: U64, rand: Random)
  =>
    _key = key
    _agg = agg
    _delay = delay
    _identity_acc = _agg.initial_accumulator()
    _highest_seen_event_ts = watermark_ts
    _starting_event_ts = watermark_ts
    _trigger_point = _starting_event_ts + trigger_range
    _remove_point = _trigger_point + post_trigger_range
    _late_data_policy = late_data_policy

  fun ref apply(input: In, event_ts: U64, watermark_ts: U64):
    WindowOutputs[Out]
  =>
    //!@ Do we need this?
    if event_ts > _highest_seen_event_ts then
      _highest_seen_event_ts = event_ts
    end
    //!@ FAKE
    (recover Array[(Out, U64)] end, 0)

  fun ref attempt_to_trigger(watermark_ts: U64): WindowOutputs[Out] =>
    (recover Array[(Out, U64)] end, 0)

  fun window_count(): USize =>
    1

  fun earliest_start_ts(): U64 =>
    _starting_event_ts

  fun check_panes_increasing(): Bool =>
    false


