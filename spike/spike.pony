use "net"
use "time"
use "collections"
use "options"
use "assert"

actor Main
  new create(env: Env) =>
    var options = Options(env)
    var seed = Time.now()._2.u64()
    var destruction = "pass"
    // Probability from 0 to 100 (corresponding to 0% to 100%)
    var prob: U64 = 10

    options
      .add("prob", "p", StringArgument)
      .add("seed", "s", StringArgument)

    try
      for option in options do
        match option
        | ("prob", let arg: String) => prob = arg.u64()
        | ("seed", let arg: String) => seed = arg.u64()
        end
      end
    else
      env.out.print("Parameters: input_address output_address destruction-mode [--seed seed --prob probability]")
      return
    end

    var args = options.remaining()

    try
      let in_addr = args(1).split(":")
      let in_ip = in_addr(0)
      let in_port = in_addr(1)
      let out_addr = args(2).split(":")
      let out_ip = out_addr(0)
      let out_port = out_addr(1)
      let mode: Mode = ModeMaker.from(args(3), env)
      let processor = Processor(mode, seed, prob)
      let notifier = recover Notifier(env, out_ip, out_port, processor) end
      UDPSocket.ip4(env.root as AmbientAuth, consume notifier, in_ip, in_port)
    else
      env.out.print("Parameters: input_address output_address destruction-mode [--seed seed --prob probability]")
    end


  fun parse_addr(from: String): (String val, String val) ? =>
    let split = from.split(":")
    Fact(split.size() == 2)
    (split(0), split(1))


actor Processor
  let _mode: Mode
  let _destructor: Destructor

  new create(mode: Mode, seed: U64, probability: U64) =>
    _mode = mode
    _destructor = match _mode
    | DuplicateMode => DuplicateDestructor(seed, probability)
    | DropMode => DropDestructor(seed, probability)
    | GarbleMode => GarbleDestructor(seed, probability)
    | DelayMode => DelayDestructor(seed, probability)
    | ReorderMode => ReorderDestructor(seed, probability)
    | RandomMode => RandomDestructor(seed, probability)
    | PassMode => PassDestructor
    else
      PassDestructor
    end

  be spike(packet: Array[U8] val, sock: UDPSocket, remote_addr: IPAddress, env: Env) =>
    _destructor.spike(packet, sock, remote_addr, env)
    (let host, let service) =
      try
        remote_addr.name()
      else
        ("???", "???")
      end
    env.out.print("spike: Sent message to " + host + ":" + service + " in " + ModeMaker.string_for(_mode))
