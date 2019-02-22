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
use "format"
use "wallaroo_labs/conversions"
use "wallaroo/core/common"
use "wallaroo/core/invariant"
use "wallaroo/core/messages"
use "wallaroo/core/checkpoint"
use "wallaroo_labs/mort"


//////////////////////////////////
// Helpers for RotatingFileBackend
//////////////////////////////////
primitive HexOffset
  fun apply(offset: U64): String iso^ =>
    Format.int[U64](where x=offset, fmt=FormatHexBare, width=16,
      fill=48)

  fun u64(hex: String): U64 ? =>
    hex.u64(16)?

primitive FilterLogFiles
  fun apply(base_name: String, suffix: String = ".evlog",
    entries: Array[String] iso): Array[String]
  =>
    let es: Array[String] val = consume entries
    recover
      let filtered: Array[String] ref = Array[String]
      for e in es.values() do
        try
          if (e.find(base_name)? == 0) and
             (e.rfind(suffix)? == (e.size() - suffix.size()).isize()) then
            filtered.push(e)
          end
        end
      end
      Sort[Array[String], String](filtered)
      filtered
    end

primitive LastLogFilePath
  fun apply(base_name: String, suffix: String = ".evlog", base_dir: FilePath):
    FilePath ?
  =>
    let dir = Directory(base_dir)?
    let filtered = FilterLogFiles(base_name, suffix, dir.entries()?)
    let last_string = filtered(filtered.size()-1)?
    FilePath(base_dir, last_string)?

/////////////////////////////////
// BACKENDS
/////////////////////////////////

trait Backend
  fun ref dispose()
  fun ref sync() ?
  fun ref datasync() ?
  // Rollback from recovery file and return number of entries replayed.
  fun ref start_rollback(checkpoint_id: CheckpointId): USize
  fun ref write(): USize ?
  fun ref encode_entry(resilient_id: RoutingId, checkpoint_id: CheckpointId,
    payload: Array[ByteSeq] val, is_last_entry: Bool)
  fun ref encode_checkpoint_id(checkpoint_id: CheckpointId)
  fun bytes_written(): USize

class EmptyBackend is Backend
  fun ref dispose() => Fail()
  fun ref sync() => Fail()
  fun ref datasync() => Fail()
  fun ref start_rollback(checkpoint_id: CheckpointId): USize => Fail(); 0
  fun ref write(): USize => Fail(); 0
  fun ref encode_entry(resilient_id: RoutingId, checkpoint_id: CheckpointId,
    payload: Array[ByteSeq] val, is_last_entry: Bool)
  =>
    Fail()
  fun ref encode_checkpoint_id(checkpoint_id: CheckpointId) => Fail()
  fun bytes_written(): USize => 0

class DummyBackend is Backend
  let _event_log: EventLog ref

  new create(event_log: EventLog ref) =>
    _event_log = event_log

  fun ref dispose() => None
  fun ref sync() => None
  fun ref datasync() => None
  fun ref start_rollback(checkpoint_id: CheckpointId): USize => 0
  fun ref write(): USize => 0
  fun ref encode_entry(resilient_id: RoutingId, checkpoint_id: CheckpointId,
    payload: Array[ByteSeq] val, is_last_entry: Bool)
  =>
    None
  fun ref encode_checkpoint_id(checkpoint_id: CheckpointId) => None
  fun bytes_written(): USize => 0

