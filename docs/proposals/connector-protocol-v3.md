# Wallaroo Connector Protocol: async, credit based flow

**STATUS: version 3**

This protocol provides a method for source connectors to transmit streams of messages to Wallaroo over a reliable transport like TCP/IP. The protocol does not require that any specific mechanism or party initiate the connection, though the current Wallaroo implementation assumes that the external connector source initiates the TCP connection and that Wallaroo initiates the TCP connection to an external connector sink.

This protocol has been extended for use with connector sinks.  A separate section of this document describes the differences for use as a sink protocol.

Terms like connector, worker, and so on are assumed to be familiar to the reader. They may be refined where useful but familiarity with Wallaroo's application model should be enough. If not, it's recommended that the reader reviews the Wallaroo documentation first.


## Overview

The scope of the protocol is transmission of one or more streams. Once a connection has established a session by completing the handshake, streams are multiplexed over this connection. Each stream has a transmission order <sup>A0</sup> which is freely interleaved with other parts of the transmission. The following is an overview of the connection life cycle. Detailed parts will be explored in more detail below.

Each connection made between a connector and a Wallaroo worker is treated as a full-duplex and usually asynchronous communication channel. Most protocol messages is sent independently in one direction does not await for a response; synchronous exceptions such as the HELLO handshake and EOS_MESSAGE (End Of Stream) processing will be explicitly described. We'll use 'frame' to refer to protocol messages to avoid confusion with application messages.

Connections start with a handshake that establishes a session. The session encompasses a relatively lightweight amount of state. The connector sends a number of fields in order to establish a session including a version GUID <sup>A1</sup>, a secret cookie <sup>A2</sup>, the connector program name, and the connector instance name. The latter is what allows the connector to be appropriately routed to your application pipelines.

The worker that receives the handshake will respond with an OK or ERROR frame. The ERROR frame will end the connection, and the connector will need to reopen a socket to attempt a new connection. On success, the OK frame will include a credit count to allow stream flow to start.

With a credit count established for this session, we may start sending frames. Before we send application messages, each stream is named with a notification frame type.  Notification frames establish a mapping between the stream's fully qualified name and the id which frames will use when transmitting MESSAGE frames <sup>A6</sup>. Stream notification frames consume one credit.

Once a stream notification as been sent, the open stream can have any number of application messages for that stream sent so long as the credit count remains above zero. In order to replenish credits, Wallaroo is expected to send ACK frames to the connector. This will include the number of credits to be added to the session's current count. This allows the connector to do bookkeeping and make progress as long as Wallaroo is keeping up.

The protocol has been given plenty of room to grow and may be optimized over time. Most of the machinery is designed to allow trivial implementations which can be replaced with more sophisticated algorithms later. An example is credit flow can be adjusted in order to achieve target buffer sizes while avoiding pipeline stalls by using a PID controller rather than a fixed pipeline depth upon session initialization.

Authentication of endpoints and/or encryption of the TCP session via TLS is not supported in the current implementation.  We do not expect changes to this connector protocol when adding TLS endpoint authentication and/or session encryption.

The term point of reference is use in an attempt to avoid too much baggage with any given medium. These could be things like partition offsets in Kafka, file names, counters, dotted logical clocks, timestamps, etc.

---

<sup>A0</sup> Transmission order relates to the order of the frames as they are transported by TCP. This order is not necessarily sorted by event time.

<sup>A1</sup> Exact matching will be enforced. Incremented version numbers are avoided here as we are currently expecting source-level consistency between both parties. This means the connector runtime should be upgraded along with the worker runtime. This restriction may be lifted later and lead to stable versions of the protocol supported across releases.

<sup>A2</sup> Secret is applied loosely here. This is not meant to be the only security measure. Still, it can be an effective mitigation during incidental exposure of a network to hosts that shouldn't have direct access to a working cluster. It also protects against accidental cross-cluster configuration mistakes, which may be common when running many ephemeral clusters.

<sup>A6</sup> The layer of indirection allows for a much more efficient MESSAGE frame but also serves as a way to set the state of a stream as "in use".


## Wire Format

