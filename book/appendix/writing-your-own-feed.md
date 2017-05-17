# Writing Your Own Wallaroo Data Feed

As with any real-time data processing system, Wallaroo needs to be able to understand its source input. For now, this means the following:
1. Wallaroo sources must be TCP
2. Wallaroo sources are treated as _streams_
3. Individual messages on the _stream_ need to adhere to a framing structure

Support for both additional input formats and additional input protocols is coming soon.

## Source Message Framing

Wallaroo applies the _stream_ abstraction over inputs. Generally, this means that as far as the framework can tell, its input source is a _stream of bytes_. One of the implications that arises from this choice is that character or string delimiters don't work very well.
A stream of bytes can represent many things: each byte could be an 8-bit unsigned integer, or every 4-byte block may be a 32-bit integer. Or the stream may be an ASCII sequence (each byte is a char), or a unicode sequence (in which case characters aren't equally-wide!).

To make this easy for Wallaroo, we apply the following framing protocol:
1. each message is preceded by a fixed-width LENGTH HEADER. We typically use a U32 (4-bytes), as it's unlikely that any single message in our system is larger than 2**(32-1) bytes.
2. The next LENGTH HEADER bytes are read as _the message_.

This is a specialization, and as such it comes with both pros and cons.
Some of the pros are:
- Wallaroo can pre-allocate memory ahead of reading from the stream, which eliminates instances of having to grow arrays mid-stream
- There is no ambiguity about whether a message is complete. The message's bytes are either all there, or Wallaroo will block on reading the remaining bytes from the stream until they become available.
- Decoding can be deferred until a _processing function_ needs a specific input data type.
- Partitioning can be performed on the bytes, rather than decoded data types, to further defer the object decoding of a bytestream into the parallelized components of Wallaroo.

Some of the cons are:
- Simply piping input text into a TCP connection to Wallaroo won't work. The user must _format_ the data first! This adds work.
- You can't just send data to Wallaroo with netcat if you want to work in a more interactive mode.
- The sender must have the entire message before they start sending it to Wallaroo in order to tell its length (while this is not always true, it is the common case with variable input messages!). If your input feed was reading variable length data from another source, it would have to first stage the data before starting to send it downstream to Wallaroo. This may add latency and reduce throughput.

### Source Message Framing Protocol

As described in the previous section, the framing protocol divides a message into two parts:
1. a LENGTH HEADER of a fixed number of bytes
2. a MESSAGE of length LENGTH HEADER bytes

The user's [SourceDecoder class](/book/core-concepts/decoders-and-encoders.md#creating-a-decoder) will tell Wallaroo how many bytes to read for LENGTH HEADER via the `header_length()` function.
Thus, messages sent by your feed must encode their LENGTH HEADER in that exact length.
Our examples all use a U32 LENGTH HEADER, so the `header_length()` function returns `4`.

For example, the message `'hello world'`, which is an 11 bytes long string, will be encoded as
`\x00\x00\x00\x0bhello world`.
The first 4 bytes, `\x00\x00\x00\x0b` are the big-endian representation of the U32 `11`, and the remaining 11 bytes are the string `'hello world'`.

### Using Giles Sender

While originally designed for testing and benchmarking, if your data source is a file(s), you may find [Giles-sender](/book/wallaroo-tools/giles-sender.md) already answers your needs.

### Writing Your Own Data Source in Python

In Python, we can make use of the [struct module](https://docs.python.org/2/library/struct.html) to correctly encode standard Python data types.
For example, to encode an arbitrary length string into a U32 framed `bytes`, the following snippet will do well

```python
def encode_string(msg):
    return struct.pack('>L{}s'.format(len(msg)), len(msg), msg)
```

Using the [socket module](https://docs.python.org/2/library/socket.html), you can then send the framed data to the address Wallaroo is listening on:

```python
HOST = '127.0.0.1'
PORT= 5555

# Create a socket and connect to the Wallroo listening address
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect((HOST, PORT))

# Send some framed strings
s.send(encode_string('hello world'))
s.send(encode_string('1010'))
s.send(encode_string('lorem ipsum'))

# Once done, close the connection.
s.close()
```
