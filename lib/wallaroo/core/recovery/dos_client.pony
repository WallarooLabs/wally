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

use "collections"
use "files"
use "net"
use "promises"
use "time"
use "wallaroo_labs/bytes"
use "wallaroo_labs/mort"

type DOSreplyLS is Array[(String, USize, Bool)] val
type DOSreply is (String val| DOSreplyLS val)
primitive DOSappend
primitive DOSgetchunk
primitive DOSls
primitive DOSnoop
primitive DOSusedir
type DOSop is (DOSappend | DOSgetchunk | DOSls | DOSnoop | DOSusedir)

actor DOSclient
  var _auth: AmbientAuth
  let _host: String
  let _port: String
  let _rjc: RemoteJournalClient
  let _usedir_name: String
  var _sock: (TCPConnection | None) = None
  var _connected: Bool = false
  var _appending: Bool = false
  var _do_reconnect: Bool
  let _waiting_reply: Array[(DOSop, (Promise[DOSreply]| None))] = _waiting_reply.create()
  var _status_notifier: (({(Bool, Any): None}) | None) = None
  let _timers: Timers = Timers
  var _last_episode: USize = 0

  new create(auth: AmbientAuth, host: String, port: String,
    rjc: RemoteJournalClient, usedir_name: String = "{none}",
    do_reconnect: Bool = true)
  =>
    ifdef "dos-verbose" then
      @printf[I32]("DOS: dos-client %s 0x%lx create\n".cstring(), usedir_name.cstring(), this)
    end
    _auth = auth
    _host = host
    _port = port
    _rjc = rjc
    _usedir_name = usedir_name
    _do_reconnect = do_reconnect
    _reconn()

  be connection_status_notifier(status_notifier: {(Bool, Any): None} iso) =>
    _status_notifier = consume status_notifier
    // Deal with a race where we were connected before the status notifier
    // lambda arrives here.
    if _connected then
      _call_status_notifier(true)
    end

  fun ref _reconn(): None =>
    ifdef "dos-verbose" then
       @printf[I32]("DOS: dos-client %s 0x%lx _reconn\n".cstring(), _usedir_name.cstring(), this)
    end
    _connected = false
    _appending = false
    _sock = TCPConnection(_auth, recover DOSnotify(this, _usedir_name) end, _host, _port)

  be dispose() =>
    ifdef "dos-verbose" then
      @printf[I32]("DOS: dos-client %s 0x%lx dispose\n".cstring(), _usedir_name.cstring(), this)
    end
    _do_reconnect = false
    _dispose()

  fun ref _dispose() =>
    ifdef "dos-verbose" then
      @printf[I32]("DOS: dos-client %s 0x%lx _dispose.  Promises to reject: %d\n".cstring(), _usedir_name.cstring(), this, _waiting_reply.size())
    end
    try (_sock as TCPConnection).dispose() end
    _connected = false
    _appending = false
    for (op, p) in _waiting_reply.values() do
      match p
      | None => None
      | let pp: Promise[DOSreply] =>
        _D.d6("@@@@@@@@@@@@@@@@ promise reject, line %d\n", __loc.line())
        pp.reject()
      end
    end
    _waiting_reply.clear()

  be connected() =>
    ifdef "dos-verbose" then
      @printf[I32]("DOS: dos-client %s 0x%lx connected\n".cstring(), _usedir_name.cstring(), this)
    end
    _connected = true
    _call_status_notifier(true)

  fun ref _call_status_notifier(connect_status: Bool) =>
    try
      (_status_notifier as {(Bool, Any): None})(connect_status, this)
    end

  be disconnected() =>
    @printf[I32]("DOS: dos-client %s 0x%lx disconnected\n".cstring(), _usedir_name.cstring(), this)
    _disconnected()

  fun ref _disconnected() =>
    ifdef "dos-verbose" then
      @printf[I32]("DOS: dos-client %s 0x%lx _disconnected\n".cstring(), _usedir_name.cstring(), this)
    end
    if _connected then
      _call_status_notifier(false)
    end
    _dispose()
    if _do_reconnect then
      _reconn()
    end

  be throttled(episode: USize) =>
    ifdef "dos-verbose" then
      @printf[I32]("DOS: dos-client %s 0x%lx throttled, episode %d\n".cstring(), _usedir_name.cstring(), this, episode)
    end
    _last_episode = episode
    let dos = recover tag this end
    let later = _DoLater(recover
      {(): Bool =>
        dos.throttled_check(_last_episode)
        false
      } end)
    let t = Timer(consume later, 2_000_000_000)
    _timers(consume t)

  be unthrottled(episode: USize) =>
    ifdef "dos-verbose" then
      @printf[I32]("DOS: dos-client %s 0x%lx unthrottled, episode %d\n".cstring(), _usedir_name.cstring(), this, episode)
    end
    _last_episode = episode

  be throttled_check(last_episode: USize) =>
    ifdef "dos-verbose" then
      @printf[I32]("DOS: dos-client %s 0x%lx throttled_check last_episode %d\n".cstring(), _usedir_name.cstring(), this, last_episode)
    end
    if last_episode <= _last_episode then
      // The connection's throttled status has not changed since
      // the timer started. Disconnect and (perhaps) reconnect.
      _disconnected()
    end

  be send_unframed(data: ByteSeqIter) =>
    if _connected and _appending then
      try (_sock as TCPConnection).writev(data) end
    else
      _D.d("\n\n\t\tsend_unframed: not (connected && appending)\n\n")
    end

  be start_streaming_append(filename: String, offset: USize,
    p: (Promise[DOSreply] | None) = None)
  =>
    let request: String iso = recover String end

    if _connected and (not _appending) then
      let pdu: String = "a" + filename + "\t" + offset.string()
      ifdef "dos-verbose" then
        @printf[I32]("DOS: dos-client %s 0x%lx start_streaming_append: %s offset %d\n".cstring(), _usedir_name.cstring(), this, filename.cstring(), offset)
      end
      request.push(0)
      request.push(0)
      request.push(0)
      request.push(pdu.size().u8()) // TODO: bogus if request size > 255
      request.append(pdu)
      try (_sock as TCPConnection).write(consume request) end
      _waiting_reply.push((DOSappend, p))
    else
      match p
      | None =>
        ifdef "dos-verbose" then
          @printf[I32]("DOS: dos-client %s 0x%lx: ERROR: streaming_append not connected, no promise!  TODO\n".cstring(), _usedir_name.cstring(), this)
        end
        None
      | let pp: Promise[DOSreply] =>
        ifdef "dos-verbose" then
          @printf[I32]("DOS: dos-client %s 0x%lx: ERROR: streaming_append not connected, reject!  TODO\n".cstring(), _usedir_name.cstring(), this)
        end
        _D.d6("@@@@@@@@@@@@@@@@ promise reject, line %d\n", __loc.line())
        pp.reject()
      end
    end

  be do_ls(p: (Promise[DOSreply] | None) = None) =>
    let request: String iso = recover String end

    if _connected and (not _appending) then
      ifdef "dos-verbose" then
        @printf[I32]("DOS: dos-client %s 0x%lx do_ls\n".cstring(), _usedir_name.cstring(), this)
      end
      request.push(0)
      request.push(0)
      request.push(0)
      request.push(1)
      request.append("l")

      try (_sock as TCPConnection).write(consume request) end
      _waiting_reply.push((DOSls, p))
    else
      match p
      | None =>
        ifdef "dos-verbose" then
          @printf[I32]("DOS: dos-client %s 0x%lx %s: ERROR: ls not connected, no promise!\n".cstring(), _usedir_name.cstring(), this, _usedir_name.cstring())
        end
        None
      | let pp: Promise[DOSreply] =>
        ifdef "dos-verbose" then
          @printf[I32]("DOS: dos-client %s 0x%lx %s: ERROR: ls not connected, reject!  TODO\n".cstring(), _usedir_name.cstring(), this, _usedir_name.cstring())
        end
        _D.d6("@@@@@@@@@@@@@@@@ promise reject, line %d\n", __loc.line())
        pp.reject()
      end
    end

  be do_get_chunk(filename: String, offset: USize, size: USize,
    p: (Promise[DOSreply] | None) = None)
  =>
    let request: String iso = recover String end

    if _connected and (not _appending) then
      let pdu: String = "g" + filename + "\t" + offset.string() + "\t" + size.string()
      ifdef "dos-verbose" then
        @printf[I32]("DOS: dos-client %s 0x%lx do_get_chunk: %s\n".cstring(), _usedir_name.cstring(), this, pdu.cstring())
      end

      request.push(0)
      request.push(0)
      request.push(0)
      request.push(pdu.size().u8()) // TODO: bogus if request size > 255
      request.append(pdu)
      try (_sock as TCPConnection).write(consume request) end
      _waiting_reply.push((DOSgetchunk, p))
    else
      match p
      | None =>
        ifdef "dos-verbose" then
          @printf[I32]("DOS: dos-client %s 0x%lx %s: ERROR: get_chunk not connected, no promise!  TODO\n".cstring(), _usedir_name.cstring(), this, _usedir_name.cstring())
        end
        None
      | let pp: Promise[DOSreply] =>
        ifdef "dos-verbose" then
          @printf[I32]("DOS: dos-client %s 0x%lx %s: ERROR: get_chunk not connected, reject!  TODO\n".cstring(), _usedir_name.cstring(), this, _usedir_name.cstring())
        end
        _D.d6("@@@@@@@@@@@@@@@@ promise reject, line %d\n", __loc.line())
        pp.reject()
      end
    end

  be do_get_file[T: Any #share](filename: String,
    file_size: USize, chunk_size: USize,
    chunk_success: {(USize, DOSreply): T} val, chunk_failed: {(USize): T} val,
    notify_get_file_complete: {(Bool, Array[T] val): None} val,
    error_on_failure: Bool = true)
  =>
    let chunk_ps: Array[Promise[T]] = chunk_ps.create()

    for offset in Range[USize](0, file_size, chunk_size) do
      let p0 = Promise[DOSreply]
      // TODO add timeout goop
      let p1 = p0.next[T](
        {(chunk: DOSreply): T =>
          chunk_success.apply(offset, chunk)
        },
        {(): T ? =>
          if error_on_failure then
            // Cascade the error through the rest of the promise chain.
            // The end-of-file lambda will get an empty array of Ts and
            // thus won't be able to figure out where the error happened.
            error
          else
            // Allow chunk_failed to created a T object that the
            // end-of-file lambda can examine in its array of Ts and
            // thus figure out where the error happened.
            chunk_failed.apply(offset)
          end
        })
      chunk_ps.push(p1)
      do_get_chunk(filename, offset, chunk_size, p0)
    end

    let p_all_chunks1 = Promises[T].join(chunk_ps.values())
    p_all_chunks1.next[None](
      {(ts: Array[T] val): None =>
        ifdef "dos-verbose" then
          @printf[I32]("PROMISE BIG: yay\n".cstring())
        end
        notify_get_file_complete(true, ts)
        },
      {(): None =>
        _D.d("PROMISE BIG: BOOOOOO\n")
        let empty_array: Array[T] val = recover empty_array.create() end
       notify_get_file_complete(false, empty_array)
      })

  be do_usedir(name: String, p: (Promise[DOSreply] | None) = None)
  =>
    let request: String iso = recover String end

    if _connected and (not _appending) then
      let pdu: String = "u" + name
      ifdef "dos-verbose" then
        @printf[I32]("DOS: dos-client %s 0x%lx do_usedir: %s\n".cstring(), _usedir_name.cstring(), this, name.cstring())
      end
      request.push(0)
      request.push(0)
      request.push(0)
      request.push(pdu.size().u8()) // TODO: bogus if request size > 255
      request.append(pdu)
      try (_sock as TCPConnection).write(consume request) end
      _waiting_reply.push((DOSusedir, p))
    else
      match p
      | None =>
        ifdef "dos-verbose" then
          @printf[I32]("DOS: dos-client %s 0x%lx %s: ERROR: do_usedir not connected, no promise!  TODO\n".cstring(), _usedir_name.cstring(), this, _usedir_name.cstring())
        end
        None
      | let pp: Promise[DOSreply] =>
        ifdef "dos-verbose" then
          @printf[I32]("DOS: dos-client %s 0x%lx %s: ERROR: do_usedir not connected, reject!  TODO\n".cstring(), _usedir_name.cstring(), this, _usedir_name.cstring())
        end
        _D.d6("@@@@@@@@@@@@@@@@ promise reject, line %d\n", __loc.line())
        pp.reject()
      end
    end

  // Used only by the DOSnotify socket thingie
  be response(data: Array[U8] iso) =>
    let str = String.from_array(consume data)
    ifdef "dos-verbose" then
      @printf[I32]("DOS: dos-client %s 0x%lx GOT: %s\n".cstring(), _usedir_name.cstring(), this, str.cstring())
    end
    try
      (let op, let p) = _waiting_reply.shift()?
      match p
      | None =>
        _D.ds("DOSclient: %s: None op\n", _usedir_name)
        None
      | let pp: Promise[DOSreply] =>
        try
          match op
          | DOSappend =>
            _D.dss("DOSclient: %s: append response GOT: %s\n", _usedir_name, str)
            if str == "ok" then
              _appending = true
            end
            pp(str)
          | DOSls =>
            _D.dss("DOSclient: %s: ls response GOT: %s\n", _usedir_name, str)
            let lines = recover val str.split("\n") end
            let res: Array[(String, USize, Bool)] iso = recover res.create() end

            for l in lines.values() do
              let fs = l.split("\t")
              if fs.size() == 0 then
                // This is the split value after the final \n of the output
                break
              end
              let file = fs(0)?
              let size = fs(1)?.usize()?
              let b = if fs(2)? == "no" then false else true end
              res.push((file, size, b))
            end
            pp(consume res)
          | DOSgetchunk =>
            _D.dss("DOSclient: %s: get response GOT: %s\n", _usedir_name, str)
            pp(str)
          | DOSusedir =>
            _D.dss("DOSclient: %s: usedir response GOT: %s\n", _usedir_name, str)
            pp(str)
          end
        else
          // Protocol parsing error, e.g., for DOSls.
          // Reject so client can proceed.
          _D.ds6("DOSclient: %s: promise reject, line %d\n", _usedir_name, __loc.line())
          pp.reject()
        end
      end
    else
      if _appending then
        // We are appending.  Let's send these stats to our local Pony client.
        try
          let fs = str.split("\t")
          let written = fs(0)?.usize()?
          let synced = fs(1)?.usize()?
          _D.ds66("DOSclient: %s appending stats: written %d synced %d\n",
            _usedir_name, written, synced)
          _rjc.notify_written_synced(_usedir_name, written, synced)
        else
          Fail()
        end
      else
        // If the error is due to the socket being closed, then
        // all promises that are still in_waiting_reply will
        // be rejected by our disconnected() behavior.
        None
      end
    end

