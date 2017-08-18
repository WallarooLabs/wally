"""
# Watermarking

The package contains code for Wallaroo's watermarking functionality.
Watermarking is used to support message delivery and state resilience
guarantees. Without this core of watermarking, all resilience and
exactly-once features wouldn't work.

At it's core, watermarking is about knowing that messages sent from one step to
another have been handled; that is, that they are "done". Let's look at a
simple case:

Source -> A -> B

A message arrives at a source, it is then sent from the source to step A and
then on to step B. The message is "done" and can be acknowledged back to the
source once B is finished with the message. To do this, steps participate in
an acknowledgement protocol. When B is finished with a message, it acks
that back to A and then A acks that back to the source.

Between any given two points, such as steps A and B, we have a monotonically
increasing sequence of message identifiers. For example, if A sends 3 messages
all destined for B, they would arrive as B in a form like (A, 1), (A, 2),
(A, 3) where the first tuple item is the sender A and the second is A's
identifier for the message. When B finishes processing a message like (A, 2),
it will acknowledge back to the sender ("A") that it has processed up to
the message with the corresponding id ("2"). A can then in turn do the same
back to the source.

To chain acknowledgements in this fashion, a Step like A needs to know what
incoming message from an upstream `Producer` corresponds to what message that
was sent to a downstream `Consumer`. This incoming to outgoing tracking is done
in the `_OutgoingToIncomingMessageTracker` class.

Acknowledged messages are recorded in the `Watermarker` class on a per route
basis. A `Route` is a point between two steps. For example, A --> B results
in a `Route` from A to B. `Route`s are fundamental to how we determine what
messages can be acknowledged by a step at any given point in time. Each step's
`Watermarker` also contains a `_FilteredOnStep` route for keeping track of
any messages that entered the step but had no corresponding output message.

The `Acker` class is responsible for coordinating between the `Watermarker`
and the `_OutgoingToIncomingMessageTracker`. The `Acker` receives acks from
downstream consumers and will periodically check to see if it can acknowledge
anything back to any of it's upstream producers.

The "high watermark" for a step is the highest outgoing message id that has
been acknowledged where every message sent before it has also been
acknowledged. For example, if Step A sends to Step B messages with the ids:
1, 2, 3 and B has acknowledged back 2. Then 2 is our high watermark. A step
will always acknowledge the highest id it can to a producer. So rather than B
having to ack both 1 and 2 (which would be wasteful), it only acks 2. We can
do this because of Pony's causal messaging. If message 2 has been handled,
then message 1 also has to have been handled.

With only a single route, this is fairly easy to reason about. Once we have
more than one route, things start to get to be complicated. Imagine a step
Baz has done the following:

sent messages 1,4,5 to step Foo
sent messages 2,3,6 to step Bar

If Foo has acknowledged 5 and Bar has acknowledged 2, what is Baz's high
watermark? In this case it is 2. Baz can safely acknowledge only the lowest
value it has have seen across all routes. The `_test_watermarker.pony` file
contains a number of scenarios for high watermark algo. These are:

If all routes are fully acked. That is, the highest sent is the highest seen,
then a step's high watermark is the highest value across all routes.

If any route isn't fully acknowledged, then the step's high watermark is
the lowest acknowledged value from all routes that aren’t fully acked.

Once we have a high watermark, we can then, at any point we want, use that to
acknowlege work done to our upsteam producers. The algo for determining what
we can acknowlege back to producers is complicated due to the possibility that
1 incoming message resulted in multiple outgoing messages. Let's first look at
how acking would work if "1 to many" didn't exist.

Once a high watermark is proposed, in the absence of "1 to many" then any
incoming message whose outgoing message id is equal to or less than our
high watermark can be acknowledged. For efficiency, we only acknowlege the
highest value handled to each incoming producer. This in turn, triggers
the same process to start in the upstream producer.

Outgoing to incoming mapping is complicated by the existence of "1 to many".
"1 to many" is the possibility that 1 incoming message resulted in many
outgoing messages. In order to acknowlege an incoming message, the high
high watermark has to be greater than or equal to the highest outgoing id
corresponding to that message.
"""
