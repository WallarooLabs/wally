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

use "files"
use "promises"
use "time"
use "wallaroo_labs/mort"

type _RJCstate is
  (_SLocalSizeDiscovery |
    _SRemoteUseDir | _SRemoteUseDirWaiting |
    _SRemoteSizeDiscovery | _SRemoteSizeDiscoveryWaiting |
   _SStartRemoteFileAppend | _SStartRemoteFileAppendWaiting |
   _SCatchUp | _SSendBuffer | _SInSync)

primitive _SLocalSizeDiscovery
  fun num(): U8 => 0
primitive _SRemoteUseDir
  fun num(): U8 => 1
primitive _SRemoteUseDirWaiting
  fun num(): U8 => 2
primitive _SRemoteSizeDiscovery
  fun num(): U8 => 3
primitive _SRemoteSizeDiscoveryWaiting
  fun num(): U8 => 4
primitive _SStartRemoteFileAppend
  fun num(): U8 => 5
primitive _SStartRemoteFileAppendWaiting
  fun num(): U8 => 6
primitive _SCatchUp
  fun num(): U8 => 7
primitive _SSendBuffer
  fun num(): U8 => 8
primitive _SInSync
  fun num(): U8 => 9

actor RemoteJournalClient
  var _state: _RJCstate = _SLocalSizeDiscovery
  let _auth: AmbientAuth
  let _journal_fp: FilePath
  let _journal_path: String
  let _usedir_name: String
  let _make_dos: {(RemoteJournalClient, String): DOSclient} val
  var _dos: DOSclient
  var _connected: Bool = false
  var _usedir_sent: Bool = false
  var _appending: Bool = false
  var _in_sync: Bool = false
  var _local_size: USize = 0
  var _remote_size: USize = 0
  var _disposed: Bool = false
  var _buffer: Array[(USize, ByteSeqIter, USize)] = _buffer.create()
  var _buffer_size: USize = 0
  // Beware of races if we ever change _buffer_max_size dynamically
  let _buffer_max_size: USize = (1*1024*1024)
  let _timers: Timers = Timers
  var _remote_size_discovery_sleep: USize = 1_000_000
  let _remote_size_discovery_max_sleep: USize = 1_000_000_000
  let _timeout_nanos: U64 = 2_000_000_000
  let _qqq: U64 = Time.nanos().mod(97)

  new create(auth: AmbientAuth, journal_fp: FilePath, journal_path: String,
    usedir_name: String,
    make_dos: {(RemoteJournalClient, String): DOSclient} val)
  =>
    _auth = auth
    _journal_fp = journal_fp
    _journal_path = journal_path
    _usedir_name = usedir_name
    _make_dos = make_dos
    _dos = make_dos(recover tag this end, usedir_name)
    _D.d8("RemoteJournalClient (last _state=%d): create\n", _state.num())
    _set_connection_status_notifier()
    _local_size_discovery()

  be dispose() =>
    _D.ds("RJC %s: DISPOSE\n", _dl())
    _dos.dispose()
    _connected = false
    _usedir_sent = false
    _appending = false
    _in_sync = false
    _disposed = true

  // _dl = _debug_label
  fun _dl(): String =>
    ifdef "dos-verbose" then
