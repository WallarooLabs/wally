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
          .and_then_partition[I32]("double_partition",
            lambda(): Computation[I32, I32] iso^ => Double end, Mod4Partition)
          .and_then_partition[I32]("double_partition",
            lambda(): Computation[I32, I32] iso^ => Double end, Mod4Partition)
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
    | "double_partition" =>
      PartitionBuilder[I32, I32](lambda(): Computation[I32, I32] iso^ => Double end,
        Mod4Partition)()
    else
      error
    end

  fun sink(conn: TCPConnection): BasicStep tag =>
    ExternalConnection[I32](S, conn)

class Double is Computation[I32, I32]
  fun apply(msg: Message[I32] val): Message[I32] val =>
    let output = msg.data * 2
    Message[I32](msg.id, output)

class Mod4Partition is PartitionFunction[I32]
  fun apply(input: I32): I32 =>
    @printf[String](("Chose partition " + (input % 4).string()
      + " for input " + input.string() + "\n").cstring())
    input % 4

class P
  fun apply(s: String): I32 ? =>
    s.i32()

class S
  fun apply(input: I32): String =>
    input.string()
