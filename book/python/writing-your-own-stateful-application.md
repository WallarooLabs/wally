# Writing Your Own Wallaroo Python Stateful Application

In this section, we will go over how to write a stateful application with the Wallaroo Python API. If you haven't reviewed the simple stateless application example yet, you may find it [here](writing-your-own-application.md).

## A Stateful Application - Alphabet

Our stateful application is going to be a vote counter, called Alphabet. It receives as its input a message containing an alphabet character and a number of votes, which it then increments in its internal state. After each update, it sends the new updated vote count or that character to its output.

As with the Reverse Word example, we will list the components required:

* Input decoding
* Output encoding
* Computation for adding votes
* State objects
* State change management

### Computation

The computation here is fairly straightforward: given a data object and a state object, update the state with the new data, and return some data that tells Wallaroo what to do next.

```python
class AddVotes(object):
    def name(self):
        return "add votes"

    def compute(self, data, state):
        state.update(data)
        return (state.get_votes(data.letter), True)
```

Let's dig into that tuple that we are returning:

```python
(state.get_votes(data.letter), True)
```

The first element, `state.get_votes(data.letter)` is a message that we will send on to our next step. In this case, we will be sending information about votes for this letter on to a sink. The second element. `True` is a to let Wallaroo know if we should store an update for our state. By returning true, we are instructing to Wallaroo to save our updated state so that in the event of a crash, we can recover to this point. Being able to recover from a crash is a good thing so, why wouldn't we always return `True`? There are two answers:

1. Your computation might not have updated the state, in which case, saving its state for recovery is wasteful.
2. You might only want to save after some changes. Saving your state can be expensive for large objects. There's a tradeoff that can be made between performance and safety.

### State and StateBuilder

The state for this application is two-tiered. There is a vote count for each letter:

```python
class Votes(object):
    def __init__(self, letter, votes):
        self.letter = letter
        self.votes = votes
```

And a state map:

```python
class AllVotes(object):
    def __init__(self):
        self.votes_by_letter = {}

    def update(self, votes):
        letter = votes.letter
        vote_count = votes.votes

        votes_for_letter = self.votes_by_letter.get(letter, Votes(letter, 0))
        votes_for_letter.votes += vote_count
        self.votes_by_letter[letter] = votes_for_letter

    def get_votes(self, letter):
        vbl = self.votes_by_letter[letter]
        return Votes(letter, vbl.votes)
```

This map is the `state` object that `AddVotes.compute` above takes.
An important thing to note here is that `get_votes` returns a _new_ `Votes` instance. This is important, as this is the value that is returned eventually passed to `Encoder.encode`, and if we passed a reference to a mutable object here, there is no guarantee that `Encoder.encode` will execute before another update to this object.

Lastly, a stateful application's pipeline is going to need a `StateBuilder`, so let's create one:

```python
class LetterStateBuilder(object):
    def build(self):
        return AllVotes()
```

### Encoder
The encoder is going to receive a `Votes` instance and encode into a string with the letter, followed by the vote count as a big-endian 64-bit unsigned integer:

```python
class Encoder(object):
    def encode(self, data):
        # data is a Votes
        return struct.pack(">IsQ", 9, data.letter, data.votes)
```

### Decoder

The decoder, like the one in Reverse Word, is going to use a `header_length` of 4 bytes to denote a big-endian 32-bit unsigned integer. Then, for the data, it is expecting a single character followed by a big-endian 32-bit unsigned integer. Here we use the `struct` module to unpack these integers from the bytes string.

```python
class Decoder(object):
    def header_length(self):
        return 4

    def payload_length(self, bs):
        return struct.unpack(">I", bs)[0]

    def decode(self, bs):
        (letter, vote_count) = struct.unpack(">sI", bs)
        return Votes(letter, vote_count)
```

### Application Setup

Finally, let's set up our application topology:

```python
def application_setup(args):
    in_host, in_port = wallaroo.tcp_parse_input_addrs(args)[0]
    out_host, out_port = wallaroo.tcp_parse_output_addrs(args)[0]

    ab = wallaroo.ApplicationBuilder("alphabet")
    ab.new_pipeline("alphabet",
                    wallaroo.TCPSourceConfig(in_host, in_port, Decoder()))
    ab.to_stateful(AddVotes(), LetterStateBuilder(), "letter state")
    ab.to_sink(wallaroo.TCPSinkConfig(out_host, out_port, Encoder()))
    return ab.build()
```

The only difference between this setup and the stateless Reverse Word's one is that while in Reverse Word we used:

```python
ab.to(Reverse)
```

here we use:

```python
ab.to_stateful(AddVotes(), LetterStateBuilder(), "letter state")
```

That is, while the stateless computation constructor `to` took only a computation class as its argument, the stateful computation constructor `to_stateful` takes a computation _instance_, as well as a state-builder _instance_, along with the name of that state.

### Miscellaneous

This module needs its imports:
```python
import struct
import pickle

import wallaroo
```

## Next Steps

The complete alphabet example is available [here](https://github.com/WallarooLabs/wallaroo/tree/{{ book.wallaroo_version }}/examples/python/alphabet/). To run it, follow the [Alphabet application instructions](https://github.com/WallarooLabs/wallaroo/tree/{{ book.wallaroo_version }}/examples/python/alphabet/README.md)

To learn how to write a stateful application with partitioning, continue to [Writing Your Own Partitioned Stateful Application](writing-your-own-partitioned-stateful-application.md).

To learn how to make your application resilient and able to work across multiple workers, skip ahead to [Interworker Serialization and Resilience](interworker-serialization-and-resilience.md).
