use "net"
use "collections"
use "buffy"
use "buffy/messages"

actor Main
  new create(env: Env) =>
    let topology: Topology val = Topology(recover val [0, 1, 2, 2] end)
    Startup(env, topology, SB, 1)

// User computations
primitive ComputationTypes
  fun double(): I32 => 0
  fun halve(): I32 => 1
  fun average(): I32 => 2

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

primitive SB is StepBuilder
  fun val apply(id: I32): Any tag ? =>
    match id
    | ComputationTypes.double() => Step[I32, I32](Double)
    | ComputationTypes.halve() => Step[I32, I32](Halve)
    | ComputationTypes.average() => Step[I32, I32](Average)
    else
      error
    end
