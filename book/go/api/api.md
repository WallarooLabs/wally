# Wallaroo Go API Classes

The Wallaro Go API allows developers to create Wallaroo applications in Go.

## Overview

In order to create a Wallaroo application in Go, developers need to create classes that provide the required interfaces for each step in their pipline, and then connect them together in a topology structure that is returned by the entry-point function `ApplicationSetup`.

### Application Setup

After a Wallaroo Go application starts up, it calls the C function `ApplicationSetup`. The Go application should export a function with this name.

The `ApplicationSetup` method must create an instance of the `wallarooapi.application.Application` and use it to build the application pipelines.

For a simple application with a `Decoder`, `Compute`, and `Encoder`, this function may look like

```go
//export ApplicationSetup
func ApplicationSetup() *C.char {
        wa.Serialize = Serialize
        wa.Deserialize = Deserialize

        application := app.MakeApplication("Word Count Application")
        application.NewPipeline("pipeline 1", app.MakeTCPSourceConfig("127.0.0.1", "7002", &Decoder{})).
                To(&Compute{}).
                ToSink(app.MakeTCPSinkConfig("127.0.0.1", "7010", &Encoder{}))

        json := application.ToJson()

        return C.CString(json)
}

```

#### `wallarooapi.Args`

The Wallaroo framework uses a number of command line arguments. The variable `wallarooapi.Args` contains the arguments that were passed to the application that were not used by the Wallaroo framework. It is a `[]string` which can be used by parsers like `flags` to get application-specific command line arguments.

### `wallarooapi.application.application`

The `application` class in `wallarooapi.application` is used to create an application.

#### `application` Methods

##### constructor `MakeApplication(name string) *application`

Create a new application with the name `name`.

##### `NewPipeline(name string, source_config SourceConfig) *pipelineBuilder`

Create a new pipeline with the name `name` and a source config object.

##### `ToJson()`

Return a JSON representation of the application, which is used by the Wallaroo framework to finish building the application.

### wallarooapi.application.pipelineBuilder

Calling the `application.NewPipeline` method returns a `pipelineBuilder`, which is used to add steps to a pipeline. A pipeline is completed when either the `ToSink` or `Done` method is called.

##### `To(computationBuilder wallarooapi.ComputationBuilder) *pipelineBuilder`

Add a stateless computation that only returns one message to the current pipeline. The `computationBuilder` will create instances of the computation.

##### `ToMulti(computationBuilder wallarooapi.ComputationMultiBuilder) *pipelineBuilder`

Similar to `To`, but the computation can return more than one message.

##### `ToStatePartitionWithKeys(stateComputation wallarooapi.StateComputation, stateBuilder wallarooapi.StateBuilder, stateName string, partitionFunction wa.PartitionFunction, partitions []byte) *pipelineBuilder`

Add a partitioned state computation that only returns one message to the pipeline.

`stateBuilder` builds the state.

`stateName` is a name that the application uses for this state object; any other state computations in the application that use the same `stateName` will use the same object.

`partitionFunction` defines the key to use when partitioning.

`partitions` is a list of all of the partitions for the partitioned state.

##### `ToStatePartitionMultiWithKeys(stateComputation wallarooapi.StateComputationMulti, stateBuilder wallarooapi.StateBuilder, stateName string, partitionFunction wa.PartitionFunction, partitions []byte) *pipelineBuilder`

Similar to `ToStatePartition`, but the state computation can return more than one message.

##### `ToSink(sinkConfig SinkConfig)`

Add a sink to the end of a pipeline.

##### `Done()`

Closes the current pipeline without adding a sink.

### wallarooapi.Computation

A stateless computation is a function that takes an input message, returns an output message. It must provide `Compute` and `Name` methods.

#### `wallarooapi.Computation` Methods

##### `Name() string`

Return the name of the computation as a `string`.

##### `Compute(data interface{}) interface{}`

Use `data` to perform a computation and return a new output. `data` is the object the previous step in the pipeline returned.

#### Example

A computation that doubles an integer:

```python
type Double struct {}

func (d *Double) Name() string {
	return "double"
}

func (d *Double) Compute(data interface{}) interface{} {
	number := data.(*int)
    result = number * 2
	return &result
```

### wallarooapi.ComputationMulti

A stateless computation is a function that takes an input message, returns an output message. It must provide `Compute` and `Name` methods.

#### `wallarooapi.ComputationMulti` Methods

