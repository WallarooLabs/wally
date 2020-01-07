---
title: "Wallaroo Pony API Classes"
menu:
  toc:
    parent: "ponytutorial"
    weight: 70
toc: true
---
The Wallaroo Pony API allows developers to create Wallaroo applications in Pony.

## Overview

In order to create a Wallaroo application in Pony, you need to create the functions and classes that provide the required interfaces for each stage in your pipeline, and then connect them together in a topology structure. This topology structure should always be the last argument when calling `Wallaroo.build_application(env, app_name, pipeline)`.

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

### Application Setup

After your program loads, it executes its entry point function, `Main.create`, which builds an application topology structure that tells Wallaroo how to connect the classes, functions, and objects behind the scenes using `Wallaroo.build_application`. A Wallaroo Pony application must call this function.

#### Partial Pipelines

A pipeline includes one or more sources. You use `Wallaroo.source[InputType](...)` to define a stream originating from a source. Each source stream can be followed by one or more computation stages. A linear sequence from a source through zero or more computations constitutes a partial pipeline. Here's an example using a stateless computation:

```
let inputs = Wallaroo.source[InputType]("Source Name", source_config)
let partial_pipeline =
    inputs.to[InputType](my_stateless_computation)
```

This defines a partial pipeline that could be diagrammed as followed:

```
Source -> my_stateless_computation ->
```

The hanging arrow at the end indicates that the pipeline is partial. We can still add more stages, and to complete the pipeline we need one or more sinks.
You create complete pipeline by terminating a partial pipeline with a call to `to_sink` or `to_sinks`. For example:

```
let inputs =
    Wallaroo.source[InputType]("Source Name", source_config)
let complete_pipeline = recover val
    inputs
        .to[InputType](my_stateless_computation)
        .to_sink(sink_config)
end
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

```
let inputs = Wallaroo.source[InputType]("Source Name",
    source_config)
let complete_pipeline = recover val
    inputs
        .collect()
        .to[InputType](my_stateless_computation)
        .to_sink(sink_config))
end
```

will cause all messages from the source to be sent to the same stateless computation instance:

```
Source -> my_stateless_computation -> Sink
```

#### Merging Partial Pipelines

You can merge two partial pipelines to form a new partial pipeline. For example:

```
let inputs1 = Wallaroo.source[InputType]("Source 1",
    source_config)
let partial_pipeline1 = inputs1.to[Input1Type](computation1)

let inputs2 = Wallaroo.source[InputType]("Source 2",
    source_config)
let partial_pipeline2 = inputs2.to[Input2Type](computation2)

inputs1.merge[Input2Type](inputs2)
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

```
let pipeline = recover val
    inputs1.merge[Input2Type](inputs2)
    .to[ComputationOutputType](computation3)
    .to_sink(sink_config)
end
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

Once you have defined a complete pipeline, you must pass it into `Wallaroo.build_application(env, app_name, pipeline)`.

For a simple application with a decoder, computation, and encoder, the application setup might look like

```
let pipeline = recover val
    let inputs = Wallaroo.source[InputType]("Source Name",
        source_config)

    inputs
        .to[ComputationOutpputType](computation)
        .to_sink(sink_config)
end
Wallaroo.build_application(env, "Application Name", pipeline)
```

### `Wallaroo`

The `Wallaroo` library provides two functions that are needed to define a Wallaroo application, `source[InputType]` and `build_application`.

#### `wallaroo.source[InputType](name, source_config)`

Create a partial pipeline originating at a source.

`name` must be a string.

`source_config` must be one of the [SourceConfig](#source) classes.

There are number of methods you can call on a partial pipeline object (such as the one returned by `source`).

##### `to[ComputationOutputType](computation)`

Add a computation _function_ to the partial pipeline. This will either be a [stateless](#computation) or a [state](#statecomputation) computation. A call to `to` returns a new partial pipeline object.

##### `key_by(KeyExtractor)`

Partition messages at this point based on the key extracted using the key_extractor function. A call to `key_by` returns a new partial pipeline object.

`key_extractor` must implement the [KeyExtractor](#keyextractor) interface.

##### `collect()`

Interleave all partitions from the previous stage into one partition for all subsequent computations. This can be overridden later with key_by. The effect of collect() is similar to using a key_by that returns a constant key.

This code:

```
inputs
    .key_by(ExtractKey)
    .to[ComputationOutputType](f)
    .to[ComputationOutputType](g)
    .to_sink(sink_config)
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

