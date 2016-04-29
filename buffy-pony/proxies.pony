use "collections"
use "debug"
use "net"
use "./messages"

actor Proxy is ComputeStep[I32]
  let _env: Env
  let _step_id: I32
  let _conn: TCPConnection

  new create(env: Env, step_id: I32, conn: TCPConnection) =>
    _env = env
    _step_id = step_id
    _conn = conn

  be apply(input: Message[I32] val) =>
    _env.out.print("Proxy: received message for forwarding")
    let tcp_msg = TCPMsgEncoder.forward(_step_id, input)
    _conn.write(tcp_msg)

actor ExternalConnection is ComputeStep[I32]
  let _env: Env
  let _conn: TCPConnection

  new create(env: Env, conn: TCPConnection) =>
    _env = env
    _conn = conn

  be apply(input: Message[I32] val) =>
    _env.out.print("External connection: sending to external system")
    let tcp_msg = TCPMsgEncoder.external(input.data)
    _conn.write(tcp_msg)

actor StepManager
  let _env: Env
  let _steps: Map[I32, Any tag] = Map[I32, Any tag]

  new create(env: Env) =>
    _env = env

  be apply(step_id: I32, msg: Message[I32] val) =>
    _env.out.print("StepManager: received message " + msg.id.string() +
      " bound for step " + step_id.string())
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
    _env.out.print("StepManager: adding step " + step_id.string())
    try
      _steps(step_id) = build_step(computation_type_id)
    end

  be add_proxy(proxy_id: I32, step_id: I32, conn: TCPConnection tag) =>
    _env.out.print("StepManager: adding proxy " + proxy_id.string())
    let p = Proxy(_env, step_id, conn)
    _steps(proxy_id) = p

  be connect_steps(in_id: I32, out_id: I32) =>
    _env.out.print("StepManager: connecting step " + in_id.string() + " to "
      + out_id.string())
    try
      let input_step = _steps(in_id)
      let output_step = _steps(out_id)
      match (input_step, output_step)
      | (let i: ThroughStep[I32, I32] tag, let o: ComputeStep[I32] tag) =>
        i.add_output(o)
        _env.out.print("StepManager: connected!")
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
