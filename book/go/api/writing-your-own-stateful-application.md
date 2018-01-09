# Writing Your Own Wallaroo Go Stateful Application

In this section, we will go over how to write a stateful application with the Wallaroo Go API. If you haven't reviewed the simple stateless application example yet, you can find it [here](writing-your-own-application.md).

## A Stateful Application - Alphabet

Our stateful application is going to be a vote counter, called Alphabet. It receives as its input a message containing an alphabet character and a number of votes, which it then increments in its internal state. After each update, it sends the new updated vote count of that character to its output.

As with the Reverse Word example, we will list the components required:

* Input decoding
* Output encoding
* Computation for adding votes
* State objects
* State change management
* A list of keys that are valid for partitioning our state objects
* A partitioning function

### Computation

The computation here is fairly straightforward: given a data object and a state object, update the state with the new data, and return some data that tells Wallaroo what to do next.

```go
type AddVotes struct {}

func (av *AddVotes) Name() string {
  return "add votes"
}

func (av *AddVotes) Compute(data interface{}, state interface{}) (interface{}, bool) {
  lv := data.(*LetterAndVotes)
  rvt := state.(*RunningVoteTotal)
  rvt.Update(lv)
  return rvt.GetVotes(), true
}
```

Let's dig into our return values

```go
return rvt.GetVotes(), true
```

The first element, `rvt.GetVotes()`, is a message that we will send on to our next step. In this case, we will be sending information about votes for this letter on to a sink. The second element, `true`, is to let Wallaroo know if we should store an update for our state. By returning `true`, we are instructing Wallaroo to save our updated state so that in the event of a crash, we can recover to this point. Being able to recover from a crash is a good thing, so why wouldn't we always return `true`? There are two answers:

1. Your computation might not have updated the state, in which case saving its state for recovery is wasteful.
2. You might only want to save after some changes. Saving your state can be expensive for large objects. There's a tradeoff that can be made between performance and safety.

### State and StateBuilder

We are going to partition by letter. We'll have a separate state object for every letter.

```go
type RunningVoteTotal struct {
  Letter byte
  Votes uint64
}

func (tv *RunningVoteTotal) Update(votes *LetterAndVotes) {
  tv.Letter = votes.Letter
  tv.Votes += votes.Votes
}

func (tv *RunningVoteTotal) GetVotes() *LetterAndVotes {
  return &LetterAndVotes{tv.Letter, tv.Votes}
}
```

Lastly, a stateful application's pipeline is going to need a `StateBuilder`, so let's create one:

```go
type RunningVotesTotalBuilder struct {}

func (rvtb *RunningVotesTotalBuilder) Name() string {
  return "running votes total builder"
}

func (rvtb *RunningVotesTotalBuilder) Build() interface{} {
  return &RunningVoteTotal{}
}
```

### Encoder

By this point, we've almost made it to the end of the line. The only thing left is the sink and encoding. We don't do anything fancy with our encoding. We take the letter and its vote count, and format it into a single line of text that our receiver can record.

```go
type Encoder struct {}

func (encoder *Encoder) Encode(data interface{}) []byte {
  lav := data.(*LetterAndVotes)
  output := fmt.Sprintf("%s => %d\n", string(lav.Letter), lav.Votes)

  return []byte(output)
}
```

### Decoder

