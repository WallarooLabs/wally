use "net"
use "time"
use "random"

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
      let spiked: Array[U8] val = _spiked_header(packet)
      sock.write(spiked, remote_addr)
    else
      env.out.print("Couldn't garble header!")
    end

  fun _spiked_payload(packet: Array[U8] val): String ? =>
    let cp: Array[U8] iso = recover iso packet.clone() end
    let payload: Array[U8] iso = recover iso BuffyProtocol.decode(consume cp) end
    recover String.append(consume payload) + "_spiked" end

  fun _spiked_header(packet: Array[U8] val): Array[U8] val ? =>
    let cp: Array[U8] iso = recover iso packet.clone() end
    cp(0) = cp(0) + 1
    cp

  fun delay(packet: Array[U8] val, sock: UDPSocket, remote_addr: IPAddress, env: Env, delay_in_nano: U64) =>
    let timers = Timers

    let t = Timer(recover DelayNotify(packet, sock, remote_addr, env) end, delay_in_nano)
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