# Alphabet

## About The Application

This is an example application that takes "votes" for different letters of the alphabet and keeps a running total of the votes received for each letter. For each incoming message, it sends out a message with the total votes for that letter. The total number of votes for each letter are stored together in a single state object.

### Input

The inputs to the "Alphabet" application are the letter receiving the vote followed by a 32-bit integer representing the number of votes for this message, with the whole thing encoded in the [source message framing protocol](https://docs.wallaroolabs.com/book/appendix/tcp-decoders-and-encoders.html#framed-message-protocols). Here's an example input message, written as a Python string:

```
"\x00\x00\x00\x05A\x00\x00\x15\x34"
```

`\x00\x00\x00\x05` -- four bytes representing the number of bytes in the payload
`A` -- a single byte representing the letter "A", which is receiving the votes
`\x00\x00\x15\x34` -- the number `0x1534` (`5428`) represented as a big-endiant 32-bit integer

### Output

The outputs of the alphabet application are the letter that received the votes that triggered this message, followed by a 64-bit integer representing the total number of votes for this letter, with the whole thing encoded in the [source message framing protocol](https://docs.wallaroolabs.com/book/appendix/tcp-decoders-and-encoders.html#framed-message-protocols). Here's an example input message, written as a Python string:

```
"\x00\x00\x00\x09q\x00\x00\x5A\x21\x10\xB7\x11\xA4"
```

`\x00\x00\x00\x09` -- four bytes representing the number of bytes in the payload
`q` -- a single byte representing the letter "q", which is receiving the votes
`\x00\x00\x5A\x21\x10\xB7\x11\xA4` -- the number `0x5A2110B711A4` (`99098060853668`) represented as a big-endiant 64-bit integer

### Processing

The `Decoder`'s `decode(...)` method creates a `Votes` object with the letter being voted on and the number of votes it is receiving with this message. The `Votes` object is passed with the `AddVotes` computation to the state object that stores all of the vote totals, and the `compute(...)` function modifies the state to record the new total number of votes for the letter. It then creates an `AllVotes` message, which is sent to `Encode`'s `encode(...)` method, which converts it into an outgoing message.

## Running Alphabet

In order to run the application you will need Machida, Giles Sender, and the Cluster Shutdown tool. We provide instructions for building these tools yourself and we provide prebuilt binaries within a Docker container. Please visit our [setup](https://docs.wallaroolabs.com/book/getting-started/choosing-an-installation-option.html) instructions to choose one of these options if you have not already done so.

You will need three separate shells to run this application. Open each shell and go to the `examples/python/alphabet` directory.


### Shell 1

Run `nc` to listen for TCP output on `127.0.0.1` port `7002`:

```bash
nc -l 127.0.0.1 7002 > alphabet.out
```

### Shell 2

Set `PATH` to refer to the directory that contains the `machida` executable. Set `PYTHONPATH` to refer to the current directory (where `alphabet.py` is) and the `machida` directory (where `wallaroo.py` is). Assuming you installed Wallaroo according to the tutorial instructions you would do:

**Note:** If running in Docker, the `PATH` and `PYTHONPATH` variables are pre-set for you to include the necessary directories to run this example.

```bash
export PATH="$PATH:$HOME/wallaroo-tutorial/wallaroo/machida/build:$HOME/wallaroo-tutorial/wallaroo/giles/sender:$HOME/wallaroo-tutorial/wallaroo/utils/cluster_shutdown"
export PYTHONPATH="$PYTHONPATH:.:$HOME/wallaroo-tutorial/wallaroo/machida"
```

Run `machida` with `--application-module alphabet`:

```bash
machida --application-module alphabet --in 127.0.0.1:7010 \
  --out 127.0.0.1:7002 --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 \
  --external 127.0.0.1:5050 --cluster-initializer --data 127.0.0.1:6001 \
  --name worker-name --ponythreads=1 --ponynoblock
```

### Shell 3

Set `PATH` to refer to the directory that contains the `sender`  executable. Assuming you installed Wallaroo according to the tutorial instructions you would do:

**Note:** If running in Docker, the `PATH` variable is pre-set for you to include the necessary directories to run this example.

```bash
export PATH="$PATH:$HOME/wallaroo-tutorial/wallaroo/machida/build:$HOME/wallaroo-tutorial/wallaroo/giles/sender:$HOME/wallaroo-tutorial/wallaroo/utils/cluster_shutdown"
```

Send messages:

```bash
sender --host 127.0.0.1:7010 --file votes.msg \
  --batch-size 50 --interval 10_000_000 --messages 1000000 --binary \
  --msg-size 9 --repeat --ponythreads=1 --ponynoblock --no-write
```
## Reading the Output

You can read the output with the following code:

```python
import struct

num_bytes = 4 + 1 + 8
with open('alphabet.out', 'rb') as f:
    while True:
        try:
            print struct.unpack('>IsQ', f.read(num_bytes))
        except:
            break
```

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
