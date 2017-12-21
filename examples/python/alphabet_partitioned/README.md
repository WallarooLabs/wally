# Alphabet Partitioned

## About The Application

This is an example application that takes "votes" for different letters of the alphabet and keeps a running total of the votes received for each letter. For each incoming message, it sends out a message with the total votes for that letter. It uses state partitioning to distribute the votes so that they can be processed in parallel; the letter serves as the partitioning key, so, for example, all votes for the letter "A" are handled by the same partition.

### Input

The inputs to the "Alphabet Partitioned" application are the letter receiving the vote followed by a 32-bit integer representing the number of votes for this message, with the whole thing encoded in the [source message framing protocol](/book/core-concepts/decoders-and-encoders.md#framed-message-protocols#source-message-framing-protocol). Here's an example input message, written as a Python string:

```
"\x00\x00\x00\x05A\x00\x00\x15\x34"
```

`\x00\x00\x00\x05` -- four bytes representing the number of bytes in the payload
`A` -- a single byte representing the letter "A", which is receiving the votes
`\x00\x00\x15\x34` -- the number `0x1534` (`5428`) represented as a big-endian 32-bit integer

### Output

The outputs of the alphabet application are the letter that received the votes that triggered this message, followed by a 64-bit integer representing the total number of votes for this letter, with the whole thing encoded in the [source message framing protocol](/book/core-concepts/decoders-and-encoders.md#framed-message-protocols#source-message-framing-protocol). Here's an example input message, written as a Python string:

```
"\x00\x00\x00\x09q\x00\x00\x5A\x21\x10\xB7\x11\xA4"
```

`\x00\x00\x00\x09` -- four bytes representing the number of bytes in the payload
`q` -- a single byte representing the letter "q", which is receiving the votes
`\x00\x00\x5A\x21\x10\xB7\x11\xA4` -- the number `0x5A2110B711A4` (`99098060853668`) represented as a big-endian 64-bit integer

### Processing

The `Decoder`'s `decode(...)` method creates a `Votes` object with the letter being voted on and the number of votes it is receiving with this message. The `Votes` object is passed with the `AddVotes` computation to the state object that handles the letter being voted on, and the `AddVotes` function modifies the state to record the new total number of votes for the letter. It then creates an `AllVotes` message, which is sent to `Encode`'s `encode(...)` method, which converts it into an outgoing message.

## Running Alphabet Partitioned

In order to run the application you will need Machida, Giles Sender, Giles Receiver, and the Cluster Shutdown tool. We provide instructions for building these tools yourself and we provide prebuilt binaries within a Docker container. Please visit our [setup](/book/getting-started/choosing-an-installation-option.md) instructions to choose one of these options if you have not already done so.

You will need four separate shells to run this application. Open each shell and go to the `examples/python/alphabet_partitioned` directory.

### Shell 1

Set `PATH` to refer to the directory that contains the `receiver` executable. Assuming you installed Wallaroo according to the tutorial instructions you would do:

**Note:** If running in Docker, the `PATH` variable is pre-set for you to include the necessary directories to run this example.

```bash
export PATH="$PATH:$HOME/wallaroo-tutorial/wallaroo/machida/build:$HOME/wallaroo-tutorial/wallaroo/giles/sender:$HOME/wallaroo-tutorial/wallaroo/giles/receiver:$HOME/wallaroo-tutorial/wallaroo/utils/cluster_shutdown"
```

Run Giles Receiver to listen for TCP output on `127.0.0.1` port `7002`:

```bash
receiver --ponythreads=1 --ponynoblock \
  --listen 127.0.0.1:7002 --no-write
```

### Shell 2

Set `PATH` to refer to the directory that contains the `machida` executable. Set `PYTHONPATH` to refer to the current directory (where `alphabet_partitioned.py` is) and the `machida` directory (where `wallaroo.py` is). Assuming you installed Machida according to the tutorial instructions you would do:

**Note:** If running in Docker, the `PATH` and `PYTHONPATH` variables are pre-set for you to include the necessary directories to run this example.

```bash
export PATH="$PATH:$HOME/wallaroo-tutorial/wallaroo/machida/build:$HOME/wallaroo-tutorial/wallaroo/giles/sender:$HOME/wallaroo-tutorial/wallaroo/giles/receiver:$HOME/wallaroo-tutorial/wallaroo/utils/cluster_shutdown"
export PYTHONPATH="$PYTHONPATH:.:$HOME/wallaroo-tutorial/wallaroo/machida"
```

Run `machida` with `--application-module alphabet_partitioned` as an initializer:

```bash
machida --application-module alphabet_partitioned --in 127.0.0.1:7010 \
  --out 127.0.0.1:7002 --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 \
  --data 127.0.0.1:6001 --worker-count 2 --cluster-initializer \
  --external 127.0.0.1:5050 --ponythreads=1 --ponynoblock
```

### Shell 3

Set `PATH` to refer to the directory that contains the `machida` executable. Set `PYTHONPATH` to refer to the current directory (where `alphabet_partitioned.py` is) and the `machida` directory (where `wallaroo.py` is). Assuming you installed Machida according to the tutorial instructions you would do:

**Note:** If running in Docker, the `PATH` and `PYTHONPATH` variables are pre-set for you to include the necessary directories to run this example.

```bash
export PATH="$PATH:$HOME/wallaroo-tutorial/wallaroo/machida/build:$HOME/wallaroo-tutorial/wallaroo/giles/sender:$HOME/wallaroo-tutorial/wallaroo/giles/receiver:$HOME/wallaroo-tutorial/wallaroo/utils/cluster_shutdown"
export PYTHONPATH="$PYTHONPATH:.:$HOME/wallaroo-tutorial/wallaroo/machida"
```

Run `machida` with `--application-module alphabet_partitioned` as a worker:

```bash
machida --application-module alphabet_partitioned --in 127.0.0.1:7010 \
  --out 127.0.0.1:7002 --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 \
  --name worker-2 --external 127.0.0.1:6010 --ponythreads=1 --ponynoblock
```

### Shell 4

Set `PATH` to refer to the directory that contains the `sender`  executable. Assuming you installed Wallaroo according to the tutorial instructions you would do:

**Note:** If running in Docker, the `PATH` variable is pre-set for you to include the necessary directories to run this example.

```bash
export PATH="$PATH:$HOME/wallaroo-tutorial/wallaroo/machida/build:$HOME/wallaroo-tutorial/wallaroo/giles/sender:$HOME/wallaroo-tutorial/wallaroo/giles/receiver:$HOME/wallaroo-tutorial/wallaroo/utils/cluster_shutdown"
```

Send messages:

```bash
sender --host 127.0.0.1:7010 \
  --file votes.msg --batch-size 50 --interval 10_000_000 \
  --messages 1000000 --binary --msg-size 9 --repeat --ponythreads=1 \
  --ponynoblock --no-write
```

## Shutdown

Set `PATH` to refer to the directory that contains the `cluster_shutdown` executable. Assuming you installed Wallaroo  according to the tutorial instructions you would do:

**Note:** If running in Docker, the `PATH` variable is pre-set for you to include the necessary directories to run this example.

```bash
export PATH="$PATH:$HOME/wallaroo-tutorial/wallaroo/machida/build:$HOME/wallaroo-tutorial/wallaroo/giles/sender:$HOME/wallaroo-tutorial/wallaroo/giles/receiver:$HOME/wallaroo-tutorial/wallaroo/utils/cluster_shutdown"
```

You can shut down the cluster with this command once processing has finished:

```bash
cluster_shutdown 127.0.0.1:5050
```

You can shut down Giles Sender and Giles Receiver by pressing `Ctrl-c` from their respective shells.
