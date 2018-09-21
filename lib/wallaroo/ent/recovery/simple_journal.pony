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
use "files"
use "wallaroo_labs/mort"

trait SimpleJournalAsyncResponseReceiver
  be async_io_ok(j: SimpleJournal tag, optag: USize)
  be async_io_error(j: SimpleJournal tag, optag: USize)

trait tag SimpleJournal
  be dispose_journal()
  be remove(path: String, optag: USize = 0)
  be set_length(path: String, len: USize, optag: USize = 0)
  be writev(offset: USize, path: String, data: ByteSeqIter val, optag: USize = 0)

actor SimpleJournalNoop is SimpleJournal
  new create() =>
    None
  be dispose_journal() =>
    @printf[I32]("SimpleJournalNoop: dispose_journal\n".cstring())
    None
  be remove(path: String, optag: USize = 0) =>
    None
  be set_length(path: String, len: USize, optag: USize = 0) =>
    None
  be writev(offset: USize, path: String, data: ByteSeqIter val, optag: USize = 0) =>
    None

actor SimpleJournalMirror is SimpleJournal
  """
  This journal actor writes both to a local journal and to a remote journal.

  TODO adding multiple remote journal backends should be straightforward.
  """
  var _j_file: SimpleJournalBackend
  var _j_remote: SimpleJournalBackend
  let _name: String
  var _j_closed: Bool
  var _j_file_size: USize
  let _encode_io_ops: Bool
  let _owner: (None tag | SimpleJournalAsyncResponseReceiver tag)

  new create(j_file: SimpleJournalBackend iso,
    j_remote: SimpleJournalBackend iso,
    name: String,
    encode_io_ops: Bool = true,
    owner: (None tag | SimpleJournalAsyncResponseReceiver tag) = None)
  =>
    _encode_io_ops = encode_io_ops
    _owner = owner

    _j_file = consume j_file
    _j_remote = consume j_remote
    _name = name
    _j_closed = false
    _j_file_size = _j_file.be_position()

  // TODO This method only exists because of prototype hack laziness
  // that does not refactor both RotatingEventLog & SimpleJournal.
  // It is used only by RotatingEventLog.
  be dispose_journal() =>
    _D.ds("SimpleJournalMirror: dispose_journal %s\n", _name)
    if not _j_closed then
      _D.ds("SimpleJournalMirror: dispose_journal %s closing backends\n", _name)
      _j_file.be_dispose()
      _j_remote.be_dispose()
      _j_closed = true
    end

  be remove(path: String, optag: USize = 0) =>
    if _j_closed then
      @printf[I32]("SimpleJournalMirror: %s remove %s\n".cstring(), _name.cstring(), path.cstring())
      Fail()
    end
    if _encode_io_ops then
      (let pdu, let pdu_size) = _SJ.encode_request(optag, _SJ.remove(),
        recover [] end, recover [path] end)
      let write_res = _do_encoded_writes(consume pdu, pdu_size)
      _async_io_status(write_res, optag)
    else
      Fail()
    end

  be set_length(path: String, len: USize, optag: USize = 0) =>
    if _j_closed then
      Fail()
    end
    if _encode_io_ops then
      (let pdu, let pdu_size) = _SJ.encode_request(optag, _SJ.set_length(),
        recover [len] end, recover [path] end)
      let write_res = _do_encoded_writes(consume pdu, pdu_size)
      _async_io_status(write_res, optag)
    else
      Fail()
    end

  be writev(offset: USize, path: String, data: ByteSeqIter val, optag: USize = 0) =>
    if _j_closed then
      return // We're probably shutting down. This async write isn't bad.
    end
    let write_res =
      if _encode_io_ops then
        let bytes: Array[U8] trn = recover bytes.create() end
        let wb: Writer = wb.create()

          for bseq in data.values() do
            bytes.reserve(bseq.size())
            match bseq
            | let s: String =>
              // no: bytes.concat(s.values())
              for b in s.values() do
                bytes.push(b)
              end
            | let a: Array[U8] val =>
              // no: bytes.concat(a.values())
              for b in a.values() do
                bytes.push(b)
              end
            end
          end

        let bytes_size = bytes.size()
        (let pdu, let pdu_size) = _SJ.encode_request(optag, _SJ.writev(),
          [offset], [path; consume bytes])
        _do_encoded_writes(consume pdu, pdu_size)
      else
        var data_size: USize = 0

        for d in data.values() do
          data_size = data_size + d.size()
        end
        let ret = _j_file.be_writev(_j_file_size, data, data_size)
        if ret then
          _j_remote.be_writev(_j_file_size, data, data_size)
          _j_file_size = _j_file_size + data_size
        else
          Fail() // TODO?
        end
        ret
      end
    _async_io_status(write_res, optag)

  fun ref _async_io_status(write_res: Bool, optag: USize) =>
    if write_res then
      if optag > 0 then
        try
          let o = _owner as (SimpleJournalAsyncResponseReceiver tag)
          o.async_io_ok(this, optag)
        end
      end
    else
      // We don't know how many bytes were written.  ^_^
      // TODO So, I suppose we need to ask the OS about the file size
      // to figure that out so that we can do <TBD> to recover.
      try
        let o = _owner as (SimpleJournalAsyncResponseReceiver tag)
        o.async_io_error(this, optag)
      end
    end

  fun ref _do_encoded_writes(pdu: Array[ByteSeq] iso, pdu_size: USize): Bool =>
    if pdu_size > U32.max_value().usize() then
      Fail()
    end

    let wb: Writer = wb.create()
    wb.u32_be(pdu_size.u32())
    wb.writev(consume pdu)
    let data_size = wb.size()
    let data = recover val wb.done() end
    let ret = _j_file.be_writev(_j_file_size, data, data_size)
    if ret then
      _j_remote.be_writev(_j_file_size, data, data_size)
      _j_file_size = _j_file_size + data_size
    else
      Fail() // TODO?
    end
    ret


