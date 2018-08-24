# Celsius

## About The Application

This is an example of a stateless application that takes a floating point Celsius value and sends out a floating point Fahrenheit value.

### Input

The inputs of the "Celsius" application are binary 32-bits float encoded in the [source message framing protocol](https://docs.wallaroolabs.com/book/appendix/tcp-decoders-and-encoders.html#framed-message-protocols#source-message-framing-protocol). Here's an example message, written as a Python string:

```
"\x00\x00\x00\x04\x42\x48\x00\x00"
```

`\x00\x00\x00\x04` -- four bytes representing the number of bytes in the payload

`\x42\x48\x00\x00` -- four bytes representing the 32-bit float `50.0`

### Output

Celius will output messages that are the string representation of the converted Fahrenheit value. One entry per line. Each incoming message will generate a single corresponding output.

### Processing

The `decoder` function creates a float from the value represented by the payload. The float value is then sent to the `multiply` computation where it is multiplied by `1.8`, and the result of that computation is sent to the `add` computation where `32` is added to it. The resulting float is then sent to the `encoder` function, which converts it to a string representation.

## Running Celsius

In order to run the application you will need Machida, Giles Sender, Data Receiver, and the Cluster Shutdown tool. We provide instructions for building these tools yourself and we provide prebuilt binaries within a Docker container. Please visit our [setup](https://docs.wallaroolabs.com/book/getting-started/choosing-an-installation-option.html) instructions to choose one of these options if you have not already done so.

You will need five separate shells to run this application (please see [starting a new shell](https://docs.wallaroolabs.com/book/getting-started/starting-a-new-shell.html) for details depending on your installation choice). Open each shell and go to the `examples/python/celsius` directory.

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

### Shell 3: Celsius

Run `machida` with `--application-module celsius`:

```bash
machida --application-module celsius --in 127.0.0.1:7010 --out 127.0.0.1:7002 \
  --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 --data 127.0.0.1:6001 \
  --name worker-name --external 127.0.0.1:5050 --cluster-initializer \
  --ponythreads=1 --ponynoblock
```

### Shell 4: Sender

Send messages:

```bash
sender --host 127.0.0.1:7010 \
  --file celsius.msg --batch-size 50 --interval 10_000_000 \
  --messages 1000000 --repeat --binary --msg-size 8 --no-write \
  --ponythreads=1 --ponynoblock
```

## Shell 5: Shutdown

You can shut down the cluster with this command at any time:

```bash
cluster_shutdown 127.0.0.1:5050
```

You can shut down Giles Sender and Data Receiver by pressing `Ctrl-c` from their respective shells.

You can shut down the Metrics UI with the following command.

```bash
metrics_reporter_ui stop
```
