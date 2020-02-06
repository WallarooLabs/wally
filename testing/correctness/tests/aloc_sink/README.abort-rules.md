
# Abort Rules Configuration for aloc_sink

The `aloc_sink` external connector sink can use an "abort rules" file to configure custom behavior of the sink: abort 2PC transactions and close the TCP connection.

## File format

The file format is a collection of single ASCII lines, separated by the UNIX newline character '\n'.  Each line is parsed by using Python's built-in `eval` keyword.  Each parsed line is appended to a list of abort rules.

Each line should contain a valid Python tuple, and the tuple should not be empty, i.e., the tuple `()` will probably cause runtime exceptions.  Comment lines are not available, nor are blank lines.  Comments can be embedded using the syntax `("Some comment here.")` because the pattern-matching-like behavior of the sink will ignore tuples with element 0 that is not a member of a small subset of strings.

## Abort rules list processing

The abort rules list is evaluated against every application message and every 2PC message that is received by the sink.

### Abort based on regexp match on the 2PC transaction ID 

For a rule in the form of the 5-tuple:

```
("txnid-regexp", regexp: string, phase1-vote: bool, close-before: bool, close-after: bool)
```

For each 2PC phase 1 message, if the message's transaction ID string matches the `regexp` regular expression, then:

1. The sink is forced to send a phase 1 reply `phase1-vote` where `TwoPCReply.commit = phase1-vote`.
2. If `close-before` is true, then the sink's TCP connection is closed prior to sending the phase 1 reply message.  The practical effect of this option is that the phase 1 reply message is dropped/lost.
3. If `close-after` is true, then the sink's TCP connection is closed after sending the phase 1 reply message.

### Abort based on app message content

For a rule in the form of the 3-tuple:

```
("stream-content", stream-id: integer, regexp: string)
```

Each application message received on stream ID `stream-id` will evaluate the `regexp` string regular expression against the app message body.  If the app message body matches the regular expression, then the sink will vote "abort" for the next round of 2PC.

### Abort based on local transaction count

Not used at the moment for test purposes; this trigger may be buggy relative to the 2PC transaction ID regexp method.

For a rule in the form of the 5-tuple:

```
("local-txn", count: int, phase1-vote: bool, close-before: bool, close-after: bool)
```

For each 2PC phase 1 message, if the sink's local count of 2PC phase 1 messages is equal to `count`, then:

1. The sink is forced to send a phase 1 reply `phase1-vote` where `TwoPCReply.commit = phase1-vote`.
2. If `close-before` is true, then the sink's TCP connection is closed prior to sending the phase 1 reply message.  The practical effect of this option is that the phase 1 reply message is dropped/lost.
3. If `close-after` is true, then the sink's TCP connection is closed after sending the phase 1 reply message.
