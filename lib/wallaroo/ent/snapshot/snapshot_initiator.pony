/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "collections"
use "time"
use "wallaroo/core/common"
use "wallaroo/core/initialization"
use "wallaroo/core/sink"
use "wallaroo/core/source"
use "wallaroo/core/topology"
use "wallaroo/ent/network"
use "wallaroo_labs/mort"


actor SnapshotInitiator is (SnapshotRequester & Initializable)
  var _is_active: Bool
  var _time_between_snapshots: U64
  var _snapshot_handler: SnapshotHandler = WaitingSnapshotHandler(this)
  var _current_snapshot_id: SnapshotId = 0
  let _connections: Connections
  let _sources: Map[StepId, Source] = _sources.create()
  let _source_ids: Map[USize, StepId] = _source_ids.create()
  let _sinks: SetIs[Sink] = _sinks.create()
  let _workers: _StringSet = _workers.create()
  let _timers: Timers = Timers

  new create(connections: Connections, time_between_snapshots: U64,
    is_active: Bool = true)
  =>
    _is_active = is_active
    _time_between_snapshots = time_between_snapshots
    _connections = connections

  be application_begin_reporting(initializer: LocalTopologyInitializer) =>
    initializer.report_created(this)

  be application_created(initializer: LocalTopologyInitializer) =>
    initializer.report_initialized(this)

  be application_initialized(initializer: LocalTopologyInitializer) =>
    initializer.report_ready_to_work(this)

  be application_ready_to_work(initializer: LocalTopologyInitializer) =>
    ifdef "resilience" then
      if _is_active then
        let t = Timer(_InitiateSnapshot(this), _time_between_snapshots)
        _timers(consume t)
      end
    end

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
      s.initiate_snapshot_barrier(_current_snapshot_id)
    end

  fun ref snapshot_state(snapshot_id: SnapshotId) =>
    None

  fun ref snapshot_complete() =>
    None

  be ack_snapshot(s: Snapshottable, snapshot_id: SnapshotId) =>
    """
    Called by sinks when they have received snapshot barriers on all
    their inputs.
    """
    _snapshot_handler.ack_snapshot(s, snapshot_id)

  be worker_ack_snapshot(w: String, snapshot_id: SnapshotId) =>
    _snapshot_handler.worker_ack_snapshot(w, snapshot_id)

  be all_sinks_acked(snapshot_id: SnapshotId) =>
    //!@ Send out ack requests to cluster

    _snapshot_handler = WorkerAcksSnapshotHandler(this, snapshot_id, _workers)

  be all_workers_acked(snapshot_id: SnapshotId) =>
    //!@ Write out snapshot id to disk

    //!@ Send out "write snapshot id to disk" to cluster

    _snapshot_handler = WaitingSnapshotHandler(this)
    ifdef "resilience" then
      // Prepare for next snapshot
      if _is_active then
        let t = Timer(_InitiateSnapshot(this), _time_between_snapshots)
        _timers(consume t)
      end
    end

class _InitiateSnapshot is TimerNotify
  let _si: SnapshotInitiator

  new iso create(si: SnapshotInitiator) =>
    _si = si

  fun ref apply(timer: Timer, count: U64): Bool =>
    _si.initiate_snapshot()
    false


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
