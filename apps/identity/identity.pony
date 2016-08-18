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
          .new_pipeline[U64, U64](P, S, recover [0] end, "Identity")
          .to_simple_sink(S, recover [0] end)
      end
      Startup(env, topology, 1)
    else
      env.out.print("Couldn't build topology")
    end

class Identity is Computation[U64, U64]
  fun name(): String => "identity"
  fun apply(d: U64): U64 =>
    d

class P
  fun apply(s: String): U64 ? =>
    s.u64()

class S
  fun apply(input: U64): String =>
    input.string()
