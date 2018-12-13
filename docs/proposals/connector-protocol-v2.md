# Wallaroo Connector Protocol: source-only, async, credit based flow

**STATUS: Accepted as draft, Under revision**

This protocol provides a method for source connectors to transmit streams of messages to Wallaroo over a reliable transport like TCP/IP. The protocol does not require that any specific mechanism or party initiate the connection, thought a particular implementation may further specify this.

Terms like connector, worker, and so on are assumed to be familiar to the reader. They may be refined where useful but familiarity with Wallaroo's application model should be enough. If not, it's recommended that the reader reviews the Wallaroo documentation first.


## Overview

The scope of the protocol is transmission of one or more streams. Once a connection has established a session by completing the handshake, streams are multiplexed over this connection. Each stream has a transmission order <sup>A0</sup> which is freely interleaved with other parts of the transmission. The following is an overview of the connection lifecycle. Detailed parts will be explored in more detail below.

Each connection made between a connector and a Wallaroo worker is treated as a full-duplex and asynchronous communication channel. Each protocol message is sent independently in one direction and, other than the handshake, does not await for a response. We'll use 'frame' to refer to protocol messages to avoid confusion with application messages.

Connections start with a handshake that establishes a session. The session encompasses a relatively lightweight amount of state. The connector sends a number of fields in order to establish a session including a version GUID <sup>A1</sup>, a secret cookie <sup>A2</sup>, the connector program name, and the connector instance name. The latter is what allows the connector to be appropriately routed to your application pipelines.

The worker that receives the handshake <sup>A3</sup> will respond with an ok or error. The error will end the connection and the connector will need to reopen a socket to attempt a new connection. On success, the ok message will include any points of reference <sup>A4</sup> that belonged to prior and active sessions to allow correct resumption as well as a credit count to allow stream flow to start <sup>A5</sup>.

With a credit count established for this session, we may start pushing frames for our streams. Before we send messages streams are introduced with notification frame types to establish a mapping between the stream's fully qualified name and the id which message frames will use when transmitting messages <sup>A6</sup>. Stream notifications do consume one credit.

Once a stream notification as been sent, the open stream can have any number of messages for that stream sent so long as the credit count remains above zero. In order to replenish credits, Wallaroo is expected to send ack frames to the connector. This will include the number of credits to be added to the session's current count as well as a list of {stream id, maximum message id} pairs that have been properly processed. This allows the connector to do bookkeeping and make progress as long as Wallaroo is keeping up.

The protocol has been given plenty of room to grow and may be optimized over time. Most of the machinery is designed to allow trivial implementations which can be replaced with more sophisticated algorithms later. An example is credit flow can be adjusted in order to achieve target buffer sizes while avoiding pipeline stalls by using a PID controller rather than a fixed pipeline depth upon session initialization.

---

<sup>A0</sup> Transmission order relates to the order of the messages as encoded in the connected medium. This order is not necessarily sorted by event time. Messages may include event time to allow Wallaroo to implement time-based processing windows. This is out of scope of the protocol.

<sup>A1</sup> Exact matching will be enforced. Incremented version numbers are avoided here as we are currently expecting source-level consistency between both parties. This means the connector runtime should be upgraded along with the worker runtime. This restriction may be lifted later and lead to stable versions of the protocol supported across releases.

<sup>A2</sup> Secret is applied loosely here. This is not meant to be the only security measure. Still, it can be an effective mitigation during incidental exposure of a network to hosts that shouldn't have direct access to a working cluster. It also protects against accidental cross-cluster configuration mistakes, which may be common when running many ephemeral clusters.

<sup>A3</sup> This is currently only the initializer but this restriction will be lifted so we'll assume for now that it is any appropriate worker.

<sup>A4</sup> The term point of reference is use in an attempt to avoid too much baggage with any given medium. These could be things like partition offsets in Kafka, file names, counters, dotted logical clocks, timestamps (considering the caveats of course).

<sup>A5</sup> The initial implementation may be allowed to leave points of reference for stream progress out but it will be required for implementing safe recovery with effectively once or at least once semantics. Credits could be partitioned to a more refined scope like a single logical stream but it quickly becomes impractical under some circumstances where the set of streams a session must deal with becomes dynamic.

<sup>A6</sup> The layer of indirection allows for a much more efficient message frame but also serves as a way to set the state of a stream as "open". As we'll see later, streams may have ends in some cases which will cause them to assume they are closed to new messages.


