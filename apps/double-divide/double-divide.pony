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
          .and_then[U64]("double", lambda(): Computation[U64, U64] iso^ => Double end)
          .and_then[U64]("halve", lambda(): Computation[U64, U64] iso^ => Halve end)
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
    | "halve" => Step[U64, U64](Halve)
    else
      error
    end

  fun sink(conn: TCPConnection, metrics_collector: MetricsCollector)
    : BasicStep tag =>
    ExternalConnection[U64](S, conn, metrics_collector)

class Double is Computation[U64, U64]
  fun apply(d: U64): U64 =>
    d * 2

class Halve is Computation[U64, U64]
  fun apply(d: U64): U64 =>
    d / 2

class P
  fun apply(s: String): U64 ? =>
    s.u64()

class S
  fun apply(input: U64): String =>
    input.string()
