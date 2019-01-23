---
title: "Wallaroo Python API Classes"
menu:
  toc:
    parent: "pytutorial"
    weight: 70
toc: true
---
The Wallaroo Python API allows developers to create Wallaroo applications in Python, which can then be run by Machida.

## Overview

In order to create a Wallaroo application in Python, you need to create the functions and classes that provide the required interfaces for each stage in your pipeline, and then connect them together in a topology structure that is returned by the entry-point function `application_setup`. This function should always return the result of calling `wallaroo.build_application(app_name, pipeline)`.

## Table of Contents

* [Application Setup](#application-setup)
* [Computation](#computation)
* [State](#state)
* [StateComputation](#statecomputation)
* [Data](#data)
* [Aggregation](#aggregation)
* [Key](#key)
* [KeyExtractor](#keyextractor)
* [Windows](#windows)
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

#### Partial Pipelines

A pipeline includes one or more sources. You use `wallaroo.source(...)` to define a stream originating from a source. Each source stream can be followed by one or more computation stages. A linear sequence from a source through zero or more computations constitutes a partial pipeline. Here's an example using a stateless computation:

```python
inputs = wallaroo.source("Source Name", source_config)
partial_pipeline = inputs.to(my_stateless_computation)
```

This defines a partial pipeline that could be diagrammed as followed:

```
Source -> my_stateless_computation ->
```

The hanging arrow at the end indicates that the pipeline is partial. We can still add more stages, and to complete the pipeline we need one or more sinks.
You create complete pipeline by terminating a partial pipeline with a call to `to_sink` or `to_sinks`. For example:

```python
inputs = wallaroo.source("Source Name", source_config)
complete_pipeline = (inputs
    .to(my_stateless_computation)
    .to_sink(sink_config))
```

Our pipeline is now complete:

```
Source -> my_stateless_computation -> Sink
```

Unless a call to `to` using a stateless computation is preceded by a call to `key_by` (which partitions messages by key), there are no guarantees around the order in which messages will be processed. That's because Wallaroo might parallelize a stateless computation if that is beneficial for scaling. That means the execution graph for the above pipeline could look like this:

```
         /-> my_stateless_computation -\
        /                               \
Source ----> my_stateless_computation ----> Sink
        \                               /
         \-> my_stateless_computation -/
```

Some messages will be routed to each of the parallel computation instances. When they merge again at the sink, these messages will be interleaved in a non-deterministic fashion.

If you want to ensure that all messages are sent to the same target, then use the `collect()` API call. For example,

```python
inputs = wallaroo.source("Source Name", source_config)
complete_pipeline = (inputs
    .collect()
    .to(my_stateless_computation)
    .to_sink(sink_config))
```

will cause all messages from the source to be sent to the same stateless computation instance:

```
Source -> my_stateless_computation -> Sink
```

#### Merging Partial Pipelines

You can merge two partial pipelines to form a new partial pipeline. For example:

```python
inputs1 = wallaroo.source("Source 1", source_config)
partial_pipeline1 = inputs1.to(computation1)

inputs2 = wallaroo.source("Source 2", source_config)
partial_pipeline2 = inputs2.to(computation2)

partial_pipeline = inputs1.merge(inputs2)
```

The resulting partial pipeline could be

```
Source1 -> computation1 ->\
                           \
                            ->
                           /
Source2 -> computation2 ->/
```

Again, the hanging arrow indicates we can still add more stages, and that to complete the pipeline we still need one or more sinks. You could also merge this partial pipeline with additional partial pipelines. When you merge partial pipelines in this way, you are not creating a join in the sense familiar from SQL joins. Instead, you are combining two streams into one, with messages from the first stream interwoven with messages from the second. That combined stream is then passed to the next stage following the hanging arrow.

The following is an example of a complete pipeline including a merge where we first add one more computation before the sink:

```python
pipeline = (inputs1.merge(inputs2)
    .to(computation3)
    .to_sink(sink_config))
```

The corresponding diagram for this definition would look like this:

```
Source1 -> computation1 ->\
                           \
                            -> computation3 -> Sink
                           /
Source2 -> computation2 ->/
```

#### Building an Application

Once you have defined a complete pipeline, you must pass it into `wallaroo.build_application(app_name, pipeline)` in order to build the application object you must return from the `application_setup` function.

For a simple application with a decoder, computation, and encoder, the `application_setup` function might look like

```python
def application_setup(args):
    inputs = wallaroo.source("Source Name", source_config)

    pipeline = (inputs
        .to(computation)
        .to_sink(sink_config))

    return wallaroo.build_application("Application Name", pipeline)
```

#### `args`

Since the application is run in an embedded Python runtime, it does not have standard access to `sys.argv` from which various options parsers could be used. Instead, Wallaroo provides `application_setup` with `args`: a list of the string command-line arguments it has received.

### `wallaroo`

The `wallaroo` library provides two functions that are needed to define a Wallaroo application, `source` and `build_application`.

#### `wallaroo.source(name, source_config)`

Create a partial pipeline originating at a source.

`name` must be a string.

`source_config` must be one of the [SourceConfig](#source) classes.

There are number of methods you can call on a partial pipeline object (such as the one returned by `source`).

##### `to(computation)`

Add a computation _function_ to the partial pipeline. This will either be a [stateless](#computation) or a [state](#statecomputation) computation. A call to `to` returns a new partial pipeline object.

##### `key_by(key_extractor)`

Partition messages at this point based on the key extracted using the key_extractor function. A call to `key_by` returns a new partial pipeline object.

`key_extractor` must be a [KeyExtractor](#keyextractor).

##### `collect()`

Interleave all partitions from the previous stage into one partition for all subsequent computations. This can be overridden later with key_by. The effect of collect() is similar to using a key_by that returns a constant key.

This code:

```python
(inputs
    .key_by(extract_key)
    .to(f)
    .to(g)
    .to_sink(sink_config))
```

will partition the inputs into one partition per key. This scheme will apply to both f and g, which would look something like this:

```
         /-> f -> g -\
        /             \
Source ----> f -> g ----> Sink
        \             /
         \-> f -> g -/
```

If we want to ensure that all the results from every instance of f are sent to a single instance of g (perhaps g is used to keep track of some information about all the outputs), we would write:

```python
(inputs
    .key_by(extract_key)
    .to(f)
    .collect()
    .to(g)
    .to_sink(sink_config))
```

which would look something like:

```
         /-> f -\
        /        \
Source ----> f ----> g -> Sink
        \        /
         \-> f -/
```

##### `to_sink(sink_config)`

Add a sink to the end of a pipeline. This returns a complete pipeline object that is ready to be passed to `wallaroo.build_application`.

`sink_config` must be one of the [SinkConfig](#sink) classes.

##### `to_sinks(sink_configs)`

Add multiple sinks to the end of a pipeline. This returns a complete pipeline object that is ready to be passed to `wallaroo.build_application`.

`sink_config` must be a list of [SinkConfig](#sink) classes.

At the moment, the same pipeline output is sent via all sinks. The ability to determine what output should be sent to which sinks will be added in a future version of Wallaroo.

#### `wallaroo.build_application(application_name, pipeline)`

Returns the topology structure Wallaroo requires in order to construct the topology connecting all of the application components.

`application_name` must be a string.

`pipeline` must be a complete pipeline object returned from either `to_sink` or `to_sinks`.

### Computation

A stateless computation is a simple function that takes input, returns an output, and does not modify any variables outside of its scope. A stateless computation should have _no side effects_.

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

The output must be a list of items or `None`. Each item in the list will arrive individually at the next stage, i.e. not as a list.

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

A common issue that arises with asynchronous execution is that when references to mutable objects are passed to the next stage, if another update to the state precedes the execution of the next stage, it will then execute with the latest state (that is, it will execute with the "wrong" state). Therefore, anything returned by a [Computation](#computation) or [StateComputation](#statecomputation) ought to be either unique, or immutable.

In either case, it is up to the Python developer to provide a side-effect safe value for the computations to return!

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

Similarly to a Computation, a StateComputation function must be decorated with the `@wallaroo.state_computation` decorator.

A `state_computation` function must be decorated with one of the `@wallaroo.state_computation` or `@wallaroo.state_computation_multi` decorators, which take the name of the computation and the state class as their two arguments.

#### `@wallaroo.state_computation(name, state)`

Create a Wallaroo StateComputation from a function that takes `data` and `state` as its arguments and optionally returns an `output`.

`name` is the name of the computation in the pipeline, and must be unique.

`state` is the class used to represent state for this computation.

`data` is the output of the previous stage in the pipeline and input to our state computation.

`output` is the output data of the function (and will become the next stage's input data). If `output` is `None`, no message will be delivered to the next stage in the pipeline as a result of this iteration of the StateComputation.

##### Example

An example StateComputation that keeps track of the maximum integer value it has seen so far, and only persists the state if a new max has been set.

```python
class MaxState(object):
    max = 0

    def update(v):
        if v > max:
            max = v

@wallaroo.state_computation(name='Compute Max', state=MaxState):
def compute_max(data, state):
    before = state.max)
    state.update(data)
    output = state.max
    return output
```

#### `@wallaroo.state_computation_multi(name, state)`

Create a Wallaroo StateComputation from a function that takes `data` and `state` as its arguments and returns a tuple of `(outputs, save_state`).

`name` is the name of the computation in the pipeline, and must be unique.

`state` is the class used to represent state for this computation.

`data` is the output of the previous stage in the pipeline and input to our state computation.

`outputs` is a list of output data of the function or `None`. Each item in the list will arrive at the next stage in the pipeline as an individual message. If `outputs` is `None`, no messages will be delivered to the next stage in the pipeline as a result of this iteration of the StateComputation.

##### Example

An example StateComputation that keeps track of the longest sentence it has seen so far, and outputs the words in a new sentence if it's the longest yet.

```python
class MaxLength
    max = 0

    def update(v):
        if v > max:
            max = v

@wallaroo.state_computation(name='Longest Sentence and Split Words',
    state=MaxLength):
def longest_sentence_and_split_words(data, state):
    before = state.max
    outputs = []
    for sentence in data.strip().split('.'):
        words = sentence.split(' ')
        longest = max(longest, len(words))
        if longest > before:
            outputs.extend(words)
        before = longest
    return outputs
```

### Aggregation

For an overview of what aggregations are and how they must be implemented, see [here](/core-concepts/aggregations). 

In order to implement an aggregation, you must create a class that extends `wallaroo.Aggregation`, and you must implement four methods:

`initial_accumulator(self)`: returns the initial accumulator that is used by the aggregation. This must act as an identity element for `combine`.

`update(self, input, acc)`: uses `input` to update the accumulator `acc`.

`combine(self, acc1, acc2)`: returns an accumulator created by combining `acc1` and `acc2`. This operation must be associative, and it must not mutate `acc1` or `acc2`. 

`output(self, key, acc)`: produces an output based on the accumulator `acc`. The `key` is passed in from the context in case it is needed when creating the output. This operation must not mutate `acc`.

You can optionally implement:

`name(self)`: returns the name of the aggregation. If this method is not implemented, the class name is used instead.

##### Example

```python
class _MySum():
    def __init__(self, initial_total):
        self.total = initial_total

    def add(self, value):
        self.total = self.total + value

class MySumAgg(wallaroo.Aggregation):
    def initial_accumulator(self):
        return _MySum(0)

    def update(self, input, sum):
        sum.add(sum.total + input.value)

    def combine(self, sum1, sum2):
        return Sum(sum1.total + sum2.total)

    def output(self, key, sum):
        return MyOutputType(key, sum.total)
```

### Data

Data is the object that is passed to [Computations](#computation) and [StateComputations](#statecomputation). It is a plain Python object and can be as simple or as complex as you would like it to be.

It is important to ensure that data returned is always immutable or unique to avoid any unexpected behavior due to the asynchronous execution nature of Wallaroo.

### Key

Partition keys are `string` values.

### KeyExtractor

A key extractor function must be decorated with the `@wallaroo.key_extractor` decorator and return the appropriate [Key](#key) for `data`.

#### Example Key Extractor

An example that partitions transactions based on the user assocatied with them:

```python
@wallaroo.key_extractor
def extract_user(transaction):
    return transaction.user
```

### Windows

For an in-depth overview of windows, see [here](/core-concepts/windows). Windows are either count-based or range-based.

#### Count-based

`wallaroo.count_windows(count)`: defines count-based windows that trigger an output every `count` messages.

`over(aggregation)`: specifies the aggregation used for these windows.

##### Example

This defines count windows with a count of 5 over a user-defined [aggregation](#aggregation) class `MySumAgg`:

```python
    (inputs
        .to(wallaroo.count_windows(5)
            .over(MySumAgg))
        .to_sink(sink_config))
```

#### Range-based

`wallaroo.range_windows(range)`: defines range-based windows with the specified `range`.

`with_slide(slide)`: optionally specifies a slide for these windows, resulting in sliding (overlapping) windows. For example, if the slide is 3 seconds, then a new window of length `range` (specified via `wallaroo.range_windows(range)`) will be started every 3 seconds. The default slide is equal to the range (resulting in tumbling windows).

`with_delay(delay)`: optionally specifies a delay on triggering a window. This is either (1) an estimation of the maximum lateness expected for messages or (2) the lateness threshold beyond which you no longer care about messages. The default delay is 0.

`over(aggregation)`: specifies the aggregation used for these windows.

##### Example

This defines range-based sliding windows with a range of 6 seconds, a slide of 3 seconds, and a delay of 10 seconds:

```python
    (inputs
        .to(wallaroo.range_windows(wallaroo.seconds(6))
            .with_slide(wallaroo.seconds(3))
            .with_delay(wallaroo.seconds(10))
            .over(MySumAgg))
        .to_sink(sink_config))
```

This means windows of length 6 seconds will be started every 3 seconds. Each of these windows will be triggered 10 seconds after we have past the end of its range in event time.

### Sink

Wallaroo currently supports two types of sinks: [TCPSink](#tcpsink), [KafkaSink](#kafkasink).

#### TCPSink

A `TCPSink` is used to send output to an external system using TCP.

The `wallaroo.TCPSinkConfig` class is used to define the properties of the `TCPSink`, which will be created by Wallaroo as part of the pipeline initialization process.

A `wallaroo.TCPSinkConfig` may be passed on its own to [to_sink](#to-sink-sink-config) or as part of a list to [to_sinks](#to-sinks-sink-configs).

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
def tcp_encode(data):
    fmt = '>H{}'.format('L'*len(data))
    return struct.pack(fmt, len(data), *data)
```

##### Example encoder for a Kafka Sink

A complete `KafkaSink` encoder example that takes a word and sends it to the partition corresponding to the first letter of the word:

```python
@wallaroo.encoder
def kafka_encode(data):
    word = data[:]
    # explicitly get a substring because `[0]` in Python 3 returns an int
    letter_key = data[0:1]
    return (word, letter_key)
```

### Source

Wallaroo currently supports two types of soruces: [TCPSource](#tcpsource), [KafkaSource](#kafkasource).

#### TCPSource

The TCP Source receives data from an external TCP connection and decodes it into the data type that the first computation in its pipeline expects.

The `wallaroo.TCPSourceConfig` class is used to define the properties of the TCP Source, which will be created by Wallaroo as part of the pipeline initialization process.

An instance of `TCPSourceConfig` is a required argument of [wallaroo.source](#wallaroo-source-name-source-config).

##### `wallaroo.TCPSourceConfig(host, port, decoder)`

The class used to define the properties of a Wallaroo TCPSource.

`host` is a string representing the host address.

`port` is a string representing the port number.

`decoder` is a [Source decoder](#source-decoder).

#### KafkaSource

A `KafkaSource` is used to get input from an external Kafka cluster.

The `wallaroo.KafkaSourceConfig` class is used to define the properties of the `KafkaSource`, which will be created by Wallaroo as part of the pipeline initialization process.

An instance of `KafkaSourceConfig` is a required argument of [wallaroo.source](#wallaroo-source-name-source-config).

##### `wallaroo.KafkaSourceConfig(topic, brokers, log_level, decoder)`

The class used to define the properties of a Wallaroo KafkaSink.

`topic` is a string.

`brokers` is a list of `(host, port)` pairs of strings.

`log_level` is one of the strings `Fine`, `Info`, `Warn`, `Error`.

`decoder` is a [Source Decoder](#source-decoder).

#### Source Decoder

The Source Decoder is responsible for two tasks:

1. Telling Wallaroo _how many bytes to read_ from its input source.
2. Converting those bytes into an object that the rest of the application can process. `None` can be returned to completely discard a message.

To define a source decoder, use the [@wallaroo.decoder](#wallaroo-decoder-header-length-length-fmt) decorator to decorate a function that takes `bytes` and returns the correct data type for the next stage in the pipeline.

It is up to the developer to determine how to translate `bytes` into the next stage's input data type, and what information to keep or discard.

#### `@wallaroo.decoder(header_length, length_fmt)`

The decorator used to define [source decoders](#source-decoder).

`header_length` is the integer number of bytes to read for the header. The default value is 4.

`length_fmt` is the [struct.unpack format string](https://docs.python.org/2/library/struct.html#format-strings) to use when unpacking the header into an integer. This value is then used to determine how many bytes should be read for the `bytes` argument that will be passed to the decorated function. The default value is `">I"`.

##### Example decoder for a TCPSource

A complete `TCPSource` decoder example that decodes messages with a 32-bit unsigned integer _payload_length_ and a character followed by a 32-bit unsigned int in its _payload_. Filters out any input that raises a `struct.error` by returning `None`:

```python
@wallaroo.decoder(header_length=4, length_fmt=">I")
def decode(bs):
    try:
        return struct.unpack('>1sL', bs)
    except struct.error:
        return None
```

#### Example decoder for a KafkaSource

A complete `KafkaSource` decoder example that decodes messages with a 32-bit unsigned int in its _payload_. Filters out any input that raises a `struct.error` by returning `None`:

```python
@wallaroo.decoder(header_length=4, length_fmt=">I")
def decode(bs):
    try:
        return struct.unpack('>1sL', bs)
    except struct.error:
        return None
```

### Inter-worker serialization

When Wallaroo runs with multiple workers, a built-in serializations and deserialization functions based on pickle take care of the encoding and decoding objects on the wire. The worker processes send each other these encoded objects. In some cases, you may wish to override this built-in serialization. If you wish to know more, please refer to the [Inter-worker serialization and resilience](/python-tutorial/interworker-serialization-and-resilience/) section of the manual.
