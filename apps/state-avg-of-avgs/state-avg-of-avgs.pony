"""
Average of Averages app written using our "State" representation.
Currently, until issue #807 against ponyc is fixed (couple weeks),
we can't use the library version in steps.pony as it won't compile
so we have to "handroll" for now. That basically means doing what
a generic would do for us, by hand. At the end of this file, you
will two types that accomplish that: AveragerStateComputation and
AveragerState.
"""
use "collections"
use "buffy"
use "buffy/messages"
use "net"

actor Main
  new create(env: Env) =>
    try
      let topology: Topology val = recover val
        Topology
          .new_pipeline[I32, I32](P, S)
          .and_then[I32]("double", lambda(): Computation[I32, I32] iso^ => Double end)
          .and_then[I32]("halve", lambda(): Computation[I32, I32] iso^ => Halve end)
          .and_then_stateful[I32, Averager]("average",
            lambda(): StateComputation[I32, I32, Averager] iso^ => Average end,
            lambda(): Averager => Averager end)
          .and_then_stateful[I32, Averager]("average",
            lambda(): StateComputation[I32, I32, Averager] iso^ => Average end,
            lambda(): Averager => Averager end)
          .build()
      end
      Startup(env, topology, SL, 1)
    else
      env.out.print("Couldn't build topology")
    end

primitive SL is StepLookup
  fun val apply(computation_type: String): BasicStep tag ? =>
    match computation_type
    | "source" => Source[I32](P)
    | "double" => Step[I32, I32](Double)
    | "halve" => Step[I32, I32](Halve)
    | "average" =>
      let state_initializer = lambda(): Averager => Averager end
      StateStep[I32, I32, Averager](state_initializer, Average)
    else
      error
    end

  fun sink(conn: TCPConnection): BasicStep tag =>
    ExternalConnection[I32](S, conn)

class Double is Computation[I32, I32]
  fun apply(msg: Message[I32] val): Message[I32] val^ =>
    let output = msg.data * 2
    Message[I32](msg.id, output)

class Halve is Computation[I32, I32]
  fun apply(msg: Message[I32] val): Message[I32] val^ =>
    let output = msg.data / 2
    Message[I32](msg.id, output)

class Average is StateComputation[I32, I32, Averager]
  fun ref apply(state: Averager, msg: Message[I32] val) : Message[I32] val =>
    let output = state(msg.data)
    Message[I32](msg.id, output)

class Averager
  var count: I32 = 0
  var total: I32 = 0

  fun ref apply(value: I32): I32 =>
    count = count + 1
    total = total + value
    total / count

class P
  fun apply(s: String): I32 ? =>
    s.i32()

class S
  fun apply(input: I32): String =>
    input.string()
