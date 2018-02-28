# Celsius

This is an example of a stateless application that takes a floating point Celsius value and sends out a floating point Fahrenheit value.

### Input

The inputs and outputs of the "Celsius" application are binary 32-bits float encoded in the [source message framing protocol](/book/appendix/tcp-decoders-and-encoders.md#framed-message-protocols). Here's an example message, written as a Go string:

```
"\x00\x00\x00\x04\x42\x48\x00\x00"
```

### Output

Celius will output messages that are the string representation of the converted Fahrenheit value. One entry per line. Each incoming message will generate a single corresponding output.

### Processing

The `Decoder`'s `Decode(...)` method creates a float from the value represented by the payload. The float value is then sent to the `Multiply` computation where it is multiplied by `1.8`, and the result of that computation is sent to the `Add` computation where `32` is added to it. The resulting float is then sent to the `Encoder`, which converts it to an outgoing sequence of bytes.

## Building Celsius

In the celsius directory, run `make`.

## Running Celsius

In order to run the application you will need Giles Sender, Data Receiver, and the Cluster Shutdown tool. To build them, please see the [Linux](/book/go/getting-started/linux-setup.md) or [MacOS](/book/go/getting-started/macos-setup.md) setup instructions.

You will need five separate shells to run this application. Open each shell and go to the `examples/go/celsius` directory.

### Shell 1: Metrics

Start up the Metrics UI if you don't already have it running:

```bash
docker start mui
```

You can verify it started up correctly by visiting [http://localhost:4000](http://localhost:4000).

If you need to restart the UI, run:

```bash
docker restart mui
```

When it's time to stop the UI, run:

```bash
docker stop mui
```

If you need to start the UI after stopping it, run:

```bash
docker start mui
```

### Shell 2: Data Receiver

Run `data_receiver` to listen for TCP output on `127.0.0.1` port `7002`:

```bash
../../../utils/data_receiver/data_receiver --listen 127.0.0.1:7002
```

### Shell 3: Celsius

Run `celsius`.

```bash
./celsius --in 127.0.0.1:7010 --out 127.0.0.1:7002 \
  --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 --data 127.0.0.1:6001 \
  --name worker-name --external 127.0.0.1:5050 --cluster-initializer \
  --ponythreads=1 --ponynoblock
```

### Shell 4: Sender

Send messages:

```bash
../../../giles/sender/sender --host 127.0.0.1:7010 \
  --file celsius.msg --batch-size 50 --interval 10_000_000 \
  --messages 500 --repeat --binary --msg-size 8 --no-write \
  --ponythreads=1 --ponynoblock
```

## Reading the Output

There will be a stream of output messages in the first shell (where you ran `data_receiver`).

## Shell 5: Shutdown

You can shut down the cluster with this command at any time:

```bash
../../../utils/cluster_shutdown/cluster_shutdown 127.0.0.1:5050
```

You can shut down Giles Sender and Data Receiver by pressing `Ctrl-c` from their respective shells.

You can shut down the Metrics UI with the following command:

```bash
docker stop mui
```
