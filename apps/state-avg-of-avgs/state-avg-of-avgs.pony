"""
Average of Averages app written using our "State" representation.
Currently, until issue #807 against ponyc is fixed (couple weeks),
we can't use the library version in steps.pony as it won't compile
so we have to "handroll" for now. That basically means doing what
a generic would do for us, by hand. At the end of this file, you
will two types that accomplish that: AveragerStateComputation and
AveragerState.
"""
use "collections"
use "buffy"
use "buffy/messages"

actor Main
  new create(env: Env) =>
    let topology: Topology val =
      Topology(recover val
        ["double", "halve", "average", "average"]
      end)
    Startup(env, topology, SB, 1)

primitive SB is StepBuilder
  fun val apply(computation_type: String): Any tag ? =>
    match computation_type
    | "double" => Step[I32, I32](Double)
    | "halve" => Step[I32, I32](Halve)
    | "average" =>
      let s = recover Averager end
      AveragerState[I32, I32](consume s, Average)
    else
      error
    end

class Double is Computation[I32, I32]
  fun apply(msg: Message[I32] val): Message[I32] val^ =>
    let output = msg.data * 2
    Message[I32](msg.id, output)

class Halve is Computation[I32, I32]
  fun apply(msg: Message[I32] val): Message[I32] val^ =>
    let output = msg.data / 2
    Message[I32](msg.id, output)

class Average is AveragerStateComputation[I32, I32]
  fun ref apply(state: Averager, msg: Message[I32] val) : Message[I32] val =>
    let output = state(msg.data)
    Message[I32](msg.id, output)

class Averager
  var count: I32 = 0
  var total: I32 = 0

  fun ref apply(value: I32): I32 =>
    count = count + 1
    total = total + value
    total / count

///
///
///

interface AveragerStateComputation[In: OSCEncodable,
  Out: OSCEncodable]

  fun ref apply(state: Averager, input: Message[In] val)
    : Message[Out] val^

actor AveragerState[In: OSCEncodable val,
  Out: OSCEncodable val] is ThroughStep[In, Out]
  let _f: AveragerStateComputation[In, Out]
  var _output: (ComputeStep[Out] tag | None) = None
  let _state: Averager

  new create(state: Averager iso, f: AveragerStateComputation[In, Out] iso) =>
    _state = consume state
    _f = consume f

  be add_output(to: ComputeStep[Out] tag) =>
    _output = to

  be apply(input: Message[In] val) =>
    let r = _f(_state, input)
    match _output
      | let c: ComputeStep[Out] tag => c(r)
    end