Each frame transmitted by either side uses a 32bit big endian/network byte order length denoting all bytes that come after the 4 bytes comprising the length <sup>B1</sup>. This makes it much easier to consistently split up data which might be captured and recorded for analysis after the fact and could speed the development of other tools which can do primitive routing and management of frames without requiring a full description of the format of each frame type.

This framing mechanism applies to all frames including the handshake. The worker reading the HELLO frame should be careful to check the version and cookie value placed in fixed locations at the start before continuing the decoding. This allows the protocol to sidestep any unintended behaviors if the framing changes in the future.

After the length, each frame is tagged with a frame type. This is a single byte since the protocol is simple. Any further data in the frame depends on the type. In some cases, the final field may have variable length data and will implicitly use the remaining length in the frame.

When possible, fixed sized fields are used to encode data.

### Primitive Type Definitions

This document uses Erlang code to describe the frame format and content. You don't need to be fluent in Erlang to read most of this but it may help to review the [bitstring syntax](http://erlang.org/doc/programming_examples/bit_syntax.html).

#### Constants

```erlang
%% Frame type bytes

-define(HELLO, 0).
-define(OK, 1).
-define(ERROR, 2).

-define(NOTIFY, 3).
-define(NOTIFY_ACK, 4).
-define(MESSAGE, 5).
-define(ACK, 6).
-define(RESTART, 7).
-define(EOS_MESSAGE, 8).
```

#### Framing

Type specs:

```erlang
-type frame() :: iolist().
-type point_of_reference() ::
    non_neg_integer().
```

Constructors follow.  Note that all integers larger than 8 bits are encoded in little endian byte order.

```erlang
-spec frame(iodata()) -> iolist().
frame(Message) ->
    [u32(iolist_size(Message)), Message].

-spec short_bytes(iodata() | undefined) -> iolist().
short_bytes(undefined) ->
    [<<0:16/big-unsigned>>];
short_bytes(Data) ->
    Size = iolist_size(Data),
    [<<Size:16/big-unsigned, Data].

-spec u16(non_neg_integer()) -> binary().
u16(N) ->
    <<N:16/big-unsigned>>.

-spec u32(non_neg_integer()) -> binary().
u32(N) ->
    <<N:32/big-unsigned>>.

-spec i64(non_neg_integer()) -> binary().
i64(N) ->
    <<N:64/big-signed>>.

-spec u64(non_neg_integer()) -> binary().
u64(N) ->
    <<N:64/big-unsigned>>.

-define(U64_MAX, 1 bsl 64 - 1).
-spec point_of_reference(point_of_reference()) -> iodata().
point_of_reference(PointOfRef)
    when is_integer(PointOfRef)
    andalso PointOfRef >= 0
    andalso PointOfRef <= U64_MAX ->
        <<PointofRef:64/big-unsigned>>;
point_of_reference(_) ->
    error({unsupported, "64bit reference expected"}).

```

Aside: The iolist type in Erlang is a sequencing mechanism. The literal byte representation of each part is used in these cases and the resulting octet stream runs from the first to the last element of the list (recursively). Some of these constructors have multiple clauses. These are pattern matches on the parameters and will execute the fist match from top to bottom. Lower case words like `undefined` are atoms in Erlang and can be thought of like primitives in Pony.

`short_bytes` described the encoding of short strings or small opaque binary data using a 16bit byte-length prefix. `u32` is an unsigned integer with 32 bits of range. Fields are specified as unsigned when possible. Languages which don't have primitive unsigned integers will need to take care when decoding this protocol but shouldn't have much difficulty encoding if two's complement is handled properly in the encoder.

---

<sup>B1</sup> The length needs to have a max size set in Wallaroo. Wallaroo would have issues if someone thought it'd be clever to send 4GiB frames. To avoid this, it may be worth using a more conservative size of a few megabytes with a configuration option to change this limit.


## Handshake

Frame definitions (`?HELLO` is replaced by the constant defined previously):