The decoder, like the one in [Reverse Word](/book/go/api/writing-your-own-application.md#sourcedecoder), is going to use a `HeaderLength()` of 4 bytes to denote a big-endian 32-bit unsigned integer. Then, for the data, it is expecting a single character followed by a big-endian 32-bit unsigned integer.

```go
type Decoder struct {}

func (d *Decoder) HeaderLength() uint64 {
  return 4
}

func (d *Decoder) PayloadLength(b []byte) uint64 {
  return uint64(binary.BigEndian.Uint32(b[0:4]))
}

func (d *Decoder) Decode(b []byte) interface{} {
  letter := b[0]
  vote_count := binary.BigEndian.Uint32(b[1:])

  lav := LetterAndVotes{letter, uint64(vote_count)}
  return &lav
}
```

### Application Setup

Finally, let's set up our application topology:

```go
//export ApplicationSetup
func ApplicationSetup() *C.char {
  fs := flag.NewFlagSet("wallaroo", flag.ExitOnError)
  inHostsPortsArg := fs.String("in", "", "input host:port list")
  outHostsPortsArg := fs.String("out", "", "output host:port list")

  fs.Parse(wa.Args[1:])

  inHostsPorts := hostsPortsToList(*inHostsPortsArg)

  inHost := inHostsPorts[0][0]
  inPort := inHostsPorts[0][1]

  outHostsPorts := hostsPortsToList(*outHostsPortsArg)
  outHost := outHostsPorts[0][0]
  outPort := outHostsPorts[0][1]

  wa.Serialize = Serialize
  wa.Deserialize = Deserialize

  application := app.MakeApplication("Alphabet")
  application.NewPipeline("Alphabet", app.MakeTCPSourceConfig(inHost, inPort, &Decoder{})).
    ToStatePartition(&AddVotes{}, &RunningVotesTotalBuilder{}, "running vote totals", &LetterPartitionFunction{}, MakeLetterPartitions()).
    ToSink(app.MakeTCPSinkConfig(outHost, outPort, &Encoder{}))

  return C.CString(application.ToJson())
}
```

The only difference between this setup and the stateless Reverse Word's one is that while in Reverse Word we used:

```go
To(&ReverseBuilder{}).
```

here we use:

```go
ToStatePartition(&AddVotes{}, &RunningVotesTotalBuilder{}, "running vote totals", &LetterPartitionFunction{}, MakeLetterPartitions()).
```

That is, while the stateless computation constructor `To` took only a computation class as its argument, the stateful computation constructor `ToStatePartition` takes a computation _instance_, as well as a state-builder _instance_, along with the name of that state. Additionally, it takes two arguments needed for partitioning our state.

## Partitioning

Partitioning is a key aspect of how work is distributed in Wallaroo. From the application's point of view, what is required is:

* a list of partition keys
* a partitioning function
* partition-compatible states - the state should be defined in such a way that each partition can have its own distinct state instance

### Partition

If we were to use partitioning in the alphabet application from the previous section and we wanted to partition by key, then one way we could go about it is to create a partition key list.

To create a partition key list, we use the `MakeLetterPartitions()` function:

```go
func MakeLetterPartitions() []uint64 {
  letterPartition := make([]uint64, 26)

  for i := 0; i < 26; i++ {
    letterPartition[i] = uint64(i + 'a')
  }

  return letterPartition
}
```

And then we define a partitioning function which returns a key from the above list for input data:

```go
type LetterPartitionFunction struct {}

func (lpf *LetterPartitionFunction) Partition(data interface{}) uint64 {
  lav := data.(*LetterAndVotes)
  return uint64(lav.Letter)
}
```

When we set up our state partition, we pass both functions above as arguments to `ToStatePartition` as we saw earlier:

```go
ToStatePartition(&AddVotes{}, &RunningVotesTotalBuilder{}, "running vote totals", &LetterPartitionFunction{}, MakeLetterPartitions()).
```

## Next Steps

The complete alphabet example is available [here](https://github.com/WallarooLabs/wallaroo/tree/{{ book.wallaroo_version }}/examples/go/alphabet/). To run it, follow the [Alphabet application instructions](https://github.com/WallarooLabs/wallaroo/tree/{{ book.wallaroo_version }}/examples/go/alphabet/README.md)

To see how everything we've learned so far comes together, check out our [Word Count walkthrough](word-count.md)

Our Alphabet application contains serialization and deserialization code that we didn't cover; to learn more, skip ahead to [Interworker Serialization and Resilience](interworker-serialization-and-resilience.md).
