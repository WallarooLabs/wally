use "net"
use "time"

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
