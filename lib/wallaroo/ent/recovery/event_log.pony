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
  let _worker_name: WorkerName
  let _resilients: Map[RoutingId, Resilient] = _resilients.create()
  var _backend: Backend = EmptyBackend
  let _replay_complete_markers: Map[U64, Bool] =
    _replay_complete_markers.create()
  let _config: EventLogConfig
  var _barrier_initiator: (BarrierInitiator | None) = None
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

  new create(worker: WorkerName,
    event_log_config: EventLogConfig = EventLogConfig())
  =>
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
        _NormalEventLogPhase(1, this)
      end

  be set_barrier_initiator(barrier_initiator: BarrierInitiator) =>
    _barrier_initiator = barrier_initiator

  be quick_initialize(initializer: LocalTopologyInitializer) =>
    _initialized = true
    initializer.report_event_log_ready_to_work()

  be register_resilient(id: RoutingId, resilient: Resilient) =>
    // @printf[I32]("!@ EventLog register_resilient %s\n".cstring(), id.string().cstring())
    _resilients(id) = resilient

  be unregister_resilient(id: RoutingId, resilient: Resilient) =>
    // @printf[I32]("!@ EventLog unregister_resilient %s\n".cstring(), id.string().cstring())
    try
      _resilients.remove(id)?
    else
      @printf[I32]("Attempted to unregister non-registered resilient\n"
        .cstring())
    end

  /////////////////
  // CHECKPOINT
  /////////////////
  be initiate_checkpoint(checkpoint_id: CheckpointId, action: Promise[CheckpointId]) =>
    @printf[I32]("!@ EventLog: initiate_checkpoint\n".cstring())
    _phase.initiate_checkpoint(checkpoint_id, action, this)

  be checkpoint_state(resilient_id: RoutingId, checkpoint_id: CheckpointId,
    payload: Array[ByteSeq] val)
  =>
    _phase.checkpoint_state(resilient_id, checkpoint_id, payload)

  fun ref _initiate_checkpoint(checkpoint_id: CheckpointId,
    action: Promise[CheckpointId])
  =>
    _phase = _CheckpointEventLogPhase(this, checkpoint_id, action)

  fun ref _checkpoint_state(resilient_id: RoutingId, checkpoint_id: CheckpointId,
    payload: Array[ByteSeq] val)
  =>
    _queue_log_entry(resilient_id, checkpoint_id, payload)

  fun ref _queue_log_entry(resilient_id: RoutingId, checkpoint_id: CheckpointId,
    payload: Array[ByteSeq] val, force_write: Bool = false)
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

  be write_initial_checkpoint_id(checkpoint_id: CheckpointId) =>
    _phase.write_initial_checkpoint_id(checkpoint_id)

  be write_checkpoint_id(checkpoint_id: CheckpointId) =>
    _phase.write_checkpoint_id(checkpoint_id)

  fun ref _write_checkpoint_id(checkpoint_id: CheckpointId) =>
    // @printf[I32]("!@ EventLog: write_checkpoint_id\n".cstring())
    _backend.encode_checkpoint_id(checkpoint_id)
    _phase.checkpoint_id_written(checkpoint_id)

  fun ref checkpoint_complete(checkpoint_id: CheckpointId) =>
    // @printf[I32]("!@ EventLog: checkpoint_complete()\n".cstring())
    write_log()
    _phase = _NormalEventLogPhase(checkpoint_id + 1, this)

  /////////////////
  // ROLLBACK
  /////////////////
  be prepare_for_rollback(origin: (Recovery | Promise[None])) =>
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
    action: Promise[CheckpointRollbackBarrierToken])
  =>
    _phase = _RollbackEventLogPhase(this, token, action)

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
    _phase = _NormalEventLogPhase(checkpoint_id + 1, this)




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


  //!@We probably need to be flushing at certain points. Or do we?
  // be flush_buffer(resilient_id: RoutingId, low_watermark: U64) =>
  //   _flush_buffer(resilient_id, low_watermark)

  // fun ref _flush_buffer(resilient_id: RoutingId, low_watermark: U64) =>
  //   ifdef "trace" then
  //     @printf[I32](("flush_buffer for id: " + resilient_id.string() +
  //  "\n\n")
  //       .cstring())
  //   end

    //!@
    // try
    //   // Add low watermark ack to buffer
    //   _backend.encode_entry((true, resilient_id, 0, None, 0, low_watermark,
    //     recover Array[ByteSeq] end))

    //   num_encoded = num_encoded + 1
    //   _flush_waiting = _flush_waiting + 1
    //   //write buffer to disk
    //   write_log()

    //   // if (_flush_waiting % 50) == 0 then
    //   //   //sync any written data to disk
    //   //   _backend.sync()
    //   //   _backend.datasync()
    //   // end

    //   _resilients(resilient_id)?.log_flushed(low_watermark)
    // else
    //   @printf[I32]("Errror writing/flushing/syncing ack to disk!\n"
    //.cstring())
    //   Fail()
    // end


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
      let rotation_action = Promise[BarrierToken]
      rotation_action.next[None](recover this~rotate_file() end)
      try
        (_barrier_initiator as BarrierInitiator).inject_blocking_barrier(
          LogRotationBarrierToken(_log_rotation_id, _worker_name),
            rotation_action, LogRotationResumeBarrierToken(_log_rotation_id,
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
      let rotation_resume_action = Promise[BarrierToken]
      try
        (_barrier_initiator as BarrierInitiator).inject_barrier(
          LogRotationResumeBarrierToken(_log_rotation_id, _worker_name),
            rotation_resume_action)
      else
        Fail()
      end
    else
      Fail()
    end
    _rotating = false

