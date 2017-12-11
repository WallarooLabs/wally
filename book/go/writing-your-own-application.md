# Writing Your Own Wallaroo Go Application

In this section, we will go over the components that are required in order to write a Wallaroo Go application. We will start with the stateless `reverse`application from the [examples](https://github.com/WallarooLabs/wallaroo/tree/{{ book.wallaroo_version }}/examples/go/reverse/) section, then move on to an application that maintains and modifies state.

## A Stateless Application - Reverse Words

The `reverse` application is going to receive text as its input, reverse it, and then send out the reversed text to its sink. In order to do this, our application needs to provide the following functions:

* Input decoding - how to translate the incoming bytestream into a Go string
* Computation - this is where the input string is going to get reversed
* Output encoding - how to construct and format the bytestream that will be sent out by the sink

### Computation

Let's start with the computation, because that's the purpose of the application:

```go
type Reverse struct {}

func (r *Reverse) Name() string {
  return "reverse"
}

func (r *Reverse) Compute(data interface{}) interface{} {
  input := *(data.(*string))

  // string reversal taken from
  // https://groups.google.com/forum/#!topic/golang-nuts/oPuBaYJ17t4

  n := 0
  rune := make([]rune, len(input))
  for _, r := range input {
    rune[n] = r
    n++
  }
  rune = rune[0:n]
  // Reverse
  for i := 0; i < n/2; i++ {
    rune[i], rune[n-1-i] = rune[n-1-i], rune[i]
  }
  // Convert back to UTF-8.
  output := string(rune)

  return output
}
```

A Computation has no state, so it only needs to define its name, and how to convert input data into output data. In this case, string reversal is done using some code we got from the `go-lang nuts` forum. 

You'll notice that the type of argument to `Compute` is `interface {}`. Your data types are opaque to Wallaroo and could be of any type. For this reason, you'll see `interface {}` used in a number of places in the Wallaroo Go API. 

### Sink Encoder

Next, we are going to define how the output gets constructed for the sink. It is important to remember that Wallaroo sends its output over the network, so data going through the sink needs to be of type `[]byte`.

```go
type Encoder struct {}

func (e *Encoder) Encode(data interface {}) []byte {
  msg := data.(string)
  return []byte(msg + "\n")
```

### SourceDecoder

Now, we also need to decode the incoming bytes of the source.

```go
type Decoder struct {}

func (d *Decoder) HeaderLength() uint64 {
  return 4
}

func (d *Decoder) PayloadLength(b []byte) uint64 {
  return uint64(binary.BigEndian.Uint32(b[0:4]))
}

func (d* Decoder) Decode(b []byte) interface{} {
  x := string(b[:])
  return &x
}
```

This one is different. Wallaroo handles _streams of bytes_, and in order to do that efficiently, it uses a method called message framing. This means that Wallaroo requires input data to follow a special structure, as well as for the application to provide the mechanism with which to decode this data.

To read more about this, please refer to the [Creating A Decoder](/book/core-concepts/decoders-and-encoders.md#creating-a-decoder) section.

For our application purposes, we will simply define the structure and how it is going to get parsed:

1. Input messages have the following structure: A fixed length `PAYLOAD_SIZE` followed by `PAYLOAD`
2. Wallaroo requires three methods to parse this type of message:
  1. `HeaderLength()`, which returns the number of bytes used for the `PAYLOAD_SIZE` in the message. This value tells Wallaroo how many bytes to read from the stream as `HEADER`.
  2. `PayloadLength([]byte)`, which reads `PAYLOAD_SIZE` bytestring of the size returned by `HeaderLength()` and computes the size of `PAYLOAD`. It then returns that size as an integer to Wallaroo, which will then read that many bytes from the stream.
  3. `Decode([]byte)`, which receives the remainder of the message, `MSG`, and decodes it into a Go object. 

In our case:

* `PAYLOAD_SIZE` is a big-endian unsigned 64-bit integer, so we return `4` from `HeaderLength()` and use `uint64(binary.BigEndian.Uint32(b[0:4]))` to read it as an integer.
* `PAYLOAD` is our text that we are going to reverse.

### Application Setup

So now that we have input decoding, computation, and output decoding defined, how do we build it all into an application?

For this, two things are needed:

1. An entry point for Wallaroo to create the application. This is the function `ApplicationSetup()` that you need to define.
2. The actual topology `ApplicationSetup()` is going to return for Wallaroo to create the application.

#### Application Builder and Pipelines

An application is constructed of pipelines which, in turn, are constructed from a sequence of a source, steps, and optionally a sink. Our reverse application only has one pipeline, so we only need to create one:

```go
application := app.MakeApplication("Reverse Word")
application.NewPipeline("Reverse", app.MakeTCPSourceConfig("127.0.0.1", "7010", &Decoder{})).
```

Each pipeline must have a source, and each source must have a decoder, so `NewPipeline` takes a name and a `TCPSourceConfig` instance as its arguments.

Next, we add the computation step:

```go
To(&ReverseBuilder{}).
```

And finally, we add the sink, using a `TCPSinkConfig`:

```python
ToSink(app.MakeTCPSinkConfig("127.0.0.1", "7002", &Encoder{}))
```

### The `ApplicationSetup` Entry Point

After Wallaroo has loaded the application's python file, it will try to execute its `ApplicationSetup()` function. This function is where the application builder steps from above are going to run.

```python
//export ApplicationSetup
func ApplicationSetup() *C.char {
  wa.Serialize = Serialize
  wa.Deserialize = Deserialize

  application := app.MakeApplication("Reverse Word")
  application.NewPipeline("Reverse", app.MakeTCPSourceConfig("127.0.0.1", "7010", &Decoder{})).
    To(&ReverseBuilder{}).
    ToSink(app.MakeTCPSinkConfig("127.0.0.1", "7002", &Encoder{}))

  return C.CString(application.ToJson())
}
```

Configuration objects are used to pass information about sources and sinks to the application builder.

Wallaroo provides convenience the functions `tcp_parse_input_addrs` and `tcp_parse_output_addrs` to parse host and port information that is passed on the command line, or the user can supply their own code for getting these values. When using the convenience functions, host/port pairs are represented on the command line as colon-separated values and multiple host/port values are represented by a comma-separated list of host/port values. The functions assume that `--in` is used for input addresses, and `--out` is used for output addresses. For example, this set of command line arguments would specify two input host/port values and one output:

```bash
--in localhost:7001,localhost:7002 --out localhost:7010
```

## Running `reverse`

The complete example is available [here](https://github.com/WallarooLabs/wallaroo/tree/{{ book.wallaroo_version }}/examples/go/reverse/). To run it, follow the [Reverse application instructions](https://github.com/WallarooLabs/wallaroo/tree/{{ book.wallaroo_version }}/examples/go/reverse/README.md)

## Next Steps

To learn how to write a stateful application, continue to [Writing Your Own Stateful Application](writing-your-own-stateful-application.md).