```erlang
-spec hello(non_neg_integer(), iodata(), string(), string()) -> frame().
hello(Revision, Cookie, ProgramName, InstanceName) ->
    frame([
        ?HELLO,
        version(Revision),
        short_bytes(Cookie),
        short_bytes(ProgramName),
        short_bytes(InstanceName)
    ]).

-spec ok(positive_integer()) -> frame().
ok(InitialCredits, PointsOfReference) ->
    frame([
        ?OK,
        u32(InitialCredits)
    ]).

-spec error(string()) -> frame().
error(Reason) ->
    frame([
        ?ERROR,
        short_bytes(Reason)
    ]).
```

Aside: Erlang requires capitalized variable names. `%` introduces a comment till the end of that line.

This section assumes transport discovery and configuration has been handled elsewhere.  See also: the RESTART frame.

Upon connection, the connector must send a HELLO frame which establishes the protocol version and includes some descriptive metadata about the script as well as a preconfigured nonce called a cookie. These fields allows the Wallaroo worker to determine if it belongs with to the application or cluster and if so, how to route application messages.

The cookie is optional and can have it's length set to zero if you haven't configured one somewhere <sup>C0</sup>. This will be default for easy development but it'll be encouraged to be used in a deployed cluster to prevent accidental and unwanted connections from being made, especially in the case where more than one cluster may be run. It is not a strong security mechanism by itself but designing by the rule of defense in depth, this becomes a reasonable mitigation.

In response to the HELLO frame, the worker should send either an OK frame or an ERROR frame. ERRORs will include a short reason meant for the programmer or operator. OK frames will include the initial credit count.

NOTE: An example of this initialization data would be resuming from Kafka using a consumer group. In order to ensure all data is processed, the partition progress should be set to Wallaroo's if it is lower than the current offset on any given partition. Optionally, the connector could also jump forward to what Wallaroo has if Kafka offset commits are infrequent or suffer reliability problems of their own.

The connector is responsible for evaluating initial streaming states and resuming from the appropriate place once the OK is received. If it is unable to continue, it should send an ERROR frame so the problem may be logged within Wallaroo.

If no error has occurred and the connection remains open, the protocol moves from the Handshake state to the Streaming state (see state diagram below).

---

<sup>C0</sup> Both sides are required to set this to an empty value. If the worker does not expect a cookie but the connector gives one, this might signal a configuration error and it'd be better to fail loudly rather than continue silently.


## Streaming

Frame definitions:

```erlang
-spec notify(non_neg_integer(), string(), point_of_reference()) -> frame().
notify(StreamId, StreamName, undefined) ->
    frame([
        ?NOTIFY,
        u64(StreamId),
        short_bytes(StreamName),
        point_of_reference(0)
    ]);
notify(StreamId, StreamName, PointOfRef) ->
    frame([
        ?NOTIFY,
        u64(StreamId),
        short_bytes(StreamName),
        point_of_reference(PointOfRef)
    ]).

-spec notify_ack(non_neg_integer(), bool(), point_of_reference()) -> frame().
notify_ack(StreamId, NotifySuccess, PointOfRef) ->
    frame([
        ?NOTIFY_ACK,
        if NotifySuccess -> <<1>>;
           true          -> <<0>>
        end,
        u64(StreamId),
        u64(PointOfRef)
    ]).

-spec message(Flags, StreamId, MessageId, EventTime, Key, Message) -> frame()
  when
    Flags :: non_neg_integer(),      % See message bit flag definitions above
    StreamId :: non_neg_integer(),
    MessageId :: non_neg_integer(),
    EventTime :: non_neg_integer(),
    Key :: string(),
    Message :: iodata().
message(Flags, StreamId, MessageId, EventTime, Key, Message) ->
    frame([
        ?MESSAGE,
        u64(StreamId),
        u64(MessageId),
        i64(EventTime),
        short_bytes(Key),
        Message
    ]).

-spec eos_message(StreamId) -> frame()
  when
    StreamId :: non_neg_integer(),
    MessageId :: non_neg_integer().
eos_message(StreamId, MessageId) ->
    frame([
        ?EOS_MESSAGE,
        u64(StreamId),
        u64(MessageId)
    ]).

ack(Credits, MessageAcks) ->
    frame([
        ?ACK,
        u32(Credits),
        u32(length(MessageAcks)),
        lists:map(fun ({StreamId, PointofRef}) ->
            [u64(StreamId), u64(PointOfRef)]
        end, MessageAcks)
    ]).

restart() ->
    frame([
        ?RESTART
    ]).
```

