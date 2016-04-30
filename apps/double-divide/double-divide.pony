use "net"
use "collections"
use "buffy"
use "buffy/messages"

actor Main
  new create(env: Env) =>
    let topology: Topology val = Topology(recover val [1, 2] end)
    Startup(env, topology, SB, 1)

// User computations
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
    let output = msg.data * 2
    Message[I32](msg.id, output)

class Halve is Computation[I32, I32]
  fun apply(msg: Message[I32] val): Message[I32] val^ =>
    let output = msg.data / 2
    Message[I32](msg.id, output)

class Print[A: (OSCEncodable & Stringable)] is FinalComputation[A]
  fun apply(msg: Message[A] val) =>
    @printf[String]((msg.data.string() + "\n").cstring())

primitive SB is StepBuilder
  fun val apply(id: I32): Any tag ? =>
    match id
    | ComputationTypes.identity() => Step[I32, I32](Identity)
    | ComputationTypes.double() => Step[I32, I32](Double)
    | ComputationTypes.halve() => Step[I32, I32](Halve)
    | ComputationTypes.print() =>
      Sink[I32](recover Print[I32] end)
    else
      error
    end
