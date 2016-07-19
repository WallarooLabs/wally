use "net"
use "options"
use "collections"
//use "buffy/messages"
use "sendence/messages"
use "sendence/epoch"
use "time"

actor Main
  new create(env: Env) =>
    var i_arg: (Array[String] | None) = None
    var o_arg: (Array[String] | None) = None

    try
      var options = Options(env)

      options
        .add("in", "i", StringArgument)
        .add("out", "o", StringArgument)

      for option in options do
        match option
        | ("in", let arg: String) => i_arg = arg.split(":")
        | ("out", let arg: String) => o_arg = arg.split(":")
        end
      end

      let in_addr = i_arg as Array[String]
      let out_addr = o_arg as Array[String]

      let connect_auth = TCPConnectAuth(env.root as AmbientAuth)
      let out_socket = TCPConnection(connect_auth,
            OutNotify,
            out_addr(0),
            out_addr(1))

      let last_pass = LastPass(out_socket)
      let first_pass = FirstPass(last_pass)

      let listen_auth = TCPListenAuth(env.root as AmbientAuth)
      let listener = TCPListener(listen_auth,
            ListenerNotify(first_pass),
            in_addr(0),
            in_addr(1))
    end

class ListenerNotify is TCPListenNotify
  let _fp: FirstPass

  new iso create(fp: FirstPass) =>
    _fp = fp

  fun ref connected(listen: TCPListener ref): TCPConnectionNotify iso^ =>
    IncomingNotify(_fp)

class IncomingNotify is TCPConnectionNotify
  let _fp: FirstPass
  var _header: Bool = true
  var _count: USize = 0

  new iso create(fp: FirstPass) =>
    _fp = fp

/*
  fun ref received(conn: TCPConnection ref, data: Array[U8] iso) =>
    try
      (let host, _) = conn.remote_address().name()
    end

    if _header then
      try
        _count = _count + 1
        if (_count % 100_000) == 0 then
          @printf[I32]("%zu received\n".cstring(), _count)
        end

        let expect = Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()
        conn.expect(expect)
        _header = false
      end
    else
      _fp.take(consume data)

      conn.expect(4)
      _header = true
    end
    */

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso) =>
    //try
    //   (let host, _) = conn.remote_address().name()
    //end

    if _header then
      try
        _count = _count + 1
        if (_count % 100_000) == 0 then
          @printf[I32]("%zu received\n".cstring(), _count)
        end

    if _count == 1 then
      @printf[None]("Start: %s\n".cstring(), Time.wall_to_nanos(Time.now()).string().cstring())
    end

        let expect = Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()

        conn.expect(expect)
        _header = false
      end
    else

/*
      try
        let msg = ExternalMsgDecoder(consume data)
        match msg
        | let m: ExternalDataMsg val =>
          //let now = Epoch.nanoseconds()
          let now: U64 = 1
          //let now = Time.wall_to_nanos(Time.now())
          _fp.take(m, now)

          //_fp.take3(_count.string(), now)
        else
          @printf[None]("no match\n".cstring())
        end
      end
*/
      //let m = ExternalDataMsg(String.from_array(consume data, 2))
      //_fp.take(m, 1)
      //_fp.take2(consume data, 1)
      //_fp.take3(String.from_array(consume data), 1)
      let new_msg: Message[Array[U8] val] val = Message[Array[U8] val](
            1, 1, 1, consume data)
      _fp.take4(new_msg)
      //_fp.take5(1, 1, 1, consume data)
      conn.expect(4)
      _header = true
    end

  fun ref accepted(conn: TCPConnection ref) =>
    @printf[None]("accepted\n".cstring())
    conn.expect(4)

  fun ref connected(sock: TCPConnection ref) =>
    @printf[None]("incoming connected\n".cstring())

class OutNotify is TCPConnectionNotify
  fun ref connected(sock: TCPConnection ref) =>
    @printf[None]("outgoing connected\n".cstring())