NOTE: Each connector may provide a number of streams as a source. Each stream only has order and consistency relative to itself as far as Wallaroo is concerned. The connector itself is not really a stream as much as a collection of streams which all behave in a similar manner. Usually this denotes that the source is implemented using a single medium but it's not necessarily the case. An example of this is a connector which has an active medium which is periodically purged and an archive for when progress must resume from data that is too old to be kept in the active medium. Allowing the Wallaroo application to treat this as a single source is a convenient allowance.

Before the connector can send application messages to Wallaroo, it needs to notify Wallaroo of each new logical stream. These notifications need only come before the first application message in that specific stream. This allows subsequent application messages to omit the fully qualified name.

The choice of StreamId is the connector's responsibility.  The stream name is advisory/debugging information only; the StreamId alone is used by the protocol to identify MESSAGEs.  The StreamId should always be a deterministic mapping. For example, a partition number could be used or a hash of the {topic name, partition} could be used if multiple topics are being used under the name of a single source.

*Wallaroo will not permit simultaneous use of the same StreamId by multiple source connectors*.  Wallaroo maintains a global registry of stream names and ID numbers.  This global registry is updated when a StreamId is in active (via NOTIFY frame) or inactive (via EOS_MESSAGE frame).  Each Wallaroo worker maintains a local registry of StreamIds that are active on that worker; the local registry is maintained by the connector listener actor.

The generation of a StreamId should be unique. Failure to do so is an error. For cases where a simple StreamId scheme can't be used, we recommend using a good hash function on the fully qualified name (64 bits is large enough to avoid birthday paradox issues for many applications).

Sending a MESSAGE with a StreamId that has not been properly described using a notification is an error, and Wallaroo will signal such and close the connection.

If a connector is resuming from Wallaroo's provided point of reference, the connector should provide that point of reference in the notification for the stream. Otherwise, the connector should provide the value zero.

The worker should keep note of these mappings for metrics and debugging purposes. Each StreamId should also maintain some state, specifically whether the stream is open or closed (via EOS_MESSAGE).

For any single stream, Wallaroo assumes that the MessageId in MESSAGE frames are strictly increasing.

### Point of Reference

A point of reference define the position in a stream relative to its content, assuming there is some determinism in the ordering each time the content is replayed. This involves the guarantee that MESSAGEs sorted before and after that point of reference form a disjoint set. Certain mediums can only provide coarser granularity during replay. The whole stream itself may not have a total order but the disjoint sets formed by each point of reference do have a total order. The observation should be that all points of reference form a total order of legal places one can resume from.

This coarse-grained ordering can be thought of in terms of ranges where the bounds are the MessageIds in the frames. The starting bound is inclusive and the ending bound is exclusive. This *should* allow Wallaroo to note where streaming *should* resume without losing application messages.

### End of Stream

This is a newer feature and it aligns nicely with GenSource. Generators and batch workloads sometimes need to signal the completion of a dataset that is being streamed, and EOS_MESSAGE allows that to be expressed.

A stream that has been closed by an EOS_MESSAGE may be used again later, by sending a NOTIFY frame that uses the same StreamId.

### ACK

The worker should acknowledge frames of all types. These do not need to be 1-1 acknowledgments but it may be convenient to write it as such initially since all frames take one credit and each session needs to have these continuously replenished to avoid stuttered flow <sup>D2</sup>. ACK frames serve this purpose, almost like a regular heartbeat. Technically an ACK could be sent with zero credits but we don't currently see this as a very useful feature <sup>D3</sup>.

When Wallaroo has processed a barrier and completed a checkpoint, then, for each stream, the last received MessageId prior to the barrier will be sent to the connector client in an ACK frame to report processing progress <sup>D4</sup>.  All MESSAGEs with MessageIds less than the reported point of reference are included in the checkpoint.

