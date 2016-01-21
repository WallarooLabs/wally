use "net"
use "time"
use "collections"
use "options"

actor Main
  new create(env: Env) =>
    var options = Options(env)
    var seed = Time.now()._2.u64()
    var destruction = "pass"

    options
      .add("seed", "s", StringArgument)
      .add("destruction", "d", StringArgument)

    try
      for option in options do
        match option
        | ("seed", var arg: String) => seed = arg.u64()
        | ("destruction", var arg: String) =>
          if (is_valid_mode(arg)) then
            destruction = arg
          else
            env.out.print("Invalid mode. Valid options: duplicate, drop, garble, delay, reorder, random, pass")
            return
          end
        end
      end
    else
      env.out.print("Parameters: input_address output_address destruction-mode [seed]")
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
      let mode: String val = args(3).clone()
      let processor = Processor(mode, seed)
      let notifier = recover Notifier(env, out_ip, out_port, processor) end
      UDPSocket.ip4(consume notifier, in_ip, in_port)
    else
      env.out.print("Parameters: input_address output_address destruction-mode [seed]")
    end

  fun is_valid_mode(mode: String): Bool =>
    match mode
    | "duplicate"
    | "drop"
    | "garble"
    | "delay"
    | "reorder"
    | "random"
    | "pass" => true
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
