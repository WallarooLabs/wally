# Wallaroo Python API Classes

The Wallaroo Python API allows developers to create Wallaroo applications in Python, which can then be run by Machida.

## Overview

In order to create a Wallaroo application in Python, developers need to create classes that provide the required interfaces for each step in their pipline, and then connect them together in a topology structure that is returned by the entry-point function `application_setup`.

The recommended way to create your topology structure is by using the [ApplicationBuilder](#wallarooapplicationbuilder) in the `wallaroo` module.

## Table of Contents

* [Application setup](#application-setup)
* [ApplicationBuilder](#wallarooapplicationbuilder)
* [Computation](#computation)
* [Data](#data)
* [Key](#key)
* [PartitionFunction](#partitionfunction)
* [TCPSinkEncoder](#tcpsinkencoder)
* [TCPSourceDecoder](#tcpsourcedecoder)
* [KafkaSinkEncoder](#kafkasinkencoder)
* [kafkaSourceDecoder](#kafkasourcedecoder)
* [State](#state)
* [StateBuilder](#statebuilder)
* [StateComputation](#statecomputation)
* [TCPSourceConfig](#tcpsourceconfig)
* [TCPSinkConfig](#tcpsinkconfig)

### Application Setup

After Machida has loaded a Wallaroo Python application module, it executes its entry point function: `application_setup(args)`, which returns an application topology structure that tells Wallaroo how to connect the classes, functions, and objects behind the scenes. Therefore, any Wallaroo Python application must provide this function.

The `wallaroo` module provides an [ApplicationBuilder](#wallarooapplicationbuilder) that facilitates the creation of this data structure. When `ApplicationBuilder` is used, a topology can be built using its methods, and then its structure can be return by calling `ApplicationBuilder.build()`.

For a simple application with a `Decoder`, `Computation`, and `Encoder`, this function may look like

```python
def application_setup(args):
    in_host, in_port = wallaroo.tcp_parse_input_addrs(args)[0]
    out_host, out_port = wallaroo.tcp_parse_output_addrs(args)[0]

    ab = wallaroo.ApplicationBuilder("My Application")
    ab.new_pipeline("pipeline 1",
                    wallaroo.TCPSourceConfig(in_host, in_port, Decoder()))
    ab.to(Computation)
    ab.to_sink(wallaroo.TCPSinkConfig(out_host, out_port, Encoder()))
    ab.done()
    return ab.build()
```

#### `args`

Since the application is run in an embedded Python runtime, it does not have standard access to `sys.argv` from which various options parsers could be used. Instead, Wallaroo provides `application_setup` with `args`: a list of the string command-line arguments it has received.

### wallaroo.ApplicationBuilder

The `ApplicationBuilder` class in `wallaroo` is a utility for constructing application topologies. It also provides some additional validation on the input parameters.

#### `ApplicationBuilder` Methods

##### `__init__(name)`

Create a new application with the name `name`.

##### `new_pipeline(name, source_config)`

Create a new pipline with the name `name` and a source config object.

If you're adding more than one pipeline, make sure to call `done()` before creating another pipeline.

##### `done()`

Close the current pipeline object.

This is necessary if you intend to add another pipeline.

##### `to(computation_cls)`

Add a stateless computation _class_ to the current pipeline. Only a single instance of the computation will be created.

Note that this method takes a _class_, rather than an _instance_ as its argument. `computation_cls` must be a [Computation](#computation).

##### `to_parallel(computation_cls)`

Add a stateless computation _class_ to the current pipeline. Creates one copy of the computation per worker in the cluster allowing you to parallelize stateless work.

Note that this method takes a _class_, rather than an _instance_ as its argument. `computation_cls` must be a [Computation](#computation).

##### `to_stateful(computation, state_builder, state_name)`

Add a StateComputation _instance_, along with a [StateBuilder](#statebuilder) _instance_ and `state_name` to the current pipeline.

`computation` must be a [StateComputation](#statecomputation).

`state_builder` must be a [StateBuilder](#statebuilder).

`state_name` must be a str. `state_name` is the name of the state object that we will run computations against. You can share the object across pipelines by using the same name. Using different names for different objects, keeps them separate and in this way, acts as a sort of namespace.

##### `to_state_partition(computation, state_builder, state_partition_name, partition_function, partition_keys)`

Add a partitioned StateComputation to the current pipeline.

`computation` must be a [StateComputation](#statecomputation).

`state_builder` must be [StateBuilder](#statebuilder).

`state_partition_name` must be a str. `state_partition_name` is the name of the collection of state object that we will run computations against. You can share state partitions across pipelines by using the same name. Using different names for different partitions, keeps them separate and in this way, acts as a sort of namespace.

`partition_function` must be a [PartitionFunction](#partitionfunction).

`partition_keys` must be a list of objects where all of the objects can be hashed with the `hash` function and be checked for equality with other objects.

##### `to_state_partition_u64(computation, state_builder, state_partition_name, partition_function, partition_keys)`

Add a partitioned stateful computation to the current pipeline.

`computation` must be a [StateComputation](#statecomputation).

`state_builder` must be [StateBuilder](#statebuilder).

`state_partition_name` must be a str. `state_partition_name` is the name of the collection of state object that we will run computations against. You can share state partitions across pipelines by using the same name. Using different names for different partitions, keeps them separate and in this way, acts as a sort of namespace.

`partition_function` must be a [PartitionFunction](#partitionfunction).

`partition_keys` must be a list of non-negative `int`.

##### `to_sink(sink_config)`

Add a sink to the end of a pipeline. `sink_config` must be an instance of a sink configuration.

##### `build()`

Return the complete list of topology tuples. This is the topology structure Wallaroo requries in order to construct the topology connectinng all of the application components.

### Computation

A stateless computation is a simple function that takes input, returns an output, and does not modify any variables outside of its scope. e.g. a stateless computation has _no side effects_.

A `Computation` class must provide the `name` and `compute` methods.

##### `name()`

Return the name of the computation as a string.

##### `compute(data)`

Use `data` to perform a computation and return a new output. `data` is the python object the previous step in the pipeline returned.

##### `compute_multi(data)`

Use `data` to perform a computation and return a series of new outputs. `data` is the python object the previous step in the pipeline returned. Output is a list of items. Used to turn 1 incoming object into many outgoing objects. Each item in the list will arrive individually at the next step; i.e. not as a list.

#### Example Computations

A Computation that doubles an integer, or returns 0 if its input was not an int:

```python
class Computation(object):
    def name(self):
        return "double"

    def compute(data):
        if isinstance(data, int):
            return data*2
        else
            return 0
```

A Computation that returns both its input integer and double that value. If the incoming data isn't an integer, we filter aka drop the message by returning `None`.

```python
class Computation(object):
    def name(self):
        return "double"

    def compute_multi(data):
        if isinstance(data, int):
            return [data, data*2]
        else
            return None
```

### Data

Data is the object that is passed to a [Computation](#computation) and [StateComputation](#statecomputation)'s `compute` method. It is a plain Python object and can be as simple or as complex as you would like it to.

It is important to ensure that data returned is always immutable or unique to avoid any unexpected behvaiour due to the asynchronous execution nature of Wallaroo.

### Key

Partition Keys must correctly support the `__eq__` (`==`) and `__hash__` operators. Some built-in types, such as strings and numbers, already support these out of the box. If you are defining your own types, however, you must also implement the `__eq__` and `__hash__` methods.

### PartitionFunction

A PartitionFunction class must provide the `partition` method.

##### `partition(data)`

Return the appropriate [Key](#key) for `data`.

#### Example PartitionFunction

An example that partitions words for a word-count based on their first character, and buckets all other cases to the empty string key

```python
PartitionFunction(object):
    def partition(self, data):
        try:
            return data[0].lower() if data[0].isalpha() else ''
        except:
            return ''
```

### TCPSinkEncoder

The `TCPSinkEncoder` is responsible for taking the output of the last computation in a pipeline and converting it into a `bytes` for Wallaroo to send out over a TCP connection.

To do this, a `TCPSinkEncoder` class must provide the `encode(data)` method.

##### `encode(data)`

Return a `bytes` that can be sent over the network. It is up to the developer to determine how to translate `data` into a `bytes`, and what information to keep or discard.

#### Example TCPSinkEncoder

A complete `TCPSinkEncoder` example that takes a list of integers and encodes it to a sequence of big-endian Longs preceded by a big-endian short representing the number of integers in the list:

```python
class Encoder(object):
    def encode(self, data):
        fmt = '>H{}'.format('L'*len(data))
        return struct.pack(fmt, len(data), *data)
```

### TCPSourceDecoder

The `TCPSourceDecoder` is responsible for two tasks:
1. Telling Wallaroo _how many bytes to read_ from its input connection.
2. Converting those bytes into an object that the rest of the application can process.

To do this, a `TCPSourceDecoder` class must implement the following three methods:

##### `header_length()`

Return an integer representing the number of bytes from the beginning of an incoming message to return to the function that reads the payload length.

##### `payload_length(bs)`

Return an integer representing the number of bytes after the payload length bytes to return to the function that decodes the payload.

`bs` is a `bytes` of length `header_length()`, and it's up to the user to provide a method for converting that into an integer value.

A common encoding used in Wallaroo is a big-endien 32-bit unsigned integer, which can be decoded with the [struct module's](https://docs.python.org/2/library/struct.html) help:

```python
struct.unpack('>L', bs)
```

##### `decode(bs)`

Return a python a python object of the type the next step in the pipeline expects.

`bs` is a `bytes` of the length returned by [payload_length](#payload-length(bs)), and it is up to the developer to translate that into a python object.

#### Example TCPSourceDecoder

A complete TCPSourceDecoder example that decodes messages with a 32-bit unsigned integer _payload_length_ and a character followed by a 32-bt unsigned int in its _payload_:

```python
class Decoder(object):
    def header_length(self):
        return 4

    def payload_length(self, bs):
         return struct.unpack('>L', bs)

    def decode(self, bs):
        return struct.unpack('>1sL', bs)
```

### KafkaSinkEncoder

The `KafkaSinkEncoder` is responsible for taking the output of the last computation in a pipeline and converting it into a `bytes` for Wallaroo to send out to a Kafka sink, along with a `key` or `None`.

To do this, a `KafkaSinkEncoder` class must provide the `encode(data)` method.

##### `encode(data)`

Return a tuple of `(bytes, key)` that can be sent over the network. It is up to the developer to determine how to translate `data` into a `bytes` and `key`, and what information to keep or discard.

#### Example KafkaSinkEncoder

A complete `KafkaSinkEncoder` example that takes a word and sends it to the partition corresponding to the first letter of the word:

```python
class Encoder(object):
    def encode(self, data):
        word = data[:]
        letter_key = data[0]
        return (word, letter_key)
```

### KafakSourceDecoder

The `TCPSourceDecoder` is responsible for converting bytes into an object that the rest of the application can process.

To do this, a `KafkaSourceDecoder` class must implement the following method:

##### `decode(bs)`

Return Python object of the type the next step in the pipeline expects.

`bs` is a `bytes` of the length returned by [payload_length](#payload-length(bs)), and it is up to the developer to translate that into a Python object.

#### Example KafkaSourceDecoder

A complete KafkaSourceDecoder example that decodes messages with a 32-bit unsigned int in its _payload_:

```python
class Decoder(object):
    def decode(self, bs):
        return struct.unpack('>1sL', bs)
```

### State

State is an object that is passed to the [StateCompution's](#statecomputation) `compute` method. It is a plain Python object and can be as simple or as complex as you would like it to.

A common issue that arises with asynchronous execution, is that when references to mutable objects are passed to the next step, if another update to the state precedes the execution of the next step, it will then execute with the latest state (that is, it will execute with the "wrong" state). Therefore, anything returned by a [Computation](#computation) or [StateComputation](#statecomputation) ought to be either unique, or immutable.

In either case, it is up to the developer to provide a side-effect safe value for the Computation to return!

#### Example State

An AlphabetCounts keeps a count for how many times each letter in the English alphabet has been seen

```python
import copy

...

AlphabetCounts(objects):
    def __init__(self, initial_counts):
        self.data = dict(initial_counts)

    def update(self, c, value):
        self.data[c] += value
        return self.data[c]

    def get_counts(self):
        # Return a deep copy of the data dict
        return copy.deepcopy(self.data)

    def get_count(self, c):
        # int is safe to return as is!
        return self.data[c]
```

### StateBuilder

A StateBuilder is used by Wallaroo to create an initial state object for a [StateComputation](#statecomputation).

##### `build()`

Return a new [State](#state) instance.

#### Example StateBuilder

Return a AlphabetCounts object initialized with a count of zero for each letter in the English alphabet

```python
class StateBuilder(object):
    def build(self):
        return AlphabetCounts([(c, 0) for c in string.ascii_lowercase])
```

### StateComputation

A StateComputation is similar to a [Computation](#computation), except that its `compute` method takes an additional argument: `state`.

In order to provide resilience, Wallaroo needs to keep track of state changes, or side effects, and it does so by making `state` an explicit object that is given as input to any StateComputation step.

Like Computation, a StateComputation class must provide the `name` and `compute` methods.

##### `name()`

Return the name of the computation as a string.

##### `compute(data, state)`

`data` is anything that was returned by the previous step in the pipeline, and `state` is provided by the [StateBuilder](#statebuilder) that was defined for this step in the pipeline definition.

Returns a tuple. The first element is a message that we will send on to our next step. It should be a new object. Returning `None` will stop processing and no messages will be sent to the next step. The second element is a boolean value instructing Wallaroo to save our updated state so that in the event of a crash, we can recover to this point. Return `True` to save `state`. Return `False` to not save `state`.

Why wouldn't we always return `True`? There are two answers:

1. Your computation might not have updated the state, in which case, saving its state for recovery is wasteful.
2. You might only want to save after some changes. Saving your state can be expensive for large objects. There's a tradeoff that can be made between performance and safety.

##### `compute_multi(data, state)`

Same as `compute` but the first element of the return tuple is a list of messages to send on to our next step. Allows taking a single input message and creating multiple outputs. Each item in the list will arrive individually at the next step; i.e. not as a list.

#### Example StateComputation

An example StateComputation that keeps track of the maximum integer value it has seen so far:

```python
class StateComputation(object):
    def name(self):
        return "max"

    def compute(self, data, state):
        try:
            state.update(data)
        except TypeError:
            pass
        return (state.get_max(), True)
```

### TCPSourceConfig

A `TCPSourceConfig` object specifies the host, port, and encoder to use for a TCP source connection when creating an application. The host and port are both represented by strings. This object is provided as an argument to `new_pipeline`.

### TCPSinkConfig

A `TCPSinkConfig` object specifies the host, port, and decoder to use for the TCP sink connection when creating an application. The host and port are both represented by strings. This object is provided as an argument to `to_sink`.
