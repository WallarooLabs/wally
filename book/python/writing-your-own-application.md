# Writing Your Own Wallaroo Python Application

In this section, we will go over the components that are required in order to write a Wallaroo Python application. We will start with the stateless `reverse_word.py` application from the [Building a Python Application](building.md) section, then move on to an application that maintains and modifies state and, finally, a stateful application that also uses partitioning to divide its work.

## A Stateless Application - Reverse Words

The `reverse_word.py` application is going to receive text as its input, reverse it, and then send out the reversed text to its sink. In order to do this, our application needs to provide the following functions:

* Input decoding - how to translate the incoming bytestream into a Python string
* Computation - this is where the input string is going to get reversed
* Output encoding - how to construct and format the bytestream that will be sent out by the sink

### Computation

Let's start with the computation, because that's the purpose of the application:

```python
class Reverse(object):
    def name(self):
        return "reverse"

    def compute(self, bs):
        return data[::-1]
```

A Computation has no state, so it only needs to define its name, and how to convert input data into output data. In this case, string reversal is performed with a slice notation.

### Sink Encoder

Next, we are going to define how the output gets constructed for the output. It is important to remember that Wallaroo sends its output over the network, so data going through the sink needs to be a stream of bytes.

```python
class Encoder(object):
    def encode(self, data):
        # data is already string, so let's just add a newline to the end
        return data + "\n"
```

### SourceDecoder

Now, we also need to decode the incoming bytestream of the source.

```python
class Decoder(object):
    def header_length(self):
        return 4

    def payload_length(self, bs):
        return struct.unpack(">I", bs)[0]

    def decode(self, bs):
        return bs.decode("utf-8")
```

This one is different. Wallaroo handles _streams of bytes_, and in order to do that efficiently, it uses a method called message framing. This means that Wallaroo requires input data to follow a special structure, as well as for the application to provide the mechanism with which to decode this data.

To read more about this, please refer to the [Framed Source Handling](/book/intro/framed-source-handling.md) section.

For our application purposes, we will simply define the structure and how it is going to get parsed:

1. input messages have the following structure: `HEADER_LENGTH``MSG_LENGTH``MSG`
1. Wallaroo requires three methods to parse this type of message:
  1. `header_length()`, which returns the number of bytes used for `HEADER_LENGTH` in the message. This value tells Wallaroo how many bytes to read from the stream as `MSG_LENGTH`.
  1. `payload_length(bytestream)`, which reads a `MSG_LENGTH` bytestream of size `HEADER_LENGTH` and computes the size of `MSG`. It then returns that size as an integer to Wallaroo, which will then read that many bytes of the stream.
  1. `decode(bytestream)`, which receives the remainder of the message, `MSG`, and decodes it into a python object.

In our case:

* `HEADER_LENGTH` is 4 bytes for an unsigned 32-bit integer.
* `MSG_LENGTH` is a big-endian unsigned 32-bit integer, so we use `struct.unpack('>I', bs)` to read it as an integer.
* `MSG` is text, so we decode as such, using `'utf-8'` encoding.

### Application Setup

So now that we have input decoding, computation, and output decoding defined, how do we build it all into an application?
For this, two things are needed:
1. an entry point for Wallaroo to create the application. This is the function `application_setup` that you need to define.
1. the actual topology `application_setup` is going to return for Wallaroo to create the application.A

#### Application Builder and Pipelines

An application is constructed of pipelines who, in turn, are constructed of a sequence of a source, steps, and optionally a sink. Our reverse application only has one pipeline, so only need to create one:

```python
ab = wallaroo.ApplicationBuilder("Reverse word")
ab.new_pipeline("reverse", Decoder())
```

Since each pipeline must have a source, it must then also have a source decoder. So `new_pipeline` takes a name and a `Decoder` instance as its arguments.

Next, we add the computation step:
```python
ab.to(Reverse)
```

And finally, we add the sink along with an encoder:
```python
ab.to_sink(Encoder())
```

### The `application_setup` Entry Point

After Wallaroo has loaded the application's python file, it will try to execute its `application_setup()` function. This function is where the application builder steps from above are going to run.

```python
def application_setup(args):
    ab = wallaroo.ApplicationBuilder("Reverse Word")
    ab.new_pipeline("reverse", Decoder())
    ab.to(Reverse)
    ab.to_sink(Encoder())
    return ab.build()
```

### Miscellaneous

Of course, no python module is complete without its imports. In this case, only two imports are required:

```python
import struct
import wallaroo
```

The complete example is available [here](https://github.com/Sendence/wallaroo-documentation/tree/master/examples/reverse-python).

To learn how to write a stateful application, continue to [Writing Your Own Stateful Appliaction](writing-your-own-stateful-application.md).
