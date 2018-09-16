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
use "wallaroo/core/common"
use "wallaroo/core/initialization"
use "wallaroo/core/messages"
use "wallaroo/core/source"
use "wallaroo/core/topology"
use "wallaroo/ent/barrier"
use "wallaroo/ent/router_registry"
use "wallaroo/ent/checkpoint"
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

  new val create(log_dir': (FilePath | AmbientAuth | None) = None,
    filename': (String val | None) = None,
    logging_batch_size': USize = 10,
    backend_file_length': (USize | None) = None,
    log_rotation': Bool = false,
    suffix': String = ".evlog",
    is_recovering': Bool = false)
  =>
    filename = filename'
    log_dir = log_dir'
    logging_batch_size = logging_batch_size'
    backend_file_length = backend_file_length'
    log_rotation = log_rotation'
    suffix = suffix'
    is_recovering = is_recovering'

actor EventLog
  let _auth: AmbientAuth
  let _worker_name: WorkerName
  let _resilients: Map[RoutingId, Resilient] = _resilients.create()
  var _backend: Backend = EmptyBackend
  let _replay_complete_markers: Map[U64, Bool] =
    _replay_complete_markers.create()
  let _config: EventLogConfig
  var _barrier_initiator: (BarrierInitiator | None) = None
  var _checkpoint_initiator: (CheckpointInitiator | None) = None
  var num_encoded: USize = 0
  var _flush_waiting: USize = 0
  //!@ I don't think we need this
  var _initialized: Bool = false
  var _recovery: (Recovery | None) = None
  var _resilients_to_checkpoint: SetIs[RoutingId] =
    _resilients_to_checkpoint.create()
  var _rotating: Bool = false
  //!@ What do we do with this?
  var _backend_bytes_after_checkpoint: USize

  var _phase: _EventLogPhase = _InitialEventLogPhase

  var _log_rotation_id: LogRotationId = 0

  var _pending_sources: SetIs[(RoutingId, Source)] = _pending_sources.create()

  new create(auth: AmbientAuth, worker: WorkerName,
    event_log_config: EventLogConfig = EventLogConfig())
  =>
    _auth = auth
    _worker_name = worker
    _config = event_log_config
    _backend_bytes_after_checkpoint = _backend.bytes_written()
    _backend = match _config.filename
      | let f: String val =>
        try
          if _config.log_rotation then
            match _config.log_dir
            | let ld: FilePath =>
              RotatingFileBackend(ld, f, _config.suffix, this,
                _config.backend_file_length)?
            else
              Fail()
              DummyBackend(this)
            end
          else
            match _config.log_dir
            | let ld: FilePath =>
              FileBackend(FilePath(ld, f)?, this)
            | let ld: AmbientAuth =>
              FileBackend(FilePath(ld, f)?, this)
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
    // @printf[I32]("!@ EventLog register_resilient %s\n".cstring(), id.string().cstring())
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
      end
    else
      source.first_checkpoint_complete()
    end

  be unregister_resilient(id: RoutingId, resilient: Resilient) =>
    // @printf[I32]("!@ EventLog unregister_resilient %s\n".cstring(), id.string().cstring())
    try
      _resilients.remove(id)?
      _phase.unregister_resilient(id, resilient)
    else
      @printf[I32]("Attempted to unregister non-registered resilient\n"
        .cstring())
    end

  /////////////////
  // CHECKPOINT
  /////////////////
  be initiate_checkpoint(checkpoint_id: CheckpointId,
    promise: Promise[CheckpointId])
  =>
    @printf[I32]("!@ EventLog: initiate_checkpoint\n".cstring())
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
    for p in pending_checkpoint_states.values() do
      @printf[I32]("!@ EventLog: Process pending checkpoint_state for resilient %s for checkpoint %s\n".cstring(), p.resilient_id.string().cstring(), checkpoint_id.string().cstring())
      _phase.checkpoint_state(p.resilient_id, checkpoint_id, p.payload)
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
    // @printf[I32]("!@ EventLog: write_checkpoint_id\n".cstring())
    _backend.encode_checkpoint_id(checkpoint_id)
    for (r_id, s) in _pending_sources.values() do
      s.first_checkpoint_complete()
      _resilients(r_id) = s
    end
    _pending_sources.clear()
    _phase.checkpoint_id_written(checkpoint_id, promise)

//!@
  // fun ref update_normal_event_log_checkpoint_id(checkpoint_id: CheckpointId)
  // =>
  //   // We need to update the next checkpoint id we're expecting.
  //   //!@ This should go through a phase
  //   _phase = _WaitingForCheckpointInitiationEventLogPhase(
  //  checkpoint_id + 1, this)

  fun ref checkpoint_id_written(checkpoint_id: CheckpointId) =>
    // @printf[I32]("!@ EventLog: checkpoint_complete()\n".cstring())
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
      //!@ Currently we are immediately moving on without checking for other
      //worker acks. Is this ok?
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
      //!@ Update message
      @printf[I32](("Can't find resilient for rollback data\n").cstring())
      @printf[I32](("!@ Can't find resilient %s for rollback data\n").cstring(), resilient_id.string().cstring())
      Fail()
    end

  be ack_rollback(resilient_id: RoutingId) =>
    _phase.ack_rollback(resilient_id)

  fun ref rollback_complete(checkpoint_id: CheckpointId) =>
    _phase = _WaitingForCheckpointInitiationEventLogPhase(checkpoint_id + 1,
      this)




  //!@
  /////////////
  // STUFF
  ////////////
    //!@
  // be start_log_replay(recovery: Recovery) =>
  //   _recovery = recovery
  //   _backend.start_log_replay()

  be log_replay_finished() =>
    //!@
    None
    //!@
    // for r in _resilients.values() do
    //   r.log_replay_finished()
    // end

    // match _recovery
    // | let r: Recovery =>
    //   r.log_replay_finished()
    // else
    //   Fail()
    // end

  be replay_log_entry(resilient_id: RoutingId,
    uid: U128, frac_ids: FractionalMessageId,
    statechange_id: U64, payload: ByteSeq val)
  =>
    None
    //!@
    // try
    //   _resilients(resilient_id)?.replay_log_entry(uid, frac_ids,
    //     statechange_id, payload)
    // else
    //   @printf[I32](("FATAL: Unable to replay event log, because a replay " +
    //     "buffer has disappeared").cstring())
    //   Fail()
    // end

  be initialize_seq_ids(seq_ids: Map[RoutingId, SeqId] val) =>
    //!@
    None
    // for (resilient_id, seq_id) in seq_ids.pairs() do
    //   try
    //     _resilients(resilient_id)?.initialize_seq_id_on_recovery(seq_id)
    //   else
    //     @printf[I32](("Could not initialize seq id " + seq_id.string() +
    //       ". Resilient " + resilient_id.string() + " does not exist\n")
    //       .cstring())
    //     Fail()
    //   end
    // end



  fun ref write_log() =>
    try
      num_encoded = 0

      // write buffer to disk
      _backend.write()?
    else
      @printf[I32]("error writing log entries to disk!\n".cstring())
      Fail()
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

