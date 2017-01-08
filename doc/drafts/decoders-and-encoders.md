# Decoders and Encoders

Wallaroo currently only supports TCP sources and TCP sinks (though
we will be adding more source and sink types in the near future).
When using TCP for your input and output streams, you need a way
to convert a stream of bytes to your application input types and 
to convert your application output types to a stream of bytes. This
is where decoders and encoders come in. 

## Creating a Decoder

Currently, Wallaroo assumes that you will be using the following
protocol for the stream of bytes sent into the system over TCP:

``` 
PayloadSize [x bytes] : Payload [bytes specified in PayloadSize]
```

You decide both how many bytes you will use to specify the payload
size (depending on whether you're encoding a 16, 32, or 64-bit 
integer, for example) and how you encode that size (for example, as
a big-endian or little-endian encoding).  

In order for Wallaroo to know how to parse your incoming stream,
you need to implement a `FramedSourceHandler`. You must implement
three methods, where type `In` is the input type for your stream:

```
  fun header_length(): USize
  fun payload_length(data: Array[U8] iso): USize ?
  fun decode(data: Array[U8] val): In ?
```

`header_length()` will return the fixed size of your PayloadSize
field. 

`payload_length()` is a function that takes the bytes of your PayloadSize 
field and transforms them into an integer of type `USize`.

`decode()` takes the bytes of your Payload field and transforms them to
a value of type `In`.

Here's an example taken from the [Alphabet Popularity Contest app](...).
We're using a 32-bit payload length header using big-endian encoding.
We use the `Bytes` library to convert the four bytes in our header
array into a `U32` and then convert that to a `USize` via the `usize()`
method:

```
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

Notice that we have passed in `Votes` as our type argument, since
`Votes` is the input type into our pipeline. In the `decode()` method, 
we use the first byte in our payload array to get the letter we're voting
on and the next four to get the `U32` specifying the vote count for that
letter. 

In this example, since the payload will always be 5 bytes long, we could have actually implemented `payload_length()` as:

```
  fun payload_length(data: Array[U8] iso): USize ? =>
    5
```

In the near future, Wallaroo will allow users to use fixed length protocols without the need for size headers, but at the moment that is not supported.
