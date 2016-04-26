use "collections"
use "debug"

actor Proxy is ThroughStep[I32, I32]
  let _env: Env
  let _step_id: I32
  let _tcp_manager: TopologyManager

  new create(env: Env, step_id: I32, tcp_manager: TopologyManager) =>
    _env = env
    _step_id = step_id
    _tcp_manager = tcp_manager

  be apply(input: Message[I32] val) =>
    _env.out.print("Proxy: received message for forwarding")
    _tcp_manager.forward_message(_step_id, input)

  be add_output(to: ComputeStep[I32] tag) => None

actor StepManager
  let _env: Env
  let _actors: Map[I32, Any tag] = Map[I32, Any tag]

  new create(env: Env) =>
    _env = env

  be apply(step_id: I32, msg: Message[I32] val) =>
    _env.out.print("StepManager: received message")
    try
      match _actors(step_id)
      | let p: ComputeStep[I32] tag => p(msg)
      else
        _env.out.print("StepManager: Could not forward message")
      end
    end

  be add_proxy(step_id: I32, computation_type_id: I32) =>
    _env.out.print("StepManager: adding proxy " + step_id.string())
    try
      _actors(step_id) = build_step(computation_type_id)
    end

  be connect_steps(in_id: I32, out_id: I32) =>
    _env.out.print("StepManager: attempting to connect steps")
    _env.out.print("StepManager: connecting " + in_id.string() + " to "
      + out_id.string())
    try
      let input_step = _actors(in_id)
      let output_step = _actors(out_id)
      match (input_step, output_step)
      | (let i: Step[I32, I32] tag, let o: Sink[I32] tag) =>
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
