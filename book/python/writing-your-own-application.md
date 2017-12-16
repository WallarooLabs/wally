# Writing Your Own Wallaroo Python Application

In this section, we will go over the components that are required in order to write a Wallaroo Python application. We will start with the stateless `reverse.py` application from the [examples](https://github.com/WallarooLabs/wallaroo/tree/{{ book.wallaroo_version }}/examples/python/reverse/) section, then move on to an application that maintains and modifies state and, finally, a stateful application that also uses partitioning to divide its work.

## A Stateless Application - Reverse Words

The `reverse.py` application is going to receive text as its input, reverse it, and then send out the reversed text to its sink. In order to do this, our application needs to provide the following functions:

* Input decoding - how to translate the incoming bytestream into a Python string
* Computation - this is where the input string is going to get reversed
* Output encoding - how to construct and format the bytestream that will be sent out by the sink

### Computation

Let's start with the computation, because that's the purpose of the application:

```python
@wallaroo.computation(name='reverse'):
def reverse(self, data):
    print "compute", data
    return data[::-1]
```

A Computation has no state, so it only needs to define its name, and how to convert input data into output data. In this case, string reversal is performed with a slice notation.

Note that there is a `print` statement in the `compute` method (and in other methods in this document). They are here to help show the user what is happening at different points as the application executes. This is only for demonstration purposes and is not recommended in actual applications.

### Sink Encoder

Next, we are going to define how the output gets constructed for the sink. It is important to remember that Wallaroo sends its output over the network, so data going through the sink needs to be of type `bytes`. In Python2, this is the same as `str`.

```python
@wallaroo.encoder
def encode(self, data):
    # data is a string
    print "encode", data
    return data + "\n"
```

### SourceDecoder

Now, we also need to decode the incoming bytes of the source.

```python
@wallaroo.decoder(header_length=4, length_fmt=">I")
def decode(self, bs):
    print "decode", bs
    return bs.decode("utf-8")
```

This one is different. When using a TCP source, Wallaroo handles _streams of bytes_, and in order to do that efficiently, it uses a method called message framing. This means that Wallaroo requires input data to follow a special structure, as well as for the application to provide the mechanism with which to decode this data.

To read more about this, please refer to the [Creating A Decoder](/book/appendix/tcp-decoders-and-encoders.md#creating-a-decoder) section.

For our application purposes, we will simply define the structure and how it is going to get parsed:

1. Input messages have the following structure: A fixed length `PAYLOAD_SIZE` followed by `PAYLOAD`
2. Wallaroo requires three methods to parse this type of message:
  1. `header_length()`, which returns the number of bytes used for the `PAYLOAD_SIZE` in the message. This value tells Wallaroo how many bytes to read from the stream as `HEADER`.
  2. `payload_length(bs)`, which reads `PAYLOAD_SIZE` bytestring of the size returned by `header_length()` and computes the size of `PAYLOAD`. It then returns that size as an integer to Wallaroo, which will then read that many bytes from the stream.
  3. `decode(bs)`, which receives the remainder of the message, `MSG`, and decodes it into a python object.

In our case:

* `PAYLOAD_SIZE` is a big-endian unsigned 32-bit integer, so we return `4` from `header_length()` and use `struct.unpack('>I', bs)` to read it as an integer.
* `PAYLOAD` is text, so we decode as such, using `'utf-8'` encoding.

### Application Setup

So now that we have input decoding, computation, and output decoding defined, how do we build it all into an application?
For this, two things are needed:
1. An entry point for Wallaroo to create the application. This is the function `application_setup` that you need to define.
2. The actual topology `application_setup` is going to return for Wallaroo to create the application.

#### Application Builder and Pipelines

An application is constructed of pipelines which, in turn, are constructed from a sequence of a source, steps, and optionally a sink. Our reverse application only has one pipeline, so we only need to create one:

```python
ab = wallaroo.ApplicationBuilder("Reverse Word")
ab.new_pipeline("reverse",
                wallaroo.TCPSourceConfig(in_host, in_port, decoder))
```

Each pipeline must have a source, and each source must have a decoder, so `new_pipeline` takes a name and a `TCPSourceConfig` instance as its arguments.

Next, we add the computation step:

```python
ab.to(reverse)
```

And finally, we add the sink, using a `TCPSinkConfig`:

```python
ab.to_sink(wallaroo.TCPSinkConfig("localhost", "7010", encoder))
```

### The `application_setup` Entry Point

After Wallaroo has loaded the application's python file, it will try to execute its `application_setup()` function. This function is where the application builder steps from above are going to run.

```python
def application_setup(args):
    in_host, in_port = wallaroo.tcp_parse_input_addrs(args)[0]
    out_host, out_port = wallaroo.tcp_parse_output_addrs(args)[0]

    ab = wallaroo.ApplicationBuilder("Reverse Word")
    ab.new_pipeline("reverse",
                    wallaroo.TCPSourceConfig(in_host, in_port, decoder))
    ab.to(reverse)
    ab.to_sink(wallaroo.TCPSinkConfig(out_host, out_port, encoder))
    return ab.build()
```

Configuration objects are used to pass information about sources and sinks to the application builder. Currently the only supported source and sink types are TCP and Kafka.

Wallaroo provides convenience the functions `tcp_parse_input_addrs` and `tcp_parse_output_addrs` to parse host and port information that is passed on the command line, or the user can supply their own code for getting these values. When using the convenience functions, host/port pairs are represented on the command line as colon-separated values and multiple host/port values are represented by a comma-separated list of host/port values. The functions assume that `--in` is used for input addresses, and `--out` is used for output addresses. For example, this set of command line arguments would specify two input host/port values and one output:

```
--in localhost:7001,localhost:7002 --out localhost:7010
```

### Miscellaneous

Of course, no Python module is complete without its imports. In this case, only two imports are required:

```python
import struct
import wallaroo
```

## Running `reverse.py`

The complete example is available [here](https://github.com/WallarooLabs/wallaroo/tree/{{ book.wallaroo_version }}/examples/python/reverse/). To run it, follow the [Reverse application instructions](https://github.com/WallarooLabs/wallaroo/tree/{{ book.wallaroo_version }}/examples/python/reverse/README.md)

## Next Steps

To learn how to write a stateful application, continue to [Writing Your Own Stateful Application](writing-your-own-stateful-application.md).
