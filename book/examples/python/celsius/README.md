# Celsius

This is an example of a stateless application that takes a floating point Celsius value and sends out a floating point Fahrenheit value.

You will need a working [Wallaroo Python API](/book/python/intro.md).

## Generating Data

The Celsius application takes a binary 32-bit float as its input, encoded in the [source message framing protocol](/book/appendix/writing-your-own-feed.md#source-message-framing-protocol).

A data generator is bundled with the application:

```bash
cd data_gen
python data_gen.py 1000000
```

Will generate a million messages.

Return to the `celsius` app directory for the [running](#running) instructions.

## Running Celsius

In a shell, start up the Metrics UI if you don't already have it running:

```bash
docker start mui
```

In a shell, set up a listener:

```bash
nc -l 127.0.0.1 7002 > celsius.out
```

In another shell, set up your environment variables if you haven't already done so. Assuming you installed Machida according to the tutorial instructions you would do:

```bash
export PYTHONPATH="$PYTHONPATH:.:$HOME/wallaroo-tutorial/wallaroo/machida"
export PATH="$PATH:$HOME/wallaroo-tutorial/wallaroo/machida/build"
```

Run `machida` with `--application-module celsius`:

```bash
machida --application-module celsius --in 127.0.0.1:7010 --out 127.0.0.1:7002 \
  --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 --data 127.0.0.1:6001 \
  --name worker-name \
  --ponythreads=1
```

In a third shell, send some messages:

```bash
../../../../giles/sender/sender --host 127.0.0.1:7010 --file data_gen/celsius.msg \
  --batch-size 50 --interval 10_000_000 --messages 1000000 --repeat \
  --ponythreads=1 --binary --msg-size 8
```

## Reading the Output

The output is binary data, formatted as a 4-byte message length header, followed by a 4 byte 32-bit floating point value.

You can read it with the following code stub:

```python
import struct


with open('celsius.out', 'rb') as f:
    while True:
        try:
            print struct.unpack('>Lf', f.read(8))
        except:
            break
```
