use "net"
use "collections"
use "buffy"
use "buffy/messages"

actor Main
  new create(env: Env) =>
    let topology: Topology val =
      Topology(recover val
        ["double", "halve", "average", "average"]
      end)
    Startup(env, topology, SB, 1)

primitive SB is StepBuilder
  fun val apply(computation_type: String): BasicStep tag ? =>
    match computation_type
    | "double" => Step[I32, I32](Double)
    | "halve" => Step[I32, I32](Halve)
    | "average" => Step[I32, I32](Average)
    else
      error
    end

class Double is Computation[I32, I32]
  fun apply(msg: Message[I32] val): Message[I32] val^ =>
    let output = msg.data * 2
    Message[I32](msg.id, output)

class Halve is Computation[I32, I32]
  fun apply(msg: Message[I32] val): Message[I32] val^ =>
    let output = msg.data / 2
    Message[I32](msg.id, output)

class Average is Computation[I32, I32]
  let state: Averager = Averager

  fun ref apply(msg: Message[I32] val): Message[I32] val^ =>
    let output = state(msg.data)
    Message[I32](msg.id, output)

class Averager
  var count: I32 = 0
  var total: I32 = 0

  fun ref apply(value: I32): I32 =>
    count = count + 1
    total = total + value
    total / count