### RESTART

When a connector receives a RESTART frame from the worker, the connector must close the connection.  In order to resume sending data to the worker, the connector must open a new connection + handshake + NOTIFY for each stream.  The connector must not assume that any MESSAGEs were received by the worker that had: a). MessageIds larger than the last ACK's point of reference, and b). MessageIds larger than the point of reference contained in a subsequent NOTIFY_ACK.

In cases where the Wallaroo cluster is shrinking, a client that is connected to a soon-to-be-removed worker is informed via the RESTART frame where to connect to another Wallaroo worker.

---

<sup>D2</sup> Some amount of stuttering is okay. This can improve throughput at the cost of some latency so it's worth tuning the pipeline depth but trying different credit counts. Smarter connectors may also be able to spend their credits more intelligently on frames that are more important.

<sup>D3</sup> An idle link carries some risks but we currently expect local networking so we'll not worry about this for now. The main issue with relying on timeliness is that the current Pony mute/unmute system can create a bit of a problem when paired with head of line blocking issues. Alternative solutions exist to allow multiplexing to get around this problem but the complexity is not worth the benefit at the moment.

<sup>D4</sup> Wallaroo has completed processing MESSAGEs up to that point of reference across all pipelines that use that source.

## Protocol State Machine

Each connection must follow the following state machine definition.

```
 +-----------+       +-----------+     +-----------+
 | Connected +------>| Handshake +---->| Streaming |
 +-----------+       +-----------+     +-----------+
         |                |                  |
         |                +--------+         |
         |                V        |         |
         |            +--------+   |         |
         +----------> | Error  | <-----------+
         |            +--------+   |         |
         |                |        |         |
         |                V        V         |
         |       +-------------------+       |
         +------>+  Disconnected     |<------+
                 +-------------------+
```

In the Connected state the following frame types are valid:

    - HELLO: Connector -> Worker (next state = Handshake)
    - ERROR: * -> * (next state = Error)

In the Handshake state the following frame types are valid:

    - OK: Worker -> Connector (next state = Streaming)
    - ERROR: * -> * (next state = Error)

In the Streaming state the following frame types are valid:

    - NOTIFY: Connector -> Worker
    - NOTIFY_ACK: Worker -> Connector
    - MESSAGE: Connector -> Worker
    - EOS_MESSAGE: Connector -> Worker
    - ACK: Worker -> Connector
    - RESTART: Worker -> Connector (next state = Disconnected)
    - ERROR: * -> * (next state = Error)

In the Error state, no frames are valid. It is recommended that the transport be closed properly, though any local processing may be completed if there are bits of work that are still in progress. Any data received after the ERROR frame is discarded.

The Disconnected state has no communication, but it is recommended that the connecting party use exponential back-off during reconnects and/or retry limits.


## Stream State Machine

Each stream during a session must be in one of the following states:

```
                  +------------+-------------+--------------+
                  |            | +--------+  |              |
                  |            | |        |  |              |
                  |            | |        V  |              V
 +-------+     +------+     +------+     +--------+     +------------+
 | Start +---->|Notify|---->| Open +---->| Closed +---->| Terminated |
 +-------+     | Sent |     |      |     |        |     |            |
               +------+     +------+     +--------+     +------------+
                  ^  |                     ^ |
                  |  |                     | |
                  |  +---------------------+ |
                  +--------------------------+
```

New streams must be introduced, and closed streams (via the EOS_MESSAGE frame) must be reintroduced. The connector may not know if a notification is the first use of a stream or not. If the StreamId has been used before, the handshake will include the point of reference to resume from.

In the Start state, the following actions are valid:

- NOTIFY: Connector -> Worker (provide a StreamId and a fully qualified name)
    * The next state is Notify-Sent

In the Notify-Sent state, the following actions are valid:

