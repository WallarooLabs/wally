---
title: "Word Count"
menu:
  toc:
    parent: "ponytutorial"
    weight: 40
toc: true
---
Word count is the canonical streaming data application. It's canonical not because everyone needs to count words but because it's a good platform for demonstrating how to do many of the everyday tasks in a streaming application.

This section will take you through our [Wallaroo word count example](https://github.com/WallarooLabs/wallaroo/tree/{{% wallaroo-version %}}/examples/pony/word_count/). Along the way, we will introduce you to two new concepts: receiving and decoding data on a TCPSource, and splitting one incoming message into several outgoing ones.

## Word count

Our word counting application receives text input in the form of chunks of text. It then splits those chunks into lines and from there into individual words. We then send those words to a stateful partition where we increment the running count and finally, after updating, send as output the word and its current count.

### Application Setup

Let's dive in and take a look at our application setup:

```
let pipeline = recover val
  let lines = Wallaroo.source[String]("Word Count",
    TCPSourceConfig[String].from_options(StringFrameHandler,
          TCPSourceConfigCLIParser("Word Count", env.args)?, 1))

  lines
    .to[String](Split)
    .key_by(ExtractWord)
    .to[RunningTotal](AddCount)
    .to_sink(TCPSinkConfig[RunningTotal].from_options(
      RunningTotalEncoder, TCPSinkConfigCLIParser(env.args)?(0)?))
end
Wallaroo.build_application(env, "Word Count", pipeline)
```

By now, hopefully, most of this looks somewhat familiar. We're building on concepts we've seen in our previous example applications. But instead of using an internal generator source to simulate inputs, we're listening on a TCPSource for lines of text from an external system:

```
let lines = Wallaroo.source[String]("Word Count",
    TCPSourceConfig[String].from_options(StringFrameHandler,
          TCPSourceConfigCLIParser("Word Count", env.args)?, 1))
```

### Decoding Inputs

We have to supply a decoder for decoding the bytes received over TCP. We are going to be receiving framed TCP messages, each with a 4-byte header representing the payload length:

```
primitive StringFrameHandler is FramedSourceHandler[String]
  fun header_length(): USize =>
    4

  fun payload_length(data: Array[U8] iso): USize ? =>
    Bytes.to_u32(data(0)?, data(1)?, data(2)?, data(3)?).usize()

  fun decode(data: Array[U8] val): String =>
    String.from_array(data)
```

`header_length` is used internally to decode our message header to determine how long the payload is going to be. We rely on the WallarooLabs `Bytes` package to decode the bytes. Remember, when using `Bytes`, don't forget to import it using `use "wallaroo_labs/bytes"`!

`decode` takes a series of bytes that represent your payload and turns it into an application message. In this case, our application message is a string, so we take the incoming byte stream `data` and convert it to a Pony string.

### Splitting words

After we decode a group of incoming lines, we pass it along to a stateless computation called `split`. `split` is responsible for breaking the text down into individual words. Our word splitting is mostly uninteresting, except for one important difference: our previous examples had one output for each input. When splitting text into words, we take one input and produce multiple outputs. Let's see how that is done.

```
primitive Split is StatelessComputation[String, String]
  fun name(): String => "Split"

  fun apply(s: String): Array[String] val =>
    let punctuation = """ !"#$%&'()*+,-./:;<=>?@[\]^_`{|}~ """
    let words = recover trn Array[String] end
    for line in s.split("\n").values() do
      let cleaned =
        recover val s.clone().>lower().>lstrip(punctuation)
          .>rstrip(punctuation) end
      for word in cleaned.split(punctuation).values() do
        words.push(word)
      end
    end
    consume words
```

Previously, we've seen our stateless computations have a _one-to-one_ relationship between input and output. In this example, we have a _one-to-many_ relationship. This is indicated by the use of `Array[String]` as the return type of our `apply` function.

Our goal is to handle each word individually. By returning a `Array[String]` as part of our computation, we can then route each string for counting. If you look below, you can see that our word key extractor function is expecting a single word, not a list of words, which makes sense.

```
primitive ExtractWord
  fun apply(word: String): Key =>
    word
```

### Our counting guts

The next classes and primitive are the core of our word counting application. By this point, our messages have been split into individual words and run through our `ExtractWork`'s `apply` function and will arrive at a state computation based on which word it is.

Let's take a look at what we have. `AddCount` is a state computation. When it's run, we update our `WordTotal` state to reflect the new incoming `word`. Then, it returns the running total for that word.

```
class val RunningTotal
  let word: String
  let count: U64

  new val create(w: String, c: U64) =>
    word = w
    count = c

class WordTotal is State
  var count: U64

  new create(c: U64) =>
    count = c

primitive AddCount is StateComputation[String, RunningTotal, WordTotal]
  fun name(): String => "Add Count"

  fun apply(word: String, state: WordTotal): RunningTotal =>
    state.count = state.count + 1
    RunningTotal(word, state.count)

  fun initial_state(): WordTotal =>
    WordTotal(0)
```

### Hello world! I'm a `WordCount`.

By this point, our running word count has almost made it to the end of the pipeline. The only thing left is the sink and encoding. We don't do anything fancy with our encoding. We take the word and its count, and we format it into a single line of text that our receiver can record.

```
primitive RunningTotalEncoder
  fun apply(t: RunningTotal, wb: Writer = Writer):
    Array[ByteSeq] val
  =>
    let result =
      recover val
        String().>append(t.word).>append(", ").>append(t.count.string())
          .>append("\n")
      end
    @printf[I32]("!!%s".cstring(), result.cstring())
    wb.write(result)
```

### Running `word_count`

The complete example is available [here](https://github.com/WallarooLabs/wallaroo/tree/{{% wallaroo-version %}}/examples/pony/word_count/). To run it, follow the [Word Count application instructions](https://github.com/WallarooLabs/wallaroo/tree/{{% wallaroo-version %}}/examples/pony/word_count/README.md)

## Next Steps

For further reading, please refer to the [Wallaroo Pony API Classes](/pony-tutorial/api/).
