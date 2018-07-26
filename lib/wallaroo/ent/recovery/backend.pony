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
use "format"
use "wallaroo_labs/conversions"
use "wallaroo/core/common"
use "wallaroo/core/invariant"
use "wallaroo/core/messages"
use "wallaroo/ent/snapshot"
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
  fun ref sync() ?
  fun ref datasync() ?
  fun ref start_rollback(snapshot_id: SnapshotId)
  fun ref write(): USize ?
  fun ref encode_entry(resilient_id: RoutingId, snapshot_id: SnapshotId,
    payload: Array[ByteSeq] val)
  fun ref encode_snapshot_id(snapshot_id: SnapshotId)
  fun bytes_written(): USize

class EmptyBackend is Backend
  fun ref sync() => Fail()
  fun ref datasync() => Fail()
  fun ref start_rollback(snapshot_id: SnapshotId) => Fail()
  fun ref write(): USize => Fail(); 0
  fun ref encode_entry(resilient_id: RoutingId, snapshot_id: SnapshotId,
    payload: Array[ByteSeq] val)
  =>
    Fail()
  fun ref encode_snapshot_id(snapshot_id: SnapshotId) => Fail()
  fun bytes_written(): USize => 0

class DummyBackend is Backend
  let _event_log: EventLog ref

  new create(event_log: EventLog ref) =>
    _event_log = event_log

  fun ref sync() => None
  fun ref datasync() => None
  fun ref start_rollback(snapshot_id: SnapshotId) =>
    _event_log.rollback_complete()
  fun ref write(): USize => 0
  fun ref encode_entry(resilient_id: RoutingId, snapshot_id: SnapshotId,
    payload: Array[ByteSeq] val)
  =>
    None
  fun ref encode_snapshot_id(snapshot_id: SnapshotId) => None
  fun bytes_written(): USize => 0

class FileBackend is Backend
  //a record looks like this:
  // - is_watermark boolean
  // - producer id
  // - seq id (low watermark record ends here)
  // - uid
  // - size of fractional id list
  // - fractional id list (may be empty)
  // - statechange id
  // - payload

  let _file: File iso
  let _filepath: FilePath
  let _event_log: EventLog ref
  let _writer: Writer iso
  let _entry_len: USize = 17 // Bool -- U128
  var _replay_log_exists: Bool
  var _bytes_written: USize = 0

  new create(filepath: FilePath, event_log: EventLog ref) =>
    _writer = recover iso Writer end
    _filepath = filepath
    _replay_log_exists = _filepath.exists()
    _file = recover iso File(filepath) end
    _event_log = event_log

  fun ref dispose() =>
    _file.dispose()

  fun bytes_written(): USize =>
    _bytes_written

    //!@ Update to only get the right stuff!
  fun ref start_rollback(snapshot_id: SnapshotId) =>
    if _replay_log_exists then
      @printf[I32](("RESILIENCE: Rolling back to snapshot %s from recovery " +
        " log file: \n").cstring(), snapshot_id.string().cstring(),
        _filepath.path.cstring())

      try
        let r = Reader

        //seek beginning of file
        _file.seek_start(0)

        // array to hold recovered data temporarily until we've sent it off to
        // be replayed.
        // (resilient_id, payload)
        var replay_buffer: Array[(RoutingId, ByteSeq val)] ref =
          replay_buffer.create()

        let watermarks_trn = recover trn Map[RoutingId, SeqId] end

        var current_snapshot_id: SnapshotId = 0
        if _file.size() > 0 then
          r.append(_file.read(16))
          current_snapshot_id = r.u128_be()?
          // We need to get to the data for the provided snapshot id. We'll
          // keep reading until we find the prior snapshot id, at which point
          // we're lined up with entries for this snapshot.
          while current_snapshot_id < (snapshot_id - 1) do
            let is_watermark = BoolConverter.u8_to_bool(r.u8()?)
            if is_watermark then
              r.append(_file.read(16))
              current_snapshot_id = r.u128_be()?
            else
              // Skip this entry since we're looking for the next snapshot id.
              // We use entry length - 1 since we just read the Bool at the
              // start of this entry.
              _file.seek(_entry_len.isize() - 1)
            end
          end
          var end_of_snapshot = false
          while not end_of_snapshot do
            r.append(_file.read(32))
            let resilient_id = r.u128_be()?
            let payload_length = r.u32_be()?
            let payload = recover val
              if payload_length > 0 then
                _file.read(payload_length.usize())
              else
                Array[U8]
              end
            end
            // put entry into temporary recovered buffer
            replay_buffer.push((resilient_id, payload))

            // Check if we're at the end of this snapshot
            r.append(_file.read(1))
            end_of_snapshot = BoolConverter.u8_to_bool(r.u8()?)
          end
        else
          @printf[I32](("Trying to rollback to snapshot %s from empty " +
            "recovery file %s\n").cstring(), snapshot_id.string().cstring())
          Fail()
        end

        // clear read buffer to free file data read so far
        if r.size() > 0 then
          Fail()
        else
          r.clear()
        end

        var num_replayed: USize = 0
        for entry in replay_buffer.values() do
          num_replayed = num_replayed + 1
          _event_log.rollback_from_log_entry(entry._1, entry._2)
        end

        @printf[I32](("RESILIENCE: Replayed %d entries from recovery log " +
          "file.\n").cstring(), num_replayed)

        _file.seek_end(0)
      else
        @printf[I32]("Cannot recover state from eventlog\n".cstring())
      end
    else
      @printf[I32]("RESILIENCE: Could not find log file to replay.\n"
        .cstring())
      Fail()
    end

  fun ref write(): USize ?
  =>
    let size = _writer.size()
    if not _file.writev(recover val _writer.done() end) then
      error
    else
      _bytes_written = _bytes_written + size
    end
    _bytes_written

  fun ref encode_entry(resilient_id: RoutingId, snapshot_id: SnapshotId,
    payload: Array[ByteSeq] val)
  =>
    ifdef "trace" then
      @printf[I32]("EventLog: Writing Entry for SnapshotId %s\n".cstring(),
        snapshot_id.string().cstring())
    end

    ifdef debug then
      Invariant(payload.size() <= U32.max_value().usize())
    end

    // This is not a watermark so write false
    _writer.u8(BoolConverter.bool_to_u8(false))
    _writer.u128_be(resilient_id)
    _writer.u32_be(payload.size().u32())
    _writer.writev(payload)

  fun ref encode_snapshot_id(snapshot_id: SnapshotId) =>
    ifdef "trace" then
      @printf[I32]("EventLog: Writing SnapshotId for SnapshotId %s\n"
        .cstring(), snapshot_id.string().cstring())
    end

    // This is a watermark so write true
    _writer.u8(BoolConverter.bool_to_u8(true))
    _writer.u128_be(snapshot_id)

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

