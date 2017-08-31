# Alphabet Partitioned

This is an example application that will count the number of "votes" sent for
each letter of the alphabet, using paritioning.

You will need a working [Wallaroo Python API](/book/python/intro.md).

## Running Alphabet Partitioned

In a shell, start up the Metrics UI if you don't already have it running:

```bash
docker start mui
```

In another shell, run Giles Receiver to listen for messages:

```bash
../../../../giles/receiver/receiver --ponythreads=1 --ponynoblock \
  --listen 127.0.0.1:7002
```

In two other shells, export the current directories and machida directories to paths, then run the application main (initializer) worker and second worker:

Initializer:

```bash
export PYTHONPATH="$PYTHONPATH:.:$HOME/wallaroo-tutorial/wallaroo/machida"
export PATH="$PATH:$HOME/wallaroo-tutorial/wallaroo/machida/build"
machida --application-module alphabet_partitioned --in 127.0.0.1:7010 \
  --out 127.0.0.1:7002 --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 \
  --data 127.0.0.1:6001 --worker-count 2 --cluster-initializer \
  --external 127.0.1:6002 --ponythreads=1
```

Worker:

```bash
export PYTHONPATH="$PYTHONPATH:.:$HOME/wallaroo-tutorial/wallaroo/machida"
export PATH="$PATH:$HOME/wallaroo-tutorial/wallaroo/machida/build"
machida --application-module alphabet_partitioned --in 127.0.0.1:7010 \
  --out 127.0.0.1:7002 --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 \
  --data 127.0.0.1:6001 --worker-count 2 --name worker-2 \
  --external 127.0.1:6010 --ponythreads=1
```

In a fourth shell, send some messages

```bash
../../../../giles/sender/sender --host 127.0.0.1:7010 \
  --file votes.msg --batch-size 50 --interval 10_000_000 \
  --messages 1000000 --binary --msg-size 9 --repeat --ponythreads=1
```

The messages have a 32-bit big-endian integer that represents the message length, followed by a byte that represents the character that is being voted on, followed by a 32-bit big-endian integer that represents the number of votes received for that letter.  The output is a byte representing the character that is being voted on, followed by the total number of votes for that character.

Using these instructions, the output will be received by Giles Receiver and [stored to a file](/book/wallaroo-tools/giles-receiver.md#output-file-format) when the Giles Receiver process is killed. You can read it with the following code stub:

```python
import struct


with open('received.txt', 'rb') as f:
    while True:
        try:
           # Length, Timestamp, Character, Vote count
            print struct.unpack('>LQ1sL', f.read(17))
        except:
            break
```
