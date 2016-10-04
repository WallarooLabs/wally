use "collections"
use "net"
use "buffered"
use "options"
use "time"
use "serialise"
use "sendence/bytes"
use "sendence/fix"
use "sendence/new-fix"

interface Processor
  fun apply(d: Array[U8] val) ?

class SourceProcessor
  let _target: TCPConnection
  let _auth: AmbientAuth

  new create(target: TCPConnection, auth: AmbientAuth) =>
    _target = target
    _auth = auth
    @printf[I32]("Configured as Source!\n".cstring())

  fun apply(d: Array[U8] val) ? =>
    let msg = MsgEncoder.forward(d, "Multi-Pass", Time.nanos(), _auth)
    _target.writev(msg)

class PassProcessor
  let _target: TCPConnection

  new create(target: TCPConnection) =>
    _target = target
    @printf[I32]("Configured as Passthrough!\n".cstring())

  fun apply(d: Array[U8] val) =>
    @printf[I32]("Received!\n".cstring())
    _target.write(Bytes.from_u32(d.size().u32()))
    _target.write(d)

class SinkProcessor
  let _target: TCPConnection

  new create(target: TCPConnection) =>
    _target = target
    @printf[I32]("Configured as Sink!\n".cstring())

  fun apply(d: Array[U8] val) =>
    @printf[I32]("Received!\n".cstring())
    _target.write(Bytes.from_u32(d.size().u32()))
    _target.write(d)

class IncomingNotify is TCPConnectionNotify
  let _auth: AmbientAuth
  let _processor: Processor
  let _expected: USize
  var _header: Bool = true
  var _count: USize = 0
  var _latest: (Complex val | None) = None

  var _msg_count: USize = 0

  new iso create(auth: AmbientAuth, target: TCPConnection, expected: USize,
    is_source: Bool, is_sink: Bool) 
  =>
    _processor = 
      if is_source then
        SourceProcessor(target, auth)
      elseif is_sink then
        SinkProcessor(target)
      else
        PassProcessor(target)
      end
    _expected = expected
    _auth = auth

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso): Bool =>
    if _header then
      try
        _count = _count + 1
        let expect = Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()
        conn.expect(expect)
        _header = false
      end
    else
      if _count <= _expected then
        try
          _processor(consume data)
        else
          @printf[I32]("Error processing incoming message\n".cstring())
        end
      end

      conn.expect(4)
      _header = true
    end
    false

  fun ref accepted(conn: TCPConnection ref) =>
    @printf[None]("accepted\n".cstring())
    conn.expect(4)

  fun ref connected(sock: TCPConnection ref) =>
    @printf[None]("incoming connected\n".cstring())

class OutNotify is TCPConnectionNotify
  fun ref connected(sock: TCPConnection ref) =>
    @printf[None]("outgoing connected\n".cstring())

///
/// YAWN from here on down
///

actor Main
  new create(env: Env) =>
    var i_arg: (Array[String] | None) = None
    var o_arg: (Array[String] | None) = None
    var m_arg: (Array[String] | None) = None
    var is_source: Bool = false
    var is_sink: Bool = false
    var expected: USize = 1_000_000

    try
      var options = Options(env.args)

      options
        .add("in", "i", StringArgument)
        .add("out", "o", StringArgument)
        .add("metrics", "m", StringArgument)
        .add("source", "r", None)
        .add("sink", "s", None)
        .add("expected", "e", I64Argument)

      for option in options do
        match option
        | ("in", let arg: String) => i_arg = arg.split(":")
        | ("out", let arg: String) => o_arg = arg.split(":")
        | ("metrics", let arg: String) => m_arg = arg.split(":")
        | ("source", None) => is_source = true
        | ("sink", None) => is_sink = true
        | ("expected", let arg: I64) => expected = arg.usize()
        end
      end

      let in_addr = i_arg as Array[String]
      let out_addr = o_arg as Array[String]
      let metrics_addr = m_arg as Array[String]
      let auth = env.root as AmbientAuth

      let connect_auth = TCPConnectAuth(auth)
      let out_socket = TCPConnection(connect_auth,
            OutNotify,
            out_addr(0),
            out_addr(1))

      let listen_auth = TCPListenAuth(auth)
      let listener = TCPListener(listen_auth,
            ListenerNotify(auth, out_socket, expected, is_source, is_sink),
            in_addr(0),
            in_addr(1))

      @printf[I32]("Expecting %zu messages\n".cstring(), expected)
    end

class ListenerNotify is TCPListenNotify
  let _fp: TCPConnection
  let _expected: USize
  let _auth: AmbientAuth
  let _is_source: Bool
  let _is_sink: Bool

  new iso create(auth: AmbientAuth, fp: TCPConnection, expected: USize,
    is_source: Bool, is_sink: Bool) =>
    _fp = fp
    _expected = expected
    _auth = auth
    _is_source = is_source
    _is_sink = is_sink

  fun ref connected(listen: TCPListener ref): TCPConnectionNotify iso^ =>
    IncomingNotify(_auth, _fp, _expected, _is_source, _is_sink)


class Complex
  let _real: I32
  let _imaginary: I32

  new val create(r: I32, i: I32) =>
    _real = r
    _imaginary = i

  fun real(): I32 => _real
  fun imaginary(): I32 => _imaginary

  fun plus(c: Complex val): Complex val =>
    Complex(_real + c._real, _imaginary + c._imaginary)
 
  fun minus(c: Complex val): Complex val =>
    Complex(_real - c._real, _imaginary - c._imaginary)

  fun mul(u: I32): Complex val =>
    Complex(u * _real, u * _imaginary)

  fun conjugate(): Complex val =>
    Complex(_real, -_imaginary)

  fun string(fmt: FormatSettings[FormatDefault, PrefixDefault] 
    = FormatSettingsDefault): String iso^
  =>
    ("C(" + _real.string() + ", " + _imaginary.string() + ")").clone()

primitive ComplexSourceParser 
  fun apply(data: Array[U8] val): Complex val ? => 
    let real = Bytes.to_u32(data(0), data(1), data(2), data(3))
    let imaginary = Bytes.to_u32(data(4), data(5), data(6), data(7))
    Complex(real.i32(), imaginary.i32())

primitive ComplexEncoder
  fun apply(c: Complex val, wb: Writer = Writer): Array[ByteSeq] val =>
    // Header
    wb.u32_be(8)
    // Fields
    wb.i32_be(c.real())
    wb.i32_be(c.imaginary())
    wb.done()

primitive MsgEncoder
  fun _encode(msg: ForwardMsg val, auth: AmbientAuth, 
    wb: Writer = Writer): Array[ByteSeq] val ? 
  =>
    let serialised: Array[U8] val =
      Serialised(SerialiseAuth(auth), msg).output(OutputSerialisedAuth(auth))
    let size = serialised.size()
    if size > 0 then
      wb.u32_be(size.u32())
      wb.write(serialised)
    end
    wb.done()

  fun forward(data: Array[U8] val, metric_name: String, source_ts: U64,
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(ForwardMsg(data, metric_name, source_ts), auth)

class ForwardMsg
  let data: Array[U8] val
  let metric_name: String
  let source_ts: U64

  new val create(d: Array[U8] val, m: String, s_ts: U64) =>
    data = d
    metric_name = m
    source_ts = s_ts
