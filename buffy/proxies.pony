use "collections"
use "debug"
use "net"
use "buffy/messages"

actor Proxy is ComputeStep[I32]
  let _env: Env
  let _step_id: I32
  let _conn: TCPConnection

  new create(env: Env, step_id: I32, conn: TCPConnection) =>
    _env = env
    _step_id = step_id
    _conn = conn

  be apply(input: Message[I32] val) =>
    let tcp_msg = WireMsgEncoder.forward(_step_id, input)
    _conn.write(tcp_msg)

actor ExternalConnection is ComputeStep[I32]
  let _env: Env
  let _conn: TCPConnection

  new create(env: Env, conn: TCPConnection) =>
    _env = env
    _conn = conn

  be apply(input: Message[I32] val) =>
    let tcp_msg = WireMsgEncoder.external(input.data)
    _conn.write(tcp_msg)

actor StepManager
  let _env: Env
  let _steps: Map[I32, Any tag] = Map[I32, Any tag]

  new create(env: Env) =>
    _env = env

  be apply(step_id: I32, msg: Message[I32] val) =>
    try
      match _steps(step_id)
      | let p: ComputeStep[I32] tag => p(msg)
      else
        _env.out.print("StepManager: Could not forward message")
      end
    else
      _env.out.print("StepManager: Could not forward message")
    end

  be add_step(step_id: I32, computation_type_id: I32) =>
    try
      _steps(step_id) = build_step(computation_type_id)
    end

  be add_proxy(proxy_id: I32, step_id: I32, conn: TCPConnection tag) =>
    let p = Proxy(_env, step_id, conn)
    _steps(proxy_id) = p

  be connect_steps(in_id: I32, out_id: I32) =>
    try
      let input_step = _steps(in_id)
      let output_step = _steps(out_id)
      match (input_step, output_step)
      | (let i: ThroughStep[I32, I32] tag, let o: ComputeStep[I32] tag) =>
        i.add_output(o)
      else
        _env.out.print("StepManager: Could not connect steps")
      end
    end

  fun build_step(id: I32): Any tag ? =>
    match id
    | 0 => Step[I32, I32](Identity)
    | 1 => Step[I32, I32](Double)
    | 2 => Step[I32, I32](Halve)
    | 3 =>
      let env = _env
      Sink[I32](recover Print[I32](env) end)
    else
      error
    end
