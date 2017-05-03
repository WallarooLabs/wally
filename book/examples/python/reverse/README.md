# Reverse Word

Export the current directory as `PYTHONPATH`:

```bash
export PYTHONPATH=.
```

Set up a listener:

```bash
nc -l 127.0.0.1 7002
```

Run `dianoga` with `--wallaroo-module reverse_word`:

```bash
build/dianoga -i 127.0.0.1:7010 -o 127.0.0.1:7002 -m 127.0.0.1:8000 \
-c 127.0.0.1:6000 -d 127.0.0.1:6001 -n worker-name --ponythreads=1 \
--wallaroo-module reverse_word
```

Send some messages:

```
../../giles/sender/sender --buffy 127.0.0.1:7010 --file ./words.txt \
--batch-size 5 --interval 100_000_000 --messages 150 --repeat \
--ponythreads=1
```
