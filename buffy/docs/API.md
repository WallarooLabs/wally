# Stream-Py API

## Description
The stream-py prototype implements a directed graph with edges and vertices with the use of UDP addressable
message queues, and active vertex nodes that consume from and publish to those message queues via a simple
UDP protocol.  
The use of UDP for the message queue facilitates three functionalities:

1. Multiple vertices can consume from or publish to any single message queue, which enables use of
   an _information-highway_ style of data flow topology.
2. It is trivial to parallelize edges behind a load balancer.
3. The vertices are language agnostic from the edges, as well as from one another.

## Serialization
The binary messages are serialized for forward-only stream parsing, following
an `LHHTTT` structure where

 - `TTT` is the message text, UTF-8 encoded
 - `HH` is the byte length of `TTT`, as a hexadecimal string of maximum length 15
 - `L` is `HH`'s byte length, as a single hexadecimal character

While it may appear only useful for consuming large batches of messages from a stream, this sort
of serialization is already useful in the UDP server implementation as it tells it precisely how large
a buffer it needs to consume.


e.g. 

| Input (text) | TTT (UTF-8 encoded) | HH (hex) |  L (hex) | Output (to binary stream) |
| :-------     | :------             | :--| :-- | :--                       |
| Hello world | `b'Hello world'` | `b` | `1` | `b'1bHello world'` |
| abcdefghijklmnopqrstuvwxyz | `b'abcdefghijklmnopqrstuvwxyz'` | `1a` | `2` | `b'21aabcdefghijklmnopqrstuvwxyz'` |
| 𝐇𝐞𝐥𝐥𝐨 𝐰𝐨𝐫𝐥𝐝 | `b'\xf0\x9d\x90\x87\xf0\x9d\x90\x9e\xf0\x9d\x90\xa5\xf0\x9d\x90\xa5\xf0\x9d\x90\xa8 \xf0\x9d\x90\xb0\xf0\x9d\x90\xa8\xf0\x9d\x90\xab\xf0\x9d\x90\xa5\xf0\x9d\x90\x9d'` | `29` | `2` | `b'229\xf0\x9d\x90\x87\xf0\x9d\x90\x9e\xf0\x9d\x90\xa5\xf0\x9d\x90\xa5\xf0\x9d\x90\xa8 \xf0\x9d\x90\xb0\xf0\x9d\x90\xa8\xf0\x9d\x90\xab\xf0\x9d\x90\xa5\xf0\x9d\x90\x9d'` |
| GET | `b'GET'` | `3` | `1` | `b'13GET'` |
| SIZE | `b'SIZE'` | `4` | `1` | `b'14SIZE'` |
| PUT:Lorem Ipsum | `b'PUT:Lorem Ipsum'` | `f` | `1` | `b'1fPUT:Lorem Ipsum'` |


_Note that `b''` is Python's way of representing byte arrays to a text console. This output may differ in another language, but its binary string in the byte array should be the same._


See [stream-py/functions/mq_parse.py](https://github.com/Sendence/nisan/blob/master/stream-py/functions/mq_parse.py) for `decode` and `encode` implementations and [stream-py/worker.py](https://github.com/Sendence/nisan/blob/master/stream-py/worker.py#L59-L82) for an example implementation of how this is used in a raw UDP GET method in Python.

## Message Queue API
The following API methods are supported by the Message Queue:

1. GET
2. PUT:plaintext content
3. SIZE

To invoke a method, a client should:

1. Open a UDP connection to the message queue server
2. Create its command text (e.g. `GET`, `SIZE`, or `PUT:some text here`)
3. Serialize and encode the command text according to the `LHHTTT` serialization protocol
4. Flush the binary encoded message into the open UDP socket
5. Read the response from the socket
7. Decode the response from binary to text using the `LHHTTT` serialization protocol
8. (Optionally) close the socket once all data is consumed
9. Perform Apply additional logic based on response

Note that the _empty_ or _null_ response serializes to `10` in `LHHTTT` (`HH` is `0`, whose length is `1`).

## Worker API
Since the workers don't _listen_, they don't have any addressable API methods.
To interface _between_ a worker and a message queue, one must assume the message queue's original address
in a Man-in-the-Middle fashion.  
Instead of taking over the MQ's original address, we can simply reassign a worker's input address to
the MitM node to achieve the same effect. The MitM node is effectively a router that may choose to
forward traffic transparently, or otherwise perform another action (drop it, duplicate it, reorder, garble, etc).