- NOTIFY_ACK: Worker -> Connector
    * The `NotifySuccess` byte indicates whether the connector has successfully processed the NOTIFY frame.  Value values are:
        - 1: The connector may send MESSAGE frames for this StreamId.
            * Next state is Open
        - 0: The connector may not send MESSAGE frames for this StreamId.  Some Wallaroo worker has this StreamId in use by another connection and therefore prohibits use by this connection.
            * Next state is Closed
    * NOTE: The point of reference in this ACK may differ from the point of reference sent by the connector in the NOTIFY frame.  The connector must use the point of reference given in the NOTIFY_ACK frame.
    * The connector must not send MESSAGE frames for any StreamId before the connector receives a successful NOTIFY_ACK for the StreamId.
- RESTART: Worker -> Connector
    * Worker is requesting that all streams be reprocessed
    * The next state is Terminated

In the Open state, the following actions are valid:

- MESSAGE: Connector -> Worker (production of stream data)
    * The next state is Open
- EOS_MESSAGE: Connector -> Worker (production of stream data)
    * The next state is closed
- ACK: Worker -> Connector
    * These are not 1-1 with MESSAGE frames
    * The next state is Open
- RESTART: Worker -> Connector
    * Worker is requesting that all streams be reprocessed
    * The next state is Terminated

In the Closed state, the following actions are valid:

- NOTIFY: Connector -> Worker
    * Reopens the stream
    * The next state is open
- RESTART: Worker -> Connector
    * Worker is requesting that all streams be reprocessed
    * The next state is terminated
- ACK: Worker -> Connector
    * These can arrive asynchronously and should be processed accordingly
    * The next state is closed

In the Terminated state, no actions are valid: the worker will close the session and ignore any frames received after the RESTART frame has been sent.

## Connector sink protocol

The protocol described in this document was originally designed for use with Wallaroo sources.  When the need arose for at-least-once delivery to Wallaroo sinks and implementation of a protocol to coordinate checkpoint handling across multiple sinks, this protocol was adapted for use by connector sinks.  This section describes the changes, relative to the original use case by connector sources.

### 1. WRT the protocol description, roles of worker and connector are reversed

As used with connector sources, the word "worker" applies to a Wallaroo worker process, and the word "connector" applies to an external Wallaroo data source.  When applied to Wallaroo data sinks, the roles are reversed:

    - A Wallaroo worker initiates the TCP connection to a connector sink.
    - A Wallaroo worker sends HELLO, NOTIFY, MESSAGE, and EOS_MESSAGE frames to a connector sink.
    - A connector sinks sends OK, NOTIFY_ACK, ACK, and RESTART frames to a Wallaroo worker

### 2. Use of StreamIds is extremely limited

A connector source may use as many streams (with unique StreamIds) as the entire Wallaroo system may require.  A connector sink, however, only uses two StreamIds:

    - StreamId 1: The MESSAGE frame contains application output data via a Wallaroo sink actor.
    - StreamId 0: The MESSAGE frame contains a Two Phase Commit (2PC) protocol message.

This allocation of StreamIDs may need to change as features such as sink `parallelism` factor (see below) are added.

### 3. MessageIds within StreamId 1 are assigned by byte offset of the sink's output data

The MessageId in a StreamId1 MESSAGE is the byte offset of a Wallaroo sink's output.  The sink's output doesn't have an explicit name; a sink's implicit name is the TCP host + port tuple that the sink data is sent to.  Internally to Wallaroo, each sink is assigned an identifier for use by intra- and inter-worker routing, but the identifier is not exposed outside of Wallaroo.

There is in-progress work on Wallaroo to provide a `parallelism` factor, greater than one, for Wallaroo sinks.  The intent is to avoid potential bottlenecks for high-volume sink output that can be caused by the single Pony actor implementation, the single TCP connection per sink per worker, or both.

NOTE: For both multi-worker Wallaroo clusters and the in-progress `parallelism` factor sinks, Wallaroo provides no guarantees on ordering of sink output data of any pair of sink TCP connections.

### 4. Data encapsulated in each StreamId is related to the other

A connector source's StreamIds are logically separate from each other. In contrast, the StreamIds of connector sinks are tightly coupled:

    - The delivery order of all MESSAGE frames by the TCP stream has meaning and must be preserved by the data sink.
    - The interleaving of StreamId 0 (2PC) and StreamId 1 (application sink output) frames is strictly limited.