class DOSnotify is TCPConnectionNotify
  let _client: DOSclient
  var _header: Bool = true
  var _episode: USize = 0
  let _qqq_crashme: I64 = 111111116 // TODO delete me & test failure another way
  var _qqq_count: I64 = _qqq_crashme
  let _usedir_name: String

  new create(client: DOSclient, usedir_name: String) =>
    _client = client
    _usedir_name = usedir_name

  fun ref connect_failed(conn: TCPConnection ref) =>
    ifdef "dos-verbose" then
      @printf[I32]("SOCK: %s 0x%lx connect_failed\n".cstring(), _usedir_name.cstring(), _client)
    end

    // If the connection failed, then the server is down.
    // Reconnection will be attempted as soon as the status notification
    // arrives ...so let's delay that notification for a bit.
    let ts: Timers = Timers
    let later = _DoLater(recover {(): Bool =>
      _client.disconnected()
      false
    } end)
    let t = Timer(consume later, 500_000_000)
    ts(consume t)

  fun ref connected(conn: TCPConnection ref) =>
    ifdef "dos-verbose" then
      @printf[I32]("SOCK: %s 0x%lx connected.\n".cstring(), _usedir_name.cstring(), _client)
    end
    _header = true
    conn.set_nodelay(true)
    conn.set_keepalive(10)
    try
      conn.expect(4)?
    else
      Fail()
    end
    _client.connected()

  fun ref received(
    conn: TCPConnection ref,
    data: Array[U8] iso,
    times: USize)
    : Bool
  =>
    if _header then
      ifdef "dos-verbose" then
        @printf[I32]("SOCK: %s 0x%lx received header\n".cstring(), _usedir_name.cstring(), _client)
      end
      try
        let expect = Bytes.to_u32(data(0)?, data(1)?, data(2)?, data(3)?).usize()
        conn.expect(expect)?
        ifdef "dos-verbose" then
          @printf[I32]("SOCK: %s 0x%lx received header, expect = %d\n".cstring(), _usedir_name.cstring(), _client, expect)
        end
        if expect > 0 then
          _header = false
        else
          _client.response(recover [] end)
          conn.expect(4)?
          _header = true
        end
      else
        ifdef "dos-verbose" then
          @printf[I32]("SOCK: %s 0x%lx Error reading header on control channel\n".cstring(), _usedir_name.cstring(), _client)
        end
      end
    else
      ifdef "dos-verbose" then
        @printf[I32]("SOCK: %s 0x%lx received payload size %d\n".cstring(), _usedir_name.cstring(), _client, data.size())
      end
      _client.response(consume data)
      try
        conn.expect(4)?
      else
        Fail()
      end
      _header = true
    end
    false

  // NOTE: There is *not* a 1-1 correspondence between socket write/writev
  // and calling sent().  TCPConnection will do its own buffering and
  // may call sent() more or less frequently.
  fun ref sent(conn: TCPConnection ref, data: ByteSeq): ByteSeq =>
    ifdef "dos-verbose" then
      @printf[I32]("SOCK: %s 0x%lx sent %d, crashme %lu\n".cstring(), _usedir_name.cstring(), _client, data.size(), USize.from[I64](_qqq_count))
    end
    _qqq_count = _qqq_count - 1
    if _qqq_count <= 0 then
      conn.close()
      conn.dispose()
      _qqq_count = _qqq_crashme
    end
    data

  fun ref sentv(conn: TCPConnection ref, data: ByteSeqIter): ByteSeqIter =>
    ifdef "dos-verbose" then
      @printf[I32]("SOCK: %s 0x%lx sentv ?, crashme %lu\n".cstring(), _usedir_name.cstring(), _client, USize.from[I64](_qqq_count))
    end
    _qqq_count = _qqq_count - 1
    if _qqq_count <= 0 then
      conn.close()
      conn.dispose()
      _qqq_count = _qqq_crashme
    end
    data

  fun ref closed(conn: TCPConnection ref) =>
    ifdef "dos-verbose" then
      @printf[I32]("SOCK: %s 0x%lx closed\n".cstring(), _usedir_name.cstring(), _client)
    end
    _client.disconnected()

  fun ref throttled(conn: TCPConnection ref) =>
    ifdef "dos-verbose" then
      @printf[I32]("SOCK: %s 0x%lx throttled\n".cstring(), _usedir_name.cstring(), _client)
    end
    _client.throttled(_episode)
    _episode = _episode + 1

  fun ref unthrottled(conn: TCPConnection ref) =>
    ifdef "dos-verbose" then
      @printf[I32]("SOCK: %s 0x%lx unthrottled\n".cstring(), _usedir_name.cstring(), _client)
    end
    _client.unthrottled(_episode)
    _episode = _episode + 1

class _DoLater is TimerNotify
  let _f: {(): Bool} iso

  new iso create(f: {(): Bool} iso) =>
    _f = consume f

  fun ref apply(t: Timer, c: U64): Bool =>
    _f()

