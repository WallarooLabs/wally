use "bureaucracy"
use "collections"
use "files"
use "net"
use "signals"
use "time"

actor Main
  new create(env: Env) =>
    try
      let custodian = Custodian

      let out_addr_raw = env.args(1).split(":")
      let messages_to_send = env.args(2).u64()
      let messages_file_name = try
        env.args(3)
      else
        None
      end

      let store = Store(env)
      custodian(store)
      match SenderFactory(env, consume out_addr_raw, store)
      | let sender: Sender =>
        try
          custodian(sender)

          let data_source = match messages_file_name
          | let mfn: String =>
            try
              FileDataSource(custodian, sender, mfn, env, messages_to_send)
            else
              env.err.print("Error opening file '" + mfn + "'.")
              error
            end
          else
            IntegerDataSource(custodian, sender, messages_to_send)
          end

          let timer = Timer(consume data_source, 0, 5_000_000)
          let timer' = timer
          let timers = Timers
          timers(consume timer)
          custodian(timers)
        else
          env.err.print("Unable to setup data source. Exiting.")
          env.exitcode(1)
          custodian.dispose()
        end

        SignalHandler(TermHandler(custodian), Sig.term())
      | None =>
        env.err.print("Unable to setup application. Exiting.")
        env.exitcode(1)
        return
      end
    else
      env.out.print("running tests")
      TestMain(env)
      //env.out.print("wrong args")
    end

class SenderFactory
  fun apply(env: Env, out_addr_raw: Array[String], store: Store): (Sender | None) =>
    try
      let outgoing_address = DNS.ip4(
        env.root as AmbientAuth,
        out_addr_raw(0),
        out_addr_raw(1))(0)
      let socket = UDPSocket(env.root as AmbientAuth, SenderNotify)
      return Sender(outgoing_address, store, socket)
    else
      env.err.print("Unable to open udp socket")
      return None
    end

actor Sender
  let _to: IPAddress
  let _store: Store
  let _socket: UDPSocket
  let _encoder: Encoder = Encoder

  new create(to: IPAddress, store: Store, socket: UDPSocket) =>
    _store = store
    _to = to
    _socket = socket

  be write(data: String) =>
    let at =  Time.micros()
    _socket.write(_encoder(data), _to)
    _store.sent(data, at)

  be dispose() =>
    _socket.dispose()

class SenderNotify is UDPNotify
  fun ref received(sock: UDPSocket ref, data: Array[U8] iso, from: IPAddress) =>
    let data': ByteSeq = consume data
    let size = data'.size()

class Encoder
  fun apply(data: String): String =>
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

actor Store
  let _env: Env
  let _sent: List[(ByteSeq, U64)]
  let _encoder: SentLogEncoder = SentLogEncoder

  new create(env: Env) =>
    _env = env
    _sent = List[(ByteSeq, U64)](1_000_000)

  be sent(msg: ByteSeq, at: U64) =>
    _sent.push((msg, at))

  be dispose() =>
    _dump()

  fun _dump() =>
    try
      let sent_handle = File(FilePath(_env.root as AmbientAuth, "sent.txt"))
      for s in _sent.values() do
        sent_handle.print(_encoder(s))
      end
      sent_handle.dispose()
    else
      _env.out.print("dump exception")
    end

class SentLogEncoder
  fun apply(tuple: (ByteSeq, U64)): String =>
    let time: String = tuple._2.string()
    let payload = tuple._1

    recover
      String(time.size() + ", ".size() + payload.size())
      .append(time)
      .append(", ")
      .append(payload)
    end

class FileDataSource is TimerNotify
  var _counter: U64
  let _sender: Sender
  let _custodian: Custodian
  let _env: Env
  let _messages_to_send: U64
  let _messages_handle: File
  let _lines: Iterator[String]

  new iso create(custodian: Custodian, sender: Sender,
    message_file_name: String, env: Env, messages_to_send: U64) ?
  =>
    _counter = 0
    _sender = sender
    _custodian = custodian
    _messages_to_send = messages_to_send
    _env = env
    let path = FilePath(_env.root as AmbientAuth, message_file_name)
    if not path.exists() then
      error
    end
    _messages_handle = File(path)
    _lines = _messages_handle.lines()

  fun ref _next(): String =>
    _counter = _counter + 1
    try
      return _lines.next()
    else
      return ""
    end

  fun ref apply(timer: Timer, count: U64): Bool =>
    if _messages_to_send > _counter then
      _sender.write(_next())
      return true
    else
      _messages_handle.dispose()
      _custodian.dispose()
      return false
    end
  
class IntegerDataSource is TimerNotify
  var _counter: U64
  let _sender: Sender
  let _custodian: Custodian
  let _messages_to_send: U64

  new iso create(custodian: Custodian, sender: Sender, messages_to_send: U64) =>
    _counter = 0
    _sender = sender
    _custodian = custodian
    _messages_to_send = messages_to_send

  fun ref _next(): String =>
    _counter = _counter + 1
    _counter.string()

  fun ref apply(timer: Timer, count: U64): Bool =>
    if _messages_to_send > _counter then
      _sender.write(_next())
      return true
    else
      _custodian.dispose()
      return false
    end

class TermHandler is SignalNotify
  let _custodian: Custodian

  new iso create(custodian: Custodian) =>
    _custodian = custodian

  fun ref apply(count: U32): Bool =>
    _custodian.dispose()
    true
