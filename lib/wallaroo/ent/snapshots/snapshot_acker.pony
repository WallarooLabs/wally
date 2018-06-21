/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "collections"
use "wallaroo_labs/mort"


class SnapshotAcker
  let _snapshot_requester: SnapshotRequester ref
  let _snapshot_id: SnapshotId
  //!@ refactor to use state machine
  var _snapshot_in_progress: Bool = false
  var _all_acked: Bool = false
  let _normal_inputs: SetIs[SnapshotRequester]
  let _back_edges: SetIs[SnapshotRequester]
  let _outputs: SetIs[Snapshottable]
  let _has_started_snapshot: SetIs[SnapshotRequester]
  let _back_edges_started: SetIs[SnapshotRequester]
  let _has_acked: SetIs[Snapshottable]

  new create(sr: SnapshotRequester ref, s_id: SnapshotId) =>
    _snapshot_requester = sr
    _snapshot_id = s_id

  fun input_blocking(sr: SnapshotRequester) =>
    _has_started_snapshot.contains(sr)

  fun ref receive_snapshot_barrier(sr: SnapshotRequester,
    snapshot_id: SnapshotId)
  =>
    if _snapshot_in_progress then
      if snapshot_id != _snapshot_id then Fail() end
    else
      _snapshot_in_progress = true
      _snapshot_id = snapshot_id
    end
    if _normal_inputs.contains(sr) then
      _has_started_snapshot.set(sr)
    elseif _back_edges.contains(sr) then
      _back_edges_started.set(sr)
      if _all_acked and (_back_edges_started.size() == _back_edges.size()) then
        _send_acks()
      end
    else
      Fail()
    end

  fun ref ack_snapshot(s: Snapshottable, s_id: SnapshotId) =>
    ifdef debug then
      Invariant(_snapshot_in_progress)
    end
    if _outputs.contains(s) then
      _has_acked.set(s)
      if _outputs.size() == _has_acked.size() then
        _all_acked = true
        _snapshot_requester.snapshot_state()
        for o in _outputs.values() do
          o.begin_snapshot(_snapshot_requester, s_id)
        end
        if _back_edges_started.size() == _back_edges.size() then
          _send_acks()
        end
      end
    else
      Fail()
    end

  fun ref _send_acks() =>
    for i in _normal_inputs.values() do
      i.ack_snapshot(_snapshot_requester, _snapshot_id)
    end
    for i in _back_edges.values() do
      i.ack_snapshot(_snapshot_requester, _snapshot_id)
    end
    _has_acked.clear()
    _has_started_snapshot.clear()
    _back_edges_started.clear()
    _snapshot_in_progress = false
    _snapshot_id = -1
    _all_acked = false
    _snapshot_requester.snapshot_complete()
