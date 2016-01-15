use "net"
use "time"
use "random"

actor Main
  new create(env: Env) =>
    try
      let in_addr = env.args(1).split(":")
      let in_ip = in_addr(0)
      let in_port = in_addr(1)
      let out_addr = env.args(2).split(":")
      let out_ip = out_addr(0)
      let out_port = out_addr(1)
      let mode = env.args(3)
      var seed = Time.now()._2.u64()
      try
        seed = env.args(4).u64()
      end
      if is_valid_mode(mode) then
        let processor = Processor(mode, seed)
        let notifier = recover Notifier(env, out_ip, out_port, processor) end
        UDPSocket.ip4(notifier, in_ip, in_port)
      else
        env.out.print("Invalid mode. Valid options: duplicate, drop, garble, delay, reorder, random, pass")
      end
    else
      env.out.print("Parameters: input_address output_address destruction-mode [seed]")
    end

  fun is_valid_mode(mode: String): Bool =>
    if ((mode == "duplicate") or
        (mode == "drop") or
        (mode == "garble") or
        (mode == "delay") or
        (mode == "reorder") or
        (mode == "random") or
        (mode == "pass")) then
      true
    else
      false
    end

actor Processor
  let destructor: Destructor

  new create(mode: String, seed: U64) =>
    destructor = match mode
    | "duplicate" => DuplicateDestructor(seed)
    | "drop" => DropDestructor(seed)
    | "garble" => GarbleDestructor(seed)
    | "delay" => DelayDestructor(seed)
    | "reorder" => ReorderDestructor(seed)
    | "random" => RandomDestructor(seed)
    | "pass" => PassDestructor
    else
      PassDestructor
    end

  be spike(packet: Array[U8] val, sock: UDPSocket, remote_addr: IPAddress, env: Env) =>
    destructor.spike(packet, sock, remote_addr, env)

class Notifier is UDPNotify
  let _env: Env
  let _out_addr: IPAddress
  let _out_sock: UDPSocket
  let _processor: Processor

  new create(env: Env, out_ip: String, out_port: String, processor: Processor) ? =>
    _env = env
    _out_addr = DNS.ip4(out_ip, out_port)(0)
    _out_sock = UDPSocket.ip4(recover Forwarder(env) end)
    _processor = processor

  fun ref listening(sock: UDPSocket ref) =>
    try
      let ip = sock.local_address()
      (let host, let service) = ip.name()
      _env.out.print("spike: listening on " + host + ":" + service)
    else
      _env.out.print("spike: couldn't get local name")
      sock.dispose()
    end

  fun ref not_listening(sock: UDPSocket ref) =>
    _env.out.print("spike: not listening")
    sock.dispose()

  fun ref received(sock: UDPSocket ref, data: Array[U8] iso, from: IPAddress) =>
    let d: Array[U8] val = consume data
    let cp: Array[U8] iso = recover iso d.clone() end
    try
      let payload: Array[U8] iso = BuffyProtocol.decode(consume cp)

      _env.out.print("RECEIVING")
      try
        (let host, let service) = from.name()
        _env.out.print("from " + host + ":" + service)
      end

      _env.out.print(consume payload)
      _processor.spike(d, _out_sock, _out_addr, _env)
      sock.write("got it", from)
    end

  fun ref closed(sock: UDPSocket ref) =>
    _env.out.print("spike: closed")

class Forwarder is UDPNotify
  let _env: Env

  new create(env: Env) =>
    _env = env

  fun ref listening(sock: UDPSocket ref) =>
    try
      let ip = sock.local_address()
      (let host, let service) = ip.name()
    else
      _env.out.print("spike-output: couldn't get local name")
      sock.dispose()
    end

  fun ref not_listening(sock: UDPSocket ref) =>
    _env.out.print("spike-output: not listening")
    sock.dispose()

  fun ref closed(sock: UDPSocket ref) =>
    _env.out.print("spike: closed")

interface Destructor
  fun ref spike(packet: Array[U8] val, sock: UDPSocket, remote_addr: IPAddress, env: Env)

class PassDestructor
  fun ref spike(packet: Array[U8] val, sock: UDPSocket, remote_addr: IPAddress, env: Env) =>
    Destructions.pass(packet, sock, remote_addr, env)

class DuplicateDestructor
  let dice: Dice

  new create(seed: U64) =>
    dice = Dice(MT(seed))

  fun ref spike(packet: Array[U8] val, sock: UDPSocket, remote_addr: IPAddress, env: Env) =>
    var count = dice(1, 4)
    while (count > 0) do
      sock.write(packet, remote_addr)
      count = count - 1
    end

class DropDestructor
  let dice: Dice

  new create(seed: U64) =>
    dice = Dice(MT(seed))

  fun ref spike(packet: Array[U8] val, sock: UDPSocket, remote_addr: IPAddress, env: Env) =>
    let roll = dice(1, 10)
    if (roll > 1) then
      sock.write(packet, remote_addr)
    end

