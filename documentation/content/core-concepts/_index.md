---
title: "Wallaroo Core Concepts"
menu:
  docs:
    parent: "core-concepts"
    weight: 1
toc: true
layout: single
---
A Wallaroo application consists of a pipeline with one or more sources. A pipeline takes in data from external systems, performs a series of computations based on that data, and optionally produces outputs which are sent to an external system.

Here is a diagram illustrating a single, linear pipeline:

```
External   | Wallaroo                     Wallaroo|    External
 System ──>|  Source ─> C1 ─> C2 ─> C3 ─>   Sink  |──>  System
   A       |                                      |       B
```

An external data source sends data (say, over TCP) to an internal Wallaroo source. The Wallaroo source decodes that stream of bytes, transforming it into a stream of internal data types that are sent to a series of computations (C1, C2, and C3). Each computation takes an input and produces an output. Finally, C3 sends its output to a Wallaroo sink, which encodes that output as a series of bytes and sends it over TCP to an external system.

A Wallaroo application can have multiple sources. Each source might send data down a chain of computations. These chains can then be merged, say at a downstream state computation. For example:

```
External   | Wallaroo                    
 System ──>|  Source ─> C1 ─> C2 -\
   A       |                       \
                                    \         Wallaroo|    External
                                     -> C5 ->   Sink  |-->  System
                                    /                 |       C
External   | Wallaroo              / 
 System ──>|  Source ─> C3 ─> C4 ─/ 
   B       |                                   
```

The outputs of both C2 and C4 are sent along to C5, where they will arrive in a non-deterministic interleaving. The outputs of C5 are then sent to a sink and
ultimately sent out over TCP to an external system.

## Concepts

* *State* -- Accumulated result of data stored over the course of time
* *Stateless Computation* -- Code that transforms an input of some type `In` to
an output of some type `Out` (or optionally `None` if the input should be
filtered out).
* *State Computation* -- Code that takes an input type `In` and a state
object of some type `State`, operates on that input and state (possibly
making state updates), and optionally producing an output of some type `Out`.
* *Source* -- Ingress (input) point for data from external systems into a Wallaroo application.
* *Sink* -- Egress (output) point from a Wallaroo application to external systems.
* *Decoder* -- Code that transforms a stream of bytes from an external system
into a series of application input types.
* *Encoder* -- Code that transforms an application output type into bytes for
sending to an external system.
* *Pipeline* -- A sequence of computations and/or state computations originating from one or more sources and terminating in a sink.
* *Stage* -- A source, stateless computation, state computation, and sink each represents a single logical stage in a Wallaroo pipeline. The linear pipeline above--starting from a source, going through computations C1, C2, and C3, and terminating at a sink--has 5 logical stages (1 source, 3 computations, and 1 sink). 
* *Topology* -- A graph of how all sources, sinks, and computations are
connected within an application.
* *API* -- Wallaroo provides APIs for implementing all of the above concepts.
