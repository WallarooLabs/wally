use "net"
use "collections"
use "buffy"
use "buffy/messages"

actor Main
  new create(env: Env) =>
    let topology: Topology val =
      Topology(recover val
        ["double_partition", "double_partition"]
      end)
    Startup(env, topology, SB, 1)

primitive SB is StepBuilder
  fun val apply(computation_type: String): BasicStep tag ? =>
    match computation_type
    | "double" => Step[I32, I32](Double)
    | "double_partition" =>
      Partition[I32, I32]("double", Mod4Partition, this)
    else
      error
    end

class Double is Computation[I32, I32]
  fun apply(msg: Message[I32] val): Message[I32] val^ =>
    let output = msg.data * 2
    Message[I32](msg.id, msg.source_ts, msg.last_ingress_ts, output)

class Mod4Partition is PartitionFunction[I32]
  fun apply(input: I32): I32 =>
    @printf[String](("Chose partition " + (input % 4).string()
      + " for input " + input.string() + "\n").cstring())
    input % 4
