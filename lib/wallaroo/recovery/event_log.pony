use "buffered"
use "collections"
use "files"
use "wallaroo/core"
use "wallaroo/fail"
use "wallaroo/initialization"
use "wallaroo/messages"
use "wallaroo/ent/w_actor"
use "wallaroo/topology"

interface tag Resilient
  be replay_log_entry(uid: U128, frac_ids: FractionalMessageId,
    statechange_id: U64, payload: ByteSeq)
  be log_flushed(low_watermark: SeqId)

class val EventLogConfig
  let log_dir: (FilePath | AmbientAuth | None)
  let filename: (String val | None)
  let logging_batch_size: USize
  let backend_file_length: (USize | None)
  let log_rotation: Bool
  let suffix: String

  new val create(log_dir': (FilePath | AmbientAuth | None) = None,
    filename': (String val | None) = None,
    logging_batch_size': USize = 10,
    backend_file_length': (USize | None) = None,
    log_rotation': Bool = false,
    suffix': String = ".evlog")
  =>
    filename = filename'
    log_dir = log_dir'
    logging_batch_size = logging_batch_size'
    backend_file_length = backend_file_length'
    log_rotation = log_rotation'
    suffix = suffix'

actor EventLog
  let _origins: Map[U128, Resilient] = _origins.create()
  let _backend: Backend
  let _replay_complete_markers: Map[U64, Bool] =
    _replay_complete_markers.create()
  let _config: EventLogConfig
  var num_encoded: USize = 0
  var _flush_waiting: USize = 0
  var _initialized: Bool = false
  var _recovery: (Recovery | None) = None
  var _steps_to_snapshot: SetIs[U128] = _steps_to_snapshot.create()
  var _router_registry: (RouterRegistry | None) = None
  var _rotating: Bool = false

  new create(event_log_config: EventLogConfig = EventLogConfig()) =>
    _config = event_log_config
    _backend = match _config.filename
      | let f: String val =>
        try
          if _config.log_rotation then
            match _config.log_dir
            | let ld: FilePath =>
              RotatingFileBackend(ld, f, _config.suffix, this,
                _config.backend_file_length)
            else
              Fail()
              DummyBackend
            end
          else
            match _config.log_dir
            | let ld: FilePath =>
              FileBackend(FilePath(ld, f), this)
            | let ld: AmbientAuth =>
              FileBackend(FilePath(ld, f), this)
            else
              Fail()
              DummyBackend
            end
          end
        else
          DummyBackend
        end
      else
        DummyBackend
      end

  be set_router_registry(router_registry: RouterRegistry) =>
    _router_registry = router_registry

  be start_pipeline_logging(initializer: LocalTopologyInitializer) =>
    _initialized = true
    initializer.report_event_log_ready_to_work()

  be start_actor_system_logging(initializer: WActorInitializer) =>
    _initialized = true

  be start_log_replay(recovery: Recovery) =>
    _recovery = recovery
    _backend.start_log_replay()

  be log_replay_finished() =>
    match _recovery
    | let r: Recovery =>
      r.log_replay_finished()
    else
      Fail()
    end

  be replay_log_entry(origin_id: U128,
    uid: U128, frac_ids: FractionalMessageId,
    statechange_id: U64, payload: ByteSeq val)
  =>
    try
      _origins(origin_id).replay_log_entry(uid, frac_ids,
        statechange_id, payload)
    else
      @printf[I32]("FATAL: Unable to replay event log, because a replay buffer has disappeared".cstring())
      Fail()
    end

  be register_origin(origin: Resilient, id: U128) =>
    _origins(id) = origin

  be queue_log_entry(origin_id: U128, uid: U128, frac_ids: FractionalMessageId,
    statechange_id: U64, seq_id: U64,
    payload: Array[ByteSeq] iso)
  =>
    ifdef "resilience" then
      // add to backend buffer after encoding
      // encode right away to amortize encoding cost per entry when received
      // as opposed to when writing a batch to disk
      _backend.encode_entry((false, origin_id, uid, frac_ids, statechange_id,
        seq_id, consume payload))

      num_encoded = num_encoded + 1

      if num_encoded == _config.logging_batch_size then
        //write buffer to disk
        write_log()
      end
    else
      None
    end

  fun ref write_log() =>
    try
      num_encoded = 0

      // write buffer to disk
      _backend.write()
    else
      @printf[I32]("error writing log entries to disk!\n".cstring())
      Fail()
    end

  be flush_buffer(origin_id: U128, low_watermark:U64) =>
    ifdef "trace" then
      @printf[I32]("flush_buffer for id: %d\n\n".cstring(), origin_id)
    end

    try
      // Add low watermark ack to buffer
      _backend.encode_entry((true, origin_id, 0, None, 0, low_watermark,
        recover Array[ByteSeq] end))

      num_encoded = num_encoded + 1
      _flush_waiting = _flush_waiting + 1
      //write buffer to disk
      write_log()

      // if (_flush_waiting % 50) == 0 then
      //   //sync any written data to disk
      //   _backend.sync()
      //   _backend.datasync()
      // end

      _origins(origin_id).log_flushed(low_watermark)
    else
      @printf[I32]("Errror writing/flushing/syncing ack to disk!\n".cstring())
      Fail()
    end

  be snapshot_state(origin_id: U128, uid: U128,
    statechange_id: U64, seq_id: U64,
    payload: Array[ByteSeq] iso)
  =>
    ifdef "trace" then
      @printf[I32]("Snapshotting state for step %lu\n".cstring(), origin_id)
    end
    if _steps_to_snapshot.contains(origin_id) then
      _steps_to_snapshot.unset(origin_id)
    else
      @printf[I32](("Error writing snapshot to logfile. StepId not in set of " +
        "expected steps!\n").cstring())
      Fail()
    end
    queue_log_entry(origin_id, uid, None, statechange_id, seq_id,
      consume payload)
    if _steps_to_snapshot.size() == 0 then
      rotation_complete()
    end

  be start_rotation() =>
    if not _rotating then
      _rotating = true
      match _router_registry
      | let r: RouterRegistry =>
        r.rotate_log_file()
      else
        Fail()
      end
    end

  be rotate_file(steps: Map[U128, Step] val) =>
    @printf[I32]("Snapshotting %d steps to new log file.\n".cstring(),
      steps.size())
    match _router_registry
    | None =>
      Fail()
    end
    _rotate_file()
    _steps_to_snapshot = _steps_to_snapshot.create()
    for v in steps.keys() do
      _steps_to_snapshot.set(v)
    end
    for s in steps.values() do
      s.snapshot_state()
    end

  fun ref _rotate_file() =>
    try
      match _backend
      | let b: RotatingFileBackend => b.rotate_file()
      else
        @printf[I32](("Unsupported operation requested on log Backend: " +
                      "'rotate_file'. Request ignored.\n").cstring())
      end
    else
      @printf[I32]("Error rotating log file!\n".cstring())
      Fail()
    end

  fun ref rotation_complete() =>
    @printf[I32]("Steps snapshotting to new log file complete.\n".cstring())
    _rotating = false
    match _router_registry
    | let r: RouterRegistry => r.rotation_complete()
    else
      Fail()
    end
