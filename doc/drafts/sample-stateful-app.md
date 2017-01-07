# API Basics: Stateful App

In the documentation for creating a [stateless app](...), we 
showed how you define an `Application` object and hook that into Wallaroo via 
the `Startup` object. We showed how to create an application with a single pipeline consisting of stateless computations. In this document, we'll cover creating a stateful application using partitioned state.

## Defining a Stateful Application

Have you ever wondered which letter of the alphabet is the most popular? If so, you're in luck, since we'll be creating an application that tallies votes for best letter and outputs running totals as the state associated with a letter is updated.

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

```
        Application("Alphabet Popularity Contest")
          .new_pipeline[Votes val, LetterTotal val]("Alphabet Votes",
            VotesDecoder)
            .to_state_partition[Votes val, String, LetterTotal val,
              LetterState](AddVotes, LetterStateBuilder, "letter-state",
              letter_partition where multi_worker = true)
            .to_sink(LetterTotalEncoder, recover [0] end)
```
