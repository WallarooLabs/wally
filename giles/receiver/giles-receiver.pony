use "bureaucracy"
use "collections"
use "debug"
use "files"
use "net"
use "signals"
use "time"

actor Main
  new create(env: Env) =>
    try
      let custodian = Custodian

      let in_addr_raw = env.args(1).split(":")
      let time_to_first_message = env.args(2).u64() * 1_000_000_000
      let time_between_messages = env.args(3).u64() * 1_000_000_000

      let incoming_host = in_addr_raw(0)
      let incoming_port = in_addr_raw(1)
      let store = Store(env)
      let free_candy = FreeCandy(custodian, time_to_first_message, time_between_messages)
      let receiver = Receiver(env, store, free_candy, incoming_host, incoming_port)

      custodian(receiver)(free_candy)(store)
      SignalHandler(TermHandler(custodian), Sig.term())
    else
      env.out.print("wrong args")
    end

actor Receiver
  let _socket: UDPSocket

  new create(env: Env, store: Store,
    free_candy: FreeCandy,
    on_address: String, on_port: String) =>
    _socket = UDPSocket(ReceiverNotify(env, store, free_candy), on_address, on_port)

  be dispose() =>
    _socket.dispose()

class ReceiverNotify is UDPNotify
  let _env: Env
  let _store: Store
  let _free_candy: FreeCandy

  new iso create(env: Env, store: Store, free_candy: FreeCandy) =>
    _env = env
    _store = store
    _free_candy = free_candy

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
    _free_candy.received()

actor FreeCandy
  let _custodian: Custodian
  let _timers: Timers
  var _last_timer: Timer tag
  let _time_between_messages: U64

  new create(custodian: Custodian, time_to_first_message: U64, time_between_messages: U64) =>
    _timers = Timers
    _custodian = custodian
    _time_between_messages = time_between_messages
    _last_timer = _new_timer(custodian, _timers, time_to_first_message)
    Debug.out("free candy setup")

  be received() =>
    Debug.out("FreeCandy message received")
    _timers.cancel(_last_timer)
    _last_timer = _new_timer(_custodian, _timers, _time_between_messages)

  be dispose() =>
    _timers.dispose()

  fun tag _new_timer(custodian: Custodian, timers: Timers, time_to_fire: U64): Timer tag =>
    let timer = Timer(FreeCandyNotifier(custodian), time_to_fire, 0)
    let timer' = timer
    timers(consume timer)
    timer'

class FreeCandyNotifier is TimerNotify
  let _custodian: Custodian

  new iso create(custodian: Custodian) =>
    _custodian = custodian

  fun ref apply(timer: Timer, count: U64): Bool =>
    Debug.out("timer fired")
    _custodian.dispose()
    false

actor Store
  let _env: Env
  let _received: List[(ByteSeq, U64)]

  new create(env: Env) =>
    _env = env
    _received = List[(ByteSeq, U64)](1_000_000)

  be received(msg: ByteSeq, at: U64) =>
    _received.push((msg, at))

  be dispose() =>
    _dump()

  fun _dump() =>
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
  let _custodian: Custodian

  new iso create(custodian: Custodian) =>
    _custodian = custodian

  fun ref apply(count: U32): Bool =>
    _custodian.dispose()
    true
