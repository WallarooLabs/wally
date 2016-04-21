interface Computation[In: OSCEncodable, Out: OSCEncodable]
  fun ref apply(input: Message[In] val): Message[Out] val^

interface FinalComputation[In: OSCEncodable]
  fun ref apply(input: Message[In] val)

primitive ComputationTypes
  fun identity(): I32 => 0
  fun double(): I32 => 1
  fun halve(): I32 => 2
  fun print(): I32 => 3

class Identity is Computation[I32, I32]
  fun apply(msg: Message[I32] val): Message[I32] val^ =>
    msg

class Double is Computation[I32, I32]
  fun apply(msg: Message[I32] val): Message[I32] val^ =>
    let output = msg.data() * 2
    Message[I32](msg.id(), output)

class Halve is Computation[I32, I32]
  fun apply(msg: Message[I32] val): Message[I32] val^ =>
    let output = msg.data() / 2
    Message[I32](msg.id(), output)

class Print[A: (OSCEncodable & Stringable)] is FinalComputation[A]
  let _env: Env

  new create(env: Env) =>
    _env = env

  fun apply(msg: Message[A] val) =>
    _env.out.print(msg.data().string())
