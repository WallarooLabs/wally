# Sequence Window

Sequence window is a simple application that holds state in the form of a ring buffer.
It receives integers from the natural sequence {1,2,3,4,...,n} as its input, and outputs a window of the last 4 values it has seen, in the order they were seen as a list, with the left-most value being the oldest.

You will need a working [Wallaroo Python API](/book/python/intro.md).

## Running Sequence

In a shell, start up the Metrics UI if you don't already have it running:

```bash
docker start mui
```

In a shell, set up a listener:

```bash
nc -l 127.0.0.1 7002
```

In another shell, set up your environment variables if you haven't already done so. Assuming you installed Machida according to the tutorial instructions you would do:

```bash
export PYTHONPATH="$PYTHONPATH:.:$HOME/wallaroo-tutorial/wallaroo/machida"
export PATH="$PATH:$HOME/wallaroo-tutorial/wallaroo/machida/build"
```

Run `machida` with `--application-module sequence`:

```bash
machida --application-module sequence --in 127.0.0.1:7010 --out 127.0.0.1:7002 \
  --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 --data 127.0.0.1:6001 \
  --name worker-name \
  --ponythreads=1
```

In a third shell, send some messages:

```bash
../../../../giles/sender/sender --host 127.0.0.1:7010 --batch-size 10 \
  --interval 100_000_000 --ponythreads=1 --binary --msg-size 12 --no-write \
  --u64 --messages 100
```
