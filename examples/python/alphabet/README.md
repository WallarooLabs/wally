# Alphabet

This is an example application that will count the number of "votes" sent for
each letter of the alphabet.

You will need a working [Wallaroo Python API](/book/python/intro.md).

## Running Alphabet

In a shell, start up the Metrics UI if you don't already have it running:

```bash
docker start mui
```

In a shell, set up a listener:

```bash
nc -l 127.0.0.1 7002 > alphabet.out
```

In another shell, set up your environment variables if you haven't already done so. Assuming you installed Machida according to the tutorial instructions you would do:

```bash
export PYTHONPATH="$PYTHONPATH:.:$HOME/wallaroo-tutorial/wallaroo/machida"
export PATH="$PATH:$HOME/wallaroo-tutorial/wallaroo/machida/build"
```

Run `machida` with `--application-module alphabet`.

```bash
machida --application-module alphabet --in 127.0.0.1:7010 \
  --out 127.0.0.1:7002 --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 \
  --external 127.0.0.1:5050 --cluster-initializer --data 127.0.0.1:6001 \
  --name worker-name --ponythreads=1
```

In a third shell, send some messages

```bash
../../../giles/sender/sender --host 127.0.0.1:7010 --file votes.msg \
  --batch-size 50 --interval 10_000_000 --messages 1000000 --binary \
  --msg-size 9 --repeat --ponythreads=1
```

The messages have a 32-bit big-endian integer that represents the message length, followed by a byte that represents the character that is being voted on, followed by a 32-bit big-endian integer that represents the number of votes received for that letter.  The output is a byte representing the character that is being voted on, followed by the total number of votes for that character. You can view the output file with a tool like `hexdump`.

## Reading the Output

The output is binary data, formatted as a 4-byte message length header, followed by a character, followed by 4 byte 32-bit uint.

You can read it with the following code stub:

```python
import struct


with open('alphabet.out', 'rb') as f:
    while True:
        try:
            print struct.unpack('>LsL', f.read(9))
        except:
            break
```

## Shutting down the cluster

To shut down the cluster, you will need to use the `cluster_shutdown` tool.
```bash
../../../utils/cluster_shutdown/cluster_shutdown 127.0.0.1:5050
```