## Wire Format

Each frame transmitted by either side uses a 32bit big endian/network byte order <sup>B0</sup> length denoting all bytes that come after the 4 bytes comprising the length <sup>B1</sup>. This makes it much easier to consistently split up data which might be captured and recorded for analysis after the fact and could speed the development of other tools which can do primitive routing and management of frames without requiring a full description of the format of each frame type.

This framing mechanism applies to all messages including the handshake. The worker reading the hello frame should be careful to check the version and cookie value placed in fixed locations at the start before continuing the decoding. This allows the protocol to sidestep any unintended behaviors if the framing changes in the future <sup>B0</sup>.

After the length, each frame is tagged with a message type. This is a single byte since the protocol is simple. Any further data in the frame depends on the type. In some cases, the final field may have variable length data and will implicitly use the remaining length in the frame.

When possible, fixed sized fields are used to encode data.

### Primitive Type Definitions

This document uses Erlang code to describe the frame format and content. You don't need to be fluent in Erlang to read most of this but it may help to review the [bitstring syntax](http://erlang.org/doc/programming_examples/bit_syntax.html).

#### Constants

Frame tags (`$H` = ASCII value of H):

```erlang
-define(HELLO, $H).
-define(OK, $O).
-define(ERROR, $E).

-define(NOTIFY, $N).
-define(MESSAGE, $M).

-define(ACK, $A).
-define(RESTART, $!).
```

Message bit-flags:

```erlang
-define(EPHEMERAL, 1).
-define(BOUNDARY, 2).
-define(EOS, 4).
-define(UNSTABLE_REFERENCE, 8).
-define(EVENT_TIME, 16).
-define(KEY, 32).
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

<sup>B0</sup> Big vs little endian: (Brian) I think we should move most of this to little endian. There is not much advantage to network byte order tradition. This is easy to change so if people have issues with this, we can always go replace it all and replace the version GUID (or perhaps we'll a truncated 128bit part of the current git commit hash).

<sup>B1</sup> The length needs to have a max size set in Wallaroo. Wallaroo would have issues if someone thought it'd be cleaver to send 4GiB messages. To avoid this, it may be worth using a more conservative size of a few megabytes with a configuration option to change this limit.


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

-spec ok(positive_integer(), list(stream_info())) -> frame()
  when
    stream_info = {StreamId::non_neg_integer, StreamName::String,
                   Ref::point_of_reference()}.
ok(InitialCredits, PointsOfReference) ->
    frame([
        ?OK,
        u32(InitialCredits),
        % This encodes each point of reference in sequence using the
        % remaining bytes in the frame.
        lists:map(fun ({StreamId, StreamName, Ref}) ->
            [u64(StreamId), short_bytes(StreamName), point_of_reference(Ref)]
        end, PointsOfReference)
    ]).

-spec error(string()) -> frame().
error(Reason) ->
    frame([
        ?ERROR,
        short_bytes(Reason)
    ]).
```

Aside: Erlang requires capitalized variable names. `%` introduces a comment till the end of that line.

This section assumes transport discovery and configuration has been handled elsewhere.

Upon connection, the connector must send a hello frame which establishes the protocol version and includes some descriptive metadata about the script as well as a preconfigured nonce called a cookie. These fields allows the Wallaroo worker to determine if it belongs with to the application or cluster and if so, how to route messages.

The cookie is optional and can have it's length set to zero if you haven't configured one somewhere <sup>C0</sup>. This will be default for easy development but it'll be encouraged to be used in a deployed cluster to prevent accidental and unwanted connections from being made, especially in the case where more than one cluster may be run. It is not a strong security mechanism by itself but designing by the rule of defense in depth, this becomes a reasonable mitigation.

NOTE: The connector doesn't necessarily enumerate streams at this point. We expect some amount of change to be possible during the runtime of a connector (henceforth session) and as such, we avoid making too many assumptions during handshakes. The handshake is only to establish plausible common ground as we'll see notifications are able to handle resource description.

In response to the hello frame, the worker should send either an ok frame or an error frame. Errors will include a short reason meant for the programmer or operator. Ok frames will include the initial credit count and a list of stream id + reference point pairs <sup>C1</sup>. These can be used by the connector to resume from prior progress in a way that is coherent with Wallaroo's last checkpoint <sup>C2</sup>.