class FileBackend is Backend
  let _file: AsyncJournalledFile iso
  let _filepath: FilePath
  let _event_log: EventLog ref
  let _the_journal: SimpleJournal
  let _auth: AmbientAuth
  let _writer: Writer iso
  let _checkpoint_id_entry_len: USize = 9 // U8 -- U64
  let _log_entry_len: USize = 17 // U8 -- U128
  let _restart_len: USize = 9 // U8 -- U64
  var _bytes_written: USize = 0
  var _do_local_file_io: Bool = true

  new create(filepath: FilePath, event_log: EventLog ref,
    the_journal: SimpleJournal, auth: AmbientAuth,
    do_local_file_io: Bool)
  =>
    _writer = recover iso Writer end
    _filepath = filepath
    _file = recover iso
      AsyncJournalledFile(filepath, the_journal, auth, do_local_file_io) end
    _event_log = event_log
    _the_journal = the_journal
    _auth = auth
    _do_local_file_io = do_local_file_io

  fun ref dispose() =>
    _file.dispose()
    _the_journal.dispose_journal()

  fun bytes_written(): USize =>
    _bytes_written

  fun get_path(): String => // SLF TODO used??
    _filepath.path

  fun ref start_rollback(checkpoint_id: CheckpointId): USize =>
    if not _filepath.exists() then
      @printf[I32]("RESILIENCE: Could not find log file to rollback from.\n"
        .cstring())
      Fail()
    end
    if _file.size() == 0 then
      @printf[I32](("Trying to rollback to checkpoint %s from empty " +
        "recovery file %s\n").cstring(), checkpoint_id.string().cstring())
      Fail()
    end

    @printf[I32](("RESILIENCE: Rolling back to checkpoint %s from recovery " +
      "log file: \n").cstring(), checkpoint_id.string().cstring(),
      _filepath.path.cstring())

    // First task: append a _LogRestartEntry record to the log.
    // Any _LogDataEntry records found prior to a _LogRestartEntry
    // must be ignored by rollback recovery.
    _file.seek_end(0)
    @printf[I32](("RESILIENCE: write _LogRestartEntry at offset %d\n").cstring(), _file.position())
    encode_restart()
    try write()? else Fail() end

    // Second task: find the end offset of our desired checkpoint_id.
    // While doing so, we also find the starting offset of that checkpoint.

    let r = Reader

    // array to hold recovered data temporarily until we've sent it off to
    // be replayed.
    // (resilient_id, payload, is_last_entry)
    var replay_buffer: Array[(RoutingId, ByteSeq val, Bool)] ref =
      replay_buffer.create()
    var replay_resilients: SetIs[RoutingId] = replay_resilients.create()
    var current_checkpoint_id: CheckpointId = 0
    var target_checkpoint_offset_start: USize = 0
    var target_checkpoint_offset_end: USize = 0
    var target_checkpoint_found: Bool = false
    var first_data_entry_found: Bool = false

    //seek beginning of file
    _file.seek_start(0)

    while _file.position() < _file.size() do
      r.clear()
      r.append(_file.read(1))
      match try _LogDecoder.decode(r.u8()?)? else Fail(); _LogDataEntry end
      | _LogDataEntry =>
        if not first_data_entry_found then
          first_data_entry_found = true
          target_checkpoint_offset_start = _file.position() - 1
        end
        // First skip is_last_found byte and resilient_id
        _file.seek(17)
        // Read payload size
        r.append(_file.read(4))
        let size = try r.u32_be()? else Fail(); 0 end
        // Skip payload
        _file.seek(size.isize())
      | _LogCheckpointIdEntry =>
        target_checkpoint_offset_end = _file.position() - 1
        r.append(_file.read(8))
        current_checkpoint_id = try r.u64_be()? else Fail(); 0 end
        if current_checkpoint_id == checkpoint_id then
          target_checkpoint_found = true
          break
        end
        first_data_entry_found = false
        target_checkpoint_offset_start = _file.position()
      | _LogRestartEntry =>
        target_checkpoint_offset_start = (_file.position() - 1) + _restart_len
        _file.seek_start(target_checkpoint_offset_start)
      end
    end
    if not target_checkpoint_found then
      @printf[I32](("RESILIENCE: Rolling back to checkpoint %s from recovery "+
        "log file failed: not found \n").cstring(),
        checkpoint_id.string().cstring(), _filepath.path.cstring())
      Fail()
    end

    _file.seek_start(target_checkpoint_offset_start)

    while _file.position() < target_checkpoint_offset_end do
      r.clear()
      r.append(_file.read(1))
      match try _LogDecoder.decode(r.u8()?)? else Fail(); _LogDataEntry end
      | _LogDataEntry =>
        r.append(_file.read(21))
        let is_last_entry =
          recover
            let last_entry_byte = try r.u8()? else Fail(); 0 end
            if last_entry_byte == 1 then true else false end
          end
        let resilient_id = try r.u128_be()? else Fail(); 0 end
        let payload_length = try r.u32_be()? else Fail(); 0 end
        let payload = recover val
          if payload_length > 0 then
            _file.read(payload_length.usize())
          else
            Array[U8]
          end
        end
        // put entry into temporary recovered buffer
        replay_buffer.push((resilient_id, payload, is_last_entry))
        replay_resilients.set(resilient_id)
      | _LogCheckpointIdEntry =>
        break
      | _LogRestartEntry =>
        replay_buffer.clear()
        replay_resilients.clear()
        _file.seek(_restart_len.isize() - 1)
      end
    end

    // clear read buffer to free file data read so far
    if r.size() > 0 then
      Fail()
    else
      r.clear()
    end
    _file.seek_end(0)

    var num_replayed: USize = 0
    _event_log.expect_rollback_count(replay_resilients.size())
    for entry in replay_buffer.values() do
      num_replayed = num_replayed + 1
      _event_log.rollback_from_log_entry(entry._1, entry._2, entry._3,
        checkpoint_id)
    end

    @printf[I32](("RESILIENCE: Replayed %d entries from recovery log " +
      "file.\n").cstring(), num_replayed)
    num_replayed

  fun ref write(): USize ?
  =>
    let size = _writer.size()
    if not _file.writev(recover val _writer.done() end) then
      error
    else
      _bytes_written = _bytes_written + size
    end
    _bytes_written

  fun ref encode_entry(resilient_id: RoutingId, checkpoint_id: CheckpointId,
    payload: Array[ByteSeq] val, is_last_entry: Bool)
  =>
    ifdef debug then
      Invariant(payload.size() > 0)
      Invariant(payload.size() <= U32.max_value().usize())
    end

    ifdef "trace" then
      @printf[I32]("EventLog: Writing Entry for CheckpointId %s\n".cstring(),
        checkpoint_id.string().cstring())
    end

    var payload_size: USize = 0
    for p in payload.values() do
      payload_size = payload_size + p.size()
    end

    _writer.u8(_LogDataEntry.encode())
    _writer.u8(if is_last_entry then 1 else 0 end)
    _writer.u128_be(resilient_id)
    _writer.u32_be(payload_size.u32())
    _writer.writev(payload)

  fun ref encode_checkpoint_id(checkpoint_id: CheckpointId) =>
    ifdef "trace" then
      @printf[I32]("EventLog: Writing CheckpointId for CheckpointId %s\n"
        .cstring(), checkpoint_id.string().cstring())
    end

    _writer.u8(_LogCheckpointIdEntry.encode())
    _writer.u64_be(checkpoint_id)

  fun ref encode_restart() =>
    ifdef "trace" then
      @printf[I32]("EventLog: Writing restart entry\n".cstring())
    end

    _writer.u8(_LogRestartEntry.encode())
    _writer.u64_be(0x5265736574212121) // value is ignored: "Reset!!!"

  fun ref sync() ? =>
    _file.sync()
    match _file.errno()
    | FileOK => None
    else
      @printf[I32]("DBG sync line %d\n".cstring(), __loc.line())
      error
    end

  fun ref datasync() ? =>
    _file.datasync()
    match _file.errno()
    | FileOK => None
    else
      @printf[I32]("DBG datasync line %d\n".cstring(), __loc.line())
      error
    end

