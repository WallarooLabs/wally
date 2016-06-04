use "net"
use "collections"
use "buffy"
use "buffy/messages"
use "buffy/metrics"
use "buffy/topology"

actor Main
  new create(env: Env) =>
    try
      let topology: Topology val = recover val
        Topology
          .new_pipeline[U64, U64](P, S, recover [0] end)
          .to_partition[U64](
            lambda(): Computation[U64, U64] iso^ => Double end, Mod4Partition)
          .to_partition[U64](
            lambda(): Computation[U64, U64] iso^ => Double end, Mod4Partition)
          .build()
      end
      Startup(env, topology, 1)
    else
      env.out.print("Couldn't build topology")
    end

class Double is Computation[U64, U64]
  fun name(): String => "double"
  fun apply(d: U64): U64 =>
    d * 2

class Mod4Partition is PartitionFunction[U64]
  fun apply(input: U64): U64 =>
    @printf[String](("Chose partition " + (input % 4).string()
      + " for input " + input.string() + "\n").cstring())
    input % 4

class P
  fun apply(s: String): (U64 | None) ? =>
    s.u64()

class S
  fun apply(input: U64): String =>
    input.string()
