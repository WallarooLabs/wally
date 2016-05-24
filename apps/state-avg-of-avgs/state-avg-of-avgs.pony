use "collections"
use "buffy"
use "buffy/messages"
use "buffy/metrics"
use "buffy/topology"
use "net"

actor Main
  new create(env: Env) =>
    try
      let topology: Topology val = recover val
        Topology
          .new_pipeline[U64, U64](P, S)
          .to[U64](lambda(): Computation[U64, U64] iso^ => Double end)
          .to[U64](lambda(): Computation[U64, U64] iso^ => Halve end)
          .to_stateful[U64, Averager](
            lambda(): StateComputation[U64, U64, Averager] iso^ => Average end,
            lambda(): Averager => Averager end)
          .to_stateful[U64, Averager](
            lambda(): StateComputation[U64, U64, Averager] iso^ => Average end,
            lambda(): Averager => Averager end)
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

class Average is StateComputation[U64, U64, Averager]
  fun name(): String => "average"
  fun ref apply(state: Averager, d: U64): U64 =>
    state(d)

class Averager
  var count: U64 = 0
  var total: U64 = 0

  fun ref apply(value: U64): U64 =>
    count = count + 1
    total = total + value
    total / count

class P
  fun apply(s: String): U64 ? =>
    s.u64()

class S
  fun apply(input: U64): String =>
    input.string()