NOTE: An example of this initialization data would be resuming from Kafka using a consumer group. In order to ensure all data is processed, the partition progress should be set to Wallaroo's if it is lower than the current offset on any given partition. Optionally, the connector could also jump forward to what Wallaroo has if Kafka offset commits are infrequent or suffer reliability problems of their own.

The connector is responsible for evaluating initial streaming states and resuming from the appropriate place once the Ok is received. If it is unable to continue, it should send an error frame so the problem may be logged within Wallaroo.

If no error has occurred and the connection has remained opened, the protocol now moves from the handshake state to the streaming.

---

<sup>C0</sup> Both sides are required to set this to an empty value. If the worker does not expect a cookie but the connector gives one, this might signal a configuration error and it'd be better to fail loudly rather than continue silently.

<sup>C1</sup> These pairs use the stream id as set by the notify frame(s) sent by previous sessions.

<sup>C2</sup> Because this protocol is asynchronous, we must assume that this data is eventually consistent but not always perfectly up to date. These values are meant as hints for the connector. Right now we also don't dot the point of reference with some generational counter. This prevents certain advanced scenarios to be played out. It's out of scope for now the first few revisions of this protocol. Further issues with reprocessing are handled with RESTART frames discussed in the streaming section.


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
        u16(Flags),
        u64(StreamId),
        if Flags band ?EPHEMERAL /= 0 then
            <<>>
        else
            u64(MessageId)
        end,
        if Flags band ?EVENT_TIME /= 0 then
            u64(EventTime)
        else
            <<>>
        end,
        if Flags band ?KEY /= 0 then
            short_bytes(Key)
        else
            <<>>
        end,
        if Flags band ?BOUNDARY /= 0 then
            <<>>
        else
            Message
        end
    ]).

