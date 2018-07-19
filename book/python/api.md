# Wallaroo Python API Classes

The Wallaroo Python API allows developers to create Wallaroo applications in Python, which can then be run by Machida.

## Overview

In order to create a Wallaroo application in Python, you need to create the functions and classes that provide the required interfaces for each step in your pipeline, and then connect them together in a topology structure that is returned by the entry-point function `application_setup`.

The recommended way to create your topology structure is by using the [ApplicationBuilder](#applicationbuilder) in the `wallaroo` module.

## Table of Contents

* [Application Setup](#application-setup)
* [ApplicationBuilder](#applicationbuilder)
* [Computation](#computation)
* [State](#state)
* [StateComputation](#statecomputation)
* [Data](#data)
* [Key](#key)
* [Partition](#partition)
* [Sink](#sink)
* [TCPSink](#tcpsink)
* [KafkaSink](#kafkasink)
* [Sink Encoder](#sink-encoder)
* [Source](#source)
* [TCPSource](#tcpsource)
* [KafkaSource](#kafkasource)
* [Source Decoder](#source-decoder)
* [Inter-worker serialization](#inter-worker-serialization)

### Application Setup

After Machida loads a Wallaroo Python application module, it executes its entry point function, `application_setup(args)`, which returns an application topology structure that tells Wallaroo how to connect the classes, functions, and objects behind the scenes. A Wallaroo Python application must provide this function.

The `wallaroo` module provides an [ApplicationBuilder](#wallarooapplicationbuilder) that facilitates the creation of this data structure. When `ApplicationBuilder` is used, a topology can be built using its methods and its structure can be returned by calling `ApplicationBuilder.build()`.

For a simple application with a decoder, computation, and encoder, this function may look like

```python
def application_setup(args):
    in_host, in_port = wallaroo.tcp_parse_input_addrs(args)[0]
    out_host, out_port = wallaroo.tcp_parse_output_addrs(args)[0]

    ab = wallaroo.ApplicationBuilder("My Application")
    ab.new_pipeline("pipeline 1",
                    wallaroo.TCPSourceConfig(in_host, in_port, decoder))
    ab.to(computation)
    ab.to_sink(wallaroo.TCPSinkConfig(out_host, out_port, encoder))
    return ab.build()
```

#### `args`

Since the application is run in an embedded Python runtime, it does not have standard access to `sys.argv` from which various options parsers could be used. Instead, Wallaroo provides `application_setup` with `args`: a list of the string command-line arguments it has received.

### ApplicationBuilder

The `ApplicationBuilder` class in `wallaroo` is a utility for constructing application topologies. It also provides some additional validation on the input parameters.

#### `ApplicationBuilder` Methods

##### `__init__(name)`

Create a new application with the name `name`.

##### `new_pipeline(name, source_config)`

Create a new pipeline.

`name` must be a string.

`source_config` must be one of the [SourceConfig](#source) classes.

If you're adding more than one pipeline, make sure to call `done()` before creating another pipeline.

##### `done()`

Close the current pipeline object.

This is necessary if you intend to add another pipeline.

##### `to(computation)`

Add a stateless computation _function_ to the current pipeline.

`computation` must be a [Computation](#computation).

##### `to_parallel(computation)`

Add a stateless computation _function_ to the current pipeline.
Creates one copy of the computation per worker in the cluster allowing you to parallelize stateless work.

`computation` must be a [Computation](#computation).

##### `to_stateful(computation, state_class, state_name)`

Add a state computation _function_, along with a [State](#state) _class_ and `state_name` to the current pipeline.

`computation` must be a [StateComputation](#statecomputation).

`state_class` must be a [State](#state).

`state_name` must be a str. `state_name` is the name of the state object that we will run state computations against. You can share the object across pipelines by using the same name. Using different names for different partitions keeps them separate, acting as a namespace.

##### `to_state_partition(computation, state, state_partition_name, partition_function, partition_keys)`

Add a partitioned state computation to the current pipeline.

`computation` must be a [StateComputation](#statecomputation).

`state` must be [State](#state).

`state_partition_name` must be a str. `state_partition_name` is the name of the collection of state object that we will run state computations against. You can share state partitions across pipelines by using the same name. Using different names for different partitions keeps them separate acting as a namespace.

`partition_function` must be a [Partition](#partition).

`partition_keys` is an optional list of strings.

##### `to_sink(sink_config)`

Add a sink to the end of a pipeline.

`sink_config` must be one of the [SinkConfig](#sink) classes.

##### `to_sinks(sink_configs)`

Add multiple sinks to the end of a pipeline.

`sink_config` must be a list of [SinkConfig](#sink) classes.

At the moment, the same pipeline output is sent via all sinks. The ability to determine what output should be sent to which sinks will be added in a future version of Wallaroo.

##### `build()`

Return the complete list of topology tuples. This is the topology structure Wallaroo requires in order to construct the topology connecting all of the application components.

### Computation

A stateless computation is a simple function that takes input, returns an output, and does not modify any variables outside of its scope. A stateless computation has _no side effects_.

A `computation` function must be decorated with one of the `@wallaroo.computation` or `@wallaroo.computation_multi` decorators, which take the name of the computation as their only argument.

##### `@wallaroo.computation(name)`

Create a Wallaroo Computation from a function that takes `data` as its only argument and returns a single output.

`name` is the name of the computation in the pipeline, and must be unique.

`data` will be the output of the previous function in the pipeline.

###### Example

A Computation that doubles an integer, or returns 0 if its input was not an int:

```python
@wallaroo.computation(name="Double or Zero")
def double_or_zero(data):
    if isinstance(data, int):
        return data*2
    else
        return 0
```

##### `@wallaroo.computation_multi(name)`

Create a Wallaroo Computation from a function that takes `data` as its only argument and returns a multiple outputs (as a list).

`name` is the name of the computation in the pipeline, and must be unique.

`data` will be the output of the previous function in the pipeline.

The output must be a list of items or `None`. Each item in the list will arrive individually at the next step, i.e. not as a list.

###### Example

A Computation that returns both its input integer and double that value. If the incoming data isn't an integer, it filters (drops) the message by returning `None`.

```python
@wallaroo.computation_multi(name="Identity and Double"):
def identity_and_double(data):
    if isinstance(data, int):
        return [data, data*2]
    else
        return None
```

### State

State is an object that is passed to the [StateComputation](#statecomputation) function. It is a plain Python object and can be as simple or as complex as you would like.

A common issue that arises with asynchronous execution is that when references to mutable objects are passed to the next step, if another update to the state precedes the execution of the next step, it will then execute with the latest state (that is, it will execute with the "wrong" state). Therefore, anything returned by a [Computation](#computation) or [StateComputation](#statecomputation) ought to be either unique, or immutable.

In either case, it is up to the developer to provide a side-effect safe value for the computations to return!

#### Example State

An `AlphabetCounts` keeps a count for how many times each letter in the English alphabet has been seen:

```python
import copy

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

### StateComputation

A state computation is similar to a [Computation](#computation), except that it takes an additional argument: `state`.

In order to provide resilience, Wallaroo needs to keep track of state changes, or side effects, and it does so by making `state` an explicit object that is given as input to any StateComputation step.

Similarly to a Computation, a StateComputation function must be decorated with the `@wallaroo.state_computation` decorator.

A `state_computation` function must be decorated with one of the `@wallaroo.state_computation` or `@wallaroo.state_computation_multi` decorators, which take the name of the computation as their only argument.

#### `@wallaroo.state_computation(name)`

Create a Wallaroo StateComputation from a function that takes `data` and `state` as its arguments and returns a tuple of `(output, save_state`).

`name` is the name of the computation in the pipeline, and must be unique.

`data` is the output of the previous step in the pipeline.

`output` is the output data of the function (and will become the next step's input data). If `output` is `None`, no message will be delivered to the next step in the pipeline as a result of this iteration of the StateComputation.

`save_state` is a boolean indicating whether Wallaroo should persist the new state. This is useful if your application has infrequent but large state changes, where it would be beneficial to programmatically control when Wallaroo _persists_ a new state to its recovery logs.

##### Example

An example StateComputation that keeps track of the maximum integer value it has seen so far, and only persists the state if a new max has been set.

```python
@wallaroo.state_computation(name='Compute Max'):
def compute_max(data, state):
    before = state.get_max()
    state.update(data)
    out = state.get_max()
    return (out, True if out > before else False)
```

#### `@wallaroo.state_computation_multi(name)`

Create a Wallaroo StateComputation from a function that takes `data` and `state` as its arguments and returns a tuple of `(outputs, save_state`).

`name` is the name of the computation in the pipeline, and must be unique.

`data` is the output of the previous step in the pipeline.

`outputs` is a list of output data of the function or `None`. Each item in the list will arrive at the next step in the pipeline as an individual message. If `outputs` is `None`, no messages will be delivered to the next step in the pipeline as a result of this iteration of the StateComputation.

`save_state` is a boolean indicating whether Wallaroo should persist the new state. This is useful if your application has infrequent but large state changes, where it would be beneficial to programmatically control when Wallaroo _persists_ a new state to its recovery logs.

##### Example

An example StateComputation that keeps track of the longest sentence it has seen so far, and outputs the words in each sentence as individual words to be counted in a subsequent `word_count` step.

```python
@wallaroo.state_computation(name='Longest Sentence and Split Words'):
def longest_sentence_and_split_words(data, state):
    before = state.longest()
    longest = 0
    outputs = []
    for sentence in data.strip().split('.'):
        words = sentence.split(' ')
        longest = max(longest, len(words))
        outputs.extend(words)
    # only update if there's a longer sentence!
    if longest > before:
        state.update(data)
    return (outputs, True longest > before else False)
```

### Data

Data is the object that is passed to [Computation](#computation)s and [StateComputation](#statecomputation)s. It is a plain Python object and can be as simple or as complex as you would like it to be.

It is important to ensure that data returned is always immutable or unique to avoid any unexpected behavior due to the asynchronous execution nature of Wallaroo.

### Key

Partition keys are `string` values.

### Partition

A partition function must be decorated with the `@wallaroo.partition` decorator and return the appropriate [Key](#key) for `data`.

#### Example Partition

An example that partitions words for a word count based on their first character, and buckets all other cases to the empty string key:

```python
@wallaroo.partition
def partition(data):
    try:
        return data[0].lower() if data[0].isalpha() else ''
    except:
        return ''
```

### Sink

Wallaroo currently supports two types of sinks: [TCPSink](#tcpsink), [KafkaSink](#kafkasink).

#### TCPSink

A `TCPSink` is used to send output to an external system using TCP.

The `wallaroo.TCPSinkConfig` class is used to define the properties of the `TCPSink`, which will be created by Wallaroo as part of the pipeline initialization process.

A `wallaroo.TCPSinkConfig` may be passed on its own to [to_sink](#to_sinksink_config) or as part of a list to [to_sinks](#to_sinkssink_configs).

##### `wallaroo.TCPSinkConfig(host, port, encoder)`

The class used to define the properties of a Wallaroo TCPSink.

`host` is a string representing the host address.

`port` is a string representing the port number.

`encoder` is a [Sink Encoder](#sink-encoder) that returns `bytes`.

#### KafkaSink

A `KafkaSink` is used to send output to an external Kafka cluster.

The `wallaroo.KafkaSinkConfig` class is used to define the properties of the `KafkaSink`, which will be created by Wallaroo as part of the pipeline initialization process.

##### `wallaroo.KafkaSinkConfig(topic, brokers, log_level, max_produce_buffer_ms, max_message_size, encoder)`

The class used to define the properties of a Wallaroo KafkaSink.

`topic` is a string.

`brokers` is a list of `(host, port)` pairs of strings.

`log_level` is one of the strings `Fine`, `Info`, `Warn`, `Error`.

`max_produce_buffer_ms` is an integer representing the `max_produce_buffer` value in milliseconds. The default value is `0`.

`max_message_size` is the maximum kafka message buffer size in bytes. The default vlaue is `100000`.

`encoder` is a [Sink Encoder](#sink-encoder) that returns `(bytes, key)`, where `key` may be a string or `None`.

#### Sink Encoder

The Sink Encoder is responsible for taking the output of the last computation in a pipeline and converting it into the data type that is accepted by the Sink.

To define a sink encoder, use the `@wallaroo.encoder` decorator to decorate a function that takes `data` and returns the correct data type for the sink.

It is up to the developer to determine how to translate `data` into the output data, and what information to keep or discard.

#### `@wallaroo.encoder`

The decorator used to define [sink encoders](#sink-encoder).

##### Example encoder for a TCPSink

A complete [TCPSink](#tcpsink) encoder example that takes a list of integers and encodes it to a sequence of big-endian longs preceded by a big-endian short representing the number of integers in the list:

```python
@wallaroo.encoder
def tcp_encoder(data):
    fmt = '>H{}'.format('L'*len(data))
    return struct.pack(fmt, len(data), *data)
```

##### Example encoder for a Kafka Sink

A complete `KafkaSink` encoder example that takes a word and sends it to the partition corresponding to the first letter of the word:

```python
@wallaroo.encoder
def kafka_encoder(data):
    word = data[:]
    letter_key = data[0]
    return (word, letter_key)
```

### Source

Wallaroo currently supports two types of soruces: [TCPSource](#tcpsource), [KafkaSource](#kafkasource).

#### TCPSource

The TCP Source receives data from an external TCP connection and decodes it into the data type that the first computation in its pipeline expects.

The `wallaroo.TCPSourceConfig` class is used to define the properties of the TCP Source, which will be created by Wallaroo as part of the pipeline initialization process.

An instance of `TCPSourceConfig` is a required argument of [new_pipeline](#new_pipelinename-source_config).

##### `wallaroo.TCPSourceConfig(host, port, decoder)`

The class used to define the properties of a Wallaroo TCPSource.

`host` is a string representing the host address.

`port` is a string representing the port number.

`decoder` is a [Source decoder](#source-decoder).

#### KafkaSource

A `KafkaSource` is used to get input from an external Kafka cluster.

The `wallaroo.KafkaSourceConfig` class is used to define the properties of the `KafkaSource`, which will be created by Wallaroo as part of the pipeline initialization process.

An instance of `KafkaSourceConfig` is a required argument of [new_pipeline](#new_pipelinename-source_config).

##### `wallaroo.KafkaSourceConfig(topic, brokers, log_level, decoder)`

The class used to define the properties of a Wallaroo KafkaSink.

`topic` is a string.

`brokers` is a list of `(host, port)` pairs of strings.

`log_level` is one of the strings `Fine`, `Info`, `Warn`, `Error`.

`decoder` is a [Source Decoder](#source-decoder).

#### Source Decoder

The Source Decoder is responsible for two tasks:

1. Telling Wallaroo _how many bytes to read_ from its input source.
2. Converting those bytes into an object that the rest of the application can process.

To define a source decoder, use the [@wallaroo.decoder](#@wallaroo.decoder) decorator to decorate a function that takes `bytes` and returns the correct data type for the next step in the pipeline.

It is up to the developer to determine how to translate `bytes` into the next step's input data type, and what information to keep or discard.

#### `@wallaroo.decoder(header_length, length_fmt)`

The decorator used to define [source decoders](#source-decoder).

`header_length` is the integer number of bytes to read for the header. The default value is 4.

`length_fmt` is the [struct.unpack format string](https://docs.python.org/2/library/struct.html#format-strings) to use when unpacking the header into an integer. This value is then used to determine how many bytes should be read for the `bytes` argument that will be passed to the decorated function. The default value is `">I"`.

##### Example decoder for a TCPSource

A complete `TCPSource` decoder example that decodes messages with a 32-bit unsigned integer _payload_length_ and a character followed by a 32-bit unsigned int in its _payload_:

```python
@wallaroo.decoder(header_length=4, length_fmt=">I")
def decoder(bs):
    return struct.unpack('>1sL', bs)
```

#### Example decoder for a KafkaSource

A complete `KafkaSource` decoder example that decodes messages with a 32-bit unsigned int in its _payload_:

```python
@wallaroo.decoder(header_length=4, length_fmt=">I")
def decoder(bs):
    return struct.unpack('>1sL', bs)
```

### Inter-worker serialization

When Wallaroo runs with multiple workers, a built-in serializations and deserialization functions based on pickle take care of the encoding and decoding objects on the wire. The worker processes send each other these encoded objects. In some cases, you may wish to override this built-in serialization. If you wish to know more, please refer to the [Inter-worker serialization and resilience](interworker-serialization-and-resilience.md) section of the manual.
