# API Basics: Stateful App

In the documentation for creating a [stateless app](api-basics-stateless.md),
we showed how you define an `Application` object and hook that into Wallaroo via
the `Startup` object. We showed how to create an application with a single
pipeline consisting of stateless computations. In this document, we'll cover
creating a stateful application using partitioned state. All the code can be
found in [`examples/alphabet/pony/alphabet.pony`](https://github.com/WallarooLabs/wallaroo-examples/tree/{{ book.wallaroo_version }}/examples/alphabet/pony/alphabet.pony).

## Defining a Stateful Application

Have you ever wondered which letter of the alphabet is the most popular? If so,
you're in luck, since we'll be creating an application that tallies votes for
best letter and outputs running totals whenever we update the state associated
with a letter.

Here is all the code defining the `Application` object and passing it to the
Wallaroo entry point. Don't worry if you don't understand what's happening;
we'll be covering this piece by piece:

```pony
actor Main
  new create(env: Env) =>
    try
      let letter_partition = Partition[Votes val, String](
        LetterPartitionFunction, PartitionFileReader("letters.txt",
          env.root as AmbientAuth))

      let application = recover val
        Application("Alphabet Popularity Contest")
          .new_pipeline[Votes val, LetterTotal val]("Alphabet Votes",
            VotesDecoder)
            .to_state_partition[Votes val, String, LetterTotal val,
              LetterState](AddVotes, LetterStateBuilder, "letter-state",
              letter_partition where multi_worker = true)
            .to_sink(LetterTotalEncoder, recover [0] end)
      end
      Startup(env, application, "alphabet-contest")
    else
      @printf[I32]("Couldn't build topology\n".cstring())
    end
```

There are three parts of this code that we will be focusing on. First, we define
a state partition partitioned by letters of the alphabet. Second, we
define our `Application` object consisting of a single pipeline. And finally, we
pass this object to the `Startup` Wallaroo entry point.

### Defining a State Partition

In order to define a state partition, we need a `PartitionFunction` and a list
of keys (possibly weighted). In this example, our partition function is called
`LetterPartitionFunction` and our list of keys is defined in a file called
`letters.txt`. The relevant `Partition` definition is as follows:

```pony
      let letter_partition = Partition[Votes val, String](
        LetterPartitionFunction, PartitionFileReader("letters.txt",
          env.root as AmbientAuth))
```

We pass two type arguments into `Partition`. The first is the type of our input
data that must be routed to the appropriate state. In this case, our input data
is of type `Votes`, which looks like this:

```pony
class Votes
  let letter: String
  let count: U32

  new val create(l: String, c: U32) =>
    letter = l
    count = c
```

Our input stream consists of bundles of votes for a given letter, which are
represented by our `Votes` class.

The second type argument to `Partition` is the type of the key we use to
determine where the incoming data will be routed. In this case, we use the
`String` type since our keys are the letters of the alphabet.

A partition function is a function that transforms input to keys. We use the
following:

```pony
primitive LetterPartitionFunction
  fun apply(votes: Votes val): String =>
    votes.letter
```

We take an input of the type `Votes` and return a `String`. The `String` is
 the `letter` field in our `Votes` object. This allows us to forward the
`Votes` object to the state for that letter, where we will add our `count` field
to the running total.

We define our keys in a file called `letters.txt`, which looks like this:

```
a
b
c
d
```

all the way to "z". We use a `PartitionFileReader` and pass in the path to our
file as well as an auth token generated from `env`, defined as follows:

```pony
PartitionFileReader("letters.txt", env.root as AmbientAuth)
```

### Defining our Application Object

Our Alphabet Popularity Contest application takes an input stream where each incoming
message represents a bundle of votes for a letter and each corresponding output
message represents the running total for that letter. Our state is partitioned
by letter, allowing parallel work across threads and workers. All the code for
defining our `Application` object itself is as follows:

```pony
        Application("Alphabet Popularity Contest")
          .new_pipeline[Votes val, LetterTotal val]("Alphabet Votes",
            VotesDecoder)
            .to_state_partition[Votes val, String, LetterTotal val,
              LetterState](AddVotes, LetterStateBuilder, "letter-state",
              letter_partition where multi_worker = true)
            .to_sink(LetterTotalEncoder, recover [0] end)
```

Let's look at this line by line. In the first line, we pass in a name for our
application. We then define our one and only pipeline:

```pony
          .new_pipeline[Votes val, LetterTotal val]("Alphabet Votes",
            VotesDecoder)
```

This says that our inputs into the pipeline are of type `Votes` and our outputs
are of type `LetterTotal`. We pass in a name for the pipeline,
`"Alphabet Votes"`, and also a decoder which we define elsewhere. The decoder is
used to transform the incoming stream of bytes to messages of type `Votes`.
We'll talk about decoding in a later section.

Now that we have our pipeline started, we need to define our state partition,
which we do as follows:

```pony
            .to_state_partition[Votes val, String, LetterTotal val,
              LetterState](AddVotes, LetterStateBuilder, "letter-state",
              letter_partition where multi_worker = true)
```

We pass in four type arguments. The first two correspond to the type arguments
we used when we defined our `Partition` [above](#defining-a-state-partition).
The third is the output type emitted by our state computation, in this case
`LetterTotal`, defined elsewhere as:

```pony
class LetterTotal
  let letter: String
  let count: U32

  new val create(l: String, c: U32) =>
    letter = l
    count = c
```

This represents the running vote count for a given letter.

The final type argument is the state type itself, defined elsewhere as:

```pony
class LetterState
  let letter: String = " "
  var count: U32 = 0
```

We update the count via a `StateComputation` called `AddVotes`. Defining this
state computation is explained in a later section.

We pass in four arguments to `to_state_partition`, the `StateComputation`, a
lambda for creating a state instance, a `String` representing the name of our
state type, and the `Partition` object we defined earlier.

Finally, we define our pipeline sink:

```pony
            .to_sink(LetterTotalEncoder, recover [0] end)
```

The `LetterTotalEncoder` transforms the letter total values (which are of type
`LetterTotal`) to sequences of bytes for transmission via TCP.
The `recover [0] end` clause says that we are using the sink with id 0.
Currently, Wallaroo only supports one sink per pipeline.

### Defining a StateComputation

In defining our `Application`, we referred to a `StateComputation` object
called `AddVotes`. The definition of `AddVotes` is as follows:

```pony
primitive AddVotes is StateComputation[Votes val, LetterTotal val, LetterState]
  fun name(): String => "Add Votes"

  fun apply(votes: Votes val,
    sc_repo: StateChangeRepository[LetterState],
    state: LetterState): (LetterTotal val, StateChange[LetterState] ref)
  =>
    let state_change: AddVotesStateChange ref =
      try
        sc_repo.lookup_by_name("AddVotes") as AddVotesStateChange
      else
        AddVotesStateChange(0)
      end

    state_change.update(votes)

    (LetterTotal(state.letter, state.count), state_change)
```

There are a number of things going on here. Let's look at it piece by piece.

```pony
primitive AddVotes is StateComputation[Votes val, LetterTotal val, LetterState]
```

Here we define our primitive and pass in three type arguments. The first is
the input type that we will be performing our state computation on. The second is the output type of the state computation (which would be `None` if all this
did was update state). The third is the state type.

Then we must define an apply method, just as we did with the `Computation`
type when defining a stateless computation. Here is the signature for
a state computation apply method:

```pony
  fun apply(votes: Votes val,
    sc_repo: StateChangeRepository[LetterState],
    state: LetterState): (LetterTotal val, StateChange[LetterState] ref)
```

The first argument is the input type. The second is a
`StateChangeRepository`, which contains all the possible state change
types for our state. The third is an instance of state, the one we'll
actually be acting on.

Our return type is a tuple containing the output of the state computation, if any, and the state change, if any.

Within the apply method, we first look up a state change template. In this
case, we want to change our state by adding votes, so we have elsewhere
defined a `StateChange` object called `AddVotesStateChange`.

```pony
   let state_change: AddVotesStateChange ref =
      try
        sc_repo.lookup_by_name("AddVotes") as AddVotesStateChange
      else
        AddVotesStateChange(0)
      end
```

`StateChange` objects have an `update` method. We pass in our input, `votes`.

```pony
    state_change.update(votes)
```

Finally, we return our output and the state change. The purpose of the
state change object is to allow Wallaroo to record all state changes for
recovery purposes, thereby allowing us to reconstruct state without taking
frequent large snapshots.

```pony
    (LetterTotal(state.letter, state.count), state_change)
```

### Hooking into Wallaroo

The last thing we must do is pass our `Application` object into the Wallaroo
entry point:

```pony
      Startup(env, application, "alphabet-contest")
```

We pass in the Pony environment, our application, and a string to use for
tagging files and metrics related to this app.

## Decoding and Encoding

If you are using TCP to send data in and out of the system, then you need a way
to convert streams of bytes into semantically useful types and convert your
output types to streams of bytes. This is where the decoders and encoders
mentioned earlier come into play. For more information, see
[Decoders and Encoders](decoders-and-encoders.md).

## Rewriting our Application to Use Two Streams

To illustrate the use of two interacting stream, we're going to create a
variant on the Alphabet Popularity Contest app. Instead of emitting a running
total every time we update a letter's vote count, we're going to add a
second stream of letters that trigger outputting the running total for the
corresponding letter. The new code looks like this:

```pony
actor Main
  new create(env: Env) =>
    try
      let letter_partition = Partition[(Votes val | String), String](
        LetterPartitionFunction, PartitionFileReader("letters.txt",
          env.root as AmbientAuth))

      let application = recover val
        Application("Alphabet Popularity Contest")
          .new_pipeline[Votes val, None]("Alphabet Votes",
            VotesDecoder)
            .to_state_partition[Votes val, String, None, LetterState](
              AddVotes, LetterStateBuilder, "letter-state",
              letter_partition where multi_worker = true)
            .done()
          .new_pipeline[String, LetterTotal val]("Running Totals",
            LetterDecoder)
            .to_state_partition[String, String, LetterTotal val,
              LetterState](GetRunningTotal, LetterStateBuilder, "letter-state",
              letter_partition where multi_worker = true)
            .to_sink(LetterTotalEncoder, recover [0] end)
      end
      Startup(env, application, "alphabet-contest")
    else
      @printf[I32]("Couldn't build topology\n".cstring())
    end
```

Let's break down the differences step by step. The first difference is in
our `PartitionFunction`. In our single stream version, we knew that we would
always be partitioning based on the same incoming type, namely `Votes`. But now
we have two streams, one consisting of `Votes` data and the other consisting of
`String` data (the letters we're requesting running totals for). So we need a
partition function that can act on either type. We define this as follows:

```pony
primitive LetterPartitionFunction
  fun apply(input: (Votes val | String)): String =>
    match input
    | let v: Votes val => v.letter
    | let s: String => s
    else
      // We'll never reach this code, but Pony doesn't currently infer
      // that our match is exhaustive.
      ""
    end
```

We define our first, vote-count-updating pipeline as follows:

```pony
          .new_pipeline[Votes val, None]("Alphabet Votes",
            VotesDecoder)
            .to_state_partition[Votes val, String, None, LetterState](
              AddVotes, LetterStateBuilder, "letter-state",
              letter_partition where multi_worker = true)
            .done()
```

This is very similar to our initial version, except for a few key differences.
First, look at the beginning of our pipeline definition:

```pony
          .new_pipeline[Votes val, None]("Alphabet Votes",
            VotesDecoder)
```

We specify input type `Votes`, as before, but the output type is now `None`.
That's because this pipeline no longer has an output type (or a corresponding
sink). It simply updates state and then finishes. Our third type argument to
`to_state_partition()` is also type `None`.

Finally, instead of defining a sink, we finish the pipeline definition with:

```pony
            .done()
```

This indicates the pipeline ends there without emitting an output to an
external system.

Our second pipeline (the one triggering running total outputs), is defined
as follows:

```pony
          .new_pipeline[String, LetterTotal val]("Running Totals",
            LetterDecoder)
            .to_state_partition[String, String, LetterTotal val,
              LetterState](GetRunningTotal, LetterStateBuilder, "letter-state",
              letter_partition where multi_worker = true)
            .to_sink(LetterTotalEncoder, recover [0] end)
```

Our pipeline input type is `String` and our output type is `LetterTotal`. We
specify our state computation as `GetRunningTotal` and we use the same state
identifier, "letter-state", as we used in our first pipeline. This tells
Wallaroo that we're using the same state partition for both pipelines. We
define our sink here since this pipeline does have outputs to an external
system.