actor FirstPass
  let _last: LastPass

  new create(last: LastPass) =>
    _last = last

  be take(data: ExternalDataMsg val, s: U64) =>
    _last.take(data)

  be take2(data: Array[U8] val, s: U64) =>
    _last.take2(data)

  be take3(data: String val, s: U64) =>
    _last.take3(data)

  be take4(data: Message[Array[U8] val] val) =>
   // let message = Message[Array[U8] val](
    //        data.id(), data.source_ts(), data.last_ingress_ts(), data.data())
    _last.take4(data)

  be take5(a: U64, b: U64, c: U64, data: Array[U8] val) =>
    _last.take5(a,b,c,data)

actor LastPass
  var _count: USize = 0
  let _sender: TCPConnection
  let _buffer: WriteBuffer = WriteBuffer

  new create(sender: TCPConnection) =>
    _sender = sender

  be take(data: ExternalDataMsg val) =>
    _count = _count + 1
    if (_count % 100_000) == 0 then
      @printf[I32]("%zu sent\n".cstring(), _count)
    end

    if _count == 1000000 then
      @printf[None]("End: %s\n".cstring(), Time.wall_to_nanos(Time.now()).string().cstring())
    end

      _buffer.reserve_chunks(100)
    //let msg = Message[String](U64(1), U64(1), U64(1), data.data)

    let s: String val = data.data
    //let s: String val = _count.string()

    _buffer.u32_be((s.size() + 8).u32())
    //Message size field
    _buffer.u32_be((s.size() + 4).u32())
    _buffer.u32_be(s.size().u32())
    _buffer.write(s)
    _sender.writev(_buffer.done())

    //_sender.writev(FallorMsgEncoder(data.data, _buffer))
    //_sender.writev(FallorMsgEncoder(_count.string(), _buffer))
    //_sender.writev(FallorMsgEncoder(_count.string()))

    //_sender.write("hello")

  be take2(data: Array[U8] val) =>
    _count = _count + 1
    if (_count % 100_000) == 0 then
      @printf[I32]("%zu sent\n".cstring(), _count)
    end

    if _count == 1000000 then
      @printf[None]("End: %s\n".cstring(), Time.wall_to_nanos(Time.now()).string().cstring())
    end

    _buffer.reserve_chunks(100)

    //let s: String val = _count.string()
    let s = data
    _buffer.u32_be((s.size() + 8).u32())
    //Message size field
    _buffer.u32_be((s.size() + 4).u32())
    _buffer.u32_be(s.size().u32())
    _buffer.write(s)
    _sender.writev(_buffer.done())

  be take3(data: String val) =>
    _count = _count + 1
    if (_count % 100_000) == 0 then
      @printf[I32]("%zu sent\n".cstring(), _count)
    end

    if _count == 1000000 then
      @printf[None]("End: %s\n".cstring(), Time.wall_to_nanos(Time.now()).string().cstring())
    end

    _buffer.reserve_chunks(100)

    let s = data
    _buffer.u32_be((s.size() + 8).u32())
    //Message size field
    _buffer.u32_be((s.size() + 4).u32())
    _buffer.u32_be(s.size().u32())
    _buffer.write(s)
    _sender.writev(_buffer.done())

  be take4(data: Message[Array[U8] val] val) =>
    _count = _count + 1
    if (_count % 100_000) == 0 then
      @printf[I32]("%zu sent\n".cstring(), _count)
    end

    if _count == 1000000 then
      @printf[None]("End: %s\n".cstring(), Time.wall_to_nanos(Time.now()).string().cstring())
    end

    _buffer.reserve_chunks(100)

    let s = data.data()
    _buffer.u32_be((s.size()).u32())
    //Message size field
    _buffer.u32_be((s.size() + 4).u32())
    _buffer.u32_be(s.size().u32())
    _buffer.write(s)
    _sender.writev(_buffer.done())

  be take5(a: U64, b: U64, c: U64, data: Array[U8] val) =>
    _count = _count + 1
    if (_count % 100_000) == 0 then
      @printf[I32]("%zu sent\n".cstring(), _count)
    end

    if _count == 1000000 then
      @printf[None]("End: %s\n".cstring(), Time.wall_to_nanos(Time.now()).string().cstring())
    end

    _buffer.reserve_chunks(100)

    let s = data
    _buffer.u32_be((s.size() + 8).u32())
    //Message size field
    _buffer.u32_be((s.size() + 4).u32())
    _buffer.u32_be(s.size().u32())
    _buffer.write(s)
    _sender.writev(_buffer.done())

