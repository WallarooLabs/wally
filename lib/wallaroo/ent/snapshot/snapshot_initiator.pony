/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "buffered"
use "collections"
use "files"
use "promises"
use "time"
use "wallaroo/core/common"
use "wallaroo/core/initialization"
use "wallaroo/core/messages"
use "wallaroo/core/sink"
use "wallaroo/core/source"
use "wallaroo/core/topology"
use "wallaroo/ent/barrier"
use "wallaroo/ent/network"
use "wallaroo/ent/recovery"
use "wallaroo_labs/mort"


actor SnapshotInitiator is Initializable
  let _auth: AmbientAuth
  let _worker_name: WorkerName
  var _primary_worker: WorkerName
  var _is_active: Bool
  var _time_between_snapshots: U64
  let _event_log: EventLog
  let _barrier_initiator: BarrierInitiator
  var _current_snapshot_id: SnapshotId = 0
  let _connections: Connections
  let _snapshot_id_file: String
  let _source_ids: Map[USize, RoutingId] = _source_ids.create()
  let _timers: Timers = Timers
  let _workers: _StringSet = _workers.create()
  let _wb: Writer = Writer

  var _phase: _SnapshotInitiatorPhase = _WaitingSnapshotInitiatorPhase

  new create(auth: AmbientAuth, worker_name: WorkerName,
    primary_worker: WorkerName, connections: Connections,
    time_between_snapshots: U64, event_log: EventLog,
    barrier_initiator: BarrierInitiator, snapshot_ids_file: String,
    is_active: Bool = true, is_recovering: Bool = false)
  =>
    _auth = auth
    _worker_name = worker_name
    _primary_worker = primary_worker
    _is_active = is_active
    _time_between_snapshots = time_between_snapshots
    _event_log = event_log
    _barrier_initiator = barrier_initiator
    _connections = connections
    _snapshot_id_file = snapshot_ids_file
    if is_recovering then
      ifdef "resilience" then
        _load_latest_snapshot_id()
      end
    end

  be application_begin_reporting(initializer: LocalTopologyInitializer) =>
    initializer.report_created(this)

  be application_created(initializer: LocalTopologyInitializer) =>
    initializer.report_initialized(this)

  be application_initialized(initializer: LocalTopologyInitializer) =>
    initializer.report_ready_to_work(this)

  be application_ready_to_work(initializer: LocalTopologyInitializer) =>
    ifdef "resilience" then
      if _is_active and (_worker_name == _primary_worker) then
        initiate_snapshot()
      end
    end

  be add_worker(w: String) =>
    @printf[I32]("!@ SnapshotInitiator: add_worker %s\n".cstring(), w.cstring())
    _workers.set(w)

  be remove_worker(w: String) =>
    @printf[I32]("!@ SnapshotInitiator: remove_worker %s\n".cstring(), w.cstring())
    _workers.unset(w)

  be initiate_snapshot() =>
    _current_snapshot_id = _current_snapshot_id + 1
    let token = SnapshotBarrierToken(_current_snapshot_id)
    @printf[I32]("!@ Initiating snapshot %s\n".cstring(), _current_snapshot_id.string().cstring())

    let event_log_action = Promise[BarrierToken]
    event_log_action.next[None](
      recover this~event_log_snapshot_complete(_worker_name) end)
    _event_log.initiate_snapshot(_current_snapshot_id, token, event_log_action)

    try
      let msg = ChannelMsgEncoder.event_log_initiate_snapshot(
        _current_snapshot_id, token, _worker_name, _auth)?
      _connections.send_control_to_cluster(msg)
    else
      Fail()
    end

    let barrier_action = Promise[BarrierToken]
    barrier_action.next[None](recover this~snapshot_barrier_complete() end)
    _barrier_initiator.inject_barrier(token, barrier_action)

    _phase = _ActiveSnapshotInitiatorPhase(token, this, _workers)

  be snapshot_barrier_complete(token: BarrierToken) =>
    @printf[I32]("S_Init: Snapshot Barrier Complete\n".cstring())
    _phase.snapshot_barrier_complete(token)

  be event_log_snapshot_complete(worker: WorkerName, token: BarrierToken) =>
    @printf[I32]("S_Init: Event Log Snapshot Complete\n".cstring())
    _phase.event_log_snapshot_complete(worker, token)

  fun ref snapshot_complete(token: BarrierToken) =>
    ifdef "resilience" then
      match token
      | let st: SnapshotBarrierToken =>
        if st.id != _current_snapshot_id then Fail() end
        // @printf[I32]("!@ SnapshotInitiator: Snapshot %s is complete!\n".cstring(), st.id.string().cstring())
        _save_snapshot_id(st.id)

        try
          let msg = ChannelMsgEncoder.commit_snapshot_id(st.id, _worker_name,
            _auth)?
          _connections.send_control_to_cluster(msg)
        else
          Fail()
        end

        // Prepare for next snapshot
        if _is_active and (_worker_name == _primary_worker) then
          // @printf[I32]("!@ Creating _InitiateSnapshot timer for future snapshot %s\n".cstring(), (_current_snapshot_id + 1).string().cstring())
          let t = Timer(_InitiateSnapshot(this), _time_between_snapshots)
          _timers(consume t)
        end
      else
        Fail()
      end
    else
      Fail()
    end
    _phase = _WaitingSnapshotInitiatorPhase

  be initiate_rollback(recovery_action: Promise[SnapshotRollbackBarrierToken])
  =>
    if (_primary_worker == _worker_name) then
      if _current_snapshot_id == 0 then
        @printf[I32]("No snapshots were taken!\n".cstring())
        Fail()
      end

      // TODO: To increase odds that snapshots were successfully flushed to
      // disk, we're using the second to last snapshot if one exists. We
      // should probably change this and address the question of whether a
      // snapshot was successfully written out directly.
      let rollback_id =
        if _current_snapshot_id > 1 then
          _current_snapshot_id - 1
        else
          _current_snapshot_id
        end
      let token = SnapshotRollbackBarrierToken(rollback_id)
      let barrier_action = Promise[BarrierToken]
      barrier_action.next[None]({(t: BarrierToken) =>
        match t
        | let srbt: SnapshotRollbackBarrierToken =>
          recovery_action(srbt)
        else
          Fail()
        end
      })
      _barrier_initiator.inject_barrier(token, barrier_action)
    else
      try
        let msg = ChannelMsgEncoder.initiate_rollback(_auth)?
        _connections.send_control(_primary_worker, msg)
      else
        Fail()
      end
    end

  be commit_snapshot_id(snapshot_id: SnapshotId, sender: WorkerName) =>
    if sender == _primary_worker then
      _current_snapshot_id = snapshot_id
      _save_snapshot_id(snapshot_id)
    else
      @printf[I32](("CommitSnapshotIdMsg received from worker that is " +
        "not the primary for snapshots. Ignoring.\n").cstring())
    end

  fun ref _save_snapshot_id(snapshot_id: SnapshotId) =>
    try
      // @printf[I32]("!@ Saving SnapshotId %s\n".cstring(), snapshot_id.string().cstring())
      let filepath = FilePath(_auth, _snapshot_id_file)?
      // TODO: We'll need to rotate this file since it will grow rapidly.
      let file = File(filepath)

      _wb.u64_be(snapshot_id)
      file.writev(_wb.done())
      file.sync()
      file.dispose()
    else
      @printf[I32]("Error saving snapshot id!\n".cstring())
      Fail()
    end

  fun ref _load_latest_snapshot_id() =>
    try
      let filepath = FilePath(_auth, _snapshot_id_file)?
      if filepath.exists() then
        let file = File(filepath)
        file.seek_end(0)
        file.seek(-8)
        let r = Reader
        r.append(file.read(8))
        //!@
        let s_id = r.u64_be()?
        @printf[I32]("!@ Loaded SnapshotId: %s\n".cstring(), s_id.string().cstring())
        _current_snapshot_id = s_id
      else
        @printf[I32]("No latest snapshot id in recovery file.\n".cstring())
        _current_snapshot_id = 0
        //!@ What do we do here?
        Fail()
      end
    else
      @printf[I32]("Error reading snapshot id recovery file!".cstring())
      _current_snapshot_id = 0
      //!@ What do we do here?
      Fail()
    end

  be dispose() =>
    @printf[I32]("Shutting down SnapshotInitiator\n".cstring())
    _timers.dispose()

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

  fun contains(s: String): Bool =>
    _map.contains(s)

  fun ref clear() =>
    _map.clear()

  fun size(): USize =>
    _map.size()

  fun values(): MapValues[String, String, HashEq[String],
    this->HashMap[String, String, HashEq[String]]]^
  =>
    _map.values()