While a round of the 2PC protocol is in progress, i.e. a MESSAGE frame in StreamId 0 with a Phase 1 request and ends with MESSAGE frame in StreamId 0 Phase 2 request, Wallaroo MUST NOT send any application MESSAGEs in StreamId 1 or any other StreamId > 0.  This restriction can be onerous to Wallaroo, but it also provides the greatest applicability to connector sinks of all types and capabilities.  This restriction may change in later protocol implementations.

### 5. The Two Phase Commit (2PC) protocol controls the connector sink's durability guarantees

Periodically, Wallaroo will use a Two Phase Commit (2PC) protocol to coordinate the reliable delivery of application sink messages to one or more connector sinks.  The most common trigger of a round of 2PC is a Wallaroo state checkpoint.

During a Wallaroo state checkpoint, a checkpoint barrier token is sent by each Wallaroo source down all Wallaroo pipelines until all barrier tokens are received by Wallaroo sink actors.  Each connector sink actor then starts a round of 2PC with the external connector sink.  If any connector sink votes ABORT during phase 1, then the barrier protocol will eventually cause all connector sinks to send ABORT during phase 2.  If all connector sinks vote COMMIT during phase 1, then the barrier protocol will eventually cause all connector sinks to send COMMIT during phase 2.

A MESSAGE frame that contains a 2PC phase 1 request will specify the byte offset range(s) of the data sent to the sink for the logical time range that is managed by the Wallaroo global checkpoint protocol.

The connector sink should be able to manage the durability of the data in this byte offset range(s).  If the connector sink cannot manage durability of this sink data, then the connector sink must always vote COMMIT during phase 1; such a sink then cannot provide the end-to-end message delivery guarantees that the connector sink protocol is intended to provide.  In such cases, we recommend that the Wallaroo TCPSink be used instead.

When the connector sink receives a 2PC phase 2 request:

    - If the phase 2 decision is COMMIT, then the connector sink must make the application sink data in the transaction's byte range(s) durable, using whatever app-specific means necessary.  For example:
        - For file I/O, to write to a file(s) + flush(es) + fsync(s), etc.
        - For a relational database, to commit any pending transactions that were created by the sink data.
    - If the phase 2 decision is ABORT, then the connector sink must discard all application sink data in the transaction's byte range(s).

### 6. Durable storage of 2PC state

A connector sink must provide durable storage for the state of all 2PC state. At a minimum, a connector sink must commit to stable storage:

    - all transaction IDs in phase 1 + the local commit/abort decision
    - all sink data in the byte range(s) specified by a phase 1 local COMMIT decision

In the event of a connector sink crash, this persistent data must be used to comply with subsequent 2PC queries as the Wallaroo system works through its recovery protocols.

### 2PC protocol messages

```erlang
-define(TWOPC_LIST_UNCOMMITTED,  201).
-define(TWOPC_REPLY_UNCOMMITTED, 202).
-define(TWOPC_PCPHASE1,          203).
-define(TWOPC_REPLY,             204).
-define(TWOPC_PCPHASE2,          205).

-spec list_uncommitted(RTag) -> frame()
  when
    RTag :: non_neg_integer().
list_uncommitted(RTag) ->
    frame([
        ?TWOPC_LIST_UNCOMMITTED,
        u64(RTag)
    ]).

-spec reply_uncommitted(RTag, TxnIdList) -> frame()
  when
    RTag :: non_neg_integer(),
    frame :: list(string()).
reply_uncommitted(RTag, TxnIdList) ->
    frame([
        ?TWOPC_REPLY_UNCOMMITTED,
        u64(RTag),
        u32(length(TxnIdList)),
        lists:map(fun (TxnId) ->
            short_bytes(TxnId)
        end, TxnIdList)
    ]).

-spec twopc_phase1(TxnId, WhereList) -> frame()
  when
    TxnId :: string(),
    WhereList :: list({StreamId :: non_neg_integer,
                       StartPoR :: non_neg_integer,
                       EndPoR   :: non_neg_integer}).
twopc_phase1(TxnId, WhereList) ->
    frame([
        ?TWOPC_PHASE1,
        short_bytes(TxnId),
        u32(length(WhereList)),
        lists:map(fun ({StreamId, StartPoR, EndPoR}) ->
            [u64(StreamId), u64(StartPoR), u64(EndPoR)]
            end, WhereList)
    ]).

twopc_phase2(TxnId, Commit) -> frame()
  when
    TxnId :: string(),
    Commit :: bool().
twopc_phase2(TxnId, Commit) ->
    frame([
        ?TWOPC_PHASE2,
        short_bytes(TxnId),
        if Commit -> <<1>>;
           true   -> <<0>>
        end
    ]).

%% The twopc_reply message is used by the connector sink to reply
%% both to 2PC phase 1 and phase 2 messages.
%% NOTE: The encoding is nearly identical to the twopc_phase2 message.

twopc_reply(TxnId, Commit) -> frame()
  when
    TxnId :: string(),
    Commit :: bool().
twopc_reply(TxnId, Commit) ->
    frame([
        ?TWOPC_REPLY,
        short_bytes(TxnId),
        if Commit -> <<1>>;
           true   -> <<0>>
        end
    ]).
```

