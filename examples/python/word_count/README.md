# Word count

## About The Application

This is an example application that receives strings of text, splits it into individual words and counts the occurrences of each word.

### Input

The inputs of the "Word Count" application are strings encoded in the [source message framing protocol](https://docs.wallaroolabs.com/book/appendix/tcp-decoders-and-encoders.html#framed-message-protocols#source-message-framing-protocol). Here's an example of an input message, written as a Python string:

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

In order to run the application you will need Machida, Giles Sender, and the Cluster Shutdown tool. We provide instructions for building these tools yourself and we provide prebuilt binaries within a Docker container. Please visit our [setup](https://docs.wallaroolabs.com/book/getting-started/choosing-an-installation-option.html) instructions to choose one of these options if you have not already done so.

You will need three separate shells to run this application. Open each shell and go to the `examples/python/word_count` directory.

### Shell 1

Run `nc` to listen for TCP output on `127.0.0.1` port `7002`:

```bash
nc -l 127.0.0.1 7002
```

### Shell 2

Set `PATH` to refer to the directory that contains the `machida` executable. Set `PYTHONPATH` to refer to the current directory (where `word_count.py` is) and the `machida` directory (where `wallaroo.py` is). Assuming you installed Wallaroo according to the tutorial instructions you would do:

**Note:** If running in Docker, the `PATH` and `PYTHONPATH` variables are pre-set for you to include the necessary directories to run this example.

```bash
export PATH="$PATH:$HOME/wallaroo-tutorial/wallaroo/machida/build:$HOME/wallaroo-tutorial/wallaroo/giles/sender:$HOME/wallaroo-tutorial/wallaroo/utils/cluster_shutdown"
export PYTHONPATH="$PYTHONPATH:.:$HOME/wallaroo-tutorial/wallaroo/machida"
```

Run `machida` with `--application-module word_count`:

```bash
machida --application-module word_count --in 127.0.0.1:7010 --out 127.0.0.1:7002 \
  --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 --data 127.0.0.1:6001 \
  --name worker-name --external 127.0.0.1:5050 --cluster-initializer \
  --ponythreads=1 --ponynoblock
```

### Shell 3

Set `PATH` to refer to the directory that contains the `sender`  executable. Assuming you installed Wallaroo according to the tutorial instructions you would do:

**Note:** If running in Docker, the `PATH` variable is pre-set for you to include the necessary directories to run this example.

```bash
export PATH="$PATH:$HOME/wallaroo-tutorial/wallaroo/machida/build:$HOME/wallaroo-tutorial/wallaroo/giles/sender:$HOME/wallaroo-tutorial/wallaroo/utils/cluster_shutdown"
```
Send messages:

```bash
sender --host 127.0.0.1:7010 --file count_this.txt \
  --batch-size 5 --interval 100_000_000 --messages 10000000 \
  --ponythreads=1 --ponynoblock --repeat --no-write
```

## Reading the Output

There will be a stream of output messages in the first shell (where you ran `nc`).

## Shutdown

Set `PATH` to refer to the directory that contains the `cluster_shutdown` executable. Assuming you installed Wallaroo  according to the tutorial instructions you would do:

**Note:** If running in Docker, the `PATH` variable is pre-set for you to include the necessary directories to run this example.

```bash
export PATH="$PATH:$HOME/wallaroo-tutorial/wallaroo/machida/build:$HOME/wallaroo-tutorial/wallaroo/giles/sender:$HOME/wallaroo-tutorial/wallaroo/utils/cluster_shutdown"
```

You can shut down the Wallaroo cluster with this command once processing has finished:

```bash
cluster_shutdown 127.0.0.1:5050
```

You can shut down Giles Sender by pressing `Ctrl-c` from its shell.
