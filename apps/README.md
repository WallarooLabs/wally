# Buffy Apps

This document describes the Buffy API and how to create client apps.

## API

### Topology

`new_pipeline[In, Out](parser: Parser[In], stringify: Stringify[Out])`
  starts a new pipeline on a Topology. `In` and `Out` represent the types
  at the ends of the pipeline. `In` is returns by the supplied parser and passed to
  the source step. `Out` is sent to the sink step and then stringified
  via the supplied stringifier.

`and_then[Next: Any val](c: ComputationBuilder[Last, Next] val, id: U64 = 0)`
  specifies the next computation in the chain that takes the type emitted by
  the last step and passes along the specified type `Next`. An optional `id` allows
  a step to be shared across pipelines.

`and_then_map[Next: Any val](mc: MapComputationBuilder[Last, Next] val, id: U64 = 0)`
  same as `and_then`, except for a computation that returns a Seq of values
  to be processed separately.

`and_then_stateful[Next: Any val, State: Any #read](sc: StateComputationBuilder[Last, Next, State] val, si: {(): State} val, id: U64 = 0)`
  specifies a stateful step using a StateComputation. The supplied state initializer function
  sets the initial state.

`and_then_partition[Next: Any val](c: ComputationBuilder[Last, Next] val, p_fun: PartitionFunction[Last] val, id: U64 = 0)`
  specifies a step that uses the supplied partition function to create partitions.

`and_then_stateful_partition[Next: Any val, State: Any #read](sc: StateComputationBuilder[Last, Next, State] val, si: {(): State} val, pf: PartitionFunction[Last] val, id: U64 = 0)`
  same as `and_then_partition`, except you specify a `StateComputationBuilder` and
  state initializer to enable stateful partitions.

`build(): Topology ?`  
  returns a Topology with the current in progress pipeline set.

To start up a Buffy topology, use `Startup`, passing in `env`, your `Topology`, and the
number of sources (which currently is the number of pipelines).


## API Tutorial

You create a topology by chaining a number of API calls on a Topology instance,
ending with a call to build().  You must specify a parser and a stringifier. This
is because currently Buffy sources take Strings and Buffy sinks emit Strings.

Here is the simplest example:

```
try
  let topology: Topology val = recover val
    Topology
      .new_pipeline[U64, U64](P, S)
      .build()
  end
end

class P
  fun apply(s: String): U64 ? =>
    s.u64()

class S
  fun apply(input: U64): String =>
    input.string()
```

This useless topology takes an input at the source, parses it as a `U64`, passes
it to the sink, which then converts the `U64` to a `String` and emits it.

Here is a slightly more complex example (double divide):

```
try
  let topology: Topology val = recover val
    Topology
      .new_pipeline[U64, U64](P, S)
      .and_then[U64](lambda(): Computation[U64, U64] iso^ => Double end)
      .and_then[U64](lambda(): Computation[U64, U64] iso^ => Halve end)
      .build()
  end
end

class Double is Computation[U64, U64]
  fun name(): String => "double"
  fun apply(d: U64): U64 =>
    d * 2

class Halve is Computation[U64, U64]
  fun name(): String => "halve"
  fun apply(d: U64): U64 =>
    d / 2
```

Here we specify two `Computation` classes. We chain a couple of calls to
`and_then()` together to create a double-divide between the source and
sink. `and_then()` takes a function that returns a `Computation`. Such a
function implements the `ComputationBuilder` interface.

Here's an example of setting up a partitioning step:
```
try
  let topology: Topology val = recover val
    Topology
      .new_pipeline[U64, U64](P, S)
      .and_then_partition[U64](
        lambda(): Computation[U64, U64] iso^ => Double end, Mod4Partition)
      .build()
  end
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
```

Here's an example of setting up stateful steps:

```
try
  let topology: Topology val = recover val
    Topology
      .new_pipeline[U64, U64](P, S)
      .and_then_stateful[U64, Averager](
        lambda(): StateComputation[U64, U64, Averager] iso^ => Average end,
        lambda(): Averager => Averager end)
      .build()
  end
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
```

Finally, using all Computation classes defined already, here's a mixed example including
the call to `Startup` that kicks off topology initialization:

```
actor Main
  new create(env: Env) =>
    try
      let topology: Topology val = recover val
        Topology
          .new_pipeline[U64, U64](P, S)
          .and_then[U64](lambda(): Computation[U64, U64] iso^ => Double end)
          .and_then_partition[U64](
            lambda(): Computation[U64, U64] iso^ => Halve end, Mod4Partition)
          .and_then_stateful[U64, Averager](
            lambda(): StateComputation[U64, U64, Averager] iso^ => Average end,
            lambda(): Averager => Averager end)
          .build()
      end
      Startup(env, topology, 1)
    else
      env.out.print("Couldn't build topology")
    end
```

This doubles the incoming value, halves the result (across partitions), and statefully
keeps track of the running average.
