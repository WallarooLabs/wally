---
title: "TCP Decoders and Encoders"
menu:
  docs:
    parent: "pytutorial"
    weight: 10
toc: true
---
Earlier, we spoke of [sources and sinks](/book/core-concepts/core-concepts.md) and the role they play in Wallaroo. In this section, we are going to dive more into how you work with sources and sinks. We'll be covering two key concepts: `Decoder`s and `Encoder`s.

## Reviewing our terms

### Source

Ingress point for inputs from external systems into a Wallaroo application.

### Sink

Egress point for outputs from a Wallaroo application to external systems.

### Decoder

Code that transforms a stream of bytes from an external system
into a series of application input types.

### Encoder

Code that transforms an application output type into bytes for
sending to an external system.

## Framed Message Protocols

A Wallaroo TCP Source accepts a stream of bytes from an external source and turns that stream of bytes into a stream of application specific messages. As an application programmer, you provide a `Decoder` to tell Wallaroo how to turn that stream of bytes into messages.

An incoming stream of bytes can represent many things: each byte could be an 8-bit unsigned integer, or every 4-byte block may be a 32-bit integer. Or the stream may be an ASCII sequence (each byte is a char), or a Unicode sequence (in which case characters aren't equally-wide!).

Decoders are unique to the type of source. `TCPSource`s use a [framed message protocol](https://www.codeproject.com/Articles/37496/TCP-IP-Protocol-Design-Message-Framing). A framed message protocol boils down to:

- We have a fixed size header that tells us how long a message is
- We have a variable length message payload

The message payload is what our application cares about. The fixed length header allows us to easily get the size of our payload. With these two pieces of information, we can quickly chop up a stream of incoming bytes into a series of messages.

The size of the header is up to you the designer of the particular message type. You can make it 4 bytes, 8 bytes, 16, et cetera. The important part is that you need enough bytes to represent the length of your payload. For most data, a 4-byte header is plenty. In the abstract, this looks like

```
PayloadSize [x bytes] : Payload [bytes specified in PayloadSize]
```

So if our header is 4 bytes long, an incoming message would look something like:

| header | payload |
| - | - |
| xxxx | some data here |

Let's make that a bit more concrete. Let's say we are sending in two messages; each contains a string. The first has "first" as a payload and the second payload is "not first". Our stream of bytes would be:

- 4-byte header whose value is `5`
- 5-byte payload containing the binary representation of the ASCII string "first"
- 4-byte header whose value is `9`
- 9 byte payload containing the binary representation of the ASCII string "not first"

## Creating a Decoder

Wallaroo's `TCPSource` takes a decoder _function_ that can process a framed message protocol. You'll need to implement three methods. Below is a decoder that we can use to process a stream of strings for a word count application.

```python
@wallaroo.decoder(header_length=4, length_fmt=">I")
def decode_lines(bs):
    return bs.decode("utf-8")
```

`header_length` is the fixed size of our payload field.

`length_fmt` is used internally to decode our message header to determine how long the payload is going to be. We rely on the Python `struct` package to decode the bytes. If you aren't familiar with `struct`, you can check out [the documentation](https://docs.python.org/2/library/struct.html) to learn more. Remember, when using `struct`, don't forget to import it!

`decode_lines` takes a series of bytes that represent your payload and turns it into an application message. In this case, our application message is a string, so we take the incoming byte stream `bs` and convert it to UTF-8 Python string.

Here's a slightly more complicated example taken from our [Alphabet Popularity Contest example](https://github.com/WallarooLabs/wallaroo/tree/{{% wallaroo-version %}}/examples/python/alphabet).

```python
@wallaroo.decoder(header_length=4, length_fmt=">I")
def decode_votes(bs):
    (letter, vote_count) = struct.unpack(">sI", bs)
    letter = letter.decode("utf-8")  # for Python 3 comptibility
    return Votes(letter, vote_count)
```

Like we did in our previous example, we're using a 4-byte integer payload length header:

```python
@wallaroo.decoder(header_length=4, length_fmt=">I")
```

But this time, we are doing something slightly more complicated in our payload. Our payload is two items, a string representing a letter and some votes for that letter. We unpack those using `struct` and create a domain specific object `Votes` to return.

## Creating an Encoder

Wallaroo encoders do the opposite of decoders. A decoder takes a stream of bytes and turns in into messages for Wallaroo to process. An encoder receives a stream of messages and converts them into a stream of bytes for sending to another system.

Here's a quick example encoder:

```python
@wallaroo.encoder
def encode_data(data):
    # data is a string
    return data + "\n"
```

It takes a string that we want to send to an external system as an input, adds a newline at the end and returns it for sending.

Here's a more complicated example taken from our [Alphabet Popularity Contest example](https://github.com/WallarooLabs/wallaroo/tree/{{% wallaroo-version %}}/examples/python/alphabet):

```python
class Votes(object):
    def __init__(self, letter, votes):
        self.letter = letter
        self.votes = votes

@wallaroo.encoder
def encode_votes(votes):
    return struct.pack(">IsQ", 9, votes.letter, votes.votes)
```

Let's take a look at what is happening here. First of all, we are once again using the Python `struct` package. In this case, though, we are creating our own packed binary message. It's a framed message with a 4-byte header for the payload length, plus the payload:

```
| header | payload |
| 9 | letter & votes |
```

If we were encoding the letter "A" and a vote value of "1" our payload would be `'A\x00\x00\x00\x00\x00\x00\x00\x01'`. This along with our framing data can be sent along to another system that expects framed data.

