/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "collections"
use "wallaroo_labs/mort"


actor SnapshotInitiator is SnapshotRequester
  var _snapshot_handler: SnapshotHandler = WaitingSnapshotHandler(this)
  var _current_snapshot_id: SnapshotId = 0
  let _connections: Connections
  let _sources: Map[StepId, Source] = _sources.create()
  let _source_ids: Map[USize, StepId] = _source_ids.create()
  let _sinks: SetIs[Sink] = _sinks.create()
  let _workers: _StringSet = _workers.create()

  // !@ TODO: Make snapshot interval configurable. And also make it possible to
  // turn snapshotting off.
  new create(connections: Connections) =>
    _connections = connections

  be register_sink(sink: Sink) =>
    _sinks.set(sink)

  be unregister_sink(sink: Sink) =>
    _sinks.unset(sink)

  be register_source(source: Source, source_id: StepId) =>
    _sources(source_id) = source
    _source_ids(digestof source) = source_id

  be add_worker(w: String) =>
    //!@ What do we do if snapshot is in progress?
    _workers.set(w)

  be remove_worker(w: String) =>
    //!@ What do we do if snapshot is in progress?
    _workers.unset(w)

  be initiate_snapshot() =>
    if _snapshot_handler.in_progress() then
      Fail()
    end
    _current_snapshot_id = _current_snapshot_id + 1
    _snapshot_handler = InProgressSnapshotHandler(this, _current_snapshot_id,
      _sinks)
    for s in _sources.values() do
      s.receive_snapshot_barrier(this, _current_snapshot_id)
    end

  fun ref snapshot_state() =>
    None

  fun ref snapshot_complete() =>
    None

  be ack_snapshot(s: Snapshottable, snapshot_id: SnapshotId) =>
    _snapshot_handler.ack_snapshot(s, snapshot_id)

  be worker_ack_snapshot(w: String, snapshot_id: SnapshotId) =>
    _snapshot_handler.worker_ack_snapshot(w, snapshot_id)

  be all_sources_acked() =>
    //!@ Send out ack requests to cluster

    _snapshot_handler = WorkerAcksSnapshotHandler(this, _workers)

  be all_workers_acked() =>
    //!@ Write out snapshot id to disk

    //!@ Send out "write snapshot id to disk" to cluster

    _snapshot_handler = WaitingSnapshotHandler(this)


/////////////////////////////////////////////////////////////////////////////
// TODO: Replace using this with the badly named SetIs once we address a bug
// in SetIs where unsetting doesn't reduce set size for type SetIs[String].
class _StringSet
  let _map: Map[String, String] = _map.create()

  fun ref set(s: String) =>
    _map(s) = s

  fun ref unset(s: String) =>
    try _map.remove(s)? end

  fun ref clear() =>
    _map.clear()

  fun size(): USize =>
    _map.size()

  fun values(): MapValues[String, String, HashEq[String],
    this->HashMap[String, String, HashEq[String]]]^
  =>
    _map.values()
