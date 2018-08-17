# Reverse

## About The Application

This is an example application that receives strings as input and outputs the reversed strings.

### Input

The inputs of the "Reverse" application are strings encoded in the [source message framing protocol](/book/core-concepts/decoders-and-encoders.md#framed-message-protocols#source-message-framing-protocol). Here's an example input message, written as a Go string:

```
"\x00\x00\x00\x05hello"
```

`\x00\x00\x00\x05` -- four bytes representing the number of bytes in the payload

`hello` -- the string `"hello"`

### Output

The outputs of the application are strings followed by newlines. Here's an example output message, written as a Go string:

`olleh\n` -- the string `"olleh"` (`"hello"` reversed)

### Processing

The `Decoder`'s `Decode(...)` method creates a string from the value represented by the payload. The string is then sent to the `Reverse` computation where it is reversed. The reversed string is then sent to `Encoder`'s `Encode(...)` method, where a newline is appended to the string.

## Building Reverse

In order to build the application you will need a Wallaroo environment. Please visit our [setup](https://docs.wallaroolabs.com/book/go/getting-started/choosing-an-installation-option.html) instructions if you have not already done so.

You will need a new shell to build this application (please see [starting a new shell](https://docs.wallaroolabs.com/book/getting-started/starting-a-new-shell.html) for details). Open a shell and go to the `examples/go/reverse` directory.

In the reverse directory, run `make`.

## Running Reverse

In order to run the application you will need Giles Sender, Data Receiver, and the Cluster Shutdown tool. We provide instructions for building these tools yourself. Please visit our [setup](https://docs.wallaroolabs.com/book/go/getting-started/choosing-an-installation-option.html) instructions if you have not already done so.

You will need five separate shells to run this application (please see [starting a new shell](https://docs.wallaroolabs.com/book/getting-started/starting-a-new-shell.html) for details). Open each shell and go to the `examples/go/reverse` directory.

### Shell 1: Metrics

Start up the Metrics UI if you don't already have it running:

```bash
metrics_reporter_ui start
```

You can verify it started up correctly by visiting [http://localhost:4000](http://localhost:4000).

If you need to restart the UI, run:

```bash
metrics_reporter_ui restart
```

When it's time to stop the UI, run:

```bash
metrics_reporter_ui stop
```

If you need to start the UI after stopping it, run:

```bash
metrics_reporter_ui start
```

### Shell 2: Data Receiver

Run `data_receiver` to listen for TCP output on `127.0.0.1` port `7002`:

```bash
data_receiver/data_receiver --listen 127.0.0.1:7002
```

### Shell 3: Reverse

```bash
./reverse --in 127.0.0.1:7010 --out 127.0.0.1:7002 \
  --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 --data 127.0.0.1:6001 \
  --name worker-name --external 127.0.0.1:5050 --cluster-initializer \
  --ponythreads=1 --ponynoblock
```

### Shell 4: Sender

Send some messages:

```bash
sender --host 127.0.0.1:7010 --file words.txt \
  --batch-size 5 --interval 100_000_000 --messages 150 --repeat \
  --ponythreads=1 --ponynoblock --no-write
```

## Reading the Output

The output will be printed to the console in the first shell. Each line should be the reverse of a word found in the `words.txt` file.

## Shell 5: Shutdown

You can shut down the cluster with this command at any time:

```bash
cluster_shutdown 127.0.0.1:5050
```

You can shut down Giles Sender and Data Receiver by pressing `Ctrl-c` from their respective shells.

You can shut down the Metrics UI with the following command:

```bash
metrics_reporter_ui stop
```
