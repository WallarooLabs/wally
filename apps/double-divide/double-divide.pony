use "net"
use "collections"
use "buffy"
use "buffy/messages"
use "buffy/metrics"
use "buffy/topology"

actor Main
  new create(env: Env) =>
    try
      let topology = recover val
        Topology
          .new_pipeline[U64, U64](P, S, recover [0] end)
          .to[U64](lambda(): Computation[U64, U64] iso^ => Double end)
          .to[U64](lambda(): Computation[U64, U64] iso^ => Halve end)
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

class Halve is Computation[U64, U64]
  fun name(): String => "halve"
  fun apply(d: U64): U64 =>
    d / 2

primitive P
  fun apply(s: String): U64 ? =>
    s.u64()

primitive S
  fun apply(input: U64): String =>
    input.string()
