# Sequence Window - Partitioned

As with [Sequence window](/examples/python/sequence/), Sequence Window - Partitioned is a simple application that holds state in the form of a ring buffer.
It receives integers from the natural sequence {1,2,3,4,...,n} as its input, and outputs a window of the last 4 values it has seen, in the order they were seen as a list, with the left-most value being the oldest.

You will need a working [Wallaroo Python API](/book/python/intro.md).

In the partitioned version of this application, states are partitioned using a modulo 2 operation

```python
class SequencePartitionFunction(object):
    def partition(self, data):
        return data % 2
```

And the corresponding partitions list is

```python
sequence_partitions = [0, 1]
```

Additionally, this application differs from the non-partitioned version in that it uses `ApplicationBuilder.to_state_partition` instead of `ApplicationBuilder.to_stateful`.

Apart from that, the applications are the same

## Running Sequence - Partitioned

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
machida --application-module sequence_partitioned --in 127.0.0.1:7010 \
  --out 127.0.0.1:7002 --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 \
  --data 127.0.0.1:6001 --external 127.0.0.1:5050 --worker-count 2
  --cluster-initializer --ponythreads=1
```

Worker:

```bash
export PYTHONPATH="$PYTHONPATH:.:$HOME/wallaroo-tutorial/wallaroo/machida"
export PATH="$PATH:$HOME/wallaroo-tutorial/wallaroo/machida/build"
machida --application-module sequence_partitioned --in 127.0.0.1:7010 \
  --out 127.0.0.1:7002 --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 \
  --external 127.0.0.1:5051 --name worker-2 --ponythreads=1
```

In a third shell, send some messages:

```bash
../../../../giles/sender/sender --host 127.0.0.1:7010 --batch-size 10 \
  --interval 100_000_000 --ponythreads=1 --binary --msg-size 12 --no-write \
  --u64 --messages 100
```

Shut down cluster once finished processing:

```bash
../../../../utils/cluster_shutdown/cluster_shutdown 127.0.0.1:5050
```
