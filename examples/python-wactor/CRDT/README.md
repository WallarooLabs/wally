# CRDT Window

The CRDT app has two actor roles: counter and accumulator. There are more than
one counter but only a single accumulator. Each counter counts independently and
sends its results to the accumulator, whilst also implementing a loose gossip
protocol.

You will need a working [WActor Python API](/book/python-wactor/intro.md).

## Running CRDT

In a shell, start up the Metrics UI if you don't already have it running:

```bash
docker start mui
```

In a shell, set up a listener:

```bash
nc -l 127.0.0.1 7002
```

In another shell, set up your environment variables if you haven't already done so. Assuming you installed Atkin according to the tutorial instructions you would do:

```bash
export PYTHONPATH="$PYTHONPATH:.:$HOME/wallaroo-tutorial/wallaroo/atkin"
export PATH="$PATH:$HOME/wallaroo-tutorial/wallaroo/atkin/build"
```

Run `atkin` with `--application-module CRDT`:

```bash
atkin --application-module CRDT --in 127.0.0.1:7010 --out 127.0.0.1:7002 \
  --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 --data 127.0.0.1:6001 \
  --external 127.0.0.1:5050 --cluster-initializer --name worker-name \
  --ponythreads=1
```

In a third shell, send some messages:

```bash
../../../../giles/sender/sender --host 127.0.0.1:7010 --batch-size 10 \
  --interval 100_000_000 --ponythreads=1 --binary --msg-size 12 --no-write \
  --u64 --messages 100
```

##Output

You should expect to see messages on screen about successful gossip and counting:
```
round 0: GCounter(0)
accumulator act report: GCounter(0)
round 1: GCounter(0)
accumulator act report: GCounter(0)
round 2: GCounter(11)
accumulator act report: GCounter(11)
round 3: GCounter(15)
accumulator act report: GCounter(15)
round 4: GCounter(17)
accumulator act report: GCounter(17)
round 5: GCounter(33)
```

## Shutting down cluster once finished processing

```bash
../../../../utils/cluster_shutdown/cluster_shutdown 127.0.0.1:5050
```