```
inputs
    .key_by(extract_key)
    .to[ComputationOutputType](f)
    .collect()
    .to[ComputationOutputType](g)
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

Add a sink to the end of a pipeline. This returns a complete pipeline object that is ready to be passed to `Wallaroo.build_application`.

`sink_config` must be one of the [SinkConfig](#sink) classes.

##### `to_sinks(sink_configs)`

Add multiple sinks to the end of a pipeline. This returns a complete pipeline object that is ready to be passed to `Wallaroo.build_application`.

`sink_config` must be a list of [SinkConfig](#sink) classes.

At the moment, the same pipeline output is sent via all sinks. The ability to determine what output should be sent to which sinks will be added in a future version of Wallaroo.

#### `Wallaroo.build_application(env, application_name, pipeline)`

Returns the topology structure Wallaroo requires in order to construct the topology connecting all of the application components.

`env` must be the `Env` object passed down from our `create` function in `Main`, which represents the environment our application was evoked in.

`application_name` must be a `String`.

`pipeline` must be a complete pipeline object returned from either `to_sink` or `to_sinks`.

### Computation

A stateless computation is a simple function that takes input, returns an output, and does not modify any variables outside of its scope. A stateless computation should have _no side effects_.

A `computation` function must use nominal subtyping and implement the `StatelessComputation` trait. The input and output types should be represented in the computation definition as `StatelessComputation[InputType, OutputType]`.

##### `fun apply(input: In): ComputationResult[Out]`

Create an `apply` function, which takes an object of the input type and returns an object of the output type.

##### `fun name(): String`

Create a `name` function that returns the name of the computation as a string.

###### Example

A Computation that doubles an integer:

```
primitive DoubleInt is StatelessComputation[I64, I64]
  fun apply(int: I64): I64 =>
    int * 2
```

### State

State is an object that is passed to the [StateComputation](#statecomputation) function. It can be any `ref` as long as it nominally declares itself as a `State` and can be as simple or as complex as you would like.

#### Example State

A `LetterState` keeps a count for how many times a letter in the English alphabet has been seen:

```
class LetterState is State
  var letter: String = " "
  var count: U64 = 0
```

### StateComputation

A state computation is similar to a [Computation](#computation), except that it takes an additional argument: `State`.

Similarly to a Computation, a StateComputation function must implement the `StateComputation[InputType, OutputType, State ref]` trait.


##### `fun apply(input: In, state: State): ComputationResult[Out]`

Create an `apply` function, which takes an object of the input type and an object of the `State` type and returns an object of the output type.

`ComputationResult` represents the output data of the function (and will become the next stage's input data). If `Out` is `None`, no message will be delivered to the next stage in the pipeline as a result of this iteration of the StateComputation.

##### Example

An example StateComputation that keeps track of the maximum integer value it has seen so far, and only persists the state if a new max has been set.

```
class MaxState is State
  var max: U64 = 0

  fun update(num: U64) =>
    if num > max then
      max = num

primitive UpdateMax is StateComputation[U64, U64, MaxState]
  fun apply(num: U64, state: MaxState): U64 =>
    state.update(num)
    state.max

  fun name(): String => "Max State"
```

### Aggregation

For an overview of what aggregations are and how they must be implemented, see [here](/core-concepts/aggregations).

In order to implement an aggregation, you must create a class or primtivie that satisfies the  `Aggregation[In: Any val, Out: Any val, Acc: State ref]` interface, and you must implement five functions:

`initial_accumulator(): Acc`: returns the initial accumulator that is used by the aggregation. This must act as an identity element for `combine`.

`update(input: In, acc: Acc)`: uses `input` to update the accumulator `acc`.

`combine(acc1: Acc, acc2: Acc): Acc`: returns an accumulator created by combining `acc1` and `acc2`. This operation must be associative, and it must not mutate `acc1` or `acc2`.

`output(key: Key, window_end_ts: U64, acc: Acc): (Out | None)`: produces an output based on the accumulator `acc`. The `key` is passed in from the context in case it is needed when creating the output. This operation must not mutate `acc`.

`name(): String`: returns the name of the aggregation.

##### Example

```
class val Event
  // A generic event, bearing a key and a piece of data.
  let event_data: U32
  let event_key: Key

  new val create(data: U32, key: Key) =>
    event_data = data
    event_key = key

class MySum is State
  var sum_of_event_data: U32

  new create(sum: U32) =>
    sum_of_event_data = sum

primitive MySumAgg is Aggregation[Event, Event, MySum]
  fun initial_accumulator(): MySum =>
    MySum(0)

  fun update(e: Event, my_sum: MySum) =>
    my_sum.sum_of_event_data =
      my_sum.sum_of_event_data + e.event_data

  fun combine(sum1: MySum box, sum2: MySum box): MySum =>
    MySum(sum1.sum_of_event_data + sum2.sum_of_event_data)

  fun output(key: Key, sum: MySum): (None | Event) =>
    if sum.sum_of_event_data > 0 then
      Event(sum.sum_of_event_data, key)
    end

  fun name(): String =>