Use `data` to perform a computation and return a new output. `data` is the object the previous step in the pipeline returned.

##### `Name() string`

Return the name of the computation as a `string`.

##### `Compute(data interface{}) []interface{}`

Use `data` to perform a computation and return a new output. `data` is the object the previous step in the pipeline returned. Each item in the returned slice is sent to the next step in the computation as an individual message.

#### Example

A computation that doubles an integer and returns the original integer and the doubled value:

```python
type Double struct {}

func (d *Double) Name() string {
	return "double"
}

func (d *Double) Compute(data interface{}) []interface{} {
	number := data.(*int)
    result := make([]interface, 2)
    doubled := number * 2
    result[0] = &number
    result[1] = &doubled
	return result
```

### Data

Data is the object that is passed to a computation's `Compute` method. It is a plain Go object and can be as simple or as complex as you would like it to be.

It is important to ensure that data returned is always immutable or unique to avoid any unexpected behavior due to the asynchronous execution nature of Wallaroo.

### Key

Partition keys are `[]byte` values.

### wallarooapi.PartitionFunction

A `PartitionFunction` is used to determine which partition should receive a message. The function is applied to the message and the key is returned.

### `wallarooapi.PartitionFunction` Methods

##### `Partition(data interface{}) []byte`

Return the appropriate [Key](#key) for `data`.

#### Example `PartitionFunction`

An example that partitions words for a word-count based on their first character and buckets all other cases to the empty string key:

```go
type WordPartitionFunction struct{}

func (wpf *WordPartitionFunction) Partition(data interface{}) []byte {
	word := data.(*string)
	firstLetter := (*word)[0]
	if (firstLetter >= 'a') && (firstLetter <= 'z') {
		return []byte{firstLetter}
	}
	return []byte{byte('!')}
}```

### wallarooapi.Encoder

The `Encoder` is responsible for taking the output of the last computatoin in a pipeline and converting it into a `[]byte` for Wallaroo to send out over a TCP connection.

To do this, an `Encoder` must provide the `Encode(d interface{}) []byte` method.

#### `wallarooapi.Encoder` methods

##### `Encode(data interface{}) []byte`

Return a `[]byte` that can be sent over the network. It is up to the developer to determine how to translate `data` into a `[]byte`, and what information to keep or discard.

#### Example `Encoder`

An `Encoder` example that takes a slice of `int32`s and encodes it to a sequence of big-endian 32-bit integers, starting with a 32-bit integer that represents the length.

```go
type ListEncoder struct {}

func (le *ListEncoder) Encode(data interface{}) []byte {
	slice := data.([]uint32)
	buff := make([]byte, 4)
	binary.BigEndian.PutUint32(buff, uint32(len(slice)))

	for _, i := range slice {
		numBuff := make([]byte, 4)
		binary.BigEndian.PutUint32(numBuff, i)
		buff = append(buff, numBuff...)
	}

	return buff
}
```

### wallarooapi.FramedDecoder

The `FramedDecoder` is responsible for two tasks:
1. Telling Wallaroo _how many bytes to read_ from its input connection.
2. Converting those bytes into an object that the rest of the application can process.

#### `wallarooapi.FramedDecoder` Methods:

##### `HeaderLength() uint64`

Return a `uint64` representing the number of byts from the beginning of an incoming message to return to the function that reads the payload length.

##### `PayloadLength(b []byte) uint64`

Return a `uint64` representing the number of bytes after the payload length bytes to return to the function that decodes the payload.

`b` is a `[]byte` of the length returned by `HeaderLength()`, and it is up to the user to provide a method for converting that into an integer value.

A common encoding used in Wallaroo is a big-endian 32-bit unsinged integer, which can be decoded with Go's `binary.BigEndian.Uint32` function.

##### `Decode(b []byte) interface{}`

Return a Go object of the type the next step in the pipeline expects.

`b` is a `[]byte` of the length returned by `PayloadLength`, and it is up to the developer to turn that into a Go object.

#### Example `FramedDecoder`

A complete `FramedDecoder` example that decodes messages with a 32-bit unsigned integer _payload_length_ and a character followed by a 32-bit unsigned int in its _payload_:

```go
type payload struct {
	Letter string
	Votes uint32
}

type Decoder struct {}

func (d *Decoder) HeaderLength() uint64 {
	return 4
}

func (d *Decoder) PayloadLength(b []byte) uint64 {
	return uint64(binary.BigEndian.Uint32(b))
}

func (d *Decoder) Decode(b []byte) interface{} {
	return &payload{string(b[0]), binary.BigEndian.Uint32(b[1:])}
}
```

### wallarooapi.KafkaEncoder

The `KafkaEncoder` is responsible for taking the output of the last computation in a pipeline and converting it into a `[]byte` for Wallaroo to send out to a Kafka sink, along with a `[]byte` that represents the Kafka partition key or `nil` for no key.

#### `wallarooapi.KafkaEncoder` methods

##### `Encode(data interface{}) ([]byte, []byte)`

Return two values: the data in the outgoing Kafka message payload, and the Kafka partition key or `nil` if there is no key. It is up to the developer to determine how to translate `data` into the output values.

#### Example `KafkaEncoder`

A `KafkaEncoder` example that takes a word and sends it to the partition corresponding to the first letter fo the word:

```go
func encode(data interface{}) ([]byte, []byte) {
	word := data.(*string)
	key := []byte((*word)[0:1])
	return []byte(*word), key
}
```

### wallarooapi.Decoder

The `Decoder` is responsible for converting bytes into an object that the next step of the application can process.

If you are using a Kafka source then it will need a `Decoder`.

#### `wallarooapi.Decoder` Methods

##### `Decode(b []byte) interface{}`

Return an object of the type the next step in the pipeline expects.

#### Example `Decoder`

A complete `Decoder` example that decodes messages with a 32-bit unsigned integer as its _payload_:

```go
type payload struct {
	Letter string
	Votes uint32
}

type Decoder struct {}

func (d *Decoder) Decode(b []byte) interface{} {
	return &payload{string(b[0]), binary.BigEndian.Uint32(b[1:])}
}
```

### State

State is an object that is passed to the StateCompution's `Compute` method. It is a plain Go object and can be as simple or as complex as you would like it to be.

A common issue that arises with asynchronous execution is that when references to mutable objects are passed to the next step, if another update to the state precedes the execution of the next step, it will then execute with the latest state (that is, it will execute with the "wrong" state). Therefore, anything returned by a StateComputation that is based on data from the state object should use a copy of that data rather than a reference to something in the state object itself.

It is up to the developer to provide a side-effect safe value for the StateComputation to return!

### Example State

The `RunningVoteTotal` keeps a count of how many times each letter in the alphabet has been seen:

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

### wallarooapi.StateBuilder

A `StateBuilder` is used by Wallaroo to create an initial state object for a `StateComputation` or `StateComputationMulti`.

#### `wallarooapi.StateBuilder` Methods

##### `Build() interface{}`

Return a new state instance.

#### Example `StateBuilder`

Return a `RunningVoteTotal` object with the values initialized to defaults.

```go
type RunningVotesTotalBuilder struct {}

func (rvtb *RunningVotesTotalBuilder) Build() interface{} {
	return &RunningVoteTotal{}
}
```

### wallarooapi.StateComputation

A `StateComputation` is similar to a `Computation`, except that its `Compute` method takes an additional argument: `state`.

In order to provide resilience, Wallaroo needs to keep track of state changes, or side effects, and it does so by making `state` an explicit object that is given as input to any StateComputation step.

Like Computation, a StateComputation class must provide the `Name` and `Compute` methods.

#### `wallarooapi.StateComputation` Methods

##### `Name() string`

Return the name of the computation as a string.

##### `	Compute(data interface{}, state interface{}) (interface {}, bool)`

`data` is anything that was returned by the previous step in the pipeline, and `state` is provided by the `StateBuilder` that was defined for this step in the pipeline definition.

The first return value is a message that we will send on to our next step. It should be a new object. Returning `nil` will stop processing that message and no messages will be sent to the next step. The second return value instructs Wallaroo to save our updated state so that in the event of a crash, we can recover to this point. Return `true` if you wish to save the state, otherwise return `false`.

Why wouldn't we always return `true`? There are two answers:

1. Your state computation might not have updated the state, in which case saving its state for recovery is wasteful.
2. You might only want to save after some changes. Saving your state can be expensive for large objects. There's a tradeoff that can be made between performance and safety.

#### Example `StateComputation`

An example `StateComputation` that keeps track of the number of votes that have been seen:

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

### wallarooapi.StateComputationMulti

A `StateComputationMulti` is similar to a `StateComputation`, except that its `Compute` method returns a `[]interface{}`, where each object in the slice is sent out as a different message to the next step in the pipeline.

#### `wallarooapi.StateComputationMulti` Methods

##### `Name() string`

Return the name of the state computation as a string.

##### `	Compute(data interface{}, state interface{}) ([]interface {}, bool)`

`data` is anything that was returned by the previous step in the pipeline, and `state` is provided by the `StateBuilder` that was defined for this step in the pipeline definition.

The first return value is a slice of object that we will send on to our next step, where each object is a different message. Returning `nil` will stop processing that message and no messages will be sent to the next step. The second return value instructs Wallaroo to save our updated state so that in the event of a crash, we can recover to this point. Return `true` if you wish to save the state, otherwise return `false`.

### wallaroo.application.TCPSourceConfig

A `TCPSourceConfig` object specifies the host, port, and encoder to use for a TCP source connection when creating an application. The host and port are both represented by strings. This object is provided as an argument to `NewPipeline`.

#### `wallaroo.application.TCPSourceConfig` Constructor

`MakeTCPSourceConfig(host string, port string, decoder wa.Decoder)` makes a `TCPSourceConfig` object.

`host` is a hostname.

`port` is a port.

`decoder` is a `Decoder` to use with this source.

#### Example

This connects to `127.0.0.1` on port `7010` using `Decoder`:

```go
application.NewPipeline("Alphabet", app.MakeTCPSourceConfig("127.0.0.1", "7010", &Decoder{})).
```

### wallaroo.application.TCPSinkConfig

A `TCPSinkConfig` object specifies the host, port, and decoder to use for the TCP sink connection when creating an application. The host and port are both represented by strings. This object is provided as an argument to `ToSink`.

#### `wallaroo.application.TCPSinkConfig` constructor

`MakeTCPSinkConfig(host string, port string, encoder wa.Encoder)` makes a `TCPSinkConfig` object.

`host` is a hostname.

`port` is a port.

`encoder` is an `Encoder` to use with this source.

#### Example

This creates a `TCPSinkConfig` that connects to `127.0.0.1` on port `7002` using `Encoder`:

```go
ToSink(app.MakeTCPSinkConfig("127.0.0.1", "7002", &Encoder{}))
```

### wallaroo.application.KafkaSourceConfig

A `KafkaSourceConfig` object specifies the parameters to use for the Kafka source connection when creating an application. This object is provided as an argument to `NewPipeline`.

#### `wallaroo.application.KafkaSourceConfig` Constructor

`MakeKafkaSourceConfig(topic string, brokers []*KafkaHostPort, logLevel string, decoder wa.Decoder)` creates a `KafkaSourceConfig`.

`topic` is the topic string.

`brokers` is a slice of `KafkaHostPort` objects that specify the hosts and ports to use to connect to the brokers.

`logLevel` is a string with a value of `Fine`, `Info`, `Warn`, or `Error`.

`decoder` is the decoder to use with this source.

#### Example

```
brokers := []*app.KafkaHostPort{app.MakeKafkaHostPort("127.0.0.1", 9092)}
// ...
application.NewPipeline("split and reverse", app.MakeKafkaSourceConfig("words", brokers, "Warn", &Decoder{})).
```

### wallaroo.application.KafkaSinkConfig

A `KafkaSinkConfig` object specifies the parameters to use for the Kafka sink connection when creating an application. This object is provided as an argument to `ToSink`.

#### `wallaroo.application.KafkaSinkConfig` Constructor

`MakeKafkaSinkConfig(topic string, brokers []*KafkaHostPort, logLevel string, maxProduceBufferMs uint64, maxMessageSize uint64, encoder wa.KafkaEncoder)` creates a `KafkaSinkConfig`.

`topic` is the topic string.

`brokers` is a slice of `KafkaHostPort` objects that specify the hosts and ports to use to connect to the brokers.

`logLevel` is a string with a value of `Fine`, `Info`, `Warn`, or `Error`.

`maxProduceBufferMs` is the delay in milliseconds to wait for messages in the producer queue to accumulate before constructing message batches to transmit to brokers.

`maxMessageSize` is the maximum message size.

`encoder` is the encoder to use with this source.

#### Example

```
brokers := []*app.KafkaHostPort{app.MakeKafkaHostPort("127.0.0.1", 9092)}
// ...
ToSink(app.MakeKafkaSinkConfig("words-out", brokers, "Warn", 1000, 1000, &Encoder{}))
```
