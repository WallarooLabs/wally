---
title: "Wallaroo Core Concepts"
menu:
  docs:
    parent: "core-concepts"
    weight: 1
toc: true
---
A Wallaroo application consists of one or more pipelines. A pipeline takes in data from an external system, performs a series of computations based on that data, and optionally produces outputs which are sent to an external system.

Here is a diagram illustrating a single, linear pipeline:

```
External   | Wallaroo                     Wallaroo|    External
 System ──>|  Source ─> C1 ─> C2 ─> C3 ─>   Sink  |──>  System
   A       |                                      |       B
```

An external data source sends data (say, over TCP) to an internal Wallaroo source. The Wallaroo source decodes that stream of bytes, transforming it into a stream of internal data types that are sent to a series of computations (C1, C2, and C3). Each computation takes an input and produces an output. Finally, C3 sends its output to a Wallaroo sink, which encodes that output as a series of bytes and sends it over TCP to an external system.

A Wallaroo application can have multiple interacting pipelines. For example, an app could have one pipeline that takes data and updates state based on that data, and a second pipeline that takes data, does computations against the current state in the system, and produces output based on the state and data. The first of these has no sink, whereas the second does.

## Concepts

* *State* -- Accumulated result of data stored over the course of time
* *Computation* -- Code that transforms an input of some type `In` to
an output of some type `Out` (or optionally `None` if the input should be
filtered out).
* *State Computation* -- Code that takes an input type `In` and a state
object of some type `State`, operates on that input and state (possibly
making state updates), and optionally producing an output of some type `Out`.
* *Source* -- Input point for data from external systems into an application.
* *Sink* -- Output point from an application to external systems.
* *Decoder* -- Code that transforms a stream of bytes from an external system
into a series of application input types.
* *Encoder* -- Code that transforms an application output type into bytes for
sending to an external system.
* *Pipeline* -- A sequence of computations and/or state computations originating
from a source and optionally terminating in a sink.
* *Application* -- A collection of pipelines.
* *Topology* -- A graph of how all sources, sinks, and computations are
connected within an application.
* *API* -- Wallaroo provides APIs for implementing all of the above concepts.
