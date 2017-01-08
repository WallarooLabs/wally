# API Basics: Stateful App

In the documentation for creating a [stateless app](...), we 
showed how you define an `Application` object and hook that into Wallaroo via 
the `Startup` object. We showed how to create an application with a single pipeline consisting of stateless computations. In this document, we'll cover creating a stateful application using partitioned state.

## Defining a Stateful Application

Have you ever wondered which letter of the alphabet is the most popular? If so, you're in luck, since we'll be creating an application that tallies votes for best letter and outputs running totals whenever we update the state associated with a letter.

Here is all the code defining the `Application` object and passing it to the Wallaroo entry point. Don't worry if you don't understand what's happening; we'll be covering this piece by piece:

```
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
      env.out.print("Couldn't build topology")
    end
```

There are three parts of this code that we will be focusing on. First, we define a state partition partitioned by letters of the alphabet. Second, we
define our `Application` object consisting of a single pipeline. And finally, we pass this object to the `Startup` Wallaroo entry point.

### Defining a State Partition

In order to define a state partition, we need a `PartitionFunction` and a list of keys (possibly weighted). In this example, our partition function is called `LetterPartitionFunction` and our list of keys is defined in a file called `letters.txt`. The relevant `Partition` definition is as follows:

```
      let letter_partition = Partition[Votes val, String](
        LetterPartitionFunction, PartitionFileReader("letters.txt",
          env.root as AmbientAuth)) 
```

We pass two type arguments into `Partition`. The first is the type of our input data that must be routed to the appropriate state. In this case, our input data is of type `Votes`, which looks like this:

```
class Votes
  let letter: String
  let count: U32

  new val create(l: String, c: U32) =>
    letter = l
    count = c
```

Our input stream consists of bundles of votes for a given letter, which are represented by our `Votes` class. 

The second type argument to `Partition` is the type of the key we use to determine where the incoming data will be routed. In this case, we use the 
`String` type since our keys are the letters of the alphabet.

A partition function is a function that transforms input to keys. We use the following:

```
primitive LetterPartitionFunction
  fun apply(votes: Votes val): String =>
    votes.letter
```

We take an input of the type `Votes` and return a `String`. The `String` is simply the `letter` field in our `Votes` object. This allows us to forward the 
`Votes` object to the state for that letter, where we will add our `count` field to the running total.

We define our keys in a file called `letters.txt`, which looks like this:

```
a
b
c
d
```

all the way to "z". We use a `PartitionFileReader` and pass in the path to our file as well as an auth token generated from `env`, defined as follows:

```
PartitionFileReader("letters.txt", env.root as AmbientAuth)
```

### Defining our Application Object

Our Alphabet Popularity Contest app takes an input stream where each incoming message represents a bundle of votes for a letter and each corresponding output message represents the running total for that letter. Our state is partitioned by letter, allowing parallel work across threads and workers. All the code for defining our `Application` object itself is as follows:

```
        Application("Alphabet Popularity Contest")
          .new_pipeline[Votes val, LetterTotal val]("Alphabet Votes",
            VotesDecoder)
            .to_state_partition[Votes val, String, LetterTotal val,
              LetterState](AddVotes, LetterStateBuilder, "letter-state",
              letter_partition where multi_worker = true)
            .to_sink(LetterTotalEncoder, recover [0] end)
```

Let's look at this line by line. In the first line, we pass in a name for our application. We then define our one and only pipeline:

```
          .new_pipeline[Votes val, LetterTotal val]("Alphabet Votes",
            VotesDecoder)
```

This says that our inputs into the pipeline are of type `Votes` and our outputs are of type `LetterTotal`. We pass in a name for the pipeline, 
`"Alphabet Votes"`, and also a decoder which we define elsewhere. The decoder is used to transform the incoming stream of bytes to messages of type `Votes`. We'll talk about decoding in a later section.

Now that we have our pipeline started, we need to define our state partition, which we do as follows:

```
            .to_state_partition[Votes val, String, LetterTotal val,
              LetterState](AddVotes, LetterStateBuilder, "letter-state",
              letter_partition where multi_worker = true)
```

We pass in four type arguments. The first two correspond to the type arguments we used when we defined our `Partition` [above](...). The third is the output type emitted by our state computation, in this case `LetterTotal`, defined elsewhere as:

```
class LetterTotal
  let letter: String
  let count: U32

  new val create(l: String, c: U32) =>
    letter = l
    count = c 
```

This represents the running vote count for a given letter.

The final type argument is the state type itself, defined elsewhere as:

```
// TODO: This is not in the working application in this form yet. See the
// corresponding TODO in the app.
class LetterState
  let letter: String
  var count: U32 = 0

  new create(l: String) =>
    letter = l
```

We update the count via a `StateComputation` called `AddVotes`.  
//TODO: How much detail should we go into about StateChange objects

We pass in four arguments to `to_state_partition`, the `StateComputation`, a lambda for creating a state instance, a `String` representing the name of our state type, and the `Partition` object we defined earlier. 

Finally, we define our pipeline sink:

```
            .to_sink(LetterTotalEncoder, recover [0] end)
```

The `LetterTotalEncoder` transforms the letter total values (which are of type
`LetterTotal`) to sequences of bytes for transmission via TCP. 
The `recover [0] end` clause says that we are using the sink with id 0. Currently Wallaroo only supports one sink per pipeline.

### Hooking into Wallaroo

The last thing we must do is pass our `Application` object into the Wallaroo entry point:

```
      Startup(env, application, "alphabet-contest")
```

We pass in the Pony environment, our application, and a string to use for tagging files and metrics related to this app.

## Decoding and Encoding

If you are using TCP to send data in and out of the system, then you need a way to convert streams of bytes into semantically useful types and convert your output types to streams of bytes. This is where the decoders and encoders mentioned earlier come into play. For more information, see [Decoders and Encoders](...).


