/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "collections"
use "wallaroo/core/boundary"
use "wallaroo/core/common"
use "wallaroo_labs/mort"


class SnapshotBarrierForwarder
  let _step_id: StepId
  let _snapshot_requester: SnapshotRequester ref
  let _snapshot_id: SnapshotId
  let _inputs: Map[StepId, SnapshotRequester] box
  let _outputs: Map[StepId, Snapshottable] box
  let _has_started_snapshot: Map[StepId, SnapshotRequester] =
    _has_started_snapshot.create()

  // !@ Right now it's possible that inputs or outputs could change out
  // from under us.  Should we stick them in a new val collections?  But then
  // those changes could still happen even if not reflected here.  Perhaps
  // better to add invariant wherever inputs and outputs can be updated in
  // the encapsulating actor to check if snapshot is in progress.
  new create(step_id: StepId, sr: SnapshotRequester ref,
    inputs: Map[StepId, SnapshotRequester] box,
    outputs: Map[StepId, Snapshottable] box, s_id: SnapshotId)
  =>
    _step_id = step_id
    _snapshot_requester = sr
    _inputs = inputs
    _outputs = outputs
    _snapshot_id = s_id

  fun input_blocking(id: StepId, sr: SnapshotRequester): Bool =>
    _has_started_snapshot.contains(id)

  fun ref receive_snapshot_barrier(step_id: StepId, sr: SnapshotRequester,
    snapshot_id: SnapshotId)
  =>
    if snapshot_id != _snapshot_id then Fail() end

    if _inputs.contains(step_id) then
      _has_started_snapshot(step_id) = sr
      if _inputs.size() == _has_started_snapshot.size() then
        _snapshot_requester.snapshot_state(_snapshot_id)
        for (o_id, o) in _outputs.pairs() do
          match o
          | let ob: OutgoingBoundary =>
            ob.forward_snapshot_barrier(o_id, _step_id, _snapshot_id)
          else
            o.receive_snapshot_barrier(_step_id, _snapshot_requester,
              _snapshot_id)
          end
        end
        _snapshot_requester.snapshot_complete()
      end
    else
      Fail()
    end
