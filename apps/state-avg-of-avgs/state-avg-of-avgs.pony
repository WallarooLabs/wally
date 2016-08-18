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
          .new_pipeline[U64, U64](P, "State Average of Averages")
          .to[U64](lambda(): Computation[U64, U64] iso^ => Double end)
          .to[U64](lambda(): Computation[U64, U64] iso^ => Halve end)
          .to_stateful[U64, Averager](
            Average,
            lambda(): Averager => Averager end, 1)
          .to_stateful[U64, Averager](
            Average,
            lambda(): Averager => Averager end, 2)
          .to_simple_sink(S, recover [0] end)
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
  fun apply(d: U64, state: Averager, output: MessageTarget[U64] val)
    : Averager =>
    output(state(d))
    state

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