trait SimpleJournalBackend
  fun ref be_dispose(): None

  fun ref be_position(): USize

  fun ref be_writev(offset: USize,
    data: ByteSeqIter val, data_size: USize): Bool

class SimpleJournalBackendLocalFile is SimpleJournalBackend
  let _j_file: File

  new create(filepath: FilePath) =>
    _j_file = File(filepath)
    _j_file.seek_end(0)

  fun ref be_dispose() =>
    _j_file.dispose()

  fun ref be_position(): USize =>
    _j_file.position()

  fun ref be_writev(offset: USize, data: ByteSeqIter val, data_size: USize)
  : Bool
  =>
    let res1 = _j_file.writev(data)
    let res2 = _j_file.flush()
    if not (res1 and res2) then
      // TODO: The RemoteJournalClient assumes that data written to the
      // local journal file is always up-to-date and never buffered.
      Fail()
    end
    true

class SimpleJournalBackendRemote is SimpleJournalBackend
  let _rjc: RemoteJournalClient

  new create(rjc: RemoteJournalClient) =>
    _rjc = rjc

  fun ref be_dispose() =>
    _rjc.dispose()

  fun ref be_position(): USize =>
    666 // TODO

  fun ref be_writev(offset: USize, data: ByteSeqIter val, data_size: USize)
    : Bool
  =>
    // TODO offset sanity check
    // TODO offset update
    _D.d66("SimpleJournalBackendRemote: be_writev offset %d data_size %d\n", offset, data_size)
    _rjc.be_writev(offset, data, data_size)
    true

/**********************************************************
|------+----------------+---------------------------------|
| Size | Type           | Description                     |
|------+----------------+---------------------------------|
|    1 | U8             | Protocol version = 0            |
|    1 | U8             | Op type                         |
|    1 | U8             | Number of int args              |
|    1 | U8             | Number of string/byte args      |
|    8 | USize          | Op tag                          |
|    8 | USize          | 1st int arg                     |
|    8 | USize          | nth int arg                     |
|    8 | USize          | Size of 1st string/byte arg     |
|    8 | USize          | Size of nth string/byte arg     |
|    X | String/ByteSeq | Contents of 1st string/byte arg |
|    X | String/ByteSeq | Contents of nth string/byte arg |
 **********************************************************/

primitive _SJ
  fun set_length(): U8 => 0
  fun writev(): U8 => 1
  fun remove(): U8 => 2

  fun encode_request(optag: USize, op: U8,
    ints: Array[USize], bss: Array[ByteSeq]):
    (Array[ByteSeq] iso^, USize)
  =>
    let wb: Writer = wb.create()

    wb.u8(0)
    wb.u8(op)
    wb.u8(ints.size().u8())
    wb.u8(bss.size().u8())
    wb.u64_be(optag.u64())
    for i in ints.values() do
      wb.i64_be(i.i64())
    end
    for bs in bss.values() do
      wb.i64_be(bs.size().i64())
    end
    for bs in bss.values() do
      wb.write(bs)
    end
    let size = wb.size()
    (wb.done(), size)