```

### Input

`In` is the object that is passed to [Computations](#computation) and [StateComputations](#statecomputation). It can be any Pony type as long as it has a `val` reference capability. It can be as simple or as complex as you would like it to be.

### Key

Partition keys are `string` values.

### KeyExtractor

A key extractor function must implement the `KeyExtractor[In: Any val]` interface and return the appropriate [Key](#key) for `input` in its `apply(input: In): Key`.

#### Example Key Extractor

An example that partitions transactions based on the user associated with them:

```
primitive ExtractUser
  fun apply(t: Transaction): String =>
    t.user()
```

### Windows

For an in-depth overview of windows, see [here](/core-concepts/windows). Windows are either count-based or range-based.

#### Count-based

`Wallaroo.count_windows(count)`: defines count-based windows that trigger an output every `count` messages.

`over[ThingToCount, SumCount, RunningTotal](MySumAgg)`: specifies the aggregation used for these windows.

##### Example

This defines count windows with a count of 5 over a user-defined [aggregation](#aggregation) class `MySumAgg`:

```
inputs
  .to[SumCount](Wallaroo.count_windows(5)
    .over[ThingToCount, SumCount, RunningTotal](MySumAgg))
  .to_sink(sink_config))
```

#### Range-based

`Wallaroo.range_windows(range)`: defines range-based windows with the specified `range`.

`with_slide(slide)`: optionally specifies a slide for these windows, resulting in sliding (overlapping) windows. For example, if the slide is 3 seconds, then a new window of length `range` (specified via `Wallaroo.range_windows(range)`) will be started every 3 seconds. The default slide is equal to the range (resulting in tumbling windows).

`with_delay(delay)`: optionally specifies a delay on triggering a window. This is either (1) an estimation of the maximum lateness expected for messages or (2) the lateness threshold beyond which you no longer care about messages. The default delay is 0.

`with_late_data_policy(policy)`: optionally specifies a policy to handle late data. You can use late data policies if you want more fine-grained control over late data other than just dropping late messages. See [here](/core-concepts/windows) for more details.

`.over[ThingToCount, SumCount, RunningTotal](MySumAgg)`: specifies the aggregation used for these windows.

##### Example

This defines range-based sliding windows with a range of 6 seconds, a slide of 3 seconds, and a delay of 10 seconds:

```
inputs
   .to[SumCount](Wallaroo.range_windows(Seconds(6))
     .with_slide(Seconds(3))
     .over[ThingToCount, SumCount, RunningTotal](MySumAgg))
   .to_sink(sink_config)
```

This means windows of length 6 seconds will be started every 3 seconds. Each of these windows will be triggered 10 seconds after we have past the end of its range in event time.

### Sink

Wallaroo currently supports two types of sinks: [TCPSink](#tcpsink), [KafkaSink](#kafkasink).

#### TCPSink

A `TCPSink` is used to send output to an external system using TCP.

The `TCPSinkConfig[Out: Any val]` class is used to define the properties of the `TCPSink`, which will be created by Wallaroo as part of the pipeline initialization process.

A `TCPSinkConfig` may be passed on its own to [to_sink](#to-sink-sink-config) or as part of a list to [to_sinks](#to-sinks-sink-configs).

##### `TCPSinkConfig[OutType].from_options(encoder, TCPSinkConfigCLIParser(env.args)?(0)?))`

The class used to define the properties of a Wallaroo TCPSink.

`encoder` is a [Sink Encoder](#sink-encoder) that returns `bytes`.

`TCPSinkConfigCLIParser` parses the command line arguments and returns the host and service for the sink in the form of `TCPSinkConfigOptions`.

#### KafkaSink

A `KafkaSink` is used to send output to an external Kafka cluster.

The `KafkaSinkConfig[Out: Any val]` class is used to define the properties of the `KafkaSink`, which will be created by Wallaroo as part of the pipeline initialization process.

##### `KafkaSinkConfig[OutputType](encoder, KafkaSinkConfigCLIParser(env.out).parse_options(env.args)?, env.root as AmbientAuth)`

The class used to define the properties of a Wallaroo KafkaSink.

`encoder` is a [Sink Encoder](#sink-encoder) that returns `(bytes, key)`, where `key` may be a string or `None`.

##### `KafkaSinkConfigCLIParser`

The helper class that parsers the Kafka Sink CLI options.

Some of the available options are:

`topic` is a string.

`brokers` is a list of `(host, port)` pairs of strings.

`log_level` is one of the strings `Fine`, `Info`, `Warn`, `Error`.

`max_produce_buffer_ms` is an integer representing the `max_produce_buffer` value in milliseconds. The default value is `0`.

`max_message_size` is the maximum kafka message buffer size in bytes. The default vlaue is `100000`.

#### Sink Encoder

The Sink Encoder is responsible for taking the output of the last computation in a pipeline and converting it into the data type that is accepted by the Sink.

##### Example encoder for a TCPSink

A complete [TCPSink](#tcpsink) encoder example that takes a `LetterTotal` object and writes out the message size, in this case 9 bytes to represent the individual letter and 8 bytes for the count, followed by the letter and the count:

```
primitive LetterTotalEncoder
  fun apply(t: LetterTotal val, wb: Writer = Writer): Array[ByteSeq] val =>
    wb.u32_be(9)
    wb.write(t.letter) // Assumption: letter is 1 byte
    wb.u64_be(t.count)
    wb.done()
