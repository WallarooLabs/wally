# Writing Your Own Wallaroo Python Partitioned Stateful Application

In this section, we will go over how to write a partitioned stateful application with the Wallaroo Python API. If you haven't reviewed the simple state application and simple stateful application examples, you can find them [here](writing-your-own-application.md) and [here](writing-your-own-stateful-application.md).

## Partitioning

Partitioning is a key aspect of how work is distributed in Wallaroo. From the application's point of view, what is required are:

* a list of partition keys
* a partitioning function
* partition-compatible states - the state should be defined in such a way that each partition can have its own distinct state instance

## A Partitioned Stateful Application - Alphabet (partitioned)

Our partitioned application is going to be very similar to the Alphabet application. The difference is that it is going to use partitioning to distribute the work, and the state classes will need to reflect that.

**Encode**, **Decode**, **Computation**, and **Votes** are exactly the same as before, so we will not include them here.

### Partition

If we were to use partitioning in the alphabet application from the previous section, and we wanted to partition by key, then one way we could go about it is:

Create a partition key list:

```python
letter_partitions = list(string.ascii_lowercase)
```

And then a partitioning function which returns a key from the above list for input data:

```python
class LetterPartitionFunction(object):
    def partition(self, data):
        return data.letter[0]
```

Later when we build the application topology, we will pass both the keys and the function to the builder.

### State and StateBuilder

Previously we had a state map called `AllVotes` that kept a `dict` of votes by letter:

```python
class AllVotes(object):
    def __init__(self):
        self.votes_by_letter = {}
```

But since we are going to partition by letter, there is no reason to keep this structure. Instead, we will store the votes for a single letter in each state:

```python
class TotalVotes(object):
    def __init__(self):
        self.letter = 'X'
        self.votes = 0

    def update(self, votes):
        self.letter = votes.letter
        self.votes += votes.votes

    def get_votes(self):
        return Votes(self.letter, self.votes)
```

And since we changed the name of the state class from `AllVotes` to `TotalVotes`, the State Builder needs to be updated to reflect this:

```python
class LetterStateBuilder(object):
    def name(self):
        return "Letter State Builder"

    def build(self):
        return TotalVotes()
```

### Application Setup

Finally, the application setup is a little different now that we use partitioning. A partition is an intrinsic part of a pipeline's definition, as it changes how Wallaroo connects elements behind the scenes, so we have to distinguish partitioned state from non-partitioned state. This is done with `to_state_partition` and `to_state_partition_u64` respectively (compared with `to_stateful` in the non-partitioned case, as in the previous section).

As with `to_stateful`, `to_state_partition` takes a Computation, a StateBuilder, and a state name. In addition, it takes a partition function and a partition keys list:

```python
ab.to_state_partition(AddVotes(), LetterStateBuilder(), "letter state",
                      LetterPartitionFunction(), letter_partitions)
```

So the new `application_setup` is going to look like
```python
def application_setup(args):
    in_host, in_port = wallaroo.tcp_parse_input_addrs(args)[0]
    out_host, out_port = wallaroo.tcp_parse_output_addrs(args)[0]

    letter_partitions = list(string.ascii_lowercase)
    ab = wallaroo.ApplicationBuilder("alphabet")
    ab.new_pipeline("alphabet",
                    wallaroo.TCPSourceConfig(in_host, in_port, Decoder()))
    ab.to_state_partition(AddVotes(), LetterStateBuilder(), "letter state",
                          LetterPartitionFunction(), letter_partitions)
    ab.to_sink(wallaroo.TCPSinkConfig(out_host, out_port, Encoder()))
    return ab.build()
```

### Miscellaneous

The imports used in this module are
```python
import string
import struct
import wallaroo
```

## Next Steps

The complete alphabet example is available [here](https://github.com/WallarooLabs/wallaroo/tree/{{ book.wallaroo_version }}/examples/python/alphabet_partitioned/). To run it, follow the [Alphabet_partitioned application instructions](https://github.com/WallarooLabs/wallaroo/tree/{{ book.wallaroo_version }}/examples/python/alphabet_partitioned/README.md)

To see how everything we've learned so far comes together, check out our [Word Count walkthrough](word-count.md)
