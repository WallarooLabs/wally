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
use "wallaroo/core/barrier"
use "wallaroo/core/network"
use "wallaroo/core/recovery"
use "wallaroo_labs/mort"
use "wallaroo_labs/string_set"


actor CheckpointInitiator is Initializable
  """
  Phases:
    _WaitingCheckpointInitiatorPhase: Waiting for a checkpoint to be initiated.

    _CheckpointingPhase: A checkpoint barrier is in flight. Waiting for a
      the barrier to be acked by all sinks.
      |||| ASSUMPTION: There is only one checkpoint barrier in flight
      |||| at a time. The barrier protocol in general does not require this,
      |||| but we currently assume that all checkpoint event log entries for a
      |||| single checkpoint id are consecutive.

    _WaitingForEventLogIdWrittenPhase: Waiting for event log to persist a
      committed checkpoint id.

    _RollbackCheckpointInitiatorPhase: A rollback is ongoing, so we ignore any
      current checkpoint activity. Waiting for rollback to complete.

    _DisposedCheckpointInitiatorPhase: This actor is disposed, so we ignore all
      activity.
  """
  let _self: CheckpointInitiator tag = this

  let _auth: AmbientAuth
  let _worker_name: WorkerName
  var _primary_worker: WorkerName
  var _time_between_checkpoints: U64
  let _event_log: EventLog
  let _barrier_coordinator: BarrierCoordinator
  var _recovery: (Recovery | None) = None

  let _source_coordinators: SetIs[SourceCoordinator] = _source_coordinators.create()
  let _sinks: SetIs[Sink] = _sinks.create()

  // Used as a way to identify outdated timer-based initiate_checkpoint calls
  var _checkpoint_group: USize = 0

  var _current_checkpoint_id: CheckpointId = 0
  var _last_complete_checkpoint_id: CheckpointId = 0
  var _last_rollback_id: RollbackId = 0
  let _connections: Connections
  let _checkpoint_id_file: String
  let _source_ids: Map[USize, RoutingId] = _source_ids.create()
  var _timers: Timers = Timers
  let _workers: StringSet = _workers.create()
  let _wb: Writer = Writer
  let _the_journal: SimpleJournal
  let _do_local_file_io: Bool

  var _is_recovering: Bool

  var _phase: _CheckpointInitiatorPhase = _WaitingCheckpointInitiatorPhase

  new create(auth: AmbientAuth, worker_name: WorkerName,
    primary_worker: WorkerName, connections: Connections,
    time_between_checkpoints: U64, event_log: EventLog,
    barrier_coordinator: BarrierCoordinator, checkpoint_ids_file: String,
    the_journal: SimpleJournal, do_local_file_io: Bool,
    is_active: Bool = true, is_recovering: Bool = false)
  =>
    _auth = auth
    _worker_name = worker_name
    _primary_worker = primary_worker
    _time_between_checkpoints = time_between_checkpoints
    _event_log = event_log
    _barrier_coordinator = barrier_coordinator
    _connections = connections
    _checkpoint_id_file = checkpoint_ids_file
    _the_journal = the_journal
    _do_local_file_io = do_local_file_io
    _is_recovering = is_recovering
    _event_log.set_checkpoint_initiator(this)

  be initialize_checkpoint_id(
    ids: ((CheckpointId, RollbackId) | None) = None)
  =>
    """
    Passing in ids here means that we are using external information to
    initialize (like in a join).
    """
    match ids
    | (let cid: CheckpointId, let rid: RollbackId) =>
      ifdef "checkpoint_trace" then
        @printf[I32]("CheckpointInitiator: initializing cid/rid to %s/%s\n"
          .cstring(), cid.string().cstring(), rid.string().cstring())
      end
      ifdef "resilience" then
        _commit_checkpoint_id(cid, rid)
        ifdef "checkpoint_trace" then
          @printf[I32]("-- Writing cid %s to event log\n".cstring(),
            _current_checkpoint_id.string().cstring())
        end
        _event_log.write_initial_checkpoint_id(_current_checkpoint_id)
      end
    else
      if _is_recovering then
        ifdef "resilience" then
          _load_latest_checkpoint_id()
        end
      else
        ifdef "resilience" then
          _event_log.write_initial_checkpoint_id(_current_checkpoint_id)
          _commit_checkpoint_id(_last_complete_checkpoint_id,
            _last_rollback_id)
        end
      end
    end

  be set_recovery(r: Recovery) =>
    _recovery = r

  be application_begin_reporting(initializer: LocalTopologyInitializer) =>
    initializer.report_created(this)

  be application_created(initializer: LocalTopologyInitializer) =>
    initializer.report_initialized(this)

  be application_initialized(initializer: LocalTopologyInitializer) =>
    initializer.report_ready_to_work(this)

  be application_ready_to_work(initializer: LocalTopologyInitializer) =>
    None

  be cluster_ready_to_work(initializer: LocalTopologyInitializer) =>
    ifdef "resilience" then
      if _worker_name == _primary_worker then
        _phase.start_checkpoint_timer(1_000_000_000, this)
      end
    end
    _is_recovering = false

  fun ref _start_checkpoint_timer(time_until_checkpoint: U64) =>
    """
    Ignoring the initial checkpoint, we only set a new checkpoint timer once
    the last checkpoint is complete. That means that "time_until_checkpoint"
    is the absolute minimum time between checkpoints. In reality, we need to
    add the time taken to actually complete the checkpoint to this time.
    """
    let t = Timer(_InitiateCheckpoint(this, _checkpoint_group),
      time_until_checkpoint)
    _timers(consume t)

  fun workers(): StringSet box => _workers

  be add_worker(w: String) =>
    ifdef "checkpoint_trace" then
      @printf[I32]("CheckpointInitiator: add_worker %s\n".cstring(),
        w.cstring())
    end
    _workers.set(w)

  be remove_worker(w: String) =>
    ifdef "checkpoint_trace" then
      @printf[I32]("CheckpointInitiator: remove_worker %s\n".cstring(),
        w.cstring())
    end
    _workers.unset(w)

  be register_sink(sink: Sink) =>
    _sinks.set(sink)

  be unregister_sink(sink: Sink) =>
    _sinks.unset(sink)

  be register_source_coordinator(source_coordinator: SourceCoordinator) =>
    _source_coordinators.set(source_coordinator)

  be unregister_source_coordinator(source_coordinator: SourceCoordinator) =>
    _source_coordinators.unset(source_coordinator)

  be lookup_next_checkpoint_id(p: Promise[CheckpointId]) =>
    p(_last_complete_checkpoint_id + 1)

  be lookup_checkpoint_id(p: Promise[(CheckpointId, RollbackId)]) =>
    p((_last_complete_checkpoint_id, _last_rollback_id))

  be initiate_checkpoint(checkpoint_group: USize) =>
    if checkpoint_group == _checkpoint_group then
      _phase.initiate_checkpoint(checkpoint_group, this)
    end

  be clear_pending_checkpoints(promise: Promise[None]) =>
    _clear_pending_checkpoints()
    promise(None)

  be restart_repeating_checkpoints() =>
    _clear_pending_checkpoints()
    _phase.initiate_checkpoint(_checkpoint_group, this)

  fun ref _initiate_checkpoint(checkpoint_group: USize) =>
    ifdef "resilience" then
      _clear_pending_checkpoints()
      _current_checkpoint_id = _current_checkpoint_id + 1

      ifdef "checkpoint_trace" then
        try
          (let s, let ns) = Time.now()
          let us = ns / 1000
          let ts = PosixDate(s, ns).format("%Y-%m-%d %H:%M:%S." + us.string())?
          @printf[I32]("Initiating checkpoint %s at %s\n".cstring(),
            _current_checkpoint_id.string().cstring(), ts.string().cstring())
        else
          Fail()
        end
      end

      let event_log_promise = Promise[CheckpointId]
      event_log_promise.next[None](
        recover this~event_log_checkpoint_complete(_worker_name) end)
      _event_log.initiate_checkpoint(_current_checkpoint_id,
        event_log_promise)

      try
        let msg = ChannelMsgEncoder.event_log_initiate_checkpoint(
          _current_checkpoint_id, _worker_name, _auth)?
        _connections.send_control_to_cluster(msg)
      else
        Fail()
      end

      let token = CheckpointBarrierToken(_current_checkpoint_id)

      let barrier_promise = Promise[BarrierToken]
      barrier_promise.next[None](
        recover this~checkpoint_barrier_complete() end,
        recover this~abort_checkpoint(_current_checkpoint_id) end)
      _barrier_coordinator.inject_barrier(token, barrier_promise)

      _phase = _CheckpointingPhase(token, this)
    end

  be resume_checkpointing_from_rollback() =>
    ifdef "checkpoint_trace" then
      @printf[I32]("CheckpointInitiator: resume_checkpointing_from_rollback()\n"
        .cstring())
    end
    if _worker_name == _primary_worker then
      _clear_pending_checkpoints()
      ifdef "resilience" then
        let promise = Promise[BarrierToken]
        promise.next[None]({(t: BarrierToken) =>
          _self.initiate_checkpoint(_checkpoint_group)})
        _barrier_coordinator.inject_barrier(
          CheckpointRollbackResumeBarrierToken(_last_rollback_id,
            _last_complete_checkpoint_id), promise)
        _phase.resume_checkpointing_from_rollback()
      end
    else
      try
        ifdef "resilience" then
          let msg = ChannelMsgEncoder.resume_checkpoint(_worker_name, _auth)?
          _connections.send_control(_primary_worker, msg)
          _phase.resume_checkpointing_from_rollback()
        end
      else
        Fail()
      end
    end

  fun ref wait_for_next_checkpoint() =>
    _phase = _WaitingCheckpointInitiatorPhase

  be checkpoint_barrier_complete(token: BarrierToken) =>
    """
    This is called when all sinks have acked the checkpoint barrier.
    """
    ifdef debug then
      @printf[I32]("Checkpoint_Initiator: Checkpoint Barrier %s Complete\n"
        .cstring(), token.string().cstring())
    end
    _phase.checkpoint_barrier_complete(token)

  be abort_checkpoint(checkpoint_id: CheckpointId) =>
    """
    If a sink fails to successfully precommit its outputs, or runs into some
    other irreversible problem, then it will abort the checkpoint barrier.
    At this point, we must roll back to the last successful checkpoint.
    """
    _phase.abort_checkpoint(checkpoint_id, this)

  fun ref _abort_checkpoint(checkpoint_id: CheckpointId) =>
    if _primary_worker == _worker_name then
      @printf[I32]("CheckpointInitiator: Aborting Checkpoint %s\n".cstring(),
        checkpoint_id.string().cstring())
      _phase = _RollbackCheckpointInitiatorPhase(this)
      match _recovery
      | let r: Recovery =>
        let ws: Array[WorkerName] iso = recover Array[WorkerName] end
        for w in _workers.values() do
          ws.push(w)
        end
        if checkpoint_id == 1 then
          @printf[I32](("We are aborting the initial checkpoint, which " +
            "should never happen.\n").cstring())
          Fail()
        else
          r.update_checkpoint_id(_last_complete_checkpoint_id)
        end
        r.start_recovery(consume ws where with_reconnect = false)
      else
        Fail()
      end
    else
      try
        let msg = ChannelMsgEncoder.abort_checkpoint(checkpoint_id,
          _worker_name, _auth)?
        _connections.send_control(_primary_worker, msg)
      else
        Fail()
      end
    end

  be event_log_checkpoint_complete(worker: WorkerName,
    checkpoint_id: CheckpointId)
  =>
    """
    This is called when the EventLog has written all entries in the scope of
    this checkpoint
    """
    ifdef debug then
      @printf[I32](("Checkpoint_Initiator: Event Log CheckpointId %s " +
        "complete for worker %s\n").cstring(), checkpoint_id.string()
        .cstring(), worker.cstring())
    end
    _phase.event_log_checkpoint_complete(worker, checkpoint_id)

  be event_log_id_written(worker: WorkerName, checkpoint_id: CheckpointId) =>
    """
    This is called once the EventLog on this worker has persisted this
    checkpoint id.
    """
    _phase.event_log_id_written(worker, checkpoint_id)

  be inform_recovering_worker(w: WorkerName, conn: TCPConnection) =>
    """
    Tell a recovering worker what the last complete checkpoint was.
    """
    try
      @printf[I32]("Sending recovery data to %\n".cstring(),
        w.cstring())
      let msg = ChannelMsgEncoder.inform_recovering_worker(_worker_name,
        _last_complete_checkpoint_id, _auth)?
      conn.writev(msg)
    else
      Fail()
    end

  // fun ref event_log_write_checkpoint_id(checkpoint_id: CheckpointId,
  //   token: CheckpointBarrierToken, repeating: Bool)
  fun ref event_log_write_checkpoint_id(checkpoint_id: CheckpointId,
    token: CheckpointBarrierToken)
  =>
    ifdef "checkpoint_trace" then
      @printf[I32]("CheckpointInitiator: event_log_write_checkpoint_id()\n"
        .cstring())
    end
    ifdef "resilience" then
      let promise = Promise[CheckpointId]
      promise.next[None](
        recover this~event_log_id_written(_worker_name) end)
      _event_log.write_checkpoint_id(checkpoint_id, promise)

      try
        let msg = ChannelMsgEncoder.event_log_write_checkpoint_id(
          checkpoint_id, _worker_name, _auth)?
        for w in _workers.values() do
          if w != _worker_name then
            _connections.send_control(w, msg)
          end
        end
      else
        Fail()
      end
    end

    _phase = _WaitingForEventLogIdWrittenPhase(token, this)

  fun ref checkpoint_complete(token: BarrierToken) =>
    """
    This is called once all workers in the cluster have committed the
    checkpoitn id for this token.
    """
    ifdef "resilience" then
      match token
      | let st: CheckpointBarrierToken =>
        if st.id != _current_checkpoint_id then Fail() end
        ifdef "checkpoint_trace" then
          @printf[I32]("CheckpointInitiator: Checkpoint %s is complete!\n".
            cstring(), st.id.string().cstring())
        end
        _save_checkpoint_id(st.id, _last_rollback_id)
        _last_complete_checkpoint_id = st.id
        _propagate_checkpoint_complete(st.id)
        try
          let msg = ChannelMsgEncoder.commit_checkpoint_id(st.id,
            _last_rollback_id, _worker_name, _auth)?
          _connections.send_control_to_cluster(msg)
        else
          Fail()
        end

        // Prepare for next checkpoint
        if _worker_name == _primary_worker then
          ifdef "checkpoint_trace" then
            @printf[I32]("Creating _InitiateCheckpoint timer for future checkpoint %s\n".cstring(),
              (_current_checkpoint_id + 1).string().cstring())
          end
          _phase = _WaitingCheckpointInitiatorPhase
          _phase.start_checkpoint_timer(_time_between_checkpoints, this)
        end
      else
        Fail()
      end
    else
      Fail()
    end

  fun _propagate_checkpoint_complete(checkpoint_id: CheckpointId) =>
    for sc in _source_coordinators.values() do
      sc.checkpoint_complete(checkpoint_id)
    end
    for s in _sinks.values() do
      s.checkpoint_complete(checkpoint_id)
    end

  be prepare_for_rollback() =>
    if _worker_name == _primary_worker then
      _phase = _RollbackCheckpointInitiatorPhase(this)
    end
    _clear_pending_checkpoints()

  fun ref _clear_pending_checkpoints() =>
    _checkpoint_group = _checkpoint_group + 1
    _timers.dispose()
    _timers = Timers

  be initiate_rollback(
    recovery_promise: Promise[CheckpointRollbackBarrierToken],
    worker: WorkerName)
  =>
    ifdef "resilience" then
      _phase.initiate_rollback(recovery_promise, worker, this)
    end

  fun ref finish_initiating_rollback(
    recovery_promise: Promise[CheckpointRollbackBarrierToken],
    worker: WorkerName)
  =>
    if (_primary_worker == _worker_name) then
      if _last_complete_checkpoint_id == 0 then
        @printf[I32]("No checkpoints were taken!\n".cstring())
        Fail()
      end

      _clear_pending_checkpoints()

      let rollback_id = _last_rollback_id + 1
      _last_rollback_id = rollback_id

      ifdef "checkpoint_trace" then
        @printf[I32](("CheckpointInitiator: initiate_rollback %s on " +
          " behalf of %s\n").cstring(), rollback_id.string().cstring(),
          worker.cstring())
      end

      let token = CheckpointRollbackBarrierToken(rollback_id,
        _last_complete_checkpoint_id)
      if _current_checkpoint_id < _last_complete_checkpoint_id then
        _current_checkpoint_id = _last_complete_checkpoint_id
      end
      let barrier_promise = Promise[BarrierToken]
      barrier_promise.next[None]({(t: BarrierToken) =>
        match t
        | let srbt: CheckpointRollbackBarrierToken =>
          recovery_promise(srbt)
          _self.rollback_complete(srbt.rollback_id)
        else
          Fail()
        end
      })
      let resume_token = CheckpointRollbackResumeBarrierToken(rollback_id,
        _last_complete_checkpoint_id)
      _barrier_coordinator.inject_blocking_barrier(token, barrier_promise,
        resume_token)

      // Inform cluster we've initiated recovery
      match _recovery
      | let r: Recovery => r.recovery_initiated_at_worker(worker, token)
      end
      try
        let msg = ChannelMsgEncoder.recovery_initiated(token, worker, _auth)?
        _connections.send_control_to_cluster(msg)
      else
        Fail()
      end
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
    ifdef "resilience" then
      _last_rollback_id = rollback_id
      _save_checkpoint_id(_last_complete_checkpoint_id, rollback_id)
    end

  be commit_checkpoint_id(checkpoint_id: CheckpointId, rollback_id: RollbackId,
    sender: WorkerName)
  =>
    if sender == _primary_worker then
      _commit_checkpoint_id(checkpoint_id, rollback_id)
      _propagate_checkpoint_complete(checkpoint_id)
    else
      @printf[I32](("CommitCheckpointIdMsg received from worker that is " +
        "not the primary for checkpoints. Ignoring.\n").cstring())
    end

  fun ref _commit_checkpoint_id(checkpoint_id: CheckpointId,
    rollback_id: RollbackId)
  =>
    ifdef "resilience" then
      _current_checkpoint_id = checkpoint_id
      _last_complete_checkpoint_id = checkpoint_id
      _last_rollback_id = rollback_id
      _save_checkpoint_id(checkpoint_id, rollback_id)
    end

  fun ref _save_checkpoint_id(checkpoint_id: CheckpointId,
    rollback_id: RollbackId)
  =>
    try
      ifdef "checkpoint_trace" then
        @printf[I32]("Saving CheckpointId %s and RollbackId %s\n".cstring(),
          checkpoint_id.string().cstring(), rollback_id.string().cstring())
      end
      let filepath = FilePath(_auth, _checkpoint_id_file)?
      // TODO: We'll need to rotate this file since it will grow.
      // !TODO!: Hold onto this in a field so we don't open it every time.
      let file = AsyncJournalledFile(filepath, _the_journal, _auth,
        _do_local_file_io)
      file.seek_end(0)

      _wb.u64_be(checkpoint_id)
      _wb.u64_be(rollback_id)
      // TODO: We can't be sure we actually wrote all this out given the
      // way this code works.
      file.writev(_wb.done())
      file.sync()
      file.dispose()
    else
      @printf[I32]("Error saving checkpoint id!\n".cstring())
      Fail()
    end

  fun ref _load_latest_checkpoint_id() =>
    ifdef "resilience" then
      (let checkpoint_id, let rollback_id) =
        LatestCheckpointId.read(_auth, _checkpoint_id_file)
      _current_checkpoint_id = checkpoint_id
      _last_complete_checkpoint_id = checkpoint_id
      _last_rollback_id = rollback_id
    end

  be dispose() =>
    @printf[I32]("Shutting down CheckpointInitiator\n".cstring())
    _clear_pending_checkpoints()
    _phase = _DisposedCheckpointInitiatorPhase

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
        let checkpoint_id = r.u64_be()?
        let rollback_id = r.u64_be()?
        (checkpoint_id, rollback_id)
      else
        @printf[I32]("No latest checkpoint id in recovery file.\n".cstring())
        Fail()
        (0, 0)
      end
    else
      @printf[I32]("Error reading checkpoint id recovery file!".cstring())
      Fail()
      (0, 0)
    end

class _InitiateCheckpoint is TimerNotify
  let _si: CheckpointInitiator
  let _checkpoint_group: USize

  new iso create(si: CheckpointInitiator, checkpoint_group: USize) =>
    _si = si
    _checkpoint_group = checkpoint_group

  fun ref apply(timer: Timer, count: U64): Bool =>
    _si.initiate_checkpoint(_checkpoint_group)
    false
