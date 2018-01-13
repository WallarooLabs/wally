# Word Count

This is an example application that receives strings of text, splits it into individual words and counts the occurrences of each word.

### Input

The inputs of the "Word Count" application are strings encoded in the [source message framing protocol](/book/core-concepts/decoders-and-encoders.md#framed-message-protocols#source-message-framing-protocol). Here's an example of an input message, written as a Go string:

```
"\x00\x00\x00\x4cMy solitude is cheered by that elegant hope."
```

`\x00\x00\x00\x2c` -- four bytes representing the number of bytes in the payload

`My solitude is cheered by that elegant hope.` -- the payload

### Output

The messages are strings terminated with a newline, with the form `WORD => COUNT` where `WORD` is the word and `COUNT` is the number of times that word has been seen. Each incoming message may generate zero or more output messages, one for each word in the input.

### Processing

The `Decoder`'s `Decode(...)` method turns the input message into a string. That string is then passed to `Split`'s `Compute(...)` method, which breaks the string into individual words and returns a list containing these words. Each item in the list is sent as a separate message to the state partition for that word, along with the `CountWords` `Compute(...)` method, which updates the existing state with a new count for the word and returns a `WordCount` object. The `WordCount` object is then sent to the `Encoder`'s `Encode(...)` method where it is turned into an output message as described above.

## Building Word Count

In the word_count directory, run `make`.

## Running Word Count

In order to run the application you will need Giles Sender, Data Receiver, and the Cluster Shutdown tool. To build them, please see the [Linux](/book/go/getting-started/linux-setup.md) or [MacOS](/book/go/getting-started/macos-setup.md) setup instructions.

You will need three separate shells to run this application. Open each shell and go to the `examples/go/word_count` directory.

### Shell 1

Run `data_receiver` to listen for TCP output on `127.0.0.1` port `7002`:

```bash
../../../utils/data_receiver/data_receiver --listen 127.0.0.1:7002
```

### Shell 2

Run `word_count`.

```bash
./word_count --in 127.0.0.1:7010 --out 127.0.0.1:7002 \
  --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 --data 127.0.0.1:6001 \
  --name worker-name --external 127.0.0.1:5050 --cluster-initializer \
  --ponythreads=1 --ponynoblock
```

### Shell 3

In a third shell, send some messages:

```bash
../../../giles/sender/sender --host 127.0.0.1:7010 --file count_this.txt \
  --batch-size 5 --interval 100_000_000 --messages 10000000 \
  --ponythreads=1 --ponynoblock --repeat --no-write
```

## Reading the Output

There will be a stream of output messages in the first shell (where you ran `data_receiver`).

## Shutdown

You can shut down the cluster with this command at any time:

```bash
../../../utils/cluster_shutdown/cluster_shutdown 127.0.0.1:5050
```

You can shut down Giles Sender and Data Receiver by pressing `Ctrl-c` from their respective shells.
