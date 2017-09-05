/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "collections"
use "wallaroo/fail"

class BroadcastVariablesMap
  var _latest_ts: VectorTimestamp
  let _worker: String
  let _broadcast_map: Map[String, (VectorTimestamp, Any val)] =
    _broadcast_map.create()

  new create(worker: String, b_map: Map[String, Any val] val) =>
    _latest_ts = VectorTimestamp(worker).inc()
    _worker = worker
    for (k, v) in b_map.pairs() do
      _broadcast_map(k) = (_latest_ts, v)
      _latest_ts = _latest_ts.inc()
    end

  fun apply(k: String): Any val ? =>
    _broadcast_map(k)._2

  fun ref update(k: String, v: Any val): VectorTimestamp =>
    let current_ts = _latest_ts
    _latest_ts = _latest_ts.inc()
    _broadcast_map(k) = (current_ts, v)
    current_ts

  fun ref external_update(k: String, v: Any val, ts: VectorTimestamp,
    source_worker: String): Bool
  =>
    try
      let applied_change = _ExternalBroadcastVariableUpdater(_broadcast_map, k,
        v, ts, source_worker, _worker)
      _latest_ts = _latest_ts.merge(ts).inc()
      applied_change
    else
      Fail()
      false
    end

  fun keys(): MapKeys[String, (VectorTimestamp, Any val), HashEq[String],
    this->HashMap[String, (VectorTimestamp, Any val), HashEq[String]]]^
  =>
    _broadcast_map.keys()

primitive _ExternalBroadcastVariableUpdater
  fun apply(broadcast_map: Map[String, (VectorTimestamp, Any val)],
    k: String, v: Any val, ts: VectorTimestamp,
    source_worker: String, this_worker: String): Bool ?
  =>
    if broadcast_map.contains(k) then
      (let cur_ts, let cur_v) = broadcast_map(k)
      if not cur_ts.is_comparable(ts) then
        if source_worker > this_worker then
          return apply_update(broadcast_map, k, v, ts)
        end
      else
        if cur_ts < ts then
          return apply_update(broadcast_map, k, v, ts)
        end
      end
    else
      // We don't currently support dynamically adding broadcast variable keys
      // so all broadcast variable maps across the cluster should have the
      // same keys at initialization
      error
    end
    false

  fun apply_update(broadcast_map: Map[String, (VectorTimestamp, Any val)],
    k: String, v: Any val, ts: VectorTimestamp): Bool
  =>
    broadcast_map(k) = (ts, v)
    true