ack(Credits, MessageAcks) ->
    framed([
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

Aside: Erlang uses the `bor` operator to express bitwise OR.

NOTE: Each connector may provide a number of streams as a source. Each stream only has order and consistency relative to itself as far as Wallaroo is concerned. The source itself is not really a stream as much as a class of streams which all behave in a similar manner. Usually this denotes that the source is implemented using a single medium but it's not necessarily the case. An example of this is a connector which has an active medium which is periodically purged and an archive for when progress must resume from data that is too old to be kept in the active medium. Allowing the Wallaroo application to treat this as a single source is a convenient allowance.

Before the connector can send messages to Wallaroo, it needs to notify Wallaroo of each new logical stream. These notifications need only come before the first message in that specific stream. This allows the following messages to omit the fully qualified name.

The choice of stream id is the connector's responsibility.  The stream name is advisory/debugging information only; the stream id alone is used by the protocol to identify data messages.  The stream id should always be a deterministic mapping. For example, a partition number could be used or a hash of the {topic name, partition} could be used if multiple topics are being used under the name of a single source. The generation of an id should be unique. Failure to do so is not an error but will allow parallelism in processing where it may be unintended. For cases where simple numbering can't be done, it's recommended to use a good hash function on the fully qualified name (64bit's is large enough to avoid birthday paradox issues).

Sending a message with a stream id that has not been properly described using a notification is an error and Wallaroo should signal such and close the connection.

If a connector is resuming from Wallaroo's provided point of reference it should provide that reference in the notification for the stream. Otherwise it should provide the value zero.

The worker should keep note of these mappings for metrics and debugging purposes. Each stream id should also maintain some state, specifically whether the stream is open or closed (via EOS message or boundary). Messages sent for a closed stream should require a notification to set that stream back to an open state.

Sending a message falls into two categories: boundaries and payloads.

Boundary messages are treated as markers and carry no message payload. Boundary messages still require a message id which may be used as a point of reference for resuming or rewinding a stream if the UNSTABLE_REFERENCE flag is set to 0. Boundaries may also denote the end of the stream if there is no message to apply that notation to <sup>D0</sup>.

Payloads are what you might expect and are transmitted using the remaining bytes in the frame. Encoding is specific to the connector definition given in the application, so these bytes are effectively opaque. An optional event time can be applied to events, though the worker may not make use of this at the moment <sup>D1</sup>.

Message ids are currently 64 bits in this version of the protocol. To allow variable sized id representations in the future, we may add a message flag for this variant but chose not to for the first iteration. Wallaroo does not make any assumptions around monotonicity of message ids currently. There may be cases where this becomes an advantage to leverage when available but it is currently left out of scope for later consideration.

### Message Bit-flags

Messages currently have a 16bit field for bit-flags. Most of the bits are reserved for future use and should be set to zero. Some of the valid settings are defined in the constants above and explained in more detail below.

### Ephemeral Messaging

Messages can be marked as ephemeral denoting that the identity and content of the message may not be retrieved later. The message id is still provided for correlation purposes but should not be treated as a unique identifier by itself. Each should be unique within a session but will not guarantee this property across sessions. This feature is designed to be used for one-shot mediums like UDP or trivial TCP.

Early implementations may reject and/or mishandle streams with ephemeral and non-ephemeral messages in the same stream.

### Points of Reference

Each message id may be remembered but it can be expensive to remember them all. Thus we have points of reference to define position in a stream relative to its content, assuming there is some determinism in the ordering each time the content is replayed. This involves the guarantee that messages sorted before and after that point of reference form a disjoint set. Certain mediums can only provide coarser granularity during replay. The whole stream itself may not have a total order but the disjoint sets formed by each point of reference do have a total order. The observation should be that all points of reference form a total order of legal places one can resume from.

This course grained ordering can be thought of in terms of ranges where the bounds are the message ids in the frames. The starting bound is inclusive and the ending bound is exclusive. This *should* allow Wallaroo to note where streaming *should* resume without losing messages.

If Wallaroo is not able to support unreferenced messages with resilience turned on then it may be wise to send an error back to the connector when this occurs. Discussion around supporting this may take time and so Wallaroo will make no guarantees around supported variants in this mode, only that the streams should use this correctly so silent failures during recovery don't bite late into the application's lifetime.

(See extended discussion section for notes on why this might not work very well.)

### End of Stream

This is a newer feature and it aligns nicely with GenSource. Generators and batch workloads sometimes need to signal the completion of a dataset that is being streamed and this allows that to be expressed. It's not currently decided how this will be exposed but for now it is assumed that the worker should treat this end state strictly to help detect problems with connector behavior early.

### ACK

The worker should acknowledge frames of all types. These do not need to be 1-1 acknowledgments but it may be convenient to write it as such initially since all frames take one credit and each session needs to have these continuously replenished to avoid stuttered flow <sup>D2</sup>. Ack frames serve this purpose, almost like a regular heartbeat. Technically an ack could be sent with zero credits but we don't currently see this as a very useful feature <sup>D3</sup>.

When Wallaroo has processed a barrier and completed a checkpoint, then, for each stream, the last received MessageId prior to the barrier will be sent to the connector client in an ACK message to report processing progress <sup>D4</sup>.  All messages with MessageIds less than the reported point of reference are included in the checkpoint.

### RESTART

When a connector receives a RESTART message from the worker, the connector must close the connection.  In order to resume sending data to the worker, the connector must open a new connection + handshake + notify for each stream.  The worker cannot assume that any messages sent with MessageIds larger than the last ACK's point of reference were received by the worker.

---

<sup>D0</sup> These cases can happen for empty streams. It may also be a matter of convenience and effort for certain mediums where the end of a stream may only be discovered after the last message has been sent.

<sup>D1</sup> It could be argued that event time might make sense on boundaries as well for providing relative time in at a coarse granularity but it seems wise to leave this out for now. If that is required for the application, it makes sense to encode the time as the message id for these cases as these are also opaque fields.

<sup>D2</sup> Some amount of stuttering is okay. This can improve throughput at the cost of some latency so it's worth tuning the pipeline depth but trying different credit counts. Smarter connectors may also be able to spend their credits more intelligently on frames that are more important.

<sup>D3</sup> An idle link carries some risks but we currently expect local networking so we'll not worry about this for now. The main issue with relying on timeliness is that the current Pony mute/unmute system can create a bit of a problem when paired with head of line blocking issues. Alternative solutions exist to allow multiplexing to get around this problem but the complexity is not worth the benefit at the moment.

<sup>D4</sup> One might assume the pipeline has completed processing messages up to that point of reference across all pipelines that use that source. There are plenty of other ways this could be configured to work, depending on the trade-offs an application requires and which options are enabled in Wallaroo.


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

In the connected state the following frame types are valid:

    - HELLO: Connector -> Worker (next state = handshake)
    - ERROR: * -> * (next state = error)

In the handshake state the following frame types are valid:

    - OK: Worker -> Connector (next state = streaming)
    - ERROR: * -> * (next state = error)

In the streaming state the following frame types are valid:

   - NOFITY: Connector -> Worker
   - MESSAGE: Connector -> Worker
   - ACK: Worker -> Connector
   - RESTART: Worker -> Connector
   - ERROR: * -> * (next state = error)

In the error state no frames are valid. It is recommended that the transport be closed properly, though any local processing may be completed if there are bits of work that are still in progress. Any data received after the error frame should be discarded.

The disconnected state has no communication but it is recommended that the connecting party use backoff during reconnects and/or retry limits.


## Stream State Machine

Each stream during a session must be in one of the following states:

```
                  +-------------+--------------+
                  |             |              |
                  |             |              V
 +-------+     +------+     +--------+     +------------+
 | Start +---->| Open +---->| Closed +---->| Terminated |
 +-------+     +------+     +--------+     +------------+
                  ^             |
                  |             |
                  +-------------+
```

New streams must be introduced and reset streams must be reintroduced. The connector may not know if a notification is the first use of a stream or not. If the StreamId has been used before, the handshake will include information on where to resume from. The state machine will always end up in the open state after a notification.

In the intro state, the following actions are valid:

    - NOTIFY: Connector -> Worker (provide a stream id and a fully qualified name)

In the open state, the following actions are valid:

- MESSAGE: Connector -> Worker (production of stream data)
    * if the EOS flag is set the next state is closed
- ACK: Worker -> Connector
    * the are not 1-1 with MESSAGE frames
- RESTART: Worker -> Connector (next state is terminated)
    * worker is requesting that the stream be reprocessed in some way

In the closed state, the following actions are valid:

- NOTIFY: Connector -> Worker (next state is open)
    * reopens the stream
- RESTART: Worker -> Connector (next state is terminated)
    * worker is requesting that the stream be reprocessed in some way
- ACK: Worker -> Connector
    * these can arrive asynchronously and should be processed accordingly

In the terminated state, no actions are valid: the worker will close the session and ignore any messages received after the RESTART has been sent.

## Debugging

TODO: Decide if this protocol should define a few frames that require a debug flag in order to work. This might be useful when testing, adding the ability to do certain kinds of fault injection like stuttering to simulate timeouts without actually waiting for the wall clock.


## TODO

- ~~use proper markdown for the footnotes~~
- consider some ASCII notation rather than Erlang
    - I like the Erlang and I did use bit-strings in more clever ways in an earlier version
    - now that it's all on the byte boundary this may not matter as much
    - Erlang is less ambiguous here but it's also unfamiliar to some
- move the Erlang specs out of the main document and into the reference functions
- add some diagrams to illustrate what a potential session might look like
- review some of the edge cases that should be errors more explicitly
- label the expected and reasonable ranges for some of the parameters
    - aka. using all 32 bits might be excessive for the frame but it's simpler to use a power of 2.
- bring back some of my old discussion sections that compare this to other options if needed
    - the document was getting long so I decided to keep most of that out
- consider a section on TLS and transport setup
    - even though it was out of scope for this there is plenty to discuss there in a way that can relate to this doc
- ??? I've rewritten this about three times and it's changing less each time so perhaps it's good enough now but are there any other ideas we should write down somewhere for future work? Things I left out that might be worth revisiting in some future iteration?

## Extended Discussion

This document has plenty of points left out because of the original scope of the cancelled and now resumed/revised work plan. I'll try to add more points of discussion below to expand on various areas. Trade-offs were made so many of these sections will be dedicated to various trades that come up in discussion.

### Points of Reference vs Acknowledgments

Acknowledgments should ideally use points of reference but this is not a trivial requirement. Committed progress would be predicated a regular flow of references. We can certainly still ack credits without message ids but it still leaves some edge cases where progress might look to be standing still while the system is under full load. This unintuitive result could be explained with good UI choices but it's still a con. So we allow acks to pick up any message id.

A possible improvement would be to include a message id and a count. We can maintain a counter for each stream which helps minimize the outstanding state on the connector side (we no longer need to relate message ids as sets which may or may not have structure). We can get away with this even in unordered case because we understand the count between points of reference so we should be able to infer when committable references are hit by filling in order (note: this implies we're relying on transmission order for a stream, under recovery and migration cases, we'll need to be careful to manage the count appropriately, more on this in a bit).
