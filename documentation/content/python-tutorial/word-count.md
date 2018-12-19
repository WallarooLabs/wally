---
title: "Word Count"
menu:
  docs:
    parent: "pytutorial"
    weight: 40
toc: true
---
Word count is the canonical streaming data application. It's canonical not because everyone needs to count words but because it's a good platform for demonstrating how to do many of the everyday tasks in a streaming application.

This section will take you through our [Wallaroo word count example](https://github.com/WallarooLabs/wallaroo/tree/{{% wallaroo-version %}}/examples/python/word_count/). Along the way, we will introduce you to two new concepts: receiving and decoding data on a TCPSource, and splitting one incoming message into several outgoing ones.

## Word count

Our word counting application receives text input in the form of chunks of text. It then splits those chunks into lines and from there into individual words. We then send those words to a stateful partition where we increment the running count and finally, after updating, send as output the word and its current count.

### Application Setup

Let's dive in and take a look at our application setup:

```python
def application_setup(args):
    in_host, in_port = wallaroo.tcp_parse_input_addrs(args)[0]
    out_host, out_port = wallaroo.tcp_parse_output_addrs(args)[0]

    lines = wallaroo.source("Split and Count",
                        wallaroo.TCPSourceConfig(in_host, in_port, 
                            decode_lines))
    pipeline = lines\
        .to(split)\
        .key_by(extract_word)\
        .to(count_word)\
        .to_sink(wallaroo.TCPSinkConfig(out_host, out_port, encode_word_count))

    return wallaroo.build_application("Word Count Application", pipeline)
```

By now, hopefully, most of this looks somewhat familiar. We're building on concepts we've seen in our previous example applications. But instead of using an internal generator source to simulate inputs, we're listening on a TCPSource for lines of text from an external system:

```python
lines = wallaroo.source("Split and Count",
                    wallaroo.TCPSourceConfig(in_host, in_port, 
                        decode_line))
```

### Decoding Inputs

We have to supply a decoder for decoding the bytes received over TCP. We are going to be receiving framed TCP messages, each with a 4-byte header representing the payload length:

```python
@wallaroo.decoder(header_length=4, length_fmt=">I")
def decode_lines(bs):
    return bs.decode("utf-8")
```

`length_fmt` is used internally to decode our message header to determine how long the payload is going to be. We rely on the Python `struct` package to decode the bytes. If you aren't familiar with `struct`, you can check out [the documentation](https://docs.python.org/2/library/struct.html) to learn more. Remember, when using `struct`, don't forget to import it!

`decode_word_count` takes a series of bytes that represent your payload and turns it into an application message. In this case, our application message is a string, so we take the incoming byte stream `bs` and convert it to UTF-8 Python string.

### Splitting words

After we decode a group of incoming lines, we pass it along to a stateless computation called `split`. `split` is responsible for breaking the text down into individual words. Our word splitting is mostly uninteresting, except for one important difference: our previous examples had one output for each input. When splitting text into words, we take one input and produce multiple outputs. Let's see how that is done.

```python
@wallaroo.computation_multi(name="split into words")
def split(lines):
    punctuation = " !\"#$%&'()*+,-./:;<=>?@[\]^_`{|}~"

    words = []

    for line in lines.split("\n"):
        clean_line = line.lower().strip(punctuation)
        for word in clean_line.split(" "):
            clean_word = word.strip(punctuation)
            words.append(clean_word)

    return words
```

Previously, we've seen our stateless computations wrapped by the `computation` decorator. Why do we have both `computation` and `computation_multi`? The answer lies in Python's type system.

### `computation` vs `computation_multi`

Wallaroo's Python API allows a programmer to indicate that the output of a computation is meant to be treated as a single output by using the `compute` method. This allows us, for example, to split some text into words and have that list of words treated as a single item by Wallaroo. In our word splitting case, that isn't what we want. We want each word to be handled individually. `compute_multi` lets us tell Wallaroo that each of these words is a new message and should be handled individually.

By using `computation_multi`, each word will be handled individually. This allows us to then route each one for counting. If you look below, you can see that our word key extractor function is expecting words, not a list of words, which makes sense.

```python
@wallaroo.key_extractor
def extract_word(word):
    return word
```

### Our counting guts

The next three classes are the core of our word counting application. By this point, our messages have been split into individual words and run through our `key_extractor` function and will arrive at a state computation based on which word it is.

Let's take a look at what we have. `count_word` is a state computation. When it's run, we update our `WordTotal` state to reflect the new incoming `word`. Then, it returns the running total for that word. 

```python
class WordTotal(object):
    count = 0

@wallaroo.state_computation(name="count word", state=WordTotal)
def count_word(word, word_total):
    word_total.count = word_total.count + 1
    return WordCount(word, word_total.count)
```

### Hello world! I'm a `WordCount`.

By this point, our running word count has almost made it to the end of the pipeline. The only thing left is the sink and encoding. We don't do anything fancy with our encoding. We take the word and its count, and we format it into a single line of text that our receiver can record. As with the previous example, we encode the output for compatibility with both Python 2 and Python 3.

```python
@wallaroo.encoder
def encode_word_count(word_count):
    output = word_count.word + " => " + str(word_count.count) + "\n"
    print output
    return output.encode("utf-8")
```

### Running `word_count.py`

The complete example is available [here](https://github.com/WallarooLabs/wallaroo/tree/{{% wallaroo-version %}}/examples/python/word_count/). To run it, follow the [Word Count application instructions](https://github.com/WallarooLabs/wallaroo/tree/{{% wallaroo-version %}}/examples/python/word_count/README.md)

## Next Steps

To learn how to make your application resilient and able to work across multiple workers, please continue to [Inter-worker Serialization and Resilience](/python-tutorial/interworker-serialization-and-resilience/).

For further reading, please refer to the [Wallaroo Python API Classes](/python-tutorial/api/).