/***
      let aaa = Array[U8].create(32)
      @snprintf[I32](aaa.cpointer(), I32(32), "0x%lx", this)
      let str2 = String.copy_cstring(aaa.cpointer())
 ***/
      _usedir_name + "..." + _qqq.string() + "@" + _state.num().string()
    else
      ""
    end

  fun ref _set_connection_status_notifier() =>
    let rjc = recover tag this end

    _dos.connection_status_notifier(recover iso
      {(connected: Bool, who: Any): None => 
        @printf[I32]("RJC %s: lambda dos-client 0x%lx connected %s\n".cstring(), _usedir_name.cstring(), who, connected.string().cstring())
        _D.dss("RJC %s: lambda connected %s\n", _usedir_name, connected.string())
        if connected then
          // Notify immediately
          rjc.dos_client_connection_status(connected)
        else
          // Delay a disconnection notification very briefly.
          // We will try to reconnect immediately, but we don't want a
          // busy-loop if the server has crashed.
          let delay: U64 = 100_000_000
          let later = _DoLater(recover
            {(): Bool =>
              _D.d6("\tDoLater: dos_client_connection_status " +
                " after sleep_time %d\n", USize.from[U64](delay))
                rjc.dos_client_connection_status(connected)
              false
            } end)
          let t = Timer(consume later, delay)
          _timers(consume t)
        end
      } end)

  fun ref _make_new_dos_then_local_size_discovery() =>
    _D.ds("RJC %s: _make_new_dos_then_local_size_discovery\n\n\n", _dl())
    _dos.dispose()
    _connected = false
    _usedir_sent = false
    _appending = false
    _in_sync = false
    _dos = _make_dos(recover tag this end, _usedir_name)
    _set_connection_status_notifier()
    _local_size_discovery()

  be local_size_discovery() =>
    _local_size_discovery()

  fun ref _local_size_discovery() =>
    if _disposed then _D.ds6("RJC %s: line %d _disposed!\n", _dl(), __loc.line()); return end
      _D.ds("RJC %s: local_size_discovery\n", _dl())
    _state = _SLocalSizeDiscovery

    if _appending then
      _D.ds("RJC %s: local_size_discovery _appending true\n", _dl())
      _make_new_dos_then_local_size_discovery()
    end
    _in_sync = false
    _remote_size_discovery_sleep = 1_000_000
    try
      _find_local_file_size()?
      _remote_usedir()
    else
      // We expect that this file will exist very very shortly.
      // Yield to the scheduler.
      local_size_discovery()
    end

  fun ref _find_local_file_size() ? =>
    let info = FileInfo(_journal_fp)?
    _D.dss6("RJC %s: %s size %d\n", _dl(), _journal_fp.path, info.size)
    _local_size = info.size

  fun ref _remote_usedir() =>
    if _disposed then _D.ds6("RJC %s: line %d _disposed!\n", _dl(), __loc.line()); return end
    _D.dss("RJC %s: remote_usedir %s\n", _dl(), _usedir_name)
    _state = _SRemoteUseDir

    if not _connected then
      _D.ds6("RJC %s: line %d DOING NOTHING!\n", _dl(), __loc.line())
      None // Wait for connected status to provoke action
    elseif _usedir_sent then
      _remote_size_discovery()
    else
      let rsd = recover tag this end
      let dl = _dl()
      let p = Promise[DOSreply]
      p.timeout(_timeout_nanos)
      p.next[None](
        {(reply)(rsd) =>
          try
            _D.dss("RJC %s: remote_usedir RES %s\n", dl, (reply as String))
            if (reply as String) == "ok" then
              rsd.remote_usedir_reply(true)
            else
              rsd.remote_usedir_reply(false)
            end
          else
            Fail()
          end
        },
        {() =>
          _D.ds("RJC %s: remote_usedir REJECTED\n", dl)
          rsd.remote_usedir_reply(false)
        }
      )
      _dos.do_usedir(_usedir_name, p)
      _remote_usedir_waiting()
    end

  fun ref _remote_usedir_waiting() =>
    if _disposed then _D.ds6("RJC %s: line %d _disposed!\n", _dl(), __loc.line()); return end
    _D.ds("RJC %s: remote_usedir_waiting\n", _dl())
    _state = _SRemoteUseDirWaiting

  be remote_usedir_reply(success: Bool) =>
    if _disposed then _D.ds6("RJC %s: line %d _disposed!\n", _dl(), __loc.line()); return end
    _D.dss("RJC %s: remote_usedir_reply: success %s\n", _dl(), success.string())
    if _state.num() == _SRemoteUseDirWaiting.num() then
      if success then
        _usedir_sent = true
        _remote_size_discovery()
      else
        // Either failure: protocol was live but said not ok, or else
        // timeout/closed/other means that we should disconnect and
        // make a new connection in a known good state.
        _make_new_dos_then_local_size_discovery()
      end
    end

  fun ref _remote_size_discovery() =>
    if _disposed then _D.ds6("RJC %s: line %d _disposed!\n", _dl(), __loc.line()); return end
    _D.ds("RJC %s: remote_size_discovery\n", _dl())
    _state = _SRemoteSizeDiscovery

    if not _connected then
      remote_size_discovery_reply(false)
      return
    end
    let rsd = recover tag this end
    let p = Promise[DOSreply]
    p.timeout(_timeout_nanos)
    p.next[None](
      {(a)(rsd) =>
        var remote_size: USize = 0 // Default if remote file doesn't exist
        try
          for (file, size, appending) in (a as DOSreplyLS).values() do
            if file == _journal_path then
              _D.d("\tFound it\n")
              _D.ds6s("\t%s,%d,%s\n", file, size, appending.string())
              if appending then
                // Hmm, this is hopefully a benign race, with a prior
                // connection from us that hasn't been closed yet.
                // (If it's from another cluster member, that should
                //  never happen!)
                // So we stop iterating here and go back to the beginning
                // of the state machine; eventually the old session will
                // be closed by remote server and the file's appending
                // state will be false.
                rsd.remote_size_discovery_reply(false)
                return
              end              
              remote_size = size
              break
            end
          end
          rsd.remote_size_discovery_reply(true, remote_size)
        end
      },
      {()(rsd) =>
        _D.d("PROMISE: remote_size_discovery BUMMER!\n")
        rsd.remote_size_discovery_failed()
      })
    _dos.do_ls(p)
    _remote_size_discovery_waiting()

  fun ref _remote_size_discovery_waiting() =>
    if _disposed then _D.ds6("RJC %s: line %d _disposed!\n", _dl(), __loc.line()); return end
    _D.ds("RJC %s: remote_size_discovery_waiting\n", _dl())
    _state = _SRemoteSizeDiscoveryWaiting

  be remote_size_discovery_reply(success: Bool, remote_size: USize = 0) =>
    if _disposed then _D.ds6("RJC %s: line %d _disposed!\n", _dl(), __loc.line()); return end
    _D.dss6("RJC %s: remote_size_discovery_reply: success %s remote_size %d\n",
      _dl(), success.string(), remote_size)

    if _state.num() == _SRemoteSizeDiscoveryWaiting.num() then
      if success then
        _start_remote_file_append(remote_size)
      else
        _remote_size_discovery_sleep = _remote_size_discovery_sleep * 2
        _remote_size_discovery_sleep =
          _remote_size_discovery_sleep.min(_remote_size_discovery_max_sleep)
        let rsd = recover tag this end
        let later = _DoLater(recover
          {(): Bool =>
            _D.d6("\tDoLater: remote_size_discovery " +
              " after sleep_time %d\n", _remote_size_discovery_sleep)
            rsd.remote_size_discovery_retry()
            false
          } end)
        let t = Timer(consume later, U64.from[USize](_remote_size_discovery_sleep))
        _timers(consume t)
        _state = _SRemoteSizeDiscovery
      end
    end

  be remote_size_discovery_failed() =>
    if _disposed then _D.ds6("RJC %s: line %d _disposed!\n", _dl(), __loc.line()); return end
    _D.ds("RJC %s: remote_size_discovery_failed\n", _dl())

    if _state.num() == _SRemoteSizeDiscoveryWaiting.num() then
      _make_new_dos_then_local_size_discovery()
    end

  be remote_size_discovery_retry() =>
    _D.ds("RJC %s: remote_size_discovery_retry: \n", _dl())
    if _state.num() == _SRemoteSizeDiscovery.num() then
      _remote_size_discovery()
    end

  fun ref _start_remote_file_append(remote_size: USize) =>
    if _disposed then _D.ds6("RJC %s: line %d _disposed!\n", _dl(), __loc.line()); return end
    _D.ds("RJC %s: start_remote_file_append\n", _dl())
    _state = _SStartRemoteFileAppend

    _remote_size = remote_size
    _D.ds66("RJC %s: start_remote_file_append " +
      "_local_size %d _remote_size %d\n", _dl(), _local_size, _remote_size)

    if not _connected then
      _local_size_discovery()
      return
    end

    let rsd = recover tag this end
    let dl = _dl()
    let p = Promise[DOSreply]
    p.timeout(_timeout_nanos)
    p.next[None](
      {(reply)(rsd) =>
        try
          _D.dss("RJC %s: start_remote_file_append RES %s\n",
            dl, (reply as String))
          if (reply as String) == "ok" then
            rsd.start_remote_file_append_reply(true)
          else
            try
              _D.dss("RJC %s: start_remote_file_append failure " +
                "(reason = %s), pause & looping\n", dl, (reply as String))
            end
           rsd.start_remote_file_append_reply(false)
          end
        else
          Fail()
        end
      },
      {() =>
        _D.ds("RJC %s: start_remote_file_append REJECTED\n", dl)
        rsd.start_remote_file_append_reply(false)
      }
    )
    _dos.start_streaming_append(_journal_path, _remote_size, p)
    _start_remote_file_append_waiting()

  be start_remote_file_append_waiting() =>
    _start_remote_file_append_waiting()

  fun ref _start_remote_file_append_waiting() =>
    if _disposed then _D.ds6("RJC %s: line %d _disposed!\n", _dl(), __loc.line()); return end
    _D.ds("RJC %s: start_remote_file_append_waiting\n", _dl())
    _state = _SStartRemoteFileAppendWaiting

  be start_remote_file_append_reply(success: Bool) =>
    if _disposed then _D.ds6("RJC %s: line %d _disposed!\n", _dl(), __loc.line()); return end
    _D.dss("RJC %s: start_remote_file_append_reply: success %s\n",
      _dl(), success.string())
    if _state.num() == _SStartRemoteFileAppendWaiting.num() then
      if success then
        // From this point forward, we're in append mode.  We will
        // rely on the following for failure recovery: backpressure
        // (short-term remote failures e.g. TCP backpressure) and
        // TCP keepalive failure to close the connection (on remote
        // host failure).  We assume all short-term backpressure
        // events really are short-term; if a TCP backpressure event
        // is long-term, then we will get stuck.
        _appending = true
        _catch_up_state(0, 0)
      else
        // Either failure: protocol was live but said not ok, or else
        // timeout/closed/other means that we should disconnect and
        // make a new connection in a known good state.
        _make_new_dos_then_local_size_discovery()
      end
    end

  be catch_up_state() =>
    _catch_up_state(0, 0)

  fun ref _catch_up_state(catch_up_bytes: USize, iters: USize) =>
    if _disposed then _D.ds6("RJC %s: line %d _disposed!\n", _dl(), __loc.line()); return end
    _D.ds66("RJC %s: catch_up_state _local_size %d _remote_size %d\n",
      _dl(), _local_size, _remote_size)
    _state = _SCatchUp

    if not _connected then
      _local_size_discovery()
      return
    end

    if (iters > 100) or (catch_up_bytes > (1024*1024)) then
      // Yield via behavior call
      catch_up_state()
    elseif _local_size == _remote_size then
      _D.ds6("RJC %s: catch_up_state line %d\n", _dl(), __loc.line())
      send_buffer_state()
    elseif _local_size > _remote_size then
      _D.ds6("RJC %s: catch_up_state line %d\n", _dl(), __loc.line())
      _catch_up_send_block(catch_up_bytes, iters)
    else
      _D.ds6("RJC %s: catch_up_state line %d\n", _dl(), __loc.line())
      Fail()
    end

  fun ref _catch_up_send_block(catch_up_bytes: USize, iters: USize) =>
    var bytes_size: USize = 0
    let missing_bytes = _local_size - _remote_size
    let block_size = missing_bytes.min(64*1024)
    // Pathological test case: let block_size = missing_bytes.min(10)

    _D.ds6("\tRJC %s: _catch_up_send_block: block_size = %d\n", _dl(), block_size)
    with file = File.open(_journal_fp) do
      if not file.valid() then
        Fail()
      end
      file.seek(_remote_size.isize())
      let bytes = recover val file.read(block_size) end
      let goo = recover val [bytes] end
      _D.ds66("\tRJC %s: _catch_up_send_block: _remote_size %d bytes size = %d\n", _dl(),
        _remote_size, bytes.size())
      _dos.send_unframed(goo)
      bytes_size = bytes.size()
      _remote_size = _remote_size + bytes_size
    end
    _catch_up_state(catch_up_bytes + bytes_size, iters + 1)

  be send_buffer_state() =>
    _send_buffer_state()

  fun ref _send_buffer_state() =>
    if _disposed then _D.ds6("RJC %s: line %d _disposed!\n", _dl(), __loc.line()); return end
    _D.ds66("RJC %s: send_buffer_state _local_size %d _remote_size %d\n",
      _dl(), _local_size, _remote_size)
    if _state.num() != _SCatchUp.num() then
      return
    end
    if not _appending then
      _D.ds("RJC %s: send_buffer_state not _appending, returning\n", _dl())
      return
    end
    if not _connected then
      _local_size_discovery()
      return
    end

    if _buffer_size > _buffer_max_size then
      // We know the size of the remote file: we have been through
      // 0 or more catch-up cycles.  So, let's update our knowledge of
      // the local file size, then go through another catch-up cycle.
      try
        _find_local_file_size()?
        _buffer.clear()
        _buffer_size = 0
      else
        Fail()
      end
      _catch_up_state(0, 0)
      return
    end
    _state = _SSendBuffer

    if _buffer_size == 0 then
      _in_sync_state()
    else
      for (offset, data, data_size) in _buffer.values() do
        if (offset + data_size) <= _remote_size then
          _D.ds666("\tRJC %s: ======send_buffer_state: " +
            "skipping offset %d data_size %d remote_size %d\n", _dl(),
            offset, data_size, _remote_size)
        elseif (offset < _remote_size) and
          ((offset + data_size) > _remote_size) then
          // IIRC POSIX says that we shouldn't have to worry about this
          // case *if* the local file writer is always unbuffered?
          // But I probably don't remember correctly: what if
          // the local file writer's writev(2) call was a partial write?
          // Our local-vs-remote sync protocol then syncs to an offset
          // that ends at the partial write.  And then we stumble into
          // this case?
          //
          // This case is very rare but does happen.  TODO is it worth
          // splitting the data here? and procedding forward?
          _D.ds666("\tRJC %s: ======send_buffer_state: " +
            "TODO split offset %d data_size %d remote_size %d\n", _dl(),
            offset, data_size, _remote_size)
          _make_new_dos_then_local_size_discovery()
          return
        elseif offset == _remote_size then
          _D.ds666("\tRJC %s: ======send_buffer_state: " +
            "send_unframed offset %d data_size %d remote_size %d\n", _dl(),
            offset, data_size, _remote_size)
          // keep _local_size in sync with _remote_size
          _local_size = _local_size + data_size
          _dos.send_unframed(data)
          _remote_size = _remote_size + data_size
        else
          Fail()
        end
      end
      _buffer.clear()
      _buffer_size = 0
      _D.ds66("RJC %s: send_buffer_state _local_size %d _remote_size %d\n",
        _dl(), _local_size, _remote_size)
      _in_sync_state()
    end

  fun ref _in_sync_state() =>
    if _disposed then _D.ds6("RJC %s: line %d _disposed!\n", _dl(), __loc.line()); return end
    _D.ds66("RJC %s: in_sync_state _local_size %d _remote_size %d\n",
      _dl(), _local_size, _remote_size)
    if _state.num() != _SSendBuffer.num() then
      Fail()
    end
    _state = _SInSync

    _in_sync = true

  be be_writev(offset: USize, data: ByteSeqIter, data_size: USize) =>
    if _disposed then _D.ds6("RJC %s: line %d _disposed!\n", _dl(), __loc.line()); return end
    _D.ds6666("RJC %s: be_writev offset %d data_size %d, " +
      "_remote_size %d _buffer_size %d\n",
      _dl(), offset, data_size, _remote_size, _buffer_size)
    if _in_sync and (offset != (_remote_size + _buffer_size)) then
      if (offset + data_size) <= _remote_size then
        // During a catch-up phase, we copied a bunch of the missing
        // data from the local file -> remote file.  Due to asynchrony,
        // it's possible for the local file to be at size/offset B but
        // writev ops are delayed and only arrive here up to an
        // earlier offset A (where A < B).  The catchup phase has
        // already copied 100% of the bytes that are in this writev op.
        // We need to do nothing in this case.
        _D.ds66666("RJC %s: be_writev offset %d data_size %d, _remote_size %d " +
          "hey got old/delayed writev op for offset %d data_size %d\n",
          _dl(), offset, data_size, _remote_size, offset, data_size)
        return
      else
        // WHOA, we have an out-of-order problem, or we're missing
        // a write, or something else terrible.
        // TODO Should we go back to local_size_discovery()?
        Fail()
      end
    else
      // We aren't in sync. Do nothing here and wait for offset sanity
      // checking at buffer flush.
      None
    end
    if _in_sync then
      _dos.send_unframed(data)
      _remote_size = _remote_size + data_size
    else
      if _buffer_size < _buffer_max_size then
        _buffer.push((offset, data, data_size))
      else
        // We're over the max size. Clear buffer if it's full, but
        // keep counting buffered bytes.
        if _buffer.size() > 0 then
          _D.ds("\tRJC %s: ====be_writev: be_writev CLEAR _buffer\n", _dl())
          _buffer.clear()
        end
      end
      _buffer_size = _buffer_size + data_size
      _D.ds6("\tRJC %s: ====be_writev: be_writev new _buffer_size %d\n", _dl(), _buffer_size)
    end

  be dos_client_connection_status(connected: Bool) =>
    if _disposed then _D.ds6("RJC %s: line %d _disposed!\n", _dl(), __loc.line()); return end
    _D.dss("RJC %s: dos_client_connection_status %s\n",
      _dl(), connected.string())
    _connected = connected
    if not _connected then
      // We use the DOSclient in do_reconnect=false mode.  So we need
      // to manage disconnections ourselves.  When disconnected, we
      // not only need to reconnect but also to move the protocol forward
      // beyond its initial state: usedir, remote size discovery, start
      // append, etc.
      _usedir_sent = false
      _appending = false
      _in_sync = false
      _make_new_dos_then_local_size_discovery()
    else
      _local_size_discovery()
    end

  be notify_written_synced(usedir_name: String,
    written: USize, synced: USize)
  =>
    _D.dss66("RJC %s: usedir_name %s written %d synced %d\n",
      _dl(), usedir_name, written, synced)
