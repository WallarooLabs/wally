# Pony Connector Sink

This is a Pony implementation of a sink that uses the Wallaroo Connector Protocol. It is based on the [Python At Least Once Sink](https://github.com/WallarooLabs/wallaroo/blob/master/testing/correctness/tests/aloc_sink).

## Current Limitations

This implementation is incomplete.

* Testing has been limited, there may be errors.
* Error handling is very limited. There are places where it should probably exit.
* Reporting is done through the `Debug` package.
* It does not implement persistence, so it cannot be restarted.

## Overall Design

The sink listens for HTTP connections from Wallaroo workers and communciates with them using the Connector protocol. Each connection maintains a state machine that ensures proper Connector message handling and provides a mechanism for sharing information with other actors.

The Connector protocol is based on a two-phase commit protocol.

* There is an initial handshake where a connecting Wallaroo worker sends information about itself to the sink. If the sink is not currently processing information from another worker with the same name then it can begin accepting application messages.
* The sink receives application messages and processes them.
* The worker can send a phase 1 message indicating that it is ready to start the two-phase commit. If the information that the worker sends matches the information that the sink sees, then the sink will reply with a "success" message, otherwise it will reply with a "rollback" message.
* If the sink sent a "success" message then the worker can reply with either a "commit" message or a "rollback" message. If the message is a "commit" message then all of the messages received before the phase 1 message are committed, otherwise they are rolled back.

If a Wallaroo worker dies and restarts then the worker can reconnect and the sink will continue processing it's messages. This requires that the sink maintain a list of connected workers and data associated with those workers that can be passed to a new state machine when the worker reconnects.

### Global Data

#### Active Workers

A set of workers that are currently connected to the sink. This allows the sink to make sure that it is only processing one connection for a given worker. If a second connection from a worker with the same name is attempted, it will fail.

#### Streams

Stream data for each worker that connects to a sink is stored. This allows a worker to reconnect to a sink and have the sink continue to process messages from that worker using the data it received up until the point where it was disconnected.

### Local State (per state machine)

State that is local to a state machine is stored in a `StateContext` object. The major points of interest are the local information about the streams for the worker associated with this state machine, the transaction state, and the two-phase commit output.

#### Streams

This maps a stream ID to a stream name and the point of reference for the stream. If the worker has connected to the sink before then the state machine receives the information about this worker when the worker reconnects, otherwise this map starts out empty.

#### Transaction State

This stores the transaction state associated a phase 1 messages.

#### Two-Phase Commit Output

This stores information about information that is committed during the two-phase commit process.

NOTE: This is currently only stored to memory, in a working system it would be committed to disk.

### States

States handle different kinds of messages, either in the form of Connector protocol messages, or internal sink messages. These descriptions list the primary responsiblities for each state. In addition to the messages listed, the `AwaitMessageOr2PCPhaseX` states also handle Error, Notify, EOS, Worker Left, and ListUncommitted messages.

#### `InitialState`

This state waits for a `Hello` message from the Wallaroo worker. When the message is received it is checked to make sure that the worker is using the correct protocol version and cookie. If so, it tries to see if the worker name is already active by sending a message to the actor that stores the information about active and previously connected workers, and moves into the `AwaitApproveOrDenyWorker` state.

#### `AwaitApproveOrDenyWorker`

This state waits for a message from the actor that tracks active workers about whether or not the connecting worker is already active. While the state machine is in this state, all other incoming messages are queued. If it is active then it receives a message denying the new connection, otherwise it receives a message approving the new worker, along with the streams data for that worker if it is reconnecting. If the worker is approved then the state machine goes into the `AwaitMessageOr2PCPhase1State` and synchronously processes all of the queued messages.

#### `AwaitMessageOr2PCPhase1State`

This state waits for application messages or a phase 1 message.

#### `AwaitMessageOr2PCPhase2State`

This state waits for application messages or a phase 2 message.

### Considerations When Building Another Connector-Based Source or Sink

When I was talking to Scott he said that the most difficult part of writing the Python ALOC Sink was getting all the edge cases right. I spent a lot of time trying to reverse engineer what he had done with respect to keeping track of points of reference and I'm still not sure I got it right. I'd like to believe what I did in Pony might be a little more readable because I'm using a typed language and so there's a bit more clarity about what is going into different data structures, but I'm also not completely confident that I got everything right so the Python ALOC Sink should still probably be considered the source of truth with respect to the logic of the system. If we plan to continue to use the Connector protocol we should look at how to hide some of this complexity from the user.

The Pony library for connectors provides encoding and decoding support for the protocol messges, but we should probably also provide some classes that represent the transaction log data, along with encoders and decoders. As with all the point-of-reference related code, there's probably a way that we can provide one implementation that will work for most use-cases, rather than being forced to rewrite them from scratch every time we build a new source or sink.

I spent a lot more time than I wanted to trying to figure out how to translate between `Array[U8]`s, `String`s, `ByteSeq`s, and `ByteSeqIter`s. I understand why this flexibility exists in Pony but from an application programmer standpoint (or at least from my standpoint) it's a lot of overhead to work with. I think we should creating APIs that, for example, only accept at return an `Array[U8]`.

Providing a reusable state machine implementation for the protocol would be extremely useful if we need to create lots of Connector sources and sinks in the future. Otherwise the programmer will be forced to do it over and over again, and there really shouldn't be too many variations on how it is done.

In general, if we plan to continue to use the Connector protocol internally or let other parties develop their own Connector sources and sinks, we need to figure out how to abstract away as much of this complexity as possible. I believe there are enough common pieces we could incrementally get pieces in place that would greatly reduce developement time.
