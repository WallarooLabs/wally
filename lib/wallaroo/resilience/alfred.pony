use "buffered"
use "files"
use "collections"

trait Backend
  fun ref write(log: Array[ByteSeq] val)
  //fun read(from: U64, to: U64): Array[Array[U8] val] val
  fun ref flush()
  fun ref start()

class DummyBackend is Backend
  fun ref write(log: Array[ByteSeq] val) => None
  fun ref flush() => None
  fun ref start() => None

class FileBackend is Backend
  let _file: File iso
  let _filepath: FilePath
  let _alfred: Alfred tag

  new create(filepath: FilePath, alfred: Alfred) =>
    _alfred = alfred
    _filepath = filepath
    _file = recover iso File(filepath) end

  fun ref start() =>
    if _filepath.exists() then
      //replay log to Alfred
      try
        let r = Reader
        //seek beginning of file
        _file.seek_start(0)
        var size = _file.size()
        //start iterating until we reach start
        while _file.position() < size do
          //a record looks like this:
          // - buffer id
          // - uid
          // - size of fractional id list
          // - fractional id list (may be empty)
          // - statechange id
          // - payload
          let buffer_id = r.u64_be()
          let uid = r.u64_be()
          let fractional_size = r.u64_be()
          let frac_ids = recover val
            if fractional_size > 0 then
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
          let statechange_id = r.u64_be()
          let payload_length = r.u64_be()
          let payload = recover val _file.read(payload_length.usize()) end
          let log_entry = LogEntry(uid, frac_ids, statechange_id, payload)
          _alfred.replay_log_entry(buffer_id, log_entry)
        end
        _file.seek_end(0)
        _alfred.replay_finished()
      else
        @printf[I32]("Cannot recover state from eventlog\n".cstring())
      end
    //else
      //start writing a new one
    end

  fun ref write(log: Array[ByteSeq] val) =>
    _file.writev(log)

  fun ref flush() =>
    _file.sync()
    

actor Alfred
    let _log_buffers: Array[EventLogBuffer tag]
    let _backend: Backend iso
    let _writer: Writer iso
    let resilient_mode: Bool

    new create(backend: Backend iso, resilient_mode': Bool = true) =>
      _log_buffers = Array[EventLogBuffer tag]
      _backend = consume backend
      _writer = recover iso Writer end
      resilient_mode = resilient_mode'

    be ready() =>
      _backend.start()
      //_status = Ready

    be replay_finished() =>
      //TODO: Signal all buffers that replay is finished
      None

    be replay_log_entry(buffer_id: U64, log_entry: LogEntry val) =>
      try
        _log_buffers(buffer_id.usize()).replay_log_entry(log_entry)
      else
        //TODO: explode here
        @printf[I32]("FATAL: Unable to replay event log, because a replay buffer has disappeared".cstring())
      end

    be register_log_buffer(logbuffer: EventLogBuffer tag) =>
      _log_buffers.push(logbuffer)
      let id = _log_buffers.size().u64()
      logbuffer.set_id(id)

    be log(buffer_id: U64, log_entries: Array[LogEntry val] iso) =>
    //TODO: move this serialisation to the file backend
      try
        for i in Range(0,log_entries.size()) do
          //a record looks like this:
          // - buffer id
          // - uid
          // - size of fractional id list
          // - fractional id list (may be empty)
          // - statechange id
          // - payload
          let entry = log_entries(i)
          _writer.u64_be(buffer_id)
          _writer.u64_be(entry.uid())
          match entry.frac_ids()
          | let ids: Array[U64] val =>
            let s = ids.size()
            _writer.u64_be(s.u64())
            for j in Range(0,s) do
              _writer.u64_be(ids(j))
            end
          else
            //we have no frac_ids
            _writer.u64_be(0)
          end
          _writer.u64_be(entry.statechange_id())
          _writer.u64_be(entry.payload().size().u64())
          _writer.write(entry.payload())
          _backend.write(recover val _writer.done() end)
        end
        _backend.flush()
        //TODO: communicate that writing is finished
      else
        @printf[I32]("unrecoverable error while trying to write event log".cstring())
      end
