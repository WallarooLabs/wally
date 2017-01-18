use "buffered"
use "collections"
use "files"
use "wallaroo/boundary"
use "wallaroo/fail"
use "wallaroo/invariant"
use "wallaroo/messages"
use "wallaroo/routing"
use "wallaroo/initialization"

//TODO: origin needs to get its own file
trait tag Resilient
  be replay_log_entry(uid: U128, frac_ids: None, statechange_id: U64,
    payload: ByteSeq)
  be replay_finished()
  be start_without_replay()

//TODO: explain in comment
type LogEntry is (Bool, U128, U128, None, U64, U64, Array[ByteSeq] iso)

// used to hold a receovered log entry that might need to be replayed on
// recovery
type ReplayEntry is (U128, U128, None, U64, U64, ByteSeq val)

trait Backend
  fun ref sync() ?
  fun ref datasync() ?
  fun ref start()
  fun ref write() ?
  fun ref encode_entry(entry: LogEntry)

class DummyBackend is Backend
  new create() => None
  fun ref sync() => None
  fun ref datasync() => None
  fun ref start() => None
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
  let _alfred: Alfred tag
  let _writer: Writer iso
  var _replay_on_start: Bool

  new create(filepath: FilePath, alfred: Alfred,
    file_length: (USize | None) = None) =>
    _writer = recover iso Writer end
    _filepath = filepath
    _replay_on_start = _filepath.exists()
    _file = recover iso File(filepath) end
    match file_length
    | let len: USize => _file.set_length(len)
    end
    _alfred = alfred

  fun ref start() =>
    if _replay_on_start then
      @printf[I32]("RESILIENCE: Replaying from recovery log file.\n".cstring())

      //replay log to Alfred
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
            r.append(_file.read(24))
            let uid = r.u128_be()
            let fractional_size = r.u64_be()
            let frac_ids = recover val
              if fractional_size > 0 then
                r.append(_file.read(fractional_size.usize() * 8))
                let l = Array[U64]
                for i in Range(0,fractional_size.usize()) do
                  l.push(r.u64_be())
                end
                l
              else
                //None is faster if we have no frac_ids, which will probably be
                //true most of the time
                None
              end
            end
            r.append(_file.read(16)) //TODO: use sizeof-type things?
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
          r.clear()
        end

        // iterate through recovered buffer and replay entries at or below
        // watermark
        for entry in replay_buffer.values() do
          try
            // only replay if at or below watermark
            if entry._5 <= watermarks(entry._1) then
              num_replayed = num_replayed + 1
              _alfred.replay_log_entry(entry._1, entry._2, entry._3, entry._4
                                      , entry._6)
            else
              num_skipped = num_skipped + 1
            end
          else
            Fail()
          end
        end

        @printf[I32]("RESILIENCE: Replayed %d entries from recovery log file.\n"
          .cstring(), num_replayed)
        @printf[I32]("RESILIENCE: Skipped %d entries from recovery log file.\n"
          .cstring(), num_skipped)

        _file.seek_end(0)
        _alfred.log_replay_finished()
      else
        @printf[I32]("Cannot recover state from eventlog\n".cstring())
      end
    else
      @printf[I32]("RESILIENCE: Nothing to replay from recovery log file.\n"
        .cstring())
      _alfred.start_without_replay()
    end

  fun ref write() ?
  =>
    if not _file.writev(recover val _writer.done() end) then
      error
    end

  fun ref encode_entry(entry: LogEntry)
  =>
    (let is_watermark: Bool, let origin_id: U128, let uid: U128,
     let frac_ids: None, let statechange_id: U64, let seq_id: U64,
     let payload: Array[ByteSeq] val)
    = consume entry

    _writer.bool(is_watermark)
    _writer.u128_be(origin_id)
    _writer.u64_be(seq_id)

    if not is_watermark then

      _writer.u128_be(uid)

      //we have no frac_ids
      _writer.u64_be(0)

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


actor Alfred
    let _origins: Map[U128, (Resilient & Producer)] = _origins.create()
    let _logging_batch_size: USize
    let _backend: Backend ref
    let _incoming_boundaries: Array[DataReceiver tag] ref =
      _incoming_boundaries.create(1)
    let _replay_complete_markers: Map[U64, Bool] =
      _replay_complete_markers.create()
    var num_encoded: USize = 0
    var _flush_waiting: USize = 0

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

    be start(initializer: LocalTopologyInitializer) =>
      _backend.start()
      initializer.report_alfred_ready_to_work()

    be register_incoming_boundary(boundary: DataReceiver tag) =>
      _incoming_boundaries.push(boundary)

    be log_replay_finished() =>
      //signal all buffers that event log replay is finished
      for boundary in _incoming_boundaries.values() do
        _replay_complete_markers.update((digestof boundary),false)
        boundary.request_replay()
      end

    be upstream_replay_finished(boundary: DataReceiver tag) =>
      _replay_complete_markers.update((digestof boundary), true)
      var finished = true
      for b in _incoming_boundaries.values() do
        try
          if not _replay_complete_markers((digestof b)) then
            finished = false
          end
        else
          @printf[I32]("A boundary just disappeared!".cstring())
        end
      end
      if finished then
        _replay_finished()
      end

    fun _replay_finished() =>
      for b in _origins.values() do
        b.replay_finished()
      end

    be start_without_replay() =>
      //signal all buffers that there is no event log replay
      for b in _origins.values() do
        b.start_without_replay()
      end

    be replay_log_entry(origin_id: U128, uid: U128, frac_ids: None,
      statechange_id: U64, payload: ByteSeq val)
    =>
      try
        _origins(origin_id).replay_log_entry(uid, frac_ids, statechange_id,
          payload)
      else
        //TODO: explode here
        @printf[I32]("FATAL: Unable to replay event log, because a replay buffer has disappeared".cstring())
        Fail()
      end

    be register_origin(origin: (Resilient & Producer), id: U128) =>
      _origins(id) = origin

    be queue_log_entry(origin_id: U128, uid: U128,
      frac_ids: None, statechange_id: U64, seq_id: U64,
      payload: Array[ByteSeq] iso)
    =>
      ifdef "resilience" then
        // add to backend buffer after encoding
        // encode right away to amortize encoding cost per entry when received
        // as opposed to when writing a batch to disk
        _backend.encode_entry((false, origin_id, uid, frac_ids, statechange_id,
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
        @printf[I32](("flush_buffer for id: " +
          origin_id.string() + "\n\n").cstring())
      end

      try
        // Add low watermark ack to buffer
        _backend.encode_entry((true, origin_id, 0, None, 0, low_watermark
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