type _LogEntry is (_LogDataEntry | _LogCheckpointIdEntry | _LogRestartEntry)

primitive _LogDataEntry
  fun encode(): U8 => 0
primitive _LogCheckpointIdEntry
  fun encode(): U8 => 1
primitive _LogRestartEntry
  fun encode(): U8 => 2

primitive _LogDecoder
  fun decode(b: U8): _LogEntry ? =>
    match b
    | 0 =>
      return _LogDataEntry
    | 1 =>
      return _LogCheckpointIdEntry
    | 2 =>
      return _LogRestartEntry
    else
      error
    end

//!TODO!: Manage this with new checkpoint approach.
class RotatingFileBackend is Backend
  // _basepath identifies the worker
  // For unique file identifier, we use the sum of payload sizes saved as a
  // U64 encoded in hex. This is maintained with _offset and
  // _backend.bytes_written()
  var _backend: FileBackend
  let _base_dir: FilePath
  let _base_name: String
  let _suffix: String
  let _event_log: EventLog ref
  let _the_journal: SimpleJournal
  let _auth: AmbientAuth
  let _worker_name: String
  let _do_local_file_io: Bool
  let _file_length: (USize | None)
  var _offset: U64
  var _rotate_requested: Bool = false
  let _rotation_enabled: Bool
  let _dos_servers: Array[(String,String)] val

  new create(base_dir: FilePath, base_name: String, suffix: String = ".evlog",
    event_log: EventLog ref, file_length: (USize | None),
    the_journal: SimpleJournal, auth: AmbientAuth, worker_name: String,
    do_local_file_io: Bool, dos_servers: Array[(String,String)] val,
    rotation_enabled: Bool = true) ?
  =>
    _base_dir = base_dir
    _base_name = base_name
    _suffix = suffix
    _file_length = file_length
    _event_log = event_log
    _the_journal = the_journal
    _auth = auth
    _worker_name = worker_name
    _do_local_file_io = do_local_file_io
    _dos_servers = dos_servers
    _rotation_enabled = rotation_enabled

    // scan existing files matching _base_path, and identify the latest one
    // based on the hex offset
    _offset = try
      let last_file_path = LastLogFilePath(_base_name, _suffix, _base_dir)?
      let parts = last_file_path.path.split("-.")
      let offset_str = parts(parts.size()-2)?
      HexOffset.u64(offset_str)?
    else // create a new file with offset 0
      0
    end
    let p = if _rotation_enabled then
      _base_name + "-" + HexOffset(_offset) + _suffix
    else
      _base_name + _suffix
    end
    let fp = FilePath(_base_dir, p)?
    let local_journal_filepath = FilePath(_base_dir, p + ".journal")?
    let local_journal = _start_journal(auth, the_journal, local_journal_filepath, false, worker_name, dos_servers)
    _backend = FileBackend(fp, _event_log, local_journal, _auth, _do_local_file_io)

  fun tag _start_journal(auth: AmbientAuth, the_journal: SimpleJournal,
    local_journal_filepath: FilePath, encode_io_ops: Bool,
    worker_name: String, dos_servers: Array[(String,String)] val):
    SimpleJournal
  =>
    match the_journal
    | let lj: SimpleJournalNoop =>
      // If the main journal is a noop journal, then don't bother
      // creating a real journal for the event log data.
      SimpleJournalNoop
    else
      let local_basename = try local_journal_filepath.path.split("/").pop()? else Fail(); "Fail()" end
      let usedir_name = worker_name
      StartJournal.start(auth, local_journal_filepath, local_basename,
        usedir_name, false, worker_name, dos_servers, "backend")
    end

  fun ref dispose() =>
    @printf[I32]("FileBackend: dispose\n".cstring())
    _backend.dispose()

  fun bytes_written(): USize => _backend.bytes_written()

  fun ref sync() ? => _backend.sync()?

  fun ref datasync() ? => _backend.datasync()?

  fun ref start_rollback(checkpoint_id: CheckpointId): USize =>
    _backend.start_rollback(checkpoint_id)

  fun ref write(): USize ? =>
    let bytes_written' = _backend.write()?
    match _file_length
    | let l: USize =>
      if bytes_written' >= l then
        if not _rotate_requested then
          _rotate_requested = true
          _event_log._start_rotation()
        end
      end
    end
    bytes_written'

  fun ref encode_entry(resilient_id: RoutingId, checkpoint_id: CheckpointId,
    payload: Array[ByteSeq] val, is_last_entry: Bool)
  =>
    _backend.encode_entry(resilient_id, checkpoint_id, payload, is_last_entry)

  fun ref encode_checkpoint_id(checkpoint_id: CheckpointId) =>
    _backend.encode_checkpoint_id(checkpoint_id)

  fun ref rotate_file() ? =>
    // only do this if current backend has actually written anything
    if _rotation_enabled and (_backend.bytes_written() > 0) then
      // TODO This is a placeholder for recording that we're rotating
      // an EventLog backend file, which is a prototype quick hack for
      // keeping such state within an SimpleJournal collection thingie.
      let rotation_history = AsyncJournalledFile(FilePath(_auth, "TODO-EventLog-rotation-history.txt")?, _the_journal, _auth,
        _do_local_file_io)
      rotation_history.print("START of rotation: finished writing to " + _backend.get_path())

      // 1. sync/datasync the current backend to ensure everything is written
      _backend.sync()?
      _backend.datasync()?
      // 2. close the file by disposing the backend
      _backend.dispose()
      // 3. update _offset
      _offset = _offset + _backend.bytes_written().u64()
      // 4. open new backend with new file set to new offset.
      let p = _base_name + "-" + HexOffset(_offset) + _suffix
      let fp = FilePath(_base_dir, p)?
      let local_journal_filepath = FilePath(_base_dir, p + ".journal")?
      let local_journal = _start_journal(_auth, _the_journal, local_journal_filepath, false, _worker_name, _dos_servers)
      _backend = FileBackend(fp, _event_log, local_journal, _auth, _do_local_file_io)

      // TODO Part two of the log rotation hack.  Sync
      rotation_history.print("END of rotation: starting writing to " + _backend.get_path())
      rotation_history.sync() // TODO we want synchronous response
      rotation_history.dispose()
    else
      ifdef debug then
        @printf[I32]("Trying to rotate file but no bytes have been written\n"
          .cstring())
      end
    end
    _event_log.rotation_complete()
    _rotate_requested = false

