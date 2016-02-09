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

      let outgoing_address = DNS.ip4(out_addr_raw(0), out_addr_raw(1))(0)
      let store = Store(env)
      let sender = Sender(outgoing_address, store)

      let timer = Timer(DataGenerator(sender), 0, 5_000_000)
      let timer' = timer
      timers(consume timer)

      SignalHandler(TermHandler(sender, timers, timer', store), Sig.term())
    else
      env.out.print("wrong args")
    end

actor Sender
  let _to: IPAddress
  let _store: Store
  let _socket: UDPSocket

  new create(to: IPAddress, store: Store) =>
    _store = store
    _to = to
    _socket = UDPSocket(SenderNotify)

  be write(data: String) =>
    let at =  Time.micros()
    _socket.write(_build_output(data), _to)
    _store.sent(data, at)

  be dispose() =>
    _socket.dispose()

  fun _build_output(data: String): String =>
    let put: String = "PUT:" + data
    let hexFormat = FormatSettingsInt.set_format(FormatHexBare)
    let h: String = put.size().string(hexFormat)
    let l: String = h.size().string(hexFormat)

    recover
      String(l.size() + h.size() + put.size())
      .append(l)
      .append(h)
      .append(put)
    end

class SenderNotify is UDPNotify
  fun ref received(sock: UDPSocket ref, data: Array[U8] iso, from: IPAddress) =>
    let data': ByteSeq = consume data
    let size = data'.size()

actor Store
  let _env: Env
  let _sent: List[(ByteSeq, U64)]

  new create(env: Env) =>
    _env = env
    _sent = List[(ByteSeq, U64)](1_000_000)

  be sent(msg: ByteSeq, at: U64) =>
    _sent.push((msg, at))

  be dump() =>
    try
      let sent_handle = File(FilePath(_env.root, "sent.txt"))
      for s in _sent.values() do
        sent_handle.print(_format_output(s))
      end
      sent_handle.dispose()
    else
      _env.out.print("dump exception")
    end

  fun _format_output(tuple: (ByteSeq, U64)): String =>
    let time: String = tuple._2.string()
    let payload = tuple._1

    recover
      String(time.size() + ", ".size() + payload.size())
      .append(time)
      .append(", ")
      .append(payload)
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
  let _sender: Sender
  let _timers: Timers
  let _timer: Timer tag
  let _store: Store

  new iso create(sender: Sender, timers: Timers, timer: Timer tag, store: Store) =>
    _sender = sender
    _timers = timers
    _timer = timer
    _store = store

  fun ref apply(count: U32): Bool =>
    _timers.cancel(_timer)
    _sender.dispose()
    _store.dump()
    true
