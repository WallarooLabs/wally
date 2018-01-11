# Bringing it all together with word count

Word count is the canonical streaming data application. It's canonical not because everyone needs to count words but because it's a good platform for demonstrating how to do many of the everyday tasks in a streaming application.

This section will take you through our [Wallaroo word count example](https://github.com/WallarooLabs/wallaroo/tree/{{ book.wallaroo_version }}/examples/python/word_count/). Along the way, we will introduce you to a couple of new concepts: parallelizing stateless computations, and splitting one incoming message into several outgoing ones.

## Word count

Our word counting application receives text input in the form of chunks of text. It then splits those chunks into lines and from there into individual words. We then send those words to a stateful partition where we increment the running count and finally, after updating, send as output the word and its current count.

### Application Setup

Let's dive in and take a look at our application setup:

```python
def application_setup(args):
    in_host, in_port = wallaroo.tcp_parse_input_addrs(args)[0]
    out_host, out_port = wallaroo.tcp_parse_output_addrs(args)[0]

    word_partitions = list(string.ascii_lowercase)
    word_partitions.append("!")

    ab = wallaroo.ApplicationBuilder("Word Count Application")
    ab.new_pipeline("Split and Count",
                    wallaroo.TCPSourceConfig(in_host, in_port, decoder))
    ab.to_parallel(split)
    ab.to_state_partition(count_word, WordTotals, "word totals",
        partition, word_partitions)
    ab.to_sink(wallaroo.TCPSinkConfig(out_host, out_port, encoder))
    return ab.build()
```

By now, hopefully, most of this looks somewhat familiar. We're building on concepts we've seen in our previous example applications. We set up a new application with a single pipeline:

```python
ab = wallaroo.ApplicationBuilder("Word Count Application")
ab.new_pipeline("Split and Count",
                wallaroo.TCPSourceConfig(in_host, in_port, decoder))
```

Upon receiving some textual input, our word count application will route it to a stateless computation called `split`. `split` is responsible for breaking the text down into individual words. You might notice something a little different about how we set up this stateless computation. In our previous example, we called `to` on our application builder. In this case, we are calling `to_parallel`. What's the difference between `to` and `to_parallel`? The `to` method creates a single instance of the stateless computation. No matter how many workers we might run in our Wallaroo cluster, there will only be a single instance of the computation. Every message that is processed by the computation will need to be routed the worker running that computation. `to_parallel` is different. By doing `to_parallel(split)`, we are placing the `split` computation on every worker in our cluster.

### A `to` vs `to_parallel` digression

Parallelizing a stateless computation seems like something you'd always want to do. So why does `to` exist? Message ordering. Some applications require that all incoming messages maintain ordering. Some don't. If we don't care about message order, we probably want to use `to_parallel`.

Imagine that our word splitting application has the following two blocks of text arrive:

```text
BLOCK 1:

Hello there, how are you?

BLOCK 2:

Fred needs help.
```

In the case of word count, it doesn't matter what order we count the messages. We just want to do it quickly. `to_parallel` is our friend. However, if all words starting with the letter "h" were going to be sent along to the same computation after splitting **and** the order they arrived was important than `to_parallel` would not be our friend. If the computation that deals with the letter "h" needs to see "Hello" then "how" and then "help", you have to use `to`. It will maintain ordering by processing the incoming blocks sequentially rather than in parallel.

In our current case, counting words, we don't care about the order of the words, so `to_parallel` is fine.

### Application setup, the return

Back to our application setup:

```python
def application_setup(args):
    in_host, in_port = wallaroo.tcp_parse_input_addrs(args)[0]
    out_host, out_port = wallaroo.tcp_parse_output_addrs(args)[0]

    word_partitions = list(string.ascii_lowercase)
    word_partitions.append("!")

    ab = wallaroo.ApplicationBuilder("Word Count Application")
    ab.new_pipeline("Split and Count",
                    wallaroo.TCPSourceConfig(in_host, in_port, decoder))
    ab.to_parallel(split)
    ab.to_state_partition(count_word, WordTotals, "word totals",
        partition, word_partitions)
    ab.to_sink(wallaroo.TCPSinkConfig(out_host, out_port, encoder))
    return ab.build()
```

Beyond `to_parallel`, there's nothing new in our word count application. After we split our text chunks into words, they get routed to a state partition where they are counted.

```python
    ab.to_state_partition(count_word, WordTotals, "word totals",
        partition, word_partitions)
```

Note we set up 27 partitions to count our words, one for each letter plus one called "!" which will handle any "word" that doesn't start with a letter:

```python
word_partitions = list(string.ascii_lowercase)
word_partitions.append("!")

...

ab.to_state_partition(count_word, WordTotals, "word totals",
    partition, word_partitions)
```

### Splitting words

Our word splitting is mostly uninteresting, except for one huge difference: our previous examples had one output for each input. When splitting text into words, we take one input and produce multiple outputs. Let's see how that is done.

```python
@wallaroo.computation_multi(name="split into words")
def split(data):
    punctuation = " !\"#$%&'()*+,-./:;<=>?@[\]^_`{|}~"

    words = []

    for line in data.split("\n"):
        clean_line = line.lower().strip(punctuation)
        for word in clean_line.split(' '):
            clean_word = word.strip(punctuation)
            words.append(clean_word)

    return words
```  

Did you catch what is going on? Previously, we've seen our stateless computations wrapped by the `computation` decorator. Why do we have both `computation` and `computation_multi`? The answer lies in Python's type system.

### `computation` vs `computation_multi`

Wallaroo's Python API allows a programmer to indicate that the output of a computation is meant to be treated as a single output by using the `compute` method. This allows us, for example, to split some text into words and have that list of words treated as a single item by Wallaroo. In our word splitting case, that isn't what we want. We want each word to be handled individually. `compute_multi` lets us tell Wallaroo that each of these words is a new message and should be handled individually.

By using `computation_multi`, each word will be handled individually. This allows us to then route each one based on its first letter for counting. If you look below, you can see that our word partitioning function is expecting words, not a list, which makes sense.

```python
@wallaroo.partition
def partition(data):
    if data[0] >= 'a' or data[0] <= 'z':
        return data[0]
    else:
        return "!"
```

### Our counting guts

The next three classes are the core of our word counting application. By this point, our messages have been split into individual words and run through our `partition` function and will arrive at a state computation based on the first letter of the word.

Let's take a look at what we have. `CountWord` is a State Computation. When it's run, we update our `word_totals` state to reflect the new incoming `word`. Then, it returns a tuple of the return value from `word_totals.get_count` and `True`. The return value of `get_count` is an instance of the `WordCount` class containing the word and its current count.

```python
@wallaroo.state_computation(name="Count Word")
def count_word(word, word_totals):
    word_totals.update(word)
    return (word_totals.get_count(word), True)


class WordCount(object):
    def __init__(self, word, count):
        self.word = word
        self.count = count
```

`WordTotals` isn't all that interesting. When we `update`, we check to see if we have seen the word before and if not, add it to our map of words and set the count to one. If we have seen the word before, we increment its count. `get_count` looks up a word and returns a `WordCount` for it.

```python
class WordTotals(object):
    def __init__(self):
        self.word_totals = {}

    def update(self, word):
        if self.word_totals.has_key(word):
            self.word_totals[word] = self.word_totals[word] + 1
        else:
            self.word_totals[word] = 1

    def get_count(self, word):
        return WordCount(word, self.word_totals[word])
```

### Hello world! I'm a `WordCount`.

By this point, our word has almost made it to the end of the pipeline. The only thing left is the sink and encoding. We don't do anything fancy with our encoding. We take the word and its count, and we format it into a single line of text that our receiver can record.

```python
@wallaroo.encoder
def encoder(data):
    return data.word + " => " + str(data.count) + "\n"
```

### Running `word_count.py`

The complete example is available [here](https://github.com/WallarooLabs/wallaroo/tree/{{ book.wallaroo_version }}/examples/python/word_count/). To run it, follow the [Word Count application instructions](https://github.com/WallarooLabs/wallaroo/tree/{{ book.wallaroo_version }}/examples/python/word_count/README.md)

### Next Steps

To learn how to make your application resilient and able to work across multiple workers, please continue to [Inter-worker Serialization and Resilience](interworker-serialization-and-resilience.md).

For further reading, please refer to the [Wallaroo Python API Classes](api.md).
