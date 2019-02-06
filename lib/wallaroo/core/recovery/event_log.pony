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
use "promises"
use "wallaroo/core/common"
use "wallaroo/core/initialization"
use "wallaroo/core/messages"
use "wallaroo/core/source"
use "wallaroo/core/topology"
use "wallaroo/core/barrier"
use "wallaroo/core/router_registry"
use "wallaroo/core/checkpoint"
use "wallaroo_labs/mort"


trait tag Resilient
  be prepare_for_rollback()
  be rollback(payload: ByteSeq val, event_log: EventLog,
    checkpoint_id: CheckpointId)

class val EventLogConfig
  let log_dir: (FilePath | AmbientAuth | None)
  let filename: (String val | None)
  let logging_batch_size: USize
  let backend_file_length: (USize | None)
  let log_rotation: Bool
  let suffix: String
  let is_recovering: Bool
  let do_local_file_io: Bool
  let worker_name: String
  let dos_servers: Array[(String,String)] val

  new val create(log_dir': (FilePath | AmbientAuth | None) = None,
    filename': (String val | None) = None,
    logging_batch_size': USize = 10,
    backend_file_length': (USize | None) = None,
    log_rotation': Bool = false,
    suffix': String = ".evlog",
    is_recovering': Bool = false,
    do_local_file_io': Bool = true,
    worker_name': String = "unknown-worker-name",
    dos_servers': Array[(String,String)] val = recover val [] end)
  =>
    filename = filename'
    log_dir = log_dir'
    logging_batch_size = logging_batch_size'
    backend_file_length = backend_file_length'
    log_rotation = log_rotation'
    suffix = suffix'
    is_recovering = is_recovering'
    do_local_file_io = do_local_file_io'
    worker_name = worker_name'
    dos_servers = dos_servers'

actor EventLog is SimpleJournalAsyncResponseReceiver
  let _auth: AmbientAuth
  let _worker_name: WorkerName
  let _resilients: Map[RoutingId, Resilient] = _resilients.create()
  var _backend: Backend = EmptyBackend
  let _replay_complete_markers: Map[U64, Bool] =
    _replay_complete_markers.create()
  let _config: EventLogConfig
  let _the_journal: SimpleJournal
  var _barrier_initiator: (BarrierInitiator | None) = None
  var _checkpoint_initiator: (CheckpointInitiator | None) = None
  var num_encoded: USize = 0
  var _flush_waiting: USize = 0
  var _initialized: Bool = false
  var _recovery: (Recovery | None) = None
  var _resilients_to_checkpoint: SetIs[RoutingId] =
    _resilients_to_checkpoint.create()
  var _rotating: Bool = false
  var _backend_bytes_after_checkpoint: USize
  var _disposed: Bool = false

  var _phase: _EventLogPhase = _InitialEventLogPhase

  var _log_rotation_id: LogRotationId = 0

  var _pending_sources: SetIs[(RoutingId, Source)] = _pending_sources.create()

  new create(auth: AmbientAuth, worker: WorkerName, the_journal: SimpleJournal,
    event_log_config: EventLogConfig = EventLogConfig())
  =>
    _auth = auth
    _worker_name = worker
    _config = event_log_config
    _the_journal = the_journal
    _backend_bytes_after_checkpoint = _backend.bytes_written()
    _backend = match _config.filename
      | let f: String val =>
        try
          if _config.log_rotation then
            match _config.log_dir
            | let ld: FilePath =>
              RotatingFileBackend(ld, f, _config.suffix, this,
                _config.backend_file_length, _the_journal, _auth,
                _config.worker_name, _config.do_local_file_io,
                _config.dos_servers
                where rotation_enabled = true)?
            else
              Fail()
              DummyBackend(this)
            end
          else
            match _config.log_dir
            | let ld: FilePath =>
              RotatingFileBackend(ld, f, "", this,
                _config.backend_file_length, _the_journal, _auth,
                _config.worker_name, _config.do_local_file_io,
                _config.dos_servers
                where rotation_enabled = false)?
            | let ld: AmbientAuth =>
              RotatingFileBackend(FilePath(ld, f)?, f, "", this,
                _config.backend_file_length, _the_journal, _auth,
                _config.worker_name, _config.do_local_file_io,
                _config.dos_servers
                where rotation_enabled = false)?
            else
              Fail()
              DummyBackend(this)
            end
          end
        else
          DummyBackend(this)
        end
      else
        DummyBackend(this)
      end
    _phase =
      if _config.is_recovering then
        _RecoveringEventLogPhase(this)
      else
        _WaitingForCheckpointInitiationEventLogPhase(1, this)
      end

  be set_barrier_initiator(barrier_initiator: BarrierInitiator) =>
    _barrier_initiator = barrier_initiator

  be set_checkpoint_initiator(checkpoint_initiator: CheckpointInitiator) =>
    _checkpoint_initiator = checkpoint_initiator

  be quick_initialize(initializer: LocalTopologyInitializer) =>
    _initialized = true
    initializer.report_event_log_ready_to_work()

  be register_resilient(id: RoutingId, resilient: Resilient) =>
    ifdef debug then
      match resilient
      | let s: Source =>
        // TODO: Sources need to be registered via register_source because they
        // can come into and out of existence. Make them static to avoid this.
        Fail()
      end
    end
    _resilients(id) = resilient

  be register_resilient_source(id: RoutingId, source: Source) =>
    ifdef "resilience" then
      if _initialized == true then
        _pending_sources.set((id, source))
      else
        source.first_checkpoint_complete()
        _resilients(id) = source
      end
    else
      source.first_checkpoint_complete()
      _resilients(id) = source
    end

  be unregister_resilient(id: RoutingId, resilient: Resilient) =>
    try
      _resilients.remove(id)?
      _phase.unregister_resilient(id, resilient)
    else
      @printf[I32]("Attempted to unregister non-registered resilient\n"
        .cstring())
    end

  be dispose() =>
    match _phase
    | let delp: _DisposedEventLogPhase => None
    else
      @printf[I32]("EventLog: dispose\n".cstring())
      _backend.dispose()
      _disposed = true
      _phase = _DisposedEventLogPhase
    end

  /////////////////
  // CHECKPOINT
  /////////////////
  be initiate_checkpoint(checkpoint_id: CheckpointId,
    promise: Promise[CheckpointId])
  =>
    ifdef "checkpoint_trace" then
      @printf[I32]("EventLog: initiate_checkpoint\n".cstring())
    end
    _phase.initiate_checkpoint(checkpoint_id, promise, this)

  be checkpoint_state(resilient_id: RoutingId, checkpoint_id: CheckpointId,
    payload: Array[ByteSeq] val)
  =>
    _phase.checkpoint_state(resilient_id, checkpoint_id, payload)

  fun ref _initiate_checkpoint(checkpoint_id: CheckpointId,
    promise: Promise[CheckpointId],
    pending_checkpoint_states: Array[_QueuedCheckpointState] =
      Array[_QueuedCheckpointState])
  =>
    _phase = _CheckpointEventLogPhase(this, checkpoint_id, promise,
      _resilients)
    if pending_checkpoint_states.size() == 0 then
      @printf[I32]("QQQ: %s %d\n".cstring(), __loc.method_name().cstring(), __loc.line())
      _phase.check_completion()
    else
      for p in pending_checkpoint_states.values() do
        ifdef "checkpoint_trace" then
          @printf[I32](("EventLog: Process pending checkpoint_state for " +
            "resilient %s for checkpoint %s\n").cstring(),
            p.resilient_id.string().cstring(),
            checkpoint_id.string().cstring())
        end
        _phase.checkpoint_state(p.resilient_id, checkpoint_id, p.payload)
      end
    end

  fun ref _checkpoint_state(resilient_id: RoutingId,
    checkpoint_id: CheckpointId, payload: Array[ByteSeq] val)
  =>
    if payload.size() > 0 then
      _queue_log_entry(resilient_id, checkpoint_id, payload)
    end
    _phase.state_checkpointed(resilient_id)

  fun ref _queue_log_entry(resilient_id: RoutingId,
    checkpoint_id: CheckpointId, payload: Array[ByteSeq] val,
    force_write: Bool = false)
  =>
    ifdef "resilience" then
      // add to backend buffer after encoding
      // encode right away to amortize encoding cost per entry when received
      // as opposed to when writing a batch to disk
      _backend.encode_entry(resilient_id, checkpoint_id, payload)

      num_encoded = num_encoded + 1

      if (num_encoded == _config.logging_batch_size) or force_write then
        //write buffer to disk
        write_log()
      end
    else
      None
    end

  fun ref state_checkpoints_complete(checkpoint_id: CheckpointId) =>
    _phase = _WaitingForWriteIdEventLogPhase(this, checkpoint_id)

  be write_initial_checkpoint_id(checkpoint_id: CheckpointId) =>
    _phase.write_initial_checkpoint_id(checkpoint_id)

  fun ref _write_initial_checkpoint_id(checkpoint_id: CheckpointId) =>
    _backend.encode_checkpoint_id(checkpoint_id)
    checkpoint_id_written(checkpoint_id)

  be write_checkpoint_id(checkpoint_id: CheckpointId,
    promise: Promise[CheckpointId])
  =>
    _phase.write_checkpoint_id(checkpoint_id, promise)

  fun ref _write_checkpoint_id(checkpoint_id: CheckpointId,
    promise: Promise[CheckpointId])
  =>
    ifdef "checkpoint_trace" then
      @printf[I32]("EventLog: write_checkpoint_id %s!!\n".cstring(),
        checkpoint_id.string().cstring())
    end
    _backend.encode_checkpoint_id(checkpoint_id)
    for (r_id, s) in _pending_sources.values() do
      s.first_checkpoint_complete()
      _resilients(r_id) = s
    end
    _pending_sources.clear()
    _phase.checkpoint_id_written(checkpoint_id, promise)

  fun ref checkpoint_id_written(checkpoint_id: CheckpointId) =>
    write_log()
    _phase = _WaitingForCheckpointInitiationEventLogPhase(checkpoint_id + 1,
      this)

  /////////////////
  // ROLLBACK
  /////////////////
  be prepare_for_rollback(origin: (Recovery | Promise[None]),
    checkpoint_initiator: CheckpointInitiator)
  =>
    checkpoint_initiator.prepare_for_rollback()
    for r in _resilients.values() do
      r.prepare_for_rollback()
    end
    match origin
    | let r: Recovery =>
      // !TODO!: Currently we are immediately moving on without checking for
      // other worker acks. Is this ok?
      r.rollback_prep_complete()
    | let p: Promise[None] =>
      p(None)
    end

  be initiate_rollback(token: CheckpointRollbackBarrierToken,
    promise: Promise[CheckpointRollbackBarrierToken])
  =>
    _phase = _RollbackEventLogPhase(this, token, promise)

    // If we have no resilients on this worker for some reason, then we
    // should abort rollback early.
    if _resilients.size() > 0 then
      let entries = _backend.start_rollback(token.checkpoint_id)
      if entries == 0 then
        _phase.complete_early()
      end
    else
      _phase.complete_early()
    end

  fun ref expect_rollback_count(count: USize) =>
    _phase.expect_rollback_count(count)

  fun ref rollback_from_log_entry(resilient_id: RoutingId,
    payload: ByteSeq val, checkpoint_id: CheckpointId)
  =>
    try
      _resilients(resilient_id)?.rollback(payload, this, checkpoint_id)
    else
      @printf[I32](("Can't find resilient %s for rollback data\n").cstring(),
        resilient_id.string().cstring())
      Fail()
    end

  be ack_rollback(resilient_id: RoutingId) =>
    _phase.ack_rollback(resilient_id)

  fun ref rollback_complete(checkpoint_id: CheckpointId) =>
    _phase = _WaitingForCheckpointInitiationEventLogPhase(checkpoint_id + 1,
      this)










  fun ref write_log() =>
    try
      num_encoded = 0

      // write buffer to disk
      _backend.write()?
    else
      if not _disposed then
        @printf[I32]("error writing log entries to disk!\n".cstring())
        Fail()
      end
    end

  be start_rotation() =>
    _start_rotation()

  fun ref _start_rotation() =>
    if _rotating then
      @printf[I32](("Event log rotation already ongoing. Rotate log request "
        + "ignored.\n").cstring())
    elseif _backend.bytes_written() > _backend_bytes_after_checkpoint then
      @printf[I32]("Starting event log rotation.\n".cstring())
      _rotating = true
      _log_rotation_id = _log_rotation_id + 1
      let rotation_promise = Promise[BarrierToken]
      rotation_promise.next[None](recover this~rotate_file() end)
      try
        (_barrier_initiator as BarrierInitiator).inject_blocking_barrier(
          LogRotationBarrierToken(_log_rotation_id, _worker_name),
            rotation_promise, LogRotationResumeBarrierToken(_log_rotation_id,
            _worker_name))
      else
        Fail()
      end
    else
      @printf[I32](("Event log does not contain new data. Rotate log request"
        + " ignored.\n").cstring())
    end

  be rotate_file(token: BarrierToken) =>
    match token
    | let lbt: LogRotationBarrierToken =>
      _rotate_file()
    else
      Fail()
    end

  fun ref _rotate_file() =>
    try
      match _backend
      | let b: RotatingFileBackend =>
        ifdef debug then
          @printf[I32]("EventLog: Rotating log file.\n".cstring())
        end
        b.rotate_file()?
      else
        @printf[I32](("Unsupported operation requested on log Backend: " +
          "'rotate_file'. Request ignored.\n").cstring())
      end
    else
      @printf[I32]("Error rotating log file!\n".cstring())
      Fail()
    end

  fun ref rotation_complete() =>
    ifdef debug then
      @printf[I32]("EventLog: Rotating log file complete.\n".cstring())
    end
    try
      _backend.sync()?
      _backend.datasync()?
      _backend_bytes_after_checkpoint = _backend.bytes_written()
      let rotation_resume_promise = Promise[BarrierToken]
      try
        (_barrier_initiator as BarrierInitiator).inject_barrier(
          LogRotationResumeBarrierToken(_log_rotation_id, _worker_name),
            rotation_resume_promise)
      else
        Fail()
      end
    else
      Fail()
    end
    _rotating = false

 // TODO: If we're using RotatingFileBackend, then knowing the
 // identity of the failed journal isn't really helpful, is it?

  be async_io_ok(j: SimpleJournal, optag: USize) =>
      // @printf[I32]("EventLog: TODO async_io_ok journal %d tag %d\n".cstring(), j, optag)
      None

  be async_io_error(j: SimpleJournal, optag: USize) =>
      @printf[I32]("EventLog: TODO async_io_error journal %d tag %d\n".cstring(),
      j, optag)
    Fail()
