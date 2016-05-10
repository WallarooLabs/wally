use "net"
use "collections"
use "buffy"
use "buffy/messages"

actor Main
  new create(env: Env) =>
    try
      let topology: Topology val = recover val
        Topology
          .new_pipeline[I32, I32](P, S)
          .and_then[I32]("double", lambda(): Computation[I32, I32] iso^ => Double end)
          .and_then[I32]("halve", lambda(): Computation[I32, I32] iso^ => Halve end)
          .build()
      end
      Startup(env, topology, SB, 1)
    else
      env.out.print("Couldn't build topology")
    end

primitive SB is StepLookup
  fun val apply(computation_type: String): BasicStep tag ? =>
    match computation_type
    | "source" => Source[I32](P)
    | "double" => Step[I32, I32](Double)
    | "halve" => Step[I32, I32](Halve)
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

class P is Parser[I32]
  fun apply(s: String): I32 ? =>
    s.i32()

class S is Stringify[I32]
  fun apply(input: I32): String =>
    input.string()
