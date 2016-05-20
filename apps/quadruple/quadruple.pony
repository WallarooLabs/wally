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
          .new_pipeline[U64, U64](P, S)
          .and_then_partition[U64]("double_partition",
            lambda(): Computation[U64, U64] iso^ => Double end, Mod4Partition)
          .and_then_partition[U64]("double_partition",
            lambda(): Computation[U64, U64] iso^ => Double end, Mod4Partition)
          .build()
      end
      Startup(env, topology, SL, 1)
    else
      env.out.print("Couldn't build topology")
    end

primitive SL is StepLookup
  fun val apply(computation_type: String): BasicStep tag ? =>
    match computation_type
    | "source" => Source[U64](P)
    | "double" => Step[U64, U64](Double)
    | "double_partition" =>
      PartitionBuilder[U64, U64](lambda(): Computation[U64, U64] iso^ => Double end,
        Mod4Partition)()
    else
      error
    end

  fun sink(conn: TCPConnection, metrics_collector: MetricsCollector)
    : BasicStep tag =>
    ExternalConnection[U64](S, conn, metrics_collector)

class Double is Computation[U64, U64]
  fun apply(d: U64): U64 =>
    d * 2

class Mod4Partition is PartitionFunction[U64]
  fun apply(input: U64): U64 =>
    @printf[String](("Chose partition " + (input % 4).string()
      + " for input " + input.string() + "\n").cstring())
    input % 4

class P
  fun apply(s: String): U64 ? =>
    s.u64()

class S
  fun apply(input: U64): String =>
    input.string()
