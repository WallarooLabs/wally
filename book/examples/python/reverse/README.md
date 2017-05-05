# Reverse

The reverse application receives strings as input and outputs the reversed strings.

## Running Reverse

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

Run `machida` with `--application-module reverse`:

```bash
machida --application-module reverse -i 127.0.0.1:7010 -o 127.0.0.1:7002 \
  -m 127.0.0.1:8000 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -n worker-name \
  --ponythreads=1
```

In a third shell, send some messages:

```bash
../../../../giles/sender/sender --buffy 127.0.0.1:7010 --file words.txt \
--batch-size 5 --interval 100_000_000 --messages 150 --repeat \
--ponythreads=1
```
