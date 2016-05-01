use "net"
use "collections"
use "buffy"
use "buffy/messages"

actor Main
  new create(env: Env) =>
    let topology: Topology val =
      Topology(recover val
        ["double", "halve"]
      end)
    Startup(env, topology, SB, 1)

primitive SB is StepBuilder
  fun val apply(computation_type: String): Any tag ? =>
    match computation_type
    | "identity" => Step[I32, I32](Identity)
    | "double" => Step[I32, I32](Double)
    | "halve" => Step[I32, I32](Halve)
    | "print" =>
      Sink[I32](recover Print[I32] end)
    else
      error
    end

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