## Simplified state update sequences for the connector source protocol with sources on multiple workers and source migration

### States

#### notifier
(class instance on connector source)

- _pending_notify
- _active_streams
- _pending_close
- _pending_relinquish


#### local registry
(class instance on connector source listener)

- _active_streams (stream_id, (stream_name, connector source, last_acked, last_seen))


#### global registry
(class instance on connector source listener)

- _active_streams (stream_id, worker_name)
- _inactive_streams (stream_id, last acked por)


### Sequences

```
-> = delegate
@ terminate/return to sender
```

#### Simplified notify

```
notifier
  -> is in any local state?
    -> reject @
  -> ask listener, put stream_id in pending_notify

listener
  -> check local registry
    -> accept @ (see below
    -> reject @ (see below)
  -> check global registry @ (see below)

local registry
  -> is in _active_streams?
    -> owned by requester?
      -> accept @
    -> else reject @
  -> else go to global

global registry
  -> am I leader?
    -> is in _inactive?
      -> move from _inactive to _active, owned by requester
      -> accept @
    -> is in _active?
      -> reject @
    -> accept @ (new stream)
```

#### Simplified stream_update

```
notifier
  -> barrier_complete
  -> update local state
  -> update listener
listener
  -> update local registry
```

#### Simplified EOS_MESSAGE

```
notifier
  -> move stream from _active to _pending_notify
  -> wait for barrier_complete
  -> barrier_complete
    -> update local state (last_seen = last_acked, checkpoint_id =...)
    -> _relinquish request
    -> move from _pending_notify to _pending_relinquish (stream_id, stream_state)
```

#### Simplified relinquish

```
notifier
  -> _relinquish request
  -> listener.relinquish_request(stream_id, last_ack)
listener
  -> local_registry.relinquish_request
    -> global_registry.relinquish_request
      -> am I leader?
        -> is stream in _active? request name matches?
          -> move from _active to _inactive
          -> ack @
        -> nack @
      -> connections -> leader -> global registry
    -> local_registry ack relinquish
    -> notifier ack relinquish
notifier
  -> remove from _pending_relinquish
```



At the end of a recovery, local_registry relinquishes any streams that don't have a connector_source associated with them


## Listener checkpoint logic

_This part is preparation for when John's barrier protocol updates are ready_


State hierarchy:

Listener
  - local registry
    - global registry
    -< active sources
      - notifiers

Communication order:

notifier -> source -> listener -> local registry -> global registry or other active sources


Creating a checkpoint (return Array[ByteSeq]):

listener.create_checkpoint()
  -> local_registry.create_checkpoint()
    -> serialize local () +
       serialize global()
       // + length encoding or whatever's needed

       /* This part will be used in some fashion when john's work is done:
          /* we currently save this state in the notifier, so it's not necessary here */
       + sources.get_checkpoints()
       */

listener.rollback(payload; Array[U8], ...)
  ->
    deserialize and save local and global states
