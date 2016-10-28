use "buffered"
use "files"
use "collections"

trait Backend
  //fun read(from: U64, to: U64): Array[Array[U8] val] val
  fun ref flush()
  fun ref start()
  fun ref write_entry(buffer_id: U128, entry: (U128, (Array[U64] val | None), U64,
    Array[ByteSeq] val))

class DummyBackend is Backend
  new create() => None
  fun ref flush() => None
  fun ref start() => None
  fun ref write_entry(buffer_id: U128, entry: (U128, (Array[U64] val | None), U64,
    Array[ByteSeq] val)) => None

class FileBackend is Backend
  //a record looks like this:
  // - buffer id
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

  new create(filepath: FilePath, alfred: Alfred) =>
    _writer = recover iso Writer end
    _filepath = filepath
    _replay_on_start = _filepath.exists()
    _file = recover iso File(filepath) end
    _alfred = alfred

  fun ref start() =>
    if _replay_on_start then
      //replay log to Alfred
      try
        let r = Reader
        //seek beginning of file
        _file.seek_start(0)
        var size = _file.size()
        //start iterating until we reach start
        while _file.position() < size do
          r.append(_file.read(40))
          let buffer_id = r.u128_be()
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
          r.append(_file.read(16))
          let statechange_id = r.u64_be()
          let payload_length = r.u64_be()
          let payload_single = recover val _file.read(payload_length.usize()) end
          let payload = recover val
            let p = Array[ByteSeq]
            p.push(payload_single)
            p
          end
          _alfred.replay_log_entry(buffer_id, uid, frac_ids, statechange_id, payload)
        end
        _file.seek_end(0)
        _alfred.replay_finished()
      else
        @printf[I32]("Cannot recover state from eventlog\n".cstring())
      end
    else
      _alfred.start_without_replay()
    end

  fun ref write_entry(buffer_id: U128, entry: (U128, (Array[U64] val | None), U64,
    Array[ByteSeq] val))
  =>
    (let uid:U128, let frac_ids: (Array[U64] val | None),
     let statechange_id: U64, let payload: Array[ByteSeq] val)
    = entry
    _writer.u128_be(buffer_id)
    _writer.u128_be(uid)
    match frac_ids
    | let ids: Array[U64] val =>
      let s = ids.size()
      _writer.u64_be(s.u64())
      for j in Range(0,s) do
        try
          _writer.u64_be(ids(j))
        else
          @printf[I32]("fractional id %d on message %d disappeared!".cstring(),
            j, uid)
        end
      end
    else
      //we have no frac_ids
      _writer.u64_be(0)
    end
    _writer.u64_be(statechange_id)
    var payload_size: USize = 0
    for p in payload.values() do
      payload_size = payload_size + p.size()
    end
    _writer.u64_be(payload_size.u64())
    _writer.writev(payload)
    _file.writev(recover val _writer.done() end)

  fun ref flush() =>
    _file.flush()
 

actor Alfred
    let _log_buffers: Map[U128, EventLogBuffer tag] = 
      _log_buffers.create()
    // TODO: Why are these things isos? Because Alfred is the only thing that
    // should ever be using them, so we can't pass them anywhere.
    let _backend: Backend ref

    new create(env: Env, filename: (String val | None) = None) =>
      _backend = 
      recover iso
        match filename
        | let f: String val =>
          try 
            FileBackend(FilePath(env.root as AmbientAuth, f), this)
          else
            DummyBackend
          end
        else
          DummyBackend
        end
      end

    be start() =>
      _backend.start()

    be replay_finished() =>
      //signal all buffers that event log replay is finished
      for b in _log_buffers.values() do
        b.replay_finished()
      end

    be start_without_replay() =>
      //signal all buffers that there is no event log replay
      for b in _log_buffers.values() do
        b.start_without_replay()
      end

    be replay_log_entry(buffer_id: U128, uid: U128, frac_ids: (Array[U64] val | None), statechange_id: U64, payload: Array[ByteSeq] val) =>
      try
        _log_buffers(buffer_id).replay_log_entry(uid, frac_ids, statechange_id, payload)
      else
        //TODO: explode here
        @printf[I32]("FATAL: Unable to replay event log, because a replay buffer has disappeared".cstring())
      end

    be register_log_buffer(logbuffer: EventLogBuffer tag) =>
      let id = _log_buffers.size().u128()
      _log_buffers(id) = logbuffer
      logbuffer.set_id(id)

    be log(buffer_id: U128, log_entries: Array[LogEntry val] iso, low_watermark: U64) =>
      let write_count = log_entries.size()
      for i in Range(0, write_count) do
        try
          _backend.write_entry(buffer_id,log_entries(i))
        else
          @printf[I32]("unable to find log entry %d for buffer id %d - it seems to have disappeared!".cstring(), i, buffer_id)
        end
      end
      _backend.flush()
      try
        _log_buffers(buffer_id).log_flushed(low_watermark, write_count.u64())
      else
        @printf[I32]("buffer %d disappeared!!".cstring(), buffer_id)
      end
