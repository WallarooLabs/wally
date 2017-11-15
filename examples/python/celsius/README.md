# Celsius

## About The Application

This is an example of a stateless application that takes a floating point Celsius value and sends out a floating point Fahrenheit value.

### Input and Output

The inputs and outputs of the "Celsius" application are binary 32-bits float encoded in the [source message framing protocol](/book/core-concepts/decoders-and-encoders.md#framed-message-protocols#source-message-framing-protocol). Here's an example message, written as a Python string:

```
"\x00\x00\x00\x04\x42\x48\x00\x00"
```

`\x00\x00\x00\x04` -- four bytes representing the number of bytes in the payload

`\x42\x48\x00\x00` -- four bytes representing the 32-bit float `50.0`

### Processing

The `Decoder`'s `decode(...)` method creates a float from the value represented by the payload. The float value is then sent to the `Multiply` computation where it is multiplied by `1.8`, and the result of that computation is sent to the `Add` computation where `32` is added to it. The resulting float is then sent to the `Encoder`, which converts it to an outgoing sequence of bytes.

## Running Celsius

In order to run the application you will need Machida, Giles Sender, and the Cluster Shutdown tool. To build them, please see the [Linux](/book/getting-started/linux-setup.md) or [Mac OS](/book/getting-started/macos-setup.md) setup instructions. Alternatively, they could be run in Docker, please see the [Docker](/book/getting-started/docker-setup.md) setup instructions and our [Run an Application in Docker](/book/getting-started/run-a-wallaroo-application-docker.md) guide if you haven't already done so.

Note: If running in Docker, the relative paths are not necessary for binaries as they are all bound to the PATH within the container. You will not need to set the `PATH` variable and `PYTHONPATH` already includes the current working directory.

You will need three separate shells to run this application. Open each shell and go to the `examples/python/celsius` directory.

### Shell 1

Run `nc` to listen for TCP output on `127.0.0.1` port `7002`:

```bash
nc -l 127.0.0.1 7002 > celsius.out
```

### Shell 2

Set `PYTHONPATH` to refer to the current directory (where `celsius.py` is) and the `machida` directory (where `wallaroo.py` is). Set `PATH` to refer to the directory that contains the `machida` executable. Assuming you installed Machida according to the tutorial instructions you would do:

```bash
export PYTHONPATH="$PYTHONPATH:.:$HOME/wallaroo-tutorial/wallaroo/machida"
export PATH="$PATH:$HOME/wallaroo-tutorial/wallaroo/machida/build"
```

Run `machida` with `--application-module celsius`:

```bash
machida --application-module celsius --in 127.0.0.1:7010 --out 127.0.0.1:7002 \
  --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 --data 127.0.0.1:6001 \
  --name worker-name --external 127.0.0.1:5050 --cluster-initializer \
  --ponythreads=1 --ponynoblock
```

### Shell 3

Send messages:

```bash
../../../giles/sender/sender --host 127.0.0.1:7010 \
  --file celsius.msg --batch-size 50 --interval 10_000_000 \
  --messages 1000000 --repeat --binary --msg-size 8 --no-write \
  --ponythreads=1 --ponynoblock
```

## Reading the Output

The output data will be in the file that `nc` is writing to in shell 1. You can read the output data with the following code:

```python
import struct


with open('celsius.out', 'rb') as f:
    while True:
        try:
            print struct.unpack('>If', f.read(8))
        except:
            break
```

## Shutdown

You can shut down the cluster with this command once processing has finished:

```bash
../../../utils/cluster_shutdown/cluster_shutdown 127.0.0.1:5050
```

You can shut down Giles Sender by pressing `Ctrl-c` from its shell.
