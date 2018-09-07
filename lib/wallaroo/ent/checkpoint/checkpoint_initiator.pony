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
use "net"
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


actor CheckpointInitiator is Initializable
  let _self: CheckpointInitiator tag = this

  let _auth: AmbientAuth
  let _worker_name: WorkerName
  var _primary_worker: WorkerName
  var _is_active: Bool
  var _time_between_checkpoints: U64
  let _event_log: EventLog
  let _barrier_initiator: BarrierInitiator
  var _current_checkpoint_id: CheckpointId = 0
  var _last_complete_checkpoint_id: CheckpointId = 0
  var _last_rollback_id: RollbackId = 0
  let _connections: Connections
  let _checkpoint_id_file: String
  let _source_ids: Map[USize, RoutingId] = _source_ids.create()
  var _timers: Timers = Timers
  let _workers: _StringSet = _workers.create()
  let _wb: Writer = Writer

  var _is_recovering: Bool

  var _phase: _CheckpointInitiatorPhase = _WaitingCheckpointInitiatorPhase

  new create(auth: AmbientAuth, worker_name: WorkerName,
    primary_worker: WorkerName, connections: Connections,
    time_between_checkpoints: U64, event_log: EventLog,
    barrier_initiator: BarrierInitiator, checkpoint_ids_file: String,
    is_active: Bool = true, is_recovering: Bool = false)
  =>
    _auth = auth
    _worker_name = worker_name
    _primary_worker = primary_worker
    _is_active = is_active
    _time_between_checkpoints = time_between_checkpoints
    _event_log = event_log
    _barrier_initiator = barrier_initiator
    _connections = connections
    _checkpoint_id_file = checkpoint_ids_file
    _is_recovering = is_recovering
    @printf[I32]("!@ CheckpointInitiator: is_recovering: %s\n".cstring(), _is_recovering.string().cstring())
    if _is_recovering then
      ifdef "resilience" then
        _load_latest_checkpoint_id()
      end
    else
      ifdef "resilience" then
        _event_log.write_initial_checkpoint_id(_current_checkpoint_id)
      end
      _save_checkpoint_id(_last_complete_checkpoint_id, _last_rollback_id)
    end

  be application_begin_reporting(initializer: LocalTopologyInitializer) =>
    @printf[I32]("!@ application_begin_reporting CheckpointInitiator\n".cstring())
    initializer.report_created(this)

  be application_created(initializer: LocalTopologyInitializer) =>
    initializer.report_initialized(this)

  be application_initialized(initializer: LocalTopologyInitializer) =>
    initializer.report_ready_to_work(this)

  be application_ready_to_work(initializer: LocalTopologyInitializer) =>
    ifdef "resilience" then
      if _is_active and (_worker_name == _primary_worker) then
        initiate_checkpoint()
      end
    end
    _is_recovering = false

  be add_worker(w: String) =>
    @printf[I32]("!@ CheckpointInitiator: add_worker %s\n".cstring(), w.cstring())
    _workers.set(w)

  be remove_worker(w: String) =>
    @printf[I32]("!@ CheckpointInitiator: remove_worker %s\n".cstring(), w.cstring())
    _workers.unset(w)

  be lookup_next_checkpoint_id(p: Promise[CheckpointId]) =>
    p(_last_complete_checkpoint_id + 1)

  be initiate_checkpoint() =>
    _initiate_checkpoint()

  fun ref _initiate_checkpoint() =>
    _current_checkpoint_id = _current_checkpoint_id + 1

    //!@
    (let s, let ns) = Time.now()
    let us = ns / 1000
    let ts = PosixDate(s, ns).format("%Y-%m-%d %H:%M:%S." + us.string())
    @printf[I32]("!@ Initiating checkpoint %s at %s\n".cstring(), _current_checkpoint_id.string().cstring(), ts.string().cstring())

    let event_log_action = Promise[CheckpointId]
    event_log_action.next[None](
      recover this~event_log_checkpoint_complete(_worker_name) end)
    _event_log.initiate_checkpoint(_current_checkpoint_id, event_log_action)

    try
      let msg = ChannelMsgEncoder.event_log_initiate_checkpoint(
        _current_checkpoint_id, _worker_name, _auth)?
      _connections.send_control_to_cluster(msg)
    else
      Fail()
    end

    let token = CheckpointBarrierToken(_current_checkpoint_id)

    let barrier_action = Promise[BarrierToken]
    barrier_action.next[None](recover this~checkpoint_barrier_complete() end)
    _barrier_initiator.inject_barrier(token, barrier_action)

    _phase = _ActiveCheckpointInitiatorPhase(token, this, _workers)

  be resume_checkpoint() =>
    @printf[I32]("!@ CheckpointInitiator: resume_checkpoint()\n".cstring())
    if _is_active and (_worker_name == _primary_worker) then
      let action = Promise[BarrierToken]
      action.next[None]({(t: BarrierToken) => _self.initiate_checkpoint()})
      _barrier_initiator.inject_barrier(
        CheckpointRollbackResumeBarrierToken(_last_rollback_id,
          _last_complete_checkpoint_id), action)
    else
      try
        let msg = ChannelMsgEncoder.resume_checkpoint(_worker_name, _auth)?
        _connections.send_control(_primary_worker, msg)
      else
        Fail()
      end
    end

  be checkpoint_barrier_complete(token: BarrierToken) =>
    ifdef debug then
      @printf[I32]("Checkpoint_Initiator: Checkpoint Barrier %s Complete\n"
        .cstring(), token.string().cstring())
    end
    _phase.checkpoint_barrier_complete(token)

  be event_log_checkpoint_complete(worker: WorkerName, checkpoint_id: CheckpointId)
  =>
    ifdef debug then
      @printf[I32](("Checkpoint_Initiator: Event Log CheckpointId %s complete " +
        "for worker %s\n").cstring(), checkpoint_id.string().cstring(),
        worker.cstring())
    end
    _phase.event_log_checkpoint_complete(worker, checkpoint_id)

  be inform_recovering_worker(w: WorkerName, conn: TCPConnection) =>
    try
      @printf[I32]("Sending recovery data to %\n".cstring(),
        w.cstring())
      let msg = ChannelMsgEncoder.inform_recovering_worker(_worker_name,
        _last_complete_checkpoint_id, _auth)?
      conn.writev(msg)
    else
      Fail()
    end

  fun ref event_log_write_checkpoint_id(checkpoint_id: CheckpointId) =>
    @printf[I32]("!@ CheckpointInitiator: event_log_write_checkpoint_id()\n".cstring())
    _event_log.write_checkpoint_id(checkpoint_id)

    try
      let msg = ChannelMsgEncoder.event_log_write_checkpoint_id(
        checkpoint_id, _worker_name, _auth)?
      _connections.send_control_to_cluster(msg)
    else
      Fail()
    end

  fun ref checkpoint_complete(token: BarrierToken) =>
    ifdef "resilience" then
      match token
      | let st: CheckpointBarrierToken =>
        if st.id != _current_checkpoint_id then Fail() end
        // @printf[I32]("!@ CheckpointInitiator: Checkpoint %s is complete!\n".cstring(), st.id.string().cstring())
        _save_checkpoint_id(st.id, _last_rollback_id)
        _last_complete_checkpoint_id = st.id

        try
          let msg = ChannelMsgEncoder.commit_checkpoint_id(st.id,
            _last_rollback_id, _worker_name, _auth)?
          _connections.send_control_to_cluster(msg)
        else
          Fail()
        end

        // Prepare for next checkpoint
        if _is_active and (_worker_name == _primary_worker) then
          // @printf[I32]("!@ Creating _InitiateCheckpoint timer for future checkpoint %s\n".cstring(), (_current_checkpoint_id + 1).string().cstring())
          let t = Timer(_InitiateCheckpoint(this), _time_between_checkpoints)
          _timers(consume t)
        end
      else
        Fail()
      end
    else
      Fail()
    end
    _phase = _WaitingCheckpointInitiatorPhase

  be initiate_rollback(recovery_action: Promise[CheckpointRollbackBarrierToken],
    worker: WorkerName)
  =>
    if (_primary_worker == _worker_name) then
      if _current_checkpoint_id == 0 then
        @printf[I32]("No checkpoints were taken!\n".cstring())
        Fail()
      end

      // Clear any pending checkpoint
      _timers.dispose()
      _timers = Timers

      let rollback_id = _last_rollback_id + 1
      _last_rollback_id = rollback_id

      @printf[I32]("!@ !!!!CheckpointInitiator: initiate_rollback %s on behalf of %s!!!!\n".cstring(), rollback_id.string().cstring(), worker.cstring())

      let token = CheckpointRollbackBarrierToken(rollback_id,
        _last_complete_checkpoint_id)
      if _current_checkpoint_id < _last_complete_checkpoint_id then
        _current_checkpoint_id = _last_complete_checkpoint_id
      end
      let barrier_action = Promise[BarrierToken]
      barrier_action.next[None]({(t: BarrierToken) =>
        match t
        | let srbt: CheckpointRollbackBarrierToken =>
          recovery_action(srbt)
          _self.rollback_complete(srbt.rollback_id)
        else
          Fail()
        end
      })
      let resume_token = CheckpointRollbackResumeBarrierToken(rollback_id,
        _last_complete_checkpoint_id)
      _barrier_initiator.inject_blocking_barrier(token, barrier_action,
        resume_token)
    else
      try
        let msg = ChannelMsgEncoder.initiate_rollback_barrier(_worker_name,
          _auth)?
        _connections.send_control(_primary_worker, msg)
      else
        Fail()
      end
    end

  be rollback_complete(rollback_id: RollbackId) =>
    _last_rollback_id = rollback_id
    _save_checkpoint_id(_last_complete_checkpoint_id, rollback_id)

  be commit_checkpoint_id(checkpoint_id: CheckpointId, rollback_id: RollbackId,
    sender: WorkerName)
  =>
    if sender == _primary_worker then
      _current_checkpoint_id = checkpoint_id
      _last_complete_checkpoint_id = checkpoint_id
      _last_rollback_id = rollback_id
      _save_checkpoint_id(checkpoint_id, rollback_id)
    else
      @printf[I32](("CommitCheckpointIdMsg received from worker that is " +
        "not the primary for checkpoints. Ignoring.\n").cstring())
    end

  fun ref _save_checkpoint_id(checkpoint_id: CheckpointId, rollback_id: RollbackId)
  =>
    try
      @printf[I32]("!@ Saving CheckpointId %s and RollbackId %s\n".cstring(), checkpoint_id.string().cstring(), rollback_id.string().cstring())
      let filepath = FilePath(_auth, _checkpoint_id_file)?
      // TODO: We'll need to rotate this file since it will grow rapidly.
      let file = File(filepath)

      _wb.u64_be(checkpoint_id)
      _wb.u64_be(rollback_id)
      file.writev(_wb.done())
      file.sync()
      file.dispose()
    else
      @printf[I32]("Error saving checkpoint id!\n".cstring())
      Fail()
    end

  fun ref _load_latest_checkpoint_id() =>
    @printf[I32]("!@ Loading _load_latest_checkpoint_id\n".cstring())
    (let checkpoint_id, let rollback_id) =
      LatestCheckpointId.read(_auth, _checkpoint_id_file)
    _current_checkpoint_id = checkpoint_id
    _last_complete_checkpoint_id = checkpoint_id
    _last_rollback_id = rollback_id

  be dispose() =>
    @printf[I32]("Shutting down CheckpointInitiator\n".cstring())
    _timers.dispose()

