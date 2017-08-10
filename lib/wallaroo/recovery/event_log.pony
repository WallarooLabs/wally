use "buffered"
use "collections"
use "files"
use "wallaroo/boundary"
use "wallaroo/fail"
use "wallaroo/initialization"
use "wallaroo/invariant"
use "wallaroo/messages"
use "wallaroo/routing"
use "wallaroo/w_actor"
use "debug"

interface tag Resilient
  be replay_log_entry(uid: U128, statechange_id: U64, payload: ByteSeq)
  be log_flushed(low_watermark: SeqId)

//TODO: explain in comment
type LogEntry is (Bool, U128, U128, U64, U64, Array[ByteSeq] iso)

// used to hold a receovered log entry that might need to be replayed on
// recovery
type ReplayEntry is (U128, U128, None, U64, U64, ByteSeq val)

trait Backend
  fun ref sync() ?
  fun ref datasync() ?
  fun ref start_log_replay()
  fun ref write() ?
  fun ref encode_entry(entry: LogEntry)

class DummyBackend is Backend
  new create() => None
  fun ref sync() => None
  fun ref datasync() => None
  fun ref start_log_replay() => None
  fun ref write() => None
  fun ref encode_entry(entry: LogEntry) => None

class FileBackend is Backend
  //a record looks like this:
  // - is_watermark boolean
  // - origin id
  // - seq id (low watermark record ends here)
  // - uid
  // - size of fractional id list
  // - fractional id list (may be empty)
  // - statechange id
  // - payload

  let _file: File iso
  let _filepath: FilePath
  let _event_log: EventLog
  let _writer: Writer iso
  var _replay_log_exists: Bool

  new create(filepath: FilePath, event_log: EventLog,
    file_length: (USize | None) = None) =>
    _writer = recover iso Writer end
    _filepath = filepath
    _replay_log_exists = _filepath.exists()
    _file = recover iso File(filepath) end
    match file_length
    | let len: USize => _file.set_length(len)
    end
    _event_log = event_log

  fun ref start_log_replay() =>
    if _replay_log_exists then
      @printf[I32]("RESILIENCE: Replaying from recovery log file.\n".cstring())

      //replay log to EventLog
      try
        let r = Reader

        //seek beginning of file
        _file.seek_start(0)
        var size = _file.size()

        var num_replayed: USize = 0
        var num_skipped: USize = 0

        // array to hold recovered data temporarily until we've sent it off to
        // be replayed
        var replay_buffer: Array[ReplayEntry val] ref = replay_buffer.create()

        let watermarks: Map[U128, U64] = watermarks.create()

        //start iterating until we reach original EOF
        while _file.position() < size do
          r.append(_file.read(25))
          let is_watermark = r.bool()
          let origin_id = r.u128_be()
          let seq_id = r.u64_be()
          if is_watermark then
            // save last watermark read from file
            watermarks(origin_id) = seq_id
          else
            r.append(_file.read(32))
            let uid = r.u128_be()
            let statechange_id = r.u64_be()
            let payload_length = r.u64_be()
            let payload = recover val
              if payload_length > 0 then
                _file.read(payload_length.usize())
              else
                Array[U8]
              end
            end

            // put entry into temporary recovered buffer
            replay_buffer.push((origin_id, uid, None, statechange_id, seq_id
                               , payload))

          end

          // clear read buffer to free file data read so far
          if r.size() > 0 then
            Fail()
          end
          r.clear()
        end

        // iterate through recovered buffer and replay entries at or below
        // watermark
        for entry in replay_buffer.values() do
          // only replay if at or below watermark
          if entry._5 <= watermarks.get_or_else(entry._1, 0) then
            num_replayed = num_replayed + 1
            _event_log.replay_log_entry(entry._1, entry._2, entry._4, entry._6)
          else
            num_skipped = num_skipped + 1
          end
        end

        @printf[I32]("RESILIENCE: Replayed %d entries from recovery log file.\n"
          .cstring(), num_replayed)
        @printf[I32]("RESILIENCE: Skipped %d entries from recovery log file.\n"
          .cstring(), num_skipped)

        _file.seek_end(0)
        _event_log.log_replay_finished()
      else
        @printf[I32]("Cannot recover state from eventlog\n".cstring())
      end
    else
      @printf[I32]("RESILIENCE: Could not find log file to replay.\n"
        .cstring())
      Fail()
    end

  fun ref write() ?
  =>
    if not _file.writev(recover val _writer.done() end) then
      error
    end

  fun ref encode_entry(entry: LogEntry)
  =>
    (let is_watermark: Bool, let origin_id: U128, let uid: U128,
     let statechange_id: U64, let seq_id: U64,
     let payload: Array[ByteSeq] val) = consume entry

    ifdef "trace" then
      if is_watermark then
        @printf[I32]("Writing Watermark: %d\n".cstring(), seq_id)
      else
        @printf[I32]("Writing Message: %d\n".cstring(), seq_id)
      end
    end

    _writer.bool(is_watermark)
    _writer.u128_be(origin_id)
    _writer.u64_be(seq_id)

    if not is_watermark then
      _writer.u128_be(uid)

      _writer.u64_be(statechange_id)
      var payload_size: USize = 0
      for p in payload.values() do
        payload_size = payload_size + p.size()
      end
      _writer.u64_be(payload_size.u64())
    end

    // write data to write buffer
    _writer.writev(payload)

  fun ref sync() ? =>
    _file.sync()
    match _file.errno()
    | FileOK => None
    else
      error
    end

  fun ref datasync() ? =>
    _file.datasync()
    match _file.errno()
    | FileOK => None
    else
      error
    end

actor EventLog
  let _origins: Map[U128, Resilient] = _origins.create()
  let _logging_batch_size: USize
  let _backend: Backend ref
  let _replay_complete_markers: Map[U64, Bool] =
    _replay_complete_markers.create()
  var num_encoded: USize = 0
  var _flush_waiting: USize = 0
  var _initialized: Bool = false

  var _recovery: (Recovery | None) = None

  new create(env: Env, filename: (String val | None) = None,
    logging_batch_size: USize = 10,
    backend_file_length: (USize | None) = None)
  =>
    _logging_batch_size = logging_batch_size
    _backend =
    recover iso
      match filename
      | let f: String val =>
        try
          FileBackend(FilePath(env.root as AmbientAuth, f), this,
            backend_file_length)
        else
          DummyBackend
        end
      else
        DummyBackend
      end
    end

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

  be replay_log_entry(origin_id: U128, uid: U128, statechange_id: U64,
    payload: ByteSeq val)
  =>
    try
      _origins(origin_id).replay_log_entry(uid, statechange_id, payload)
    else
      @printf[I32]("FATAL: Unable to replay event log, because a replay buffer has disappeared".cstring())
      Fail()
    end

  be register_origin(origin: Resilient, id: U128) =>
    _origins(id) = origin

  be queue_log_entry(origin_id: U128, uid: U128,
    statechange_id: U64, seq_id: U64,
    payload: Array[ByteSeq] iso)
  =>
    ifdef "resilience" then
      // add to backend buffer after encoding
      // encode right away to amortize encoding cost per entry when received
      // as opposed to when writing a batch to disk
      _backend.encode_entry((false, origin_id, uid, statechange_id,
        seq_id, consume payload))

      num_encoded = num_encoded + 1

      if num_encoded == _logging_batch_size then
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
      _backend.encode_entry((true, origin_id, 0, 0, low_watermark
                       , recover Array[ByteSeq] end))

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
