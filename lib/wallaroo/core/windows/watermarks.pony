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
use "serialise"
use "time"
use "wallaroo/core/common"
use "wallaroo_labs/mort"


class StageWatermarks
  """
  Watermarks indicate our progress in the event time domain. The ideal
  assumption is that if a watermark passes a timestamp TS, then we will never
  see another message with an event timestamp less than or equal to TS. This
  means it's safe to trigger any windows ending at or before TS.

  In many cases, the watermark can only serve as a heuristic, for example, in
  the presence of out-of-order or late data.

  StageWatermarks are assigned at sources according to source-specific
  policies. They are then propagated with every message downstream. A stage
  calculates its input watermark as the min of all upstream watermarks, and
  its output watermark as a measure of the oldest message still being
  processed (e.g. sitting in a window that hasn't been triggered).

  If an upstream hasn't sent us a message for longer than the
  _last_heard_threshold, then we remove it from our upstreams until we
  receive a message later. This allows us to trigger straggler windows and
  always progress the watermark, even when one or more sources stops
  receiving inputs.
  """
  // Keep track of output watermarks at all upstreams
  // (Watermark, LastHeardFrom)
  let _upstreams: Map[RoutingId, (U64, U64)] = _upstreams.create()

  var _input_watermark: U64 = 0
  var _output_watermark: U64 = 0

  // Used to determine if we should start ignoring an upstream we haven't
  // heard from in a while when calculating input_watermark
  var _last_heard_threshold: U64

  // If we remove upstreams midway through iterating over _upstreams.pairs,
  // it will sometimes cause us to skip keys. We keep this array so that we
  // can remove them after iterating through all pairs.
  // !TODO!: This causes us to do extra work in the common case where there
  // is nothing to remove. We should replace this approach.
  let _upstreams_marked_remove: Array[RoutingId] = Array[RoutingId]

  //!@ Where do we determine the threshold?
  new create(last_heard_threshold: U64 = 10_000_000_000) =>
    _last_heard_threshold = last_heard_threshold
    // TODO: Remove this hack. We are keeping a 0 in this array to avoid
    // running into this ponyc bug:
    // https://github.com/ponylang/ponyc/issues/2868
    _upstreams_marked_remove.push(0)

  fun ref receive_watermark(u: RoutingId, w: U64, current_ts: U64): U64 =>
    _upstreams(u) = (w, current_ts)
    if w > _input_watermark then
      // !@ Should we check every time?  Tradeoff: If we do, then we pay the
      // cost of checking every upstream.  If we don't, then we can only notice
      // that we should ignore certain upstreams in our calculations
      // whenever a timeout is triggered.
      check_effective_input_watermark(current_ts)
    else
      _input_watermark
    end

  fun ref check_effective_input_watermark(current_ts: U64): U64 =>
    var found_live_value = false

    var new_min: U64 = U64.max_value()

    for (u, (next_w, last_heard)) in _upstreams.pairs() do
      if _still_relevant(last_heard, current_ts) then
        if next_w < new_min then
          new_min = next_w
          found_live_value = true
        end
      else
        _upstreams_marked_remove.push(u)
      end
    end

    // TODO: Remove our hack and check that size is > 0 here. For now, we are
    // keeping a 0 in this array to avoid running into this ponyc bug:
    // https://github.com/ponylang/ponyc/issues/2868
    if _upstreams_marked_remove.size() > 1 then
      for u in _upstreams_marked_remove.values() do
        try
          _upstreams.remove(u)?
        end
      end
      _upstreams_marked_remove.clear()
      // TODO: Remove this hack. We are keeping a 0 in this array to avoid
      // running into this ponyc bug:
      // https://github.com/ponylang/ponyc/issues/2868
      _upstreams_marked_remove.push(0)
    end

    if new_min > _input_watermark then
      if found_live_value then
        _input_watermark = new_min
      end
      // This might be higher than our actual input watermark. This happens in
      // the case that we haven't heard from any upstream past our threshold,
      // in which case we will trigger all windows. But we keep our input
      // watermark at its former value in that case.
      new_min
    else
      _input_watermark
    end

  fun ref update_output_watermark(w: U64): (U64, U64) =>
    let old = _output_watermark
    if (w > _output_watermark) and (w < U64.max_value()) then
      _output_watermark = w
    end
    (_output_watermark, old)

  fun ref update_last_heard_threshold(t: U64) =>
    _last_heard_threshold = t

  fun _still_relevant(last_heard: U64, current_ts: U64): Bool =>
    (current_ts - last_heard) < _last_heard_threshold

  //!@
  fun print() =>
    var o = ""
    o = o + "!@############################################\n"
    o = o + "!@ StageWatermarks\n"
    o = o + "!@#################\n"
    o = o + "!@ -- upstreams\n"
    for (u, (a, b)) in _upstreams.pairs() do
      o = o + "!@ -- -- u: " + u.string() + ", (" + a.string() + ", " + b.string() + ")\n"
    end
    o = o + "!@ -- input_watermark: " + _input_watermark.string() + "\n"
    o = o + "!@ -- output_watermark: " + _output_watermark.string() + "\n"
    o = o + "!@ -- last_heard_threshold " + _last_heard_threshold.string() + "\n"
    o = o + "!@ -- _upstreams_marked_remove\n"
    for id in _upstreams_marked_remove.values() do
      o = o + "!@ -- -- id: " + id.string() + "\n"
    end

    o = o + "!@############################################\n"
    @printf[I32]("%s\n".cstring(), o.cstring())

primitive StageWatermarksSerializer
  fun apply(w: StageWatermarks, auth: AmbientAuth): ByteSeq val =>
    @printf[I32]("!@ StageWatermarksSerializer: about to apply\n".cstring())
    //!@
    w.print()

    try
      //!@
      let s = Serialised(SerialiseAuth(auth), w)?.output(OutputSerialisedAuth(
        auth))
      @printf[I32]("!@ Got s\n".cstring())
      s
    else
      @printf[I32]("!@ - FAILED TO SERIALIZE (segfault won't get here)!\n".cstring())
      Fail()
      recover Array[U8] end
    end

primitive StageWatermarksDeserializer
  fun apply(bs: Array[U8] val, auth: AmbientAuth): StageWatermarks ? =>
    try
      match Serialised.input(InputSerialisedAuth(auth), bs)(
        DeserialiseAuth(auth))?
      | let w: StageWatermarks => w
      else
        error
      end
    else
      error
    end