```

##### Example encoder for a Kafka Sink

A complete `KafkaSink` encoder example that takes a `F32` representing a Fahrenheit value and sends it out:

```
primitive FahrenheitEncoder
  fun apply(f: F32, wb: Writer): (Array[ByteSeq] val, None, None) =>
    wb.f32_be(f)
    (wb.done(), None, None)
```

### Source

Wallaroo currently supports two types of soruces: [TCPSource](#tcpsource), [KafkaSource](#kafkasource).

#### TCPSource

The TCP Source receives data from an external TCP connection and decodes it into the data type that the first computation in its pipeline expects.

The `TCPSourceConfig` class is used to define the properties of the TCP Source, which will be created by Wallaroo as part of the pipeline initialization process.

An instance of `TCPSourceConfig` is a required argument of [wallaroo.source](#wallaroo-source-name-source-config).

##### `TCPSourceConfig[InputType].from_options(frame_handler, TCPSourceConfigCLIParser(source, env.args)?)`

The class used to define the properties of a Wallaroo TCPSource.

`frame_handler` is a primitive or class that must implement the `FramedSourceHandler` interface.

`TCPSourceConfigCLIParser` is a helper which accepts a `source`, a String representing the Source name and `env.args` which is the arguments provided to the application. These arguments are then parsed to provide a `TCPSourceConfigOptions` which has the source name, host, and service port.

#### KafkaSource

A `KafkaSource` is used to get input from an external Kafka cluster.

The `KafkaSourceConfig` class is used to define the properties of the `KafkaSource`, which will be created by Wallaroo as part of the pipeline initialization process.

An instance of `KafkaSourceConfig` is a required argument of [wallaroo.source](#wallaroo-source-name-source-config).

##### `KafkaSourceConfig[InputType](source, KafkaSourceConfigCLIParser(env.out).parse_options(env.args)?, env.root as AmbientAuth, decoder)`

The class used to define the properties of a Wallaroo KafkaSink.

`source` is a string representing the Wallaroo source name.

`env.root as AmbientAuth`

##### `KafkaSourceConfigCLIParser(env.out).parse_options(env.args)?`

The helper class that parses the arguments needed for the `KafkaSource`, such as the `topic` and `brokers`.

`decoder` is a [Source Decoder](#source-decoder).

#### Source Decoder

The Source Decoder is responsible for two tasks:

1. Telling Wallaroo _how many bytes to read_ from its input source.
2. Converting those bytes into an object that the rest of the application can process. `None` can be returned to completely discard a message.

To define a source decoder, implement a `FramedSourceHandler` that has a `decode` function that takes bytes (`Array[U8]`) and returns the correct data type for the next stage in the pipeline.

It is up to the developer to determine how to translate bytes into the next stage's input data type, and what information to keep or discard.

`header_length(): USize` is the function that returns the integer number of bytes to read for the header. The default value is 4.

`payload_length(data: Array[U8] iso): USize ?` is the function that returns the value of the size of the message.


##### Example decoder for a TCPSource

A complete `TCPSource` decoder example that decodes messages with a 32-bit unsigned integer _payload_length_ and a `decode` function that returns a `String` from the data passed in:

```
primitive StringFrameHandler is FramedSourceHandler[String]
  fun header_length(): USize =>
    4

  fun payload_length(data: Array[U8] iso): USize ? =>
    Bytes.to_u32(data(0)?, data(1)?, data(2)?, data(3)?).usize()

  fun decode(data: Array[U8] val): String =>
    String.from_array(data)
```

#### Example decoder for a KafkaSource

A complete `KafkaSource` decoder example that decodes messages as a 32-bit signed int:

```
primitive CelsiusKafkaDecoder is SourceHandler[F32]
  fun decode(a: Array[U8] val): F32 ? =>
    let r = Reader
    r.append(a)
    r.f32_be()?
```
