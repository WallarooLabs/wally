# Bringing it all together with word count

Word count is the canonical streaming data application. It's canonical not because everyone needs to count words but because it's a good platform for demonstrating how to do many of the everyday tasks in a streaming application.

This section will take you through our [Wallaroo word count example](https://github.com/WallarooLabs/wallaroo/tree/{{ book.wallaroo_version }}/examples/go/word_count/). Along the way, we will introduce you to a couple of new concepts: parallelizing stateless computations, and splitting one incoming message into several outgoing ones.

## Word count

Our word counting application receives text input in the form of chunks of text. It then splits those chunks into lines and from there into individual words. We then send those words to a stateful partition where we increment the running count and finally, after updating, send as output the word and its current count.

### Application Setup

Let's dive in and take a look at our application setup:

```go
//export ApplicationSetup
func ApplicationSetup() *C.char {
	fs := flag.NewFlagSet("wallaroo", flag.ExitOnError)
	inHostsPortsArg := fs.String("in", "", "input host:port list")
	outHostsPortsArg := fs.String("out", "", "output host:port list")

	fs.Parse(wa.Args[1:])

	inHostsPorts := hostsPortsToList(*inHostsPortsArg)

	inHost := inHostsPorts[0][0]
	inPort := inHostsPorts[0][1]

	outHostsPorts := hostsPortsToList(*outHostsPortsArg)
	outHost := outHostsPorts[0][0]
	outPort := outHostsPorts[0][1]

	wa.Serialize = Serialize
	wa.Deserialize = Deserialize

	application := app.MakeApplication("Word Count Application")
	application.NewPipeline("Split and Count", app.MakeTCPSourceConfig(inHost, inPort, &Decoder{})).
		ToMulti(&SplitBuilder{}).
		ToStatePartition(&CountWord{}, &WordTotalsBuilder{}, "word totals", &WordPartitionFunction{}, LetterPartition(), true).
		ToSink(app.MakeTCPSinkConfig(outHost, outPort, &Encoder{}))

	json := application.ToJson()

	return C.CString(json)
}
```

By now, hopefully, most of this looks somewhat familiar. We're building on concepts we've seen in our previous example applications. We get the input and output information from the command line:

```go
	fs := flag.NewFlagSet("wallaroo", flag.ExitOnError)
	inHostsPortsArg := fs.String("in", "", "input host:port list")
	outHostsPortsArg := fs.String("out", "", "output host:port list")

	fs.Parse(wa.Args[1:])

	inHostsPorts := hostsPortsToList(*inHostsPortsArg)

	inHost := inHostsPorts[0][0]
	inPort := inHostsPorts[0][1]
```

We point the Wallaroo serialization and deserialization functions to our serializer and deserializer:

```go
	wa.Serialize = Serialize
	wa.Deserialize = Deserialize
```

We set up a new application with a single pipeline:

```go
	application := app.MakeApplication("Word Count Application")
	application.NewPipeline("Split and Count", app.MakeTCPSourceConfig(inHost, inPort, &Decoder{})).
		ToMulti(&SplitBuilder{}).
		ToStatePartition(&CountWord{}, &WordTotalsBuilder{}, "word totals", &WordPartitionFunction{}, LetterPartition(), true).
		ToSink(app.MakeTCPSinkConfig(outHost, outPort, &Encoder{}))
```

Upon receiving some textual input, our word count application will route it to a stateless computation called `Split`. `Split` is responsible for breaking the text down into individual words:

```go
		ToMulti(&SplitBuilder{}).
```

After we split our text chunks into words, they get routed to a state partition where they are counted:

```go
		ToStatePartition(&CountWord{}, &WordTotalsBuilder{}, "word totals", &WordPartitionFunction{}, LetterPartition(), true).
```

Note we set up 27 partitions to count our words, one for each letter plus one called "!" which will handle any "word" that doesn't start with a letter:

```go
func LetterPartition() []uint64 {
	letterPartition := make([]uint64, 27)

	for i := 0; i < 26; i++ {
		letterPartition[i] = uint64(i + 'a')
	}

	letterPartition[26] = '!'

	return letterPartition
}
```

## Splitting Words

Our word splitting is mostly uninteresting, except for one huge difference: our previous examples had one output for each input. When splitting text into words, we take one input and produce multiple outputs. Let's see how that is done.

```go
type Split struct {}

func (s *Split) Name() string {
	return "split"
}

func (s *Split) Compute(data interface{}) []interface{} {
	punctuation := " !\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~"
	lines := data.(*string)

	words := make([]interface{}, 0)

	for _, line := range strings.Split(*lines, "\n") {
		clean_line := strings.Trim(strings.ToLower(line), punctuation)
		for _, word := range strings.Split(clean_line, " ") {
			clean_word := strings.Trim(word, punctuation)
			words = append(words, &clean_word)
		}
	}

	return words
}
```

Did you catch what is going on? Previously, we've seen our stateless computations have a `Compute` method that returns an `interface{}`. `Split` returns a `[]interface{}`. Each item in the slice is a new message that is sent individually to the next step in the pipeline. This allows us to then route each message based on its first letter for counting. If you look below, you can see that our word partitioning function is expecting words, not a list, which makes sense:

```go
type WordPartitionFunction struct {}

func (wpf *WordPartitionFunction) Partition (data interface{}) uint64 {
	word := data.(*string)
	firstLetter := (*word)[0]
	if (firstLetter >= 'a') && (firstLetter <= 'z') {
		return uint64(firstLetter)
	}
	return uint64('!')
}
```

### Our Counting Guts

The next three classes are the core of our word counting application. By this point, our messages have been split into individual words and run through our `WordPartitionFunction` and will arrive at a state computation based on the first letter of the word.

Let's take a look at what we have. `CountWord` is a `StateComputation`. When it's run, we update our state to reflect the new incoming word. Then, it returns the return value from `wordTotals.GetCount` and `true`. The return value of `GetCount` is an instance of the `WordCount` class containing the word and its current count.

```go
type CountWord struct {}

func (cw *CountWord) Name() string {
	return "count word"
}

func (cw *CountWord) Compute(data interface{}, state interface{}) (interface{}, bool) {
	word := data.(*string)
	wordTotals := state.(*WordTotals)
	wordTotals.Update(*word)
	return wordTotals.GetCount(*word), true
}
```

`WordTotals` isn't all that interesting. When we `Update`, we check to see if we have seen the word before and if not, add it to our map of words and set the count to one. If we have seen the word before, we increment its count. `GetCount` looks up a word and returns a `WordCount` for it.

```go
func MakeWordTotals() *WordTotals {
	return &WordTotals{ make(map[string]uint64) }
}

type WordTotals struct {
	WordTotals map[string]uint64
}

func (wordTotals *WordTotals) Update(word string) {
	total, found := wordTotals.WordTotals[word]
	if !found {
		total = 0
	}
	wordTotals.WordTotals[word] = total + 1
}

func (wordTotals *WordTotals) GetCount(word string) *WordCount {
	return &WordCount{word, wordTotals.WordTotals[word]}
}
```

### Hello World! I'm a `WordCount`.

By this point, our word has almost made it to the end of the pipeline. The only thing left is the sink and encoding. We don't do anything fancy with our encoding. We take the word and its count, and we format it into a single line of text that our receiver can record.

```go
type Encoder struct {}

func (encoder *Encoder) Encode(data interface{}) []byte {
	word_count := data.(*WordCount)
	msg := fmt.Sprintf("%s => %d\n", word_count.Word, word_count.Count)
	fmt.Println(msg)
	return []byte(msg)
}
```

### Running `word_count`

The complete example is available [here](https://github.com/WallarooLabs/wallaroo/tree/{{ book.wallaroo_version }}/examples/go/word_count/). To run it, follow the [Word Count application instructions](https://github.com/WallarooLabs/wallaroo/tree/{{ book.wallaroo_version }}/examples/go/word_count/README.md)

### Next Steps

For further reading, please refer to the [Wallaroo Go API Classes](api.md).
