# Wallaroo Python API

Machida allows developers to create Wallaroo application in Pony.

## Overview

Developers create applications by creating classes that represent
source decoders, sink encoders, computations, data, and state, and then connecting them together in a form that Wallaroo understands.

## Source Decoders

```python
class Decoder(object):
    def header_length(self):
        #
        return HEADER_LENGTH
    def payload_length(self, bs):
        #
        return PAYLOAD_LENGTH
    def decode(self, data):
        #
        return NEW_DATA
```

`header_length(self)` -- Return an integer that represents the number of bytes from the beginning of the incoming message to return to the fuction that reads the payload length (`payload_length`).

`payload_length(self, bs)` -- Read the bytes in `bs` (a `bytearray`) to determine the payload length, and return that value.

`decode(self, bs)` -- Read the bytes in `bs` (a `bytearray`) and create and return a message object.

## Sink Encoders

```python
class Encoder(object):
    def encode(self, data):
        #
        return BYTE_ARRAY_REPRESENTATION_OF_DATA
```

`encode(self, data)` -- Return a `bytearray` that represents the message data that was passed in `data`. `data` is whatever type is passed to the encoder.

## Stateless Computations

```python
class StatelessComputation(object):
    def name(self):
        #
        return COMPUTATION_NAME

    def compute(self, data):
        #
        return RESULT_DATA
```

`name(self)` -- Return a string that represents the name of the computation.

`compute(self, data)` -- Return the result of the computation. `data` is an object of whatever type is passed to the computation.

## Stateful Computation

```python
class StatefulComputation(object):
    def name(self):
        #
        return COMPUTATION_NAME

    def compute(self, data, state):
        #
        return RESULT_DATA
```

`name(self)` -- Return a string that represents the name of the computation.

`compute(self, data, state)` -- Return the result of the computation. `data` is of whatever type is passed to the computation, `state` is of whatever type was returned by the state builder that was specified for this computation when the application was set up. Changes to the state object are made by manipulating the object directly.

## State Builders

```python
class StateBuilder(object):
    def build(self):
        return STATE_OBJECT
```

`build(self):` -- Return an object that will hold state.

## Partition Functions

```
class PartitionFunction(object):
    def partition(self, data):
        return PARITION_KEY
```

`partition(self, data)` -- Return an object that represents the partition for `data`. If the partition is specified in the application builder as a U64 parition then this value must be an integer. Otherwise, it must be an object that correctly supports the `==` operator and the `hash` function (See Partiton Keys).

## Parition Keys

A partition key must correctly support the `==` operator and the `hash` function. Some built-in types, like strings and numbers, automatically support these operations. If you are defining your own partition key class then that class should implement the `__hash__` and `__eq__` methods.

## Message Data and State Data

The data that flows between computation and the state data are plain Python objects and can be as simple or as complicated as you would like them to be.

NOTE: We do not currently implement serialization or resilience, so there are no required methods for these objects. It is up to the developer to do whatever they want.

## Application Setup

Wallaroo calls the application setup function to get a data structure that represents the application. The developer writes this function as part of the main module for the application.

The `wallaroo` module provides an `ApplicationBuilder` class that facilitates the creation of this data structure. The application can be built by creating the object and calling its methods with the appropriate arguments, and then calling its `build()` method.

Here's an example of an `application_setup(args)` function.

```python
import wallaroo

def application_setup(args):
    ab = wallaroo.ApplicationBuilder("alphabet")

    ab.new_pipeline("alphabet", Decoder()).to_stateful(AddVotes(),
                                                       LetterStateBuilder(),
                                                       "letter state").to_sink(Encoder())

    return ab.build()
```

The `args` argument contains the command line args that were passed to the application when it was started at the command line.

### Application Builder

The `ApplicationBuilder` class has the following methods:

`__init__(self, name)` -- Create the application builder. NOTE: `name` is not currently used anywhere.

`new_pipeline(self, name, decoder, coalescing = True)` -- Add a new pipeline to the application. `name` is a string that specifies the name of the pipeline, `decoder` is an instance of the decoder class to use for the pipeline, and `coalescing` is a boolean that tells whether or not to coalesce steps.

`to(self, computation_class)` -- Add a computation to the current pipeline. `computation_class` is the class of the computation (not an instance of the class).

`to_stateful(self, computation, state_builder, state_name)` -- Add a stateful computation to the current pipeline. `computation` is the stateful computation to use, `state_builder` is a state builder, and `state_name` is a string that represents the state's name.

`to_state_partition_u64(self, computation, state_builder, state_name, partition_function, partition_keys)` -- Add a partitioned stateful computation to the current pipeline. `computation` is the stateful computation to use, `state_builder` is a state builder, `state_name` is a string that represents the state's name, partition is an instance of a partition function, and `partition_keys` is a list of integers representing the possible keys.

`to_sink(self, encoder)` -- Add a sink encoder to the current pipeline. This finishes the current pipeline. `encoder` is the encoder to use with the pipeline.

`done(self)` -- Finish the current pipeline.

`build(self)` -- Return the data structure that Wallaroo will use to create the application.
