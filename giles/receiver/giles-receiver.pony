use "collections"
use "files"
use "net"
use "signals"
use "time"

actor Main
  new create(env: Env) =>
    try
      let in_addr_raw = env.args(1).split(":")

      let incoming_host = in_addr_raw(0)
      let incoming_port = in_addr_raw(1)
      let store = Store(env)
      let receiver = Receiver(env, store, incoming_host, incoming_port)

      SignalHandler(TermHandler(receiver, store), Sig.term())
    else
      env.out.print("wrong args")
    end

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
    let at = Time.micros()
    _store.received(consume data, at)

actor Store
  let _env: Env
  let _received: List[(ByteSeq, U64)]

  new create(env: Env) =>
    _env = env
    _received = List[(ByteSeq, U64)](1_000_000)

  be received(msg: ByteSeq, at: U64) =>
    _received.push((msg, at))

  be dump() =>
    try
      let received_handle = File(FilePath(_env.root, "received.txt"))
      for r in _received.values() do
        received_handle.print(_format_output(r))
      end
      received_handle.dispose()
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

class TermHandler is SignalNotify
  let _receiver: Receiver
  let _store: Store

  new iso create(receiver: Receiver, store: Store) =>
    _receiver = receiver
    _store = store

  fun ref apply(count: U32): Bool =>
    _receiver.dispose()
    _store.dump()
    true
