use "collections"
use "files"
use "net"
use "signals"
use "time"

actor Main
  new create(env: Env) =>
    try
      let timers = Timers

      let out_addr_raw = env.args(1).split(":")
      let in_addr_raw = env.args(2).split(":")

      let outgoing_address = DNS.ip4(out_addr_raw(0), out_addr_raw(1))(0)
      let incoming_host = in_addr_raw(0)
      let incoming_port = in_addr_raw(1)
      let store = Store(env)
      let receiver = Receiver(env, store, incoming_host, incoming_port)
      let sender = Sender(env, outgoing_address, store)

      let timer = Timer(DataGenerator(sender), 0, 5_000_000)
      let timer' = timer
      timers(consume timer)

      SignalHandler(TermHandler(store, receiver) , 15)
      SignalHandler(Usr1Handler(sender, timers, timer') , 30)
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
    _store = store
    _to = to
    _socket = UDPSocket(SenderNotify)

  be write(data: String) =>
    let put: String = "PUT:" + data
    let hexFormat = FormatSettingsInt.set_format(FormatHexBare)
    let h: String = put.size().string(hexFormat)
    let l: String = h.size().string(hexFormat)

    let packet = l + h + put

    _socket.write(packet, _to)
    _store.sent(data)

  be dispose() =>
    _socket.dispose()

class SenderNotify is UDPNotify
  fun ref received(sock: UDPSocket ref, data: Array[U8] iso, from: IPAddress) =>
    let data': ByteSeq = consume data
    let size = data'.size()
    sock.write(size.string(), from)

actor Receiver
  let _socket: UDPSocket

  new create(env: Env, store: Store, on_address: String, on_port: String) =>
    _socket = UDPSocket(ReceiverNotify(env, store), on_address, on_port)

  be dispose() =>
    _socket.dispose()

class ReceiverNotify is UDPNotify
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

  fun ref received(sock: UDPSocket ref, data: Array[U8] iso, from: IPAddress) =>
    _store.received(consume data)

actor Store
  let _env: Env
  let _sent: List[ByteSeq]
  let _received: List[ByteSeq]

  new create(env: Env) =>
    _env = env
    _sent = List[ByteSeq](1_000_000)
    _received = List[ByteSeq](1_000_000)

  be sent(msg: ByteSeq) =>
    _sent.push(msg)

  be received(msg: ByteSeq) =>
    _received.push(msg)

  be dump() =>
    try
      let sent_handle = File(FilePath(_env.root, "sent.txt"))
      for s in _sent.values() do
        sent_handle.print(s)
      end
      sent_handle.dispose()

      let received_handle = File(FilePath(_env.root, "received.txt"))
      for r in _received.values() do
        received_handle.print(r)
      end
      received_handle.dispose()
    else
      _env.out.print("dump exception")
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

class TermHandler is SignalNotify
  let _store: Store
  let _receiver: Receiver

  new iso create(store: Store, receiver: Receiver) =>
    _store = store
    _receiver = receiver

  fun ref apply(count: U32): Bool =>
    _receiver.dispose()
    _store.dump()
    true

class Usr1Handler is SignalNotify
  let _sender: Sender
  let _timers: Timers
  let _timer: Timer tag

  new iso create(sender: Sender, timers: Timers, timer: Timer tag) =>
    _sender = sender
    _timers = timers
    _timer = timer

  fun ref apply(count: U32): Bool =>
    _timers.cancel(_timer)
    _sender.dispose()
    true
