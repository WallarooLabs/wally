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
          .new_pipeline[I32, I32](P, S)
          .and_then[I32]("identity", lambda(): Computation[I32, I32] iso^ => Identity end)
          .and_then[I32]("identity", lambda(): Computation[I32, I32] iso^ => Identity end)
          .and_then[I32]("identity", lambda(): Computation[I32, I32] iso^ => Identity end)
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
    | "identity" => Step[I32, I32](Identity)
    else
      error
    end

  fun sink(conn: TCPConnection, metrics_collector: MetricsCollector): BasicStep tag =>
    ExternalConnection[I32](S, conn, metrics_collector)

class Identity is Computation[I32, I32]
  fun apply(d: I32): I32 =>
    d

class P
  fun apply(s: String): I32 ? =>
    s.i32()

class S
  fun apply(input: I32): String =>
    input.string()
