# Celsius

This is an example implementation of an exchange's matching engine, for a single ticker, which creates trade, L1 and L2 feeds.
It also prints a copy of the L1 feed to stdout.

You will need a working [Wallaroo Python API](/book/python-wactor/intro.md).

## Generating Data

The matching-engine application takes a binary order feed as its input, encoded in the [source message framing protocol](/book/appendix/writing-your-own-feed.md#source-message-framing-protocol).

A data generator is bundled with the application:

```bash
cd data_gen
python data_gen.py 1000000
```

Will generate one million messages.

Return to the `matching-engine` app directory for the [running](#running) instructions.

## Running matching-engine

In a shell, start up the Metrics UI if you don't already have it running:

```bash
docker start mui
```

In a shell, set up listeners for each feed:

```bash
nc -l 127.0.0.1 7002 > matching-engine-executions.out & \
  nc -l 127.0.0.1 7003 > matching-engine-L1.out & \
  nc -l 127.0.0.1 7004 > matching-engine-L2.out &
```

In another shell, set up your environment variables if you haven't already done so. Assuming you installed Atkin according to the tutorial instructions you would do:

```bash
export PYTHONPATH="$PYTHONPATH:.:$HOME/wallaroo-tutorial/wallaroo/atkin"
export PATH="$PATH:$HOME/wallaroo-tutorial/wallaroo/atkin/build"
```

Run `atkin` with `--application-module matching-engine`:

```bash
atkin --application-module matching-engine --in 127.0.0.1:7010 \
  --out 127.0.0.1:7002,127.0.0.1:7003,127.0.0.1:7004 \
  --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 --data 127.0.0.1:6001 \
  --name worker-name --cluster-initializer --ponythreads=1
```

In a third shell, send some messages:

```bash
../../../../giles/sender/sender --host 127.0.0.1:7010 --file data_gen/orders.msg \
  --batch-size 50 --interval 10_000_000 --messages 1000000 --repeat \
  --ponythreads=1 --binary --msg-size 8
```

## Reading the Output

The output is binary data, formatted in a slightly different way for each feed. You can read it with the following code stubs.

For the Trade feed:
```python
import struct


with open('matching-engine-executions.out', 'rb') as f:
    while True:
        try:
            print struct.unpack('>LfL', f.read(12))
        except:
            break
```


For the L1 and L2 feeds:
```python
import struct


with open('matching-engine-L1.out', 'rb') as f:
    while True:
        try:
            print struct.unpack('>LsfL', f.read(13))
        except:
            break
```

"T" stands for Trade, "B" for Bid and "A" for Ask. The first number if price,
the second is quantity.