primitive Bytes
  fun length_encode(data: ByteSeq val): Array[ByteSeq] val =>
    let len: U32 = data.size().u32()
    let wb = WriteBuffer
    wb.u32_be(len)
    wb.write(data)
    wb.done()

  fun to_u16(high: U8, low: U8): U16 =>
    (high.u16() << 8) or low.u16()

  fun to_u32(a: U8, b: U8, c: U8, d: U8): U32 =>
    (a.u32() << 24) or (b.u32() << 16) or (c.u32() << 8) or d.u32()

  fun to_u64(a: U8, b: U8, c: U8, d: U8, e: U8, f: U8, g: U8, h: U8): U64 =>
    (a.u64() << 56) or (b.u64() << 48) or (c.u64() << 40) or (d.u64() << 32)
    or (e.u64() << 24) or (f.u64() << 16) or (g.u64() << 8) or h.u64()

  fun from_u16(u16: U16, arr: Array[U8] iso = recover Array[U8] end): Array[U8] iso^ =>
    let l1: U8 = (u16 and 0xFF).u8()
    let l2: U8 = ((u16 >> 8) and 0xFF).u8()
    arr.push(l2)
    arr.push(l1)
    consume arr

  fun from_u32(u32: U32, arr: Array[U8] iso = recover Array[U8] end): Array[U8] iso^ =>
    let l1: U8 = (u32 and 0xFF).u8()
    let l2: U8 = ((u32 >> 8) and 0xFF).u8()
    let l3: U8 = ((u32 >> 16) and 0xFF).u8()
    let l4: U8 = ((u32 >> 24) and 0xFF).u8()
    arr.push(l4)
    arr.push(l3)
    arr.push(l2)
    arr.push(l1)
    consume arr

  fun from_u64(u64: U64, arr: Array[U8] iso = recover Array[U8] end): Array[U8] iso^ =>
    let l1: U8 = (u64 and 0xFF).u8()
    let l2: U8 = ((u64 >> 8) and 0xFF).u8()
    let l3: U8 = ((u64 >> 16) and 0xFF).u8()
    let l4: U8 = ((u64 >> 24) and 0xFF).u8()
    let l5: U8 = ((u64 >> 32) and 0xFF).u8()
    let l6: U8 = ((u64 >> 40) and 0xFF).u8()
    let l7: U8 = ((u64 >> 48) and 0xFF).u8()
    let l8: U8 = ((u64 >> 56) and 0xFF).u8()
    arr.push(l8)
    arr.push(l7)
    arr.push(l6)
    arr.push(l5)
    arr.push(l4)
    arr.push(l3)
    arr.push(l2)
    arr.push(l1)
    consume arr

  fun u16_from_idx(idx: USize, arr: Array[U8]): U16 ? =>
    Bytes.to_u16(arr(idx), arr(idx + 1))

  fun u32_from_idx(idx: USize, arr: Array[U8]): U32 ? =>
    Bytes.to_u32(arr(idx), arr(idx + 1), arr(idx + 2), arr(idx + 3))

  fun u64_from_idx(idx: USize, arr: Array[U8]): U64 ? =>
    Bytes.to_u64(arr(idx), arr(idx + 1), arr(idx + 2), arr(idx + 3),
      arr(idx + 4), arr(idx + 5), arr(idx + 6), arr(idx + 7))

class Message[A: Any val]
  let _id: U64
  let _source_ts: U64
  let _last_ingress_ts: U64
  let _data: A

  new val create(msg_id: U64, s_ts: U64, i_ts: U64, msg_data: A) =>
    _id = msg_id
    _source_ts = s_ts
    _last_ingress_ts = i_ts
    _data = consume msg_data

  fun id(): U64 => _id
  fun source_ts(): U64 => _source_ts
  fun last_ingress_ts(): U64 => _last_ingress_ts
  fun data(): A => _data