primitive LatestCheckpointId
  fun read(auth: AmbientAuth, checkpoint_id_file: String):
    (CheckpointId, RollbackId)
  =>
    try
      let filepath = FilePath(auth, checkpoint_id_file)?
      if filepath.exists() then
        let file = File(filepath)
        file.seek_end(0)
        file.seek(-16)
        let r = Reader
        r.append(file.read(16))
        //!@
        let checkpoint_id = r.u64_be()?
        @printf[I32]("!@ Loaded CheckpointId: %s\n".cstring(), checkpoint_id.string().cstring())
        let rollback_id = r.u64_be()?
        @printf[I32]("!@ Loaded RollbackId: %s\n".cstring(), rollback_id.string().cstring())
        (checkpoint_id, rollback_id)
      else
        @printf[I32]("No latest checkpoint id in recovery file.\n".cstring())
        //!@ What do we do here?
        Fail()
        (0, 0)
      end
    else
      @printf[I32]("Error reading checkpoint id recovery file!".cstring())
      //!@ What do we do here?
      Fail()
      (0, 0)
    end

class _InitiateCheckpoint is TimerNotify
  let _si: CheckpointInitiator

  new iso create(si: CheckpointInitiator) =>
    _si = si

  fun ref apply(timer: Timer, count: U64): Bool =>
    _si.initiate_checkpoint()
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
