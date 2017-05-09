# Decoders and Encoders

Wallaroo currently only supports TCP sources and TCP sinks (though we will be adding more source and sink types in the near future). When using TCP for your input and output streams, you need a way to convert a stream of bytes to your application input types and  to convert your application output types to a stream of bytes. This is where decoders and encoders come in. 

## Creating a Decoder

Currently, Wallaroo assumes that you will be using the following protocol for the stream of bytes sent into the system over TCP:

```
PayloadSize [x bytes] : Payload [bytes specified in PayloadSize]
```

You decide both how many bytes you will use to specify the payload size (depending on whether you're encoding a 16, 32, or 64-bit  integer, for example) and how you encode that size (for example, using a big-endian or little-endian encoding).  

In order for Wallaroo to know how to parse your incoming stream, you need to implement a `FramedSourceHandler`. You must implement three methods, where type `In` is the input type for your pipeline:

```pony
fun header_length(): USize
fun payload_length(data: Array[U8] iso): USize ?
fun decode(data: Array[U8] val): In ?
```

`header_length()` will return the fixed size of your PayloadSize field. 

`payload_length()` is a function that takes the bytes of your PayloadSize field and transforms them into an integer of type `USize`.

`decode()` takes the bytes of your Payload field and transforms them to a value of type `In`.

Here's an example taken from our [Alphabet Popularity Contest app](https://github.com/Sendence/wallaroo/tree/master/book/examples/pony/alphabet). We're using a 32-bit payload length header using big-endian encoding. We use the `Bytes` library to convert the four bytes in our header array into a `U32` and then convert that to a `USize` via the `usize()` method:

```pony
primitive VotesDecoder is FramedSourceHandler[Votes val]
  fun header_length(): USize =>
    4

  fun payload_length(data: Array[U8] iso): USize ? =>
    Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()

  fun decode(data: Array[U8] val): Votes val ? =>
    // Assumption: 1 byte for letter
    let letter = String.from_array(data.trim(0, 1))
    let count = Bytes.to_u32(data(1), data(2), data(3), data(4))
    Votes(letter, count)
```

Notice that we have passed in `Votes` as our type argument, since `Votes` is the input type into our pipeline. In the `decode()` method,  we use the first byte in our payload array to get the letter we're voting on and the next four to get the `U32` specifying the vote count for that letter. 

In this example, since the payload will always be 5 bytes long, we could have actually implemented `payload_length()` as:

```pony
fun payload_length(data: Array[U8] iso): USize ? =>
  5
```

In the near future, Wallaroo will allow users to use fixed length protocols without the need for size headers, but at the moment that is not supported.

An example where our payload would not be fixed length is if we are sending in a stream of strings, such as customer names. Here's a possible `FramedSourceHandler` for that case:

```pony
primitive NamesDecoder is FramedSourceHandler[String]
  fun header_length(): USize =>
    4

  fun payload_length(data: Array[U8] iso): USize ? =>
    Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()

  fun decode(data: Array[U8] val): String ? =>
    String.from_array(data)
```

Here our input type to our pipeline is `String`. Our payload size field tells Wallaroo how many bytes to pull out of the stream for each payload, and in this case this size varies over time. Wallaroo will always pass an `Array` of bytes of this size to `decode()`. And then in `decode()` we convert those bytes directly to a `String`.

## Creating an Encoder

If your application uses a TCP sink to send outputs to an external system, then you will need an encoder converting your pipeline output types to a stream of bytes. For this purpose you need to create an encoder `primitive` that implements the following function (where `Out` is the output type for your pipeline):

```pony
fun apply(o: Out, wb: Writer = Writer): Array[ByteSeq] val
```

Wallaroo provides you with a `Writer` which you will use to buffer data to be sent out. Here's an example from the [Alphabet Popularity Contest app](https://github.com/Sendence/wallaroo/tree/master/book/examples/pony/alphabet): 

```pony
primitive LetterTotalEncoder
  fun apply(t: LetterTotal val, wb: Writer = Writer): Array[ByteSeq] val =>
    wb.write(t.letter)
    wb.u32_be(t.count)
    wb.done()
```
