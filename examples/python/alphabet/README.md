# Alphabet

## About The Application

This is an example application that takes "votes" for different letters of the alphabet and keeps a running total of the votes received for each letter. For each incoming message, it sends out a message with the total votes for that letter. The total number of votes for each letter are stored together in a single state object.

### Input

The inputs to the "Alphabet" application are the letter receiving the vote followed by a 32-bit integer representing the number of votes for this message, with the whole thing encoded in the [source message framing protocol](https://docs.wallaroolabs.com/python-tutorial/tcp-decoders-and-encoders/#framed-message-protocols). Here's an example input message, written as a Python string:

```
"\x00\x00\x00\x05A\x00\x00\x15\x34"
```

`\x00\x00\x00\x05` -- four bytes representing the number of bytes in the payload
`A` -- a single byte representing the letter "A", which is receiving the votes
`\x00\x00\x15\x34` -- the number `0x1534` (`5428`) represented as a big-endiant 32-bit integer

### Output

The messages are strings terminated with a newline, with the form `LETTER => VOTES` where `LETTER` is the letter and `VOTES` is the number of votes for said letter. Each incoming message generates one output message.

### Processing

The `decoder` function creates a `Votes` object with the letter being voted on and the number of votes it is receiving with this message. The `Votes` object is passed along with the state object that stores all of the vote totals to the `add_votes` state computation. The `add_votes` state computation then modifies the state to record the new total number of votes for the letter. It then creates a new `Votes` message, which is sent to the `encoder` function, which converts it into an outgoing message.

## Running Alphabet

In order to run the application you will need Machida, Giles Sender, Data Receiver, and the Cluster Shutdown tool. We provide instructions for building these tools yourself and we provide prebuilt binaries within a Docker container. Please visit our [setup](https://docs.wallaroolabs.com/python-installation/) instructions to choose one of these options if you have not already done so.
If you are using Python 3, replace all instances of `machida` with `machida3` in your commands.

You will need five separate shells to run this application (please see [starting a new shell](https://docs.wallaroolabs.com/python-tutorial/starting-a-new-shell/) for details depending on your installation choice). Open each shell and go to the `examples/python/alphabet` directory.

### Shell 1: Metrics

Start up the Metrics UI if you don't already have it running.

```bash
metrics_reporter_ui start
```

You can verify it started up correctly by visiting [http://localhost:4000](http://localhost:4000).

If you need to restart the UI, run the following.

```bash
metrics_reporter_ui restart
```

When it's time to stop the UI, run the following.

```bash
metrics_reporter_ui stop
```

If you need to start the UI after stopping it, run the following.

```bash
metrics_reporter_ui start
```

### Shell 2: Data Receiver

Run Data Receiver to listen for TCP output on `127.0.0.1` port `7002`:

```bash
data_receiver --ponythreads=1 --ponynoblock \
  --listen 127.0.0.1:7002
```

### Shell 3: Alphabet

Set `PATH` to refer to the directory that contains the `machida` executable. Set `PYTHONPATH` to refer to the current directory (where `alphabet.py` is) and the `machida` directory (where `wallaroo.py` is). Assuming you installed Wallaroo according to the tutorial instructions you would do:

Run `machida` with `--application-module alphabet`:

```bash
machida --application-module alphabet --in 127.0.0.1:7010 \
  --out 127.0.0.1:7002 --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 \
  --external 127.0.0.1:5050 --cluster-initializer --data 127.0.0.1:6001 \
  --name worker-name --ponythreads=1 --ponynoblock
```

### Shell 4: Sender

Send messages:

```bash
sender --host 127.0.0.1:7010 --file votes.msg \
  --batch-size 50 --interval 10_000_000 --messages 1000000 --binary \
  --msg-size 9 --repeat --ponythreads=1 --ponynoblock --no-write
```

## Shell 5: Shutdown

You can shut down the Wallaroo cluster with this command once processing has finished:

```bash
cluster_shutdown 127.0.0.1:5050
```

You can shut down Giles Sender and Data Receiver by pressing `Ctrl-c` from their respective shells.

You can shut down the Metrics UI with the following command.

```bash
metrics_reporter_ui stop
```
