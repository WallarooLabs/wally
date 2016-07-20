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
          .new_pipeline[U64, U64](P, S, recover [0] end, 
            "State Average of Averages")
          .to[U64](lambda(): Computation[U64, U64] iso^ => Double end)
          .to[U64](lambda(): Computation[U64, U64] iso^ => Halve end)
          .to_stateful[U64, Averager](
            lambda(): Computation[U64, Average val] iso^ => GenerateAverage end,
            lambda(): Averager => Averager end, 1)
          .to_stateful[U64, Averager](
            lambda(): Computation[U64, Average val] iso^ => GenerateAverage end,
            lambda(): Averager => Averager end, 2)
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

class GenerateAverage is Computation[U64, Average val]
  fun name(): String => "average"
  fun apply(d: U64): Average val =>
    Average(d)

class Average is StateComputation[U64, Averager]
  let _data: U64

  new val create(d: U64) =>
    _data = d

  fun name(): String => "average"
  fun apply(state: Averager, output: MessageTarget val)
    : Averager =>
    output(state(_data))
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