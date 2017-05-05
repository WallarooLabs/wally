# Sequence Window

Sequence window is a simple application that holds state in the form of a ring buffer.
It receives integers from the natural sequence {1,2,3,4,...,n} as its input, and outputs a window of the last 4 values it has seen, in the order they were seen as a list, with the left-most value being the oldest.

## Running Sequence

In a shell, start up the Metrics UI if you don't already have it running:

```bash
docker start mui
```

In a shell, set up a listener:

```bash
nc -l 127.0.0.1 7002
```

In another shell, export the current directory and `wallaroo.py` directories to `PYTHONPATH`:

```bash
export PYTHONPATH="$PYTHONPATH:.:../../../../machida"
```

Export the machida binary directory to `PATH`:

```bash
export PATH="$PATH:../../../../machida/build"
```

Run `machida` with `--application-module sequence`:

```bash
machida -i 127.0.0.1:7010 -o 127.0.0.1:7002 -m 127.0.0.1:8000 \
-c 127.0.0.1:6000 -d 127.0.0.1:6001 -n worker-name --ponythreads=1 \
--application-module sequence
```

In a third shell, send some messages:

```bash
../../../../giles/sender/sender -b 127.0.0.1:7010 -s 10 -i 100_000_000 \
--ponythreads=1 -y -g 12 -w -u -m 100
```