class AsyncJournalledFile
  let _filepath: FilePath
  let _file: File
  let _journal: SimpleJournal
  let _auth: AmbientAuth
  var _offset: USize
  let _do_local_file_io: Bool
  var _tag: USize = 1

  new create(filepath: FilePath, journal: SimpleJournal,
    auth: AmbientAuth, do_local_file_io: Bool)
  =>
    _filepath = filepath
    _file = if do_local_file_io then
      File(filepath)
    else
      try // Partial func hack
        File(FilePath(auth, "/dev/null")?)
      else
        Fail()
        File(filepath)
      end
    end
    _journal = journal
    _auth = auth
    _offset = 0
    _do_local_file_io = do_local_file_io

  fun ref datasync() =>
    // TODO journal!
    ifdef "journaldbg" then
      @printf[I32]("### Journal: datasync %s\n".cstring(), _filepath.path.cstring())
    end
    if _do_local_file_io then
      _file.datasync()
    end

  fun ref dispose() =>
    ifdef "journaldbg" then
      @printf[I32]("### Journal: dispose %s\n".cstring(), _filepath.path.cstring())
    end
    // Nothing (?) to do for the journal
    if _do_local_file_io then
      _file.dispose()
    end

  fun ref errno(): (FileOK val | FileError val | FileEOF val |
    FileBadFileNumber val | FileExists val | FilePermissionDenied val)
  =>
    // TODO journal!  Perhaps fake a File* error if journal write failed?
    _file.errno()

  fun ref position(): USize val =>
    ifdef "journaldbg" then
      @printf[I32]("### Journal: position %s = %d\n".cstring(), _filepath.path.cstring(), _file.position())
    end
    _file.position()

  fun ref print(data: (String val | Array[U8 val] val)): Bool val =>
    ifdef "journaldbg" then
      @printf[I32]("### Journal: print %s {data}\n".cstring(), _filepath.path.cstring())
    end
    _journal.writev(_offset, _filepath.path, [data; "\n"], _tag)
    _offset = _offset + (data.size() + 1)
    _tag = _tag + 1

    if _do_local_file_io then
      _file.writev([data; "\n"])
    else
      true // TODO journal writev success/failure
    end

  fun ref read(len: USize): Array[U8 val] iso^ =>
    ifdef "journaldbg" then
      @printf[I32]("### Journal: read %s %d bytes at position %d\n".cstring(), _filepath.path.cstring(), len, _file.position())
    end
    _file.read(len)

  fun ref seek_end(offset: USize): None =>
    ifdef "journaldbg" then
      @printf[I32]("### Journal: seek_end %s offset %d\n".cstring(), _filepath.path.cstring(), offset)
    end
    if _do_local_file_io then
      _file.seek_end(offset)
      _offset = _file.position()
    end

  fun ref seek_start(offset: USize): None =>
    ifdef "journaldbg" then
      @printf[I32]("### Journal: seek_start %s offset %d\n".cstring(), _filepath.path.cstring(), offset)
    end
    if _do_local_file_io then
      _file.seek_start(offset)
      _offset = _file.position()
    end

  fun ref seek(offset: ISize): None =>
    ifdef "journaldbg" then
      @printf[I32]("### Journal: seek %s offset %d\n".cstring(), _filepath.path.cstring(), offset)
    end
    if _do_local_file_io then
      _file.seek(offset)
      _offset = _file.position()
    end

  fun ref set_length(len: USize): Bool val =>
    ifdef "journaldbg" then
      @printf[I32]("### Journal: set_length %s len %d\n".cstring(), _filepath.path.cstring(), len)
    end
    _journal.set_length(_filepath.path, len, _tag)
    _tag = _tag + 1

    if _do_local_file_io then
      _file.set_length(len)
    else
      true // TODO journal set_length success/failure
    end

  fun ref size(): USize val =>
    if _do_local_file_io then
      _file.size()
    else
      Fail(); 0
    end

  fun ref sync() =>
    // TODO journal!
    ifdef "journaldbg" then
      @printf[I32]("### Journal: sync %s\n".cstring(), _filepath.path.cstring())
    end
    if _do_local_file_io then
      _file.sync()
    end

  fun ref writev(data: ByteSeqIter val): Bool val =>
    ifdef "journaldbg" then
      @printf[I32]("### Journal: writev %s {data} @ offset %d position %d\n".cstring(), _filepath.path.cstring(), _offset, _file.position())
    end
    _journal.writev(_offset, _filepath.path, data, _tag)
    _tag = _tag + 1

    var data_size: USize = 0

    for d in data.values() do
      data_size = data_size + d.size()
    end
    _offset = _offset + data_size

    if _do_local_file_io then
      let ret = _file.writev(data)
      ret
    else
      true
    end
