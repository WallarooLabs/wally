/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "collections"
use "wallaroo/core/common"
use "wallaroo/core/sink"
use "wallaroo_labs/mort"


class SnapshotBarrierAcker
  let _step_id: StepId
  let _sink: Sink ref
  let _snapshot_id: SnapshotId
  let _inputs: Map[StepId, SnapshotRequester] box
  let _snapshot_initiator: SnapshotInitiator
  let _has_started_snapshot: Map[StepId, SnapshotRequester] =
    _has_started_snapshot.create()

  // !@ Right now it's possible that inputs could change out
  // from under us.  Should we stick them in a new val collections?  But then
  // those changes could still happen even if not reflected here.  Perhaps
  // better to add invariant wherever inputs can be updated in
  // the encapsulating actor to check if snapshot is in progress.
  new create(step_id: StepId, sink: Sink ref,
    inputs: Map[StepId, SnapshotRequester] box,
    snapshot_initiator: SnapshotInitiator, s_id: SnapshotId)
  =>
    _step_id = step_id
    _sink = sink
    _inputs = inputs
    _snapshot_initiator = snapshot_initiator
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
        _sink.snapshot_state(_snapshot_id)
        _snapshot_initiator.ack_snapshot(_sink, _snapshot_id)
        _sink.snapshot_complete()
      end
    else
      Fail()
    end

