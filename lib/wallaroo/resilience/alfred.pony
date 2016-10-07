use "buffered"
use "files"
use "collections"

trait Backend
  fun write(log: Array[ByteSeq] val)
  //fun read(from: U64, to: U64): Array[Array[U8] val] val
  fun flush()

 
class DummyBackend is Backend
  fun write(log: Array[ByteSeq] val) => None
  fun flush() => None

class FileBackend
  let _file: File

  new create(filename: FilePath) =>
    _file = File(filename)

  fun ref write(log: Array[ByteSeq] val) =>
    _file.writev(log)

  fun ref flush() =>
    _file.sync()
    

actor Alfred
    let _log_buffers: Array[EventLogBuffer tag]
    let _backend: Backend iso
    let _writer: Writer iso

    new create(backend: Backend iso) =>
      _log_buffers = Array[EventLogBuffer tag]
      _backend = consume backend
      _writer = recover iso Writer end

    be register_log_buffer(logbuffer: EventLogBuffer tag) =>
      _log_buffers.push(logbuffer)
      let id = _log_buffers.size().u64()
      logbuffer.set_id(id)

    be log(buffer_id: U64, log_entries: Array[LogEntry val] iso) =>
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
          let s = entry.fractional_list().size()
          _writer.u64_be(s.u64())
          for j in Range(0,s) do
            _writer.u64_be(entry.fractional_list()(j))
          end
          _writer.u64_be(entry.statechange_id())
          _writer.write(entry.payload())
          _backend.write(recover val _writer.done() end)
        end
        _backend.flush()
      else
        @printf[I32]("unrecoverable error while trying to write event log".cstring())
      end