class GarbleDestructor
  let dice: Dice

  new create(seed: U64) =>
    dice = Dice(MT(seed))

  fun ref spike(packet: Array[U8] val, sock: UDPSocket, remote_addr: IPAddress, env: Env) =>
    let roll = dice(1, 5)
    if (roll > 1) then
      Destructions.garble_payload(packet, sock, remote_addr, env)
    else
      Destructions.garble_header(packet, sock, remote_addr, env)
    end

class DelayDestructor
  let dice: Dice

  new create(seed: U64) =>
    dice = Dice(MT(seed))

  fun ref spike(packet: Array[U8] val, sock: UDPSocket, remote_addr: IPAddress, env: Env) =>
    let delay = dice(1, 10_000) * 1_000_000
    Destructions.delay(packet, sock, remote_addr, env, delay)

class ReorderDestructor
  let dice: Dice
  let msg_q: Array[Array[U8] val] = Array[Array[U8] val]

  new create(seed: U64) =>
    dice = Dice(MT(seed))

  fun ref spike(packet: Array[U8] val, sock: UDPSocket, remote_addr: IPAddress, env: Env) =>
    let roll = dice(1, 6).usize()
    msg_q.push(packet)
    if (msg_q.size() > roll) then
      while (msg_q.size() > 0) do
        try
          sock.write(msg_q.pop(), remote_addr)
        else
          break
        end
      end
    end

class RandomDestructor
  let dice: Dice
  let garbler: GarbleDestructor
  let reorderer: ReorderDestructor

  new create(seed: U64) =>
    dice = Dice(MT(seed))
    garbler = GarbleDestructor(seed)
    reorderer = ReorderDestructor(seed)

  fun ref spike(packet: Array[U8] val, sock: UDPSocket, remote_addr: IPAddress, env: Env) =>
    let roll = dice(1, 6)
    match roll
    | 1 => Destructions.pass(packet, sock, remote_addr, env)
    | 2 => Destructions.duplicate(packet, sock, remote_addr, env)
    | 3 => Destructions.drop(packet, sock, remote_addr, env)
    | 4 => garbler.spike(packet, sock, remote_addr, env)
    | 5 =>
      let delay = dice(1, 10_000) * 1_000_000
      Destructions.delay(packet, sock, remote_addr, env, delay)
    | 6 => reorderer.spike(packet, sock, remote_addr, env)
    end

primitive Destructions
  fun pass(packet: Array[U8] val, sock: UDPSocket, remote_addr: IPAddress, env: Env) =>
    sock.write(packet, remote_addr)

  fun duplicate(packet: Array[U8] val, sock: UDPSocket, remote_addr: IPAddress, env: Env) =>
    sock.write(packet, remote_addr)
    sock.write(packet, remote_addr)

  fun drop(packet: Array[U8] val, sock: UDPSocket, remote_addr: IPAddress, env: Env) =>
    None

  fun garble_payload(packet: Array[U8] val, sock: UDPSocket, remote_addr: IPAddress, env: Env) =>
    try
      let spiked: String = _spiked_payload(packet)
      sock.write(BuffyProtocol.encode(spiked), remote_addr)
    else
      env.out.print("Couldn't decode the message!")
    end

  fun garble_header(packet: Array[U8] val, sock: UDPSocket, remote_addr: IPAddress, env: Env) =>
    try
      let spiked: Array[U8] = _spiked_header(packet)
      sock.write(spiked, remote_addr)
    else
      env.out.print("Couldn't garble header!")
    end

  fun _spiked_payload(packet: Array[U8] val): String ? =>
    let cp: Array[U8] iso = recover iso packet.clone() end
    let payload: Array[U8] iso = recover iso BuffyProtocol.decode(consume cp) end
    recover String.append(consume payload) + "_spiked\n" end

  fun _spiked_header(packet: Array[U8] val): Array[U8] ? =>
    let cp: Array[U8] iso = recover iso packet.clone() end
    cp(0) = cp(0) + 1
    cp

  fun delay(packet: Array[U8] val, sock: UDPSocket, remote_addr: IPAddress, env: Env, delay_in_nano: U64) =>
    let timers = Timers

    let t = Timer(DelayNotify(packet, sock, remote_addr, env), delay_in_nano)
    timers(consume t)

class DelayNotify is TimerNotify
  let _packet: Array[U8] val
  let _sock: UDPSocket
  let _remote_addr: IPAddress
  let _env: Env

  new create(packet: Array[U8] val, sock: UDPSocket, remote_addr: IPAddress, env: Env) =>
    _packet = packet
    _sock = sock
    _remote_addr = remote_addr
    _env = env

  fun ref apply(timer: Timer, count: U64): Bool =>
    _sock.write(_packet, _remote_addr)
    false