# Experimental Wallaroo Extension API

Wallaroo includes some relatively low level extension points. These may work
well for applications which want very fine grained control over sources and
sinks but for the average application, the lack of a higher level extension
point makes integrating Wallaroo into other infrastructure a bit more difficult
than it should be.

This API is an experimental way to improve this experience and with some planned
changes, improve stream fidelity as well (specifically with regards to
concurrency and resiliency). What we present here is the Python version of this
extension API. There are a few new calls which will be added when ready but for
now we'll assume only what you can use today.

All of the python facing code for this work is available under the
`wallaroo.experimental` package and is subject to change.

## Design Overview

We provide the ability to build custom sources and sinks using python code.
These are run as external scripts to give us a few clear benefits:

- avoid runtime interference with machida's pony schedulers
- avoid inversion of control for the API
- achieve an amount of fault isolation between wallaroo and extensions

The runtime issues are a bit complex but given the CPython GIL, there is a clear
win to having computationally focussed code running separately from I/O focussed
code.

Inversion of control in machida works well for streaming computations, as we
can react efficiently to incoming messages. It does not work as nicely when
writing extensions as one might need to allow something like a Kafka library to
determine when specific code is called rather than something like Machida. This
reduces the need for boilerplate induced by rendezvous between various bits of
controlflow.

Fault isolation is a nice side effect of this design. Stability can be a
difficult property to maintain. This design allows us to stabilize components
independently. As applications discover new failure conditions, only the
interacting component should need to deal with and problems that may result.

## Patterns in Wallaroo Applications

_NOTE: We use the term source to describe a series of messages we use as input
to our computations. We also call this a stream of messages in some case. Where
we divide one stream vs another is not a clear choice at the moment so for now
I'll say the use of stream which follows is non-normative but applies to logical
sources and sinks as defined in the application builder. This should be sorted
out at some point in the future._

When building an application it makes sense to construct concepts that represent
a cohesive set of concerts rather than just throw a bundle of functions at a
problem. Here, for sources and sinks, it is worth considering the stream which
they represent. The main reason we don't just call these streams is that
direction of the flow matters.

The analogies that source and sink draw are very useful but they are also
incomplete on their own. Streams are constructed in two parts. While wallaroo
might sit at the source end of a stream, there is something feeding that source
upstream. Likewise, sinks sit upstream from some downstream system.

Isolating the description of these parts can lead to accidental mismatches over
time. This can make a system harder to maintain over time. To assist here, I'm
introducing a simple pattern that I'm calling a stream description. In our
example application here, we have a couple choices for the source and sink
medium (redis and kafka). These are hooked up to Wallaroo via a stream
description.

The anatomy of one of these (let's look at `text_documents.py`) should be self
explanatory:

```python
import argparse
import wallaroo.experimental
```

This just a python script so we can pull in the packages we need to describe
the application concerns. This includes whatever discovery and configuration
system the application might have in place.

```python
class TextStream(object):

    # NOTE: We may be able to use defaults if we can add some kind of
    # protocol initialization here.
    def __init__(self, host, port):
        self.host = host
        self.port = int(port)

    def source(self):
        return wallaroo.experimental.SourceExtensionConfig(
            host=self.host,
            port=self.port,
            decoder=text_decoder)

    def extension(self):
        extension = wallaroo.experimental.SourceExtension(text_encoder)
        extension.connect(self.host, self.port)
        return extension
```

This class defines a constructor which takes whatever canonical configuration
might be appropriate. We'll follow up on that below. The source and extension
methods provide a way to help in constrcution of the wallaroo application and
extension script halves respectively.

Don't spend too much time worrying about what we're constructing here. We'll
walk through that below.

```python
def parse_text_stream_addr(args):
    parser = argparse.ArgumentParser()
    parser.add_argument('--text-stream', dest="input_addr")
    input_addr = parser.parse_known_args(args)[0].input_addr
    return tuple(input_addr.split(':'))
```

The parser here is useful for giving a standard way for configuration
management. Here we are following the CLI argument parsing convention that most
of Wallaroo's examples use. This parser is used for both the Wallaroo app
**and** the extension script.

```python
@wallaroo.experimental.streaming_message_decoder
def text_decoder(message):
    return message.decode("utf-8")


@wallaroo.experimental.streaming_message_encoder
def text_encoder(message):
    return message.encode("utf-8")
```

Most importantly we define our encoders and decoders. In this example we're
using unstructured text but we could be using other common formats. Note that
we no longer put these in our main wallaroo module. They are implementation
details that don't belong top-level.

We'lre also using a new decorator here. We'll cover this next.

## Encoders and Decoders

Traditional Wallaroo applications used a TCP based source and sink
implementation where messages were encoded within an octet stream. Pulling this
apart required specification of the framing convention. Here we've moved away
from this. We hide the framing and assuming that both halves are using the same
version of the Wallaroo, it should just work. The application's job is to
consider messages rather than various byte vectors.

These decorators assume you return a byte-string compatible type. We'll be
sending that with some internal data over the wire.

## Configuration

The stream description's constructor takes parameters and we'd like to avoid
having to hard-code these. A recommended convention is to provide a way to
parse arguments and pass those directly to this constructor. Of course, this
will vary from one application to another.

The configuration is used to construct two Wallaroo application builder classes.
`SourceExtensionConfig` and `SinkExtensionConfig` are both what they seem. We
pass these into the `new_pipeline` and `to_sink` calls respectively. The
parameters to these are identical to the TCP counterparts currently. This will
change as the Pony side implementation evolves but keeping them within the
stream description methods gives these concerns a clear place.

The `SourceExtension` and `SinkExtension` classes allow us to construct objects
which present write and read calls respectively.

Eventually we'd like to allow more automatic discovery or allocation of ports
but the idea is that we'll encourage these drivers to run locally with the
worker processes. This means it's common to assume loopback interfaces. I've
kept it explicit in this code for now.

## Source Scripts

We have two examples in this demo application. One uses Kafka,
`kafka_consumer.py`, and the other uses Redis, `redis_subscriber.py`. The
structure is quite similar. In both cases we use the source method to construct
an instance of `wallaroo.experimental.SourceExtension`. This class allows us
to use one primary call `write`.

`write` takes a few arguments:

- message: required, this is our application message and it will be passed to
    the encoder we gave it earlier
- partition: optional, this is our unit of concurrency and can be any string or
    object which can be converted to a string
- sequence: optional, this is our message id; we currently assume that it is
    monotonically increasing in Wallaroo's model

IMPORTANT: `partition` and `sequence` are currently dropped when received by
wallaroo. These will be properly wired up in the future.

## Sink Scripts

Like sources, sinks have two example scripts and instead of `write` we have
`read` which is called on our instance of `wallaroo.experimental.SinkExtension`.

`read` takes no arguments. It will block until we receive a message to return.
This is returned directly as a value to the caller. The return value is whatever
the decoder returns.

NOTE: I've lied, `read` does take an optional timeout but I'm seriously
considering the removal of this in favor of a SinkExtension method which
provides clearer timeout semantics.

## Up and Running

We have some scripts in this directory to help run the examples and I'll
be adding detail here. I did include a single-broker kafka instance in the
docker-compose file. I also have a virtualenv target in the Makefile.
