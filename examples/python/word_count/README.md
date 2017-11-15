# Word count

## About The Application

This is an example application that receives strings of text, splits it into individual words and counts the occurrences of each word.

### Input

The inputs of the "Word Count" application are strings encoded in the [source message framing protocol](/book/core-concepts/decoders-and-encoders.md#framed-message-protocols#source-message-framing-protocol). Here's an example of an input message, written as a Python string:

```
"\x00\x00\x00\x4cMy solitude is cheered by that elegant hope."
```

`\x00\x00\x00\x2c` -- four bytes representing the number of bytes in the payload

`My solitude is cheered by that elegant hope.` -- the payload

### Output

The messages are strings terminated with a newline, with the form `WORD => COUNT` where `WORD` is the word and `COUNT` is the number of times that word has been seen. Each incoming message may generate zero or more output messages, one for each word in the input.

### Processing

The `Decoder`'s `decode(...)` method turns the input message into a string. That string is then passed to `Split`'s `compute_multi(...)` method, which breaks the string into individual words and returns a list containing these words. Each item in the list is sent as a separate message to the state partition for that word, along with the `CountWords` `compute(...)` method, which updates the existing state with a new count for the word and returns a `WordCount` object. The `WordCount` object is then sent to the `Encoder`'s `encode(...)` method where it is turned into an output message as described above.

## Running Word Count

In order to run the application you will need Machida, Giles Sender, and the Cluster Shutdown tool. To build them, please see the [Linux](/book/getting-started/linux-setup.md) or [Mac OS](/book/getting-started/macos-setup.md) setup instructions. Alternatively, they could be run in Docker, please see the [Docker](/book/getting-started/docker-setup.md) setup instructions and our [Run an Application in Docker](/book/getting-started/run-a-wallaroo-application-docker.md) guide if you haven't already done so.

Note: If running in Docker, the relative paths are not necessary for binaries as they are all bound to the PATH within the container. You will not need to set the `PATH` variable and `PYTHONPATH` already includes the current working directory.

You will need three separate shells to run this application. Open each shell and go to the `examples/python/word_count` directory.

### Shell 1

Run `nc` to listen for TCP output on `127.0.0.1` port `7002`:

```bash
nc -l 127.0.0.1 7002
```

### Shell 2

Set `PYTHONPATH` to refer to the current directory (where `celsius.py` is) and the `machida` directory (where `wallaroo.py` is). Set `PATH` to refer to the directory that contains the `machida` executable. Assuming you installed Machida according to the tutorial instructions you would do:

```bash
export PYTHONPATH="$PYTHONPATH:.:$HOME/wallaroo-tutorial/wallaroo/machida"
export PATH="$PATH:$HOME/wallaroo-tutorial/wallaroo/machida/build"
```

Run `machida` with `--application-module word_count`:

```bash
machida --application-module word_count --in 127.0.0.1:7010 --out 127.0.0.1:7002 \
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

There will be a stream of output messages in the first shell (where you ran `nc`).

## Shutdown

You can shut down the cluster with this command once processing has finished:

```bash
../../../utils/cluster_shutdown/cluster_shutdown 127.0.0.1:5050
```

You can shut down Giles Sender by pressing `Ctrl-c` from its shell.
