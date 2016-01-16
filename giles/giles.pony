use "collections"
use "net"
use "time"

actor Main
  new create(env: Env) =>
    try
      let timers = Timers

      let outgoing_address = DNS.ip4(env.args(1), env.args(2))(0)
      let incoming_address = env.args(3)
      let incoming_port = env.args(4)
      let store = Store(env)
      let sender = Sender(env, outgoing_address, store)
      UDPSocket.ip4(Receiver(env, store), incoming_address, incoming_port)

      let timer = Timer(DataGenerator(sender), 0, 5_000_000)
      timers(consume timer)
    else
      env.out.print("wrong args")
    end

actor Sender
  let _to: IPAddress
  let _env: Env
  let _store: Store
  let _socket: UDPSocket

  new create(env: Env, to: IPAddress, store: Store) =>
    _env = env
    _to = to
    _store = store
    _socket = UDPSocket.ip4(EmptyNotify(_env))

  be write(data: String) =>
    //_env.out.print("sending")
    let put: String = "PUT:" + data
    let h: String = put.size().string(FormatHexBare)
    let l: String = h.size().string(FormatHexBare)

    let packet = l + h + put

    _socket.write(packet, _to)
    _store.sent(packet)

class EmptyNotify is UDPNotify
  let _env: Env

  new iso create(env: Env) =>
    _env = env

  fun ref listening(sock: UDPSocket  ref) =>
    try
      (let host, let service) = sock.local_address().name()
      _env.out.print("listening on " + host + ":" + service)
    else
      _env.out.print("couldn't get local address")
    end

  fun ref not_listening(sock: UDPSocket ref) =>
    _env.out.print("couldn't listen")
    sock.dispose()

class Receiver is UDPNotify
  let _env: Env
  let _store: Store

  new iso create(env: Env, store: Store) =>
    _env = env
    _store = store

  fun ref listening(sock: UDPSocket  ref) =>
    try
      (let host, let service) = sock.local_address().name()
      _env.out.print("listening on " + host + ":" + service)
    else
      _env.out.print("couldn't get local address")
    end

  fun ref not_listening(sock: UDPSocket ref) =>
    _env.out.print("couldn't listen")
    sock.dispose()

  fun ref received(sock: UDPSocket ref, data: Array[U8] iso, from: IPAddress)
    =>
    _store.received(consume data)

actor Store
  let _env: Env
  let _sent: HashMap[ByteSeq, ByteSeq, HashByteSeq]
  let _received: HashMap[ByteSeq, ByteSeq, HashByteSeq]

  new create(env: Env) =>
    _env = env
    _sent = HashMap[ByteSeq, ByteSeq, HashByteSeq]
    _received = HashMap[ByteSeq, ByteSeq, HashByteSeq]

  be sent(msg: ByteSeq) =>
    _sent(msg) = msg

  be received(msg: ByteSeq) =>
    _received(msg) = msg

    try
      _sent(msg)
    else
      _env.out.print("bad message")
      _env.out.print(msg)
    end

primitive HashByteSeq
  fun hash(x: ByteSeq): U64 =>
    @hash_block[U64](x.cstring(), x.size())

  fun eq(x: ByteSeq, y: ByteSeq): Bool =>
    if x.size() == y.size() then
      @memcmp[I32](x.cstring(), y.cstring(), x.size()) == 0
    else
      false
    end

class DataGenerator is TimerNotify
  var _counter: U64
  let _sender: Sender

  new iso create(sender: Sender) =>
    _counter = 0
    _sender = sender

  fun ref _next(): String =>
    _counter = _counter + 1
    _counter.string()

  fun ref apply(timer: Timer, count: U64): Bool =>
    _sender.write(_next())
    true