// !@ Manage this with new snapshot approach.
// class RotatingFileBackend is Backend
//   // _basepath identifies the worker
//   // For unique file identifier, we use the sum of payload sizes saved as a
//   // U64 encoded in hex. This is maintained with _offset and
//   // _backend.bytes_written()
//   var _backend: FileBackend
//   let _base_dir: FilePath
//   let _base_name: String
//   let _suffix: String
//   let _event_log: EventLog
//   let _file_length: (USize | None)
//   var _offset: U64
//   var _rotate_requested: Bool = false

//   new create(base_dir: FilePath, base_name: String, suffix: String = ".evlog",
//     event_log: EventLog, file_length: (USize | None)) ?
//   =>
//     _base_dir = base_dir
//     _base_name = base_name
//     _suffix = suffix
//     _file_length = file_length
//     _event_log = event_log

//     // scan existing files matching _base_path, and identify the latest one
//     // based on the hex offset
//     _offset = try
//       let last_file_path = LastLogFilePath(_base_name, _suffix, _base_dir)?
//       let parts = last_file_path.path.split("-.")
//       let offset_str = parts(parts.size()-2)?
//       HexOffset.u64(offset_str)?
//     else // create a new file with offset 0
//       0
//     end
//     let p = _base_name + "-" + HexOffset(_offset) + _suffix
//     let fp = FilePath(_base_dir, p)?
//     _backend = FileBackend(fp, _event_log)

//   fun bytes_written(): USize => _backend.bytes_written()

//   fun ref sync() ? => _backend.sync()?

//   fun ref datasync() ? => _backend.datasync()?

//   fun ref start_rollback() => _backend.start_rollback()

//   fun ref write(): USize ? =>
//     let bytes_written' = _backend.write()?
//     match _file_length
//     | let l: USize =>
//       if bytes_written' >= l then
//         if not _rotate_requested then
//           _rotate_requested = true
//           _event_log.start_rotation()
//         end
//       end
//     end
//     bytes_written'

//   fun ref encode_entry(entry: LogEntry) => _backend.encode_entry(consume entry)

//   fun ref rotate_file() ? =>
//     // only do this if current backend has actually written anything
//     if _backend.bytes_written() > 0 then
//       // 1. sync/datasync the current backend to ensure everything is written
//       _backend.sync()?
//       _backend.datasync()?
//       // 2. close the file by disposing the backend
//       _backend.dispose()
//       // 3. update _offset
//       _offset = _offset + _backend.bytes_written().u64()
//       // 4. open new backend with new file set to new offset.
//       let p = _base_name + "-" + HexOffset(_offset) + _suffix
//       let fp = FilePath(_base_dir, p)?
//       _backend = FileBackend(fp, _event_log)
//     end
//     _rotate_requested = false
