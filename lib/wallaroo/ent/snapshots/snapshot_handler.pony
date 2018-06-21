/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

trait SnapshotHandler
  fun in_progress(): Bool
  fun ref ack_snapshot(s: Snapshottable, snapshot_id: SnapshotId) =>
    Fail()
  fun ref worker_ack_snapshot(w: String, snapshot_id: SnapshotId) =>
    Fail()

class WaitingSnapshotHandler is SnapshotHandler
  let _initiator: SnapshotInitiator

  new create(i: SnapshotInitiator) =>
    _initiator = i

  fun in_progress(): Bool =>
    false

class InProgressSnapshotHandler is SnapshotHandler
  let _initiator: SnapshotInitiator
  let _snapshot_id: SnapshotId
  let _sources: SetIs[Snapshottable] = _sources.create()
  let _acked_sources: SetIs[Snapshottable] = _acked_sources.create()

  new create(i: SnapshotInitiator, snapshot_id: SnapshotId,
    sources: Map[StepId, Source] box)
  =>
    _initiator = i
    _snapshot_id = snapshot_id
    for s in sources.values() do
      _sources.set(s)
    end

  fun in_progress(): Bool =>
    true

  fun ref ack_snapshot(s: Snapshottable, snapshot_id: SnapshotId) =>
    if snapshot_id != _snapshot_id then Fail() end
    if not _sources.contains(s) then Fail() end

    _acked_sources.set(s)
    if _acked_sources.size() == _sources.size() then
      _initiator.all_sources_acked()
    end

class WorkerAcksSnapshotHandler is SnapshotHandler
  let _initiator: SnapshotInitiator
  let _workers: SetIs[String] = _workers.create()
  let _acked_workers: SetIs[String] = _acked_workers.create()

  new create(i: SnapshotInitiator, ws: SetIs[String] box) =>
    _initiator = i
    for w in ws.values() do
      _workers.set(w)
    end

  fun in_progress(): Bool =>
    true

  fun ref worker_ack_snapshot(w: String, snapshot_id: SnapshotId) =>
    if snapshot_id != _snapshot_id then Fail() end
    if not _workers.contains(w) then Fail() end

    _acked_workers.set(w)
    if _acked_workers.size() == _workers.size() then
      _initiator.all_workers_acked()
    end